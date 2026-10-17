// Run locally, or over kubectl exec stdin. No dependencies outside Node.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
const ownedTab=n=>n.type==='tab' && (n.label==='PCI_Interface'||/^M\d+_PCI-/.test(n.label||''));
export function uninstallFlows(envelope,manifest){
 if(manifest===null&&envelope?.rev&&Array.isArray(envelope.flows)){
  if(envelope.flows.some(ownedTab))throw Error('PCI-UNINSTALL-MISSING-OWNERSHIP');
  return {rev:envelope.rev,flows:envelope.flows};
 }
 if(!envelope?.rev||!Array.isArray(envelope.flows)||manifest?.version!==1||!Array.isArray(manifest.nodes))throw Error('PCI-UNINSTALL-INVALID-MANIFEST');
 const ids=new Set(manifest.nodes),tabs=new Set(envelope.flows.filter(n=>ids.has(n.id)&&ownedTab(n)).map(n=>n.id));
 const removed=new Set(envelope.flows.filter(n=>ids.has(n.id)||tabs.has(n.z)).map(n=>n.id));
 const flows=envelope.flows.filter(n=>!removed.has(n.id));
 for(const n of flows){
  if((n.wires||[]).flat().some(id=>removed.has(id))||(n.links||[]).some(id=>removed.has(id)))throw Error('PCI-UNINSTALL-FOREIGN-FLOW-REFERENCE');
  if(Object.entries(n).some(([k,v])=>!['id','z','type','name','label','info','wires','links'].includes(k)&&typeof v==='string'&&removed.has(v)))throw Error('PCI-UNINSTALL-FOREIGN-CONFIG-REFERENCE');
 }
 return {rev:envelope.rev,flows};
}
function regular(file){if(!fs.existsSync(file))return false;const stat=fs.lstatSync(file);if(!stat.isFile()||stat.isSymbolicLink())throw Error('PCI-ARTIFACT-NONREGULAR-FILE');return true;}
function leaf(name){if(typeof name!=='string'||!name||path.basename(name)!==name||name==='.'||name==='..')throw Error('PCI-ARTIFACT-INVALID-NAME');return name;}
function save(file,data){fs.writeFileSync(file+'.tmp',JSON.stringify(data),{mode:0o600});fs.renameSync(file+'.tmp',file);}
export function snapshotUI(state,ui,names,adopt=false){
 fs.mkdirSync(state,{recursive:true,mode:0o700});const file=path.join(state,'ui.json');
 const manifest=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)): {version:1,files:{},adopted:adopt};
 if(manifest.version!==1)throw Error('PCI-ARTIFACT-INVALID-MANIFEST');
 for(const name of names.map(leaf))if(!manifest.files[name]){
  const src=path.join(ui,name),present=regular(src)&&!adopt;
  manifest.files[name]={original:present?fs.readFileSync(src).toString('base64'):null,installed:null};
 }
 save(file,manifest);return manifest;
}
export function recordUI(state,ui){
 const file=path.join(state,'ui.json'),manifest=JSON.parse(fs.readFileSync(file));
 for(const [name,value]of Object.entries(manifest.files)){
  const current=path.join(ui,leaf(name));if(!regular(current))throw Error('PCI-ARTIFACT-UPLOAD-INCOMPLETE');value.installed=digest(fs.readFileSync(current));
 }save(file,manifest);
}
export function restoreUI(state,ui,checkOnly=false){
 const file=path.join(state,'ui.json'),manifest=JSON.parse(fs.readFileSync(file));
 if(manifest.version!==1)throw Error('PCI-ARTIFACT-INVALID-MANIFEST');
 for(const [name,value]of Object.entries(manifest.files)){
  const target=path.join(ui,leaf(name));const exists=regular(target),bytes=exists?fs.readFileSync(target):null;
  if(bytes && digest(bytes)!==value.installed && !(value.original!==null&&bytes.equals(Buffer.from(value.original,'base64'))))throw Error('PCI-UNINSTALL-UI-MODIFIED: '+name);
 }
 if(checkOnly)return;
 for(const [name,value]of Object.entries(manifest.files)){
  const target=path.join(ui,leaf(name));if(value.original===null)fs.rmSync(target,{force:true});else fs.writeFileSync(target,Buffer.from(value.original,'base64'));
 }
}
async function cli(){const [command,...args]=process.argv.slice(2);
 if(command==='snapshot-ui'){const [state,ui,names,adopt]=args;snapshotUI(state,ui,JSON.parse(names),adopt==='true');}
 else if(command==='record-ui')recordUI(...args);
 else if(command==='check-ui')restoreUI(...args,true);
 else if(command==='restore-ui')restoreUI(...args);
 else if(command==='uninstall-flows'){const [input,manifest,output]=args;fs.writeFileSync(output,JSON.stringify(uninstallFlows(JSON.parse(fs.readFileSync(input)),JSON.parse(fs.readFileSync(manifest)))),{mode:0o600});}
 else throw Error('PCI-ARTIFACT-UNKNOWN-COMMAND');
}
if(process.argv[1]==='-'||import.meta.url===pathToFileURL(process.argv[1]||'').href)await cli();
