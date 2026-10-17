// SPDX-License-Identifier: Apache-2.0
// Uninstall removes only fields owned by PCI. A saved whole Deployment is an
// identity/baseline record, never authority to overwrite later operator edits.
import fs from 'node:fs';
import {isDeepStrictEqual} from 'node:util';
import {pathToFileURL} from 'node:url';

export function restoreRuntime(original, current, {namespace, deployment, container}) {
  for (const value of [original, current]) {
    if (value?.metadata?.namespace !== namespace || value.metadata.name !== deployment)
      throw Error('PCI-UNINSTALL-IDENTITY');
  }
  if (!original.metadata.uid || original.metadata.uid !== current.metadata.uid || !current.metadata.resourceVersion)
    throw Error('PCI-UNINSTALL-IDENTITY');
  const spec = structuredClone(current.spec);
  const pod = spec.template.spec, before = original.spec.template.spec;
  const target = pod.containers.find(c => c.name === container);
  const previous = before.containers.find(c => c.name === container);
  if (!target || !previous) throw Error('PCI-UNINSTALL-CONTAINER');
  const annotation='fap-pci.xfsc.org/helper-runtime',encoded=spec.template.metadata?.annotations?.[annotation];
  if(encoded){
    const journal=JSON.parse(encoded);if(journal.version!==1)throw Error('PCI-UNINSTALL-JOURNAL');
    function restoreFields(target,field,records){
      if(!records)return;
      const values=target[field]||[];
      for(const [name,record] of Object.entries(records)){
        const index=values.findIndex(v=>v.name===name),live=index<0?null:values[index];
        if(!isDeepStrictEqual(live,record.applied))throw Error('PCI-UNINSTALL-HELPER-CONFLICT');
        if(index>=0)values.splice(index,1);
        if(record.before)values.push(structuredClone(record.before));
      }
      if(values.length)target[field]=values;else delete target[field];
    }
    // Validate foreign consumers before removing a helper volume.
    for(const [name,record]of Object.entries(journal.volumes||{}))if(!record.before){
      for(const c of [...pod.containers,...(pod.initContainers||[])]){
        if((c.volumeMounts||[]).some(m=>m.name===name)&&!journal.containers?.[c.name]?.volumeMounts?.[name])throw Error('PCI-UNINSTALL-FOREIGN-VOLUME-REFERENCE');
      }
    }
    for(const [name,record]of Object.entries(journal.containers||{})){
      const c=pod.containers.find(c=>c.name===name);if(!c)throw Error('PCI-UNINSTALL-HELPER-CONFLICT');
      restoreFields(c,'env',record.env);restoreFields(c,'volumeMounts',record.volumeMounts);
    }
    restoreFields(pod,'volumes',journal.volumes);delete spec.template.metadata.annotations[annotation];
  }
  const managedMounts = new Set(['fap-pci-secrets', 'fap-pci-native-tls']);
  function restoreList(live, baseline, owned, key) {
    const result = (live || []).filter(value => !owned(value));
    for (const value of baseline || []) if (owned(value)) {
      // A foreign replacement at the same mount/name is not discarded.
      if (result.some(other => key(other) === key(value))) throw Error('PCI-UNINSTALL-FIELD-CONFLICT');
      result.push(structuredClone(value));
    }
    return result;
  }
  target.envFrom = restoreList(target.envFrom, previous.envFrom,
    value => value.configMapRef?.name === 'fap-pci-config' || value.secretRef?.name === 'fap-pci-runtime',
    value => value.configMapRef?.name || value.secretRef?.name);
  target.volumeMounts = restoreList(target.volumeMounts, previous.volumeMounts,
    value => managedMounts.has(value.name), value => value.mountPath);
  // A later sidecar may deliberately depend on a PCI trust volume. Refuse
  // before any mutation rather than remove a volume that it still uses.
  const used = pod.containers.filter(c => c !== target).concat(pod.initContainers || [])
    .flatMap(c => (c.volumeMounts || []).map(m => m.name));
  if (used.some(name => managedMounts.has(name) && !(before.volumes || []).some(v => v.name === name)))
    throw Error('PCI-UNINSTALL-FOREIGN-VOLUME-REFERENCE');
  pod.volumes = restoreList(pod.volumes, before.volumes, value => managedMounts.has(value.name), value => value.name);
  if (pod.serviceAccountName === 'fap-pci-orce') {
    if (Object.hasOwn(before, 'serviceAccountName')) pod.serviceAccountName = before.serviceAccountName;
    else delete pod.serviceAccountName;
    if (pod.automountServiceAccountToken === true) {
      if (Object.hasOwn(before, 'automountServiceAccountToken')) pod.automountServiceAccountToken = before.automountServiceAccountToken;
      else delete pod.automountServiceAccountToken;
    }
  }
  for (const name of ['fap-pci.xfsc.org/version', 'fap-pci.xfsc.org/config-hash']) {
    const annotations = spec.template.metadata?.annotations;
    if (!annotations) continue;
    const prior = original.spec.template.metadata?.annotations;
    if (prior && Object.hasOwn(prior, name)) annotations[name] = prior[name];
    else delete annotations[name];
  }
  // Keep the live data mount, resource limits, replica count, image, probes,
  // other containers and operator annotations. Never reintroduce ephemeral data.
  return [
    {op:'test', path:'/metadata/uid', value:current.metadata.uid},
    {op:'test', path:'/metadata/resourceVersion', value:current.metadata.resourceVersion},
    {op:'replace', path:'/spec', value:spec},
  ];
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  const [snapshotFile, currentFile, outputFile, namespace, deployment, container] = process.argv.slice(2);
  try {
    const secret = JSON.parse(fs.readFileSync(snapshotFile));
    const original = JSON.parse(Buffer.from(secret.data['deployment.json'], 'base64'));
    const patch = restoreRuntime(original, JSON.parse(fs.readFileSync(currentFile)), {namespace, deployment, container});
    fs.writeFileSync(outputFile, JSON.stringify(patch), {mode:0o600});
  } catch (error) {
    console.error(JSON.stringify({event:'pci.uninstall.validation', status:'failed',
      code:/^PCI-UNINSTALL-[A-Z-]+$/.test(error.message) ? error.message : 'PCI-UNINSTALL-SNAPSHOT'}));
    process.exitCode = 1;
  }
}
