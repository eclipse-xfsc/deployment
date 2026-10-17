// Imported into an operator's deployment ORCE, not the PCI application runtime.
// Only an enum comes from the message. Executable/configuration paths come from
// administrator-managed environment variables, never HTTP input or msg fields.
const operation=String(msg.operation||'');
if(!['deploy','upgrade','uninstall'].includes(operation)){
 const result={event:'pci.automation.result',status:'failed',code:'PCI-AUTOMATION-OPERATION'};
 flow.set('pci.deployment',result);node.send({payload:result});return;
}
if(node.pciBusy){node.send({payload:{event:'pci.automation.result',status:'failed',code:'PCI-AUTOMATION-BUSY'}});return;}
const root=env.get('PCI_RELEASE_ROOT'),config=env.get('PCI_DEPLOY_CONFIG');
if(!root?.startsWith('/')||!config?.startsWith('/')){const result={event:'pci.automation.result',status:'failed',code:'PCI-AUTOMATION-CONFIG'};flow.set('pci.deployment',result);node.send({payload:result});return;}
node.pciBusy=true;node.status({fill:'blue',shape:'dot',text:operation});
const child=childProcess.spawn('python3',[path.join(root,'scripts/lifecycle.py'),operation,'--config',config],{cwd:root,stdio:['ignore','pipe','ignore']});
let buffer='',result=null;
child.stdout.on('data',chunk=>{
 buffer+=chunk.toString('utf8');if(buffer.length>65536){child.kill();return;}
 let end;while((end=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,end);buffer=buffer.slice(end+1);try{
 const event=JSON.parse(line);if(!['pci.automation.step','pci.automation.result'].includes(event.event))continue;
 const safe={};for(const key of ['event','runId','operation','version','status','step','code','elapsedMs','namespace','deployment','detail','nextStep','exitCode'])if(['string','number'].includes(typeof event[key]))safe[key]=event[key];
 flow.set('pci.deployment',safe);node.send({payload:safe});if(event.event==='pci.automation.result')result=safe;
 }catch{}}
});
function finished(){node.pciBusy=false;node.status({fill:result?.status==='complete'?'green':'red',shape:'dot',text:result?.status||'failed'});if(!result){result={event:'pci.automation.result',status:'failed',code:'PCI-AUTOMATION-RUNNER'};flow.set('pci.deployment',result);node.send({payload:result});}node.done();}
child.once('error',()=>{});child.once('close',finished);return;
