#!/usr/bin/env python3
"""Validate and remove only helper trust owned by this runtime installation."""
import argparse,json,subprocess
p=argparse.ArgumentParser();p.add_argument('phase',choices=['plan','check','apply']);p.add_argument('namespace');p.add_argument('deployment');p.add_argument('plan');a=p.parse_args()
k=['kubectl','-n',a.namespace]
def get(kind,name):
    raw=subprocess.check_output(k+['get',kind,name,'--ignore-not-found','-o','json']);return json.loads(raw) if raw else None
runtime=get('deployment',a.deployment);uid=runtime['metadata']['uid']
if a.phase=='plan':
    items=[]
    for kind,name in [('secrets','fap-pci-observability-tls'),('configmaps','fap-pci-observability-trust'),('secrets','fap-pci-identity')]:
        obj=get(kind,name)
        if not obj:continue
        labels=obj['metadata'].get('labels',{})
        if labels.get('app.kubernetes.io/part-of')!='fap-pci' or labels.get('fap-pci.xfsc.org/runtime-uid')!=uid:raise SystemExit('PCI-UNINSTALL-HELPER-OWNER: rerun the current helper to enroll legacy resources')
        items.append({'kind':kind,'name':name,'uid':obj['metadata']['uid']})
    with open(a.plan,'w') as f:json.dump({'runtimeUid':uid,'items':items},f)
else:
    with open(a.plan) as f:plan=json.load(f)
    if plan['runtimeUid']!=uid:raise SystemExit('PCI-UNINSTALL-HELPER-RUNTIME-REPLACED')
    pending=[]
    for entry in plan['items']:
        obj=get(entry['kind'],entry['name'])
        if not obj:continue
        if obj['metadata']['uid']!=entry['uid'] or obj['metadata'].get('labels',{}).get('fap-pci.xfsc.org/runtime-uid')!=uid:raise SystemExit('PCI-UNINSTALL-HELPER-REPLACED')
        if entry['name']=='fap-pci-identity' and obj.get('data'):raise SystemExit('PCI-UNINSTALL-IDENTITY-CREDENTIALS-REMAIN')
        pending.append((entry,obj))
    if a.phase=='check':raise SystemExit(0)
    for entry,obj in pending:
        body={'apiVersion':'v1','kind':'DeleteOptions','preconditions':{'uid':entry['uid'],'resourceVersion':obj['metadata']['resourceVersion']},'propagationPolicy':'Foreground'}
        path='/api/v1/namespaces/'+a.namespace+'/'+entry['kind']+'/'+entry['name']
        subprocess.run(k+['delete','--raw',path,'-f','-'],input=json.dumps(body),text=True,check=True,stdout=subprocess.DEVNULL)
