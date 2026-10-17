#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Import explicit trusted pre-helper values into the rc.5 CAS restore journal.
Input: {deploymentUID, namespace, deployment, container, env, volumeMounts,
volumes}. Each field is a map of helper-owned name -> {before, applied}; null
before means absent. No values are inferred from a current installation.
"""
import argparse,copy,json,os,subprocess
from pathlib import Path
from runtime_ownership import ANNOTATION
ALLOWED_ENV={'PCI_PARTICIPANT_ALLOWED_HOSTS','PCI_PARTICIPANT_PRIVATE_ADDRESSES','PCI_PARTICIPANT_JWT_ISSUERS','PCI_OTLP_HTTP_ENDPOINT','PCI_OTLP_CA_FILE'}
ALLOWED_VOLUMES={'pci-telemetry-trust'}
def plan(current,baseline):
    m=current['metadata']
    if any(m.get(k)!=baseline[v] for k,v in [('uid','deploymentUID'),('namespace','namespace'),('name','deployment')]):raise ValueError('Legacy baseline identity mismatch')
    spec=copy.deepcopy(current['spec']);pod=spec['template']['spec'];container=next(c for c in pod['containers'] if c['name']==baseline['container'])
    annotations=spec['template'].setdefault('metadata',{}).setdefault('annotations',{})
    journal=json.loads(annotations.get(ANNOTATION,'{"version":1,"containers":{},"volumes":{}}'))
    if journal.get('version')!=1:raise ValueError('Unsupported journal')
    state=journal['containers'].setdefault(baseline['container'],{'env':{},'volumeMounts':{}})
    count=0
    for field,target,records,allowed in [('env',container,state['env'],ALLOWED_ENV),('volumeMounts',container,state['volumeMounts'],ALLOWED_VOLUMES),('volumes',pod,journal['volumes'],ALLOWED_VOLUMES)]:
        for name,record in baseline.get(field,{}).items():
            if name not in allowed or set(record)!={'before','applied'}:raise ValueError('Unapproved helper field')
            if any(v is not None and (not isinstance(v,dict) or v.get('name')!=name) for v in record.values()):raise ValueError('Invalid named field baseline')
            live=next((v for v in target.get(field,[]) if v['name']==name),None)
            if live!=record['applied']:raise ValueError('Legacy applied value does not match live deployment')
            if name in records and records[name]!=record:raise ValueError('Existing journal conflicts with baseline')
            records[name]=record;count+=1
    if not count:raise ValueError('No explicit baseline fields supplied')
    annotations[ANNOTATION]=json.dumps(journal,sort_keys=True,separators=(',',':'))
    if len(annotations[ANNOTATION])>200000:raise ValueError('Journal too large')
    return [{'op':'test','path':'/metadata/uid','value':m['uid']},{'op':'test','path':'/metadata/resourceVersion','value':m['resourceVersion']},{'op':'replace','path':'/spec','value':spec}]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--context',required=True);p.add_argument('--kubeconfig',required=True);p.add_argument('--baseline',required=True);p.add_argument('--apply',action='store_true');a=p.parse_args()
    os.umask(0o077);baseline=json.loads(Path(a.baseline).read_text());k=['kubectl','--context',a.context,'--kubeconfig',a.kubeconfig,'-n',baseline['namespace']]
    current=json.loads(subprocess.check_output(k+['get','deployment',baseline['deployment'],'-o','json']));patch=plan(current,baseline)
    if a.apply:subprocess.run(k+['patch','deployment',baseline['deployment'],'--type=json','--patch',json.dumps(patch)],check=True,stdout=subprocess.DEVNULL)
    print(json.dumps({'status':'IMPORTED' if a.apply else 'PLAN_VALID','deploymentUID':current['metadata']['uid'],'baselineFields':sum(len(baseline.get(x,{})) for x in ['env','volumeMounts','volumes'])}))
if __name__=='__main__':main()
