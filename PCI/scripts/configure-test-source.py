#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Idempotently configure records on the explicitly selected synthetic datasource ORCE."""
import argparse,base64,hashlib,json,math,os,re,secrets,subprocess,sys
from pathlib import Path
NAME='pci-participant-test-source'
class SourceError(Exception):pass

def plan(deployment,existing,records,container,token_candidate=None):
    encoded=json.dumps(records,separators=(',',':'),sort_keys=True,allow_nan=False)
    if not isinstance(records,dict) or not records or len(encoded.encode())>262144 or 'REPLACE_' in encoded:raise SourceError('PCI-SOURCE-RECORDS')
    for tenant,configurations in records.items():
        if not isinstance(tenant,str) or not tenant or not isinstance(configurations,dict):raise SourceError('PCI-SOURCE-RECORDS')
        for configuration,subjects in configurations.items():
            if not configuration or not isinstance(subjects,dict):raise SourceError('PCI-SOURCE-RECORDS')
            for subject,claims in subjects.items():
                if not subject or not isinstance(claims,dict):raise SourceError('PCI-SOURCE-RECORDS')
                for key,value in claims.items():
                    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}',key) or key in ['constructor','prototype','__proto__'] or type(value) not in (str,int,float,bool):raise SourceError('PCI-SOURCE-RECORDS')
                    if isinstance(value,str) and len(value)>2000 or isinstance(value,float) and not math.isfinite(value):raise SourceError('PCI-SOURCE-RECORDS')
    meta=deployment['metadata'];namespace=meta['namespace'];uid=meta['uid']
    matches=[c for c in deployment['spec']['template']['spec']['containers'] if c['name']==container]
    if len(matches)!=1:raise SourceError('PCI-SOURCE-CONTAINER')
    annotations={'fap-pci.xfsc.org/source-deployment-uid':uid,'fap-pci.xfsc.org/source-container':container}
    if existing:
        m=existing['metadata'];a=m.get('annotations',{})
        if m.get('namespace')!=namespace or m.get('name')!=NAME or m.get('labels',{}).get('app.kubernetes.io/part-of')!='fap-pci-test-source':raise SourceError('PCI-SOURCE-OWNERSHIP')
        if a.get('fap-pci.xfsc.org/source-deployment-uid') not in (None,uid) or a.get('fap-pci.xfsc.org/source-container') not in (None,container):raise SourceError('PCI-SOURCE-OWNERSHIP')
        if not a.get('fap-pci.xfsc.org/source-deployment-uid'):
            env={e['name']:e for e in matches[0].get('env',[])}
            # Legacy adoption requires the secret already wired to this container.
            for name,key in [('PCI_TEST_SOURCE_TOKEN','token'),('PCI_TEST_SOURCE_RECORDS','records.json')]:
                if env.get(name,{}).get('valueFrom',{}).get('secretKeyRef')!={'name':NAME,'key':key}:raise SourceError('PCI-SOURCE-OWNERSHIP')
        token=base64.b64decode(existing['data']['token'],validate=True).decode()
        if not 32<=len(token)<=512 or '\n' in token or '\r' in token:raise SourceError('PCI-SOURCE-TOKEN')
        secret=json.loads(json.dumps(existing));secret['metadata'].pop('managedFields',None)
    else:
        # A previous create may have failed after writing the private token
        # file. Reuse that identity so retrying never rotates a live token.
        token=token_candidate or secrets.token_urlsafe(48)
        if not re.fullmatch(r'[A-Za-z0-9_-]{32,512}',token):raise SourceError('PCI-SOURCE-TOKEN-FILE')
        secret={'apiVersion':'v1','kind':'Secret','metadata':{'name':NAME,'namespace':namespace},'type':'Opaque'}
    secret['metadata'].setdefault('labels',{})['app.kubernetes.io/part-of']='fap-pci-test-source';secret['metadata'].setdefault('annotations',{}).update(annotations)
    data={'token':base64.b64encode(token.encode()).decode(),'records.json':base64.b64encode(encoded.encode()).decode()}
    secret['data']={**secret.get('data',{}),**data}
    revision=hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
    env=[{'name':key,'valueFrom':{'secretKeyRef':{'name':NAME,'key':field}}} for key,field in [('PCI_TEST_SOURCE_TOKEN','token'),('PCI_TEST_SOURCE_RECORDS','records.json')]]
    patch={'spec':{'template':{'metadata':{'annotations':{'fap-pci.xfsc.org/source-revision':revision}},'spec':{'containers':[{'name':container,'env':env}]}}}}
    current=deployment['spec']['template'];live_env={e['name']:e for e in matches[0].get('env',[])}
    changed=current.get('metadata',{}).get('annotations',{}).get('fap-pci.xfsc.org/source-revision')!=revision or any(live_env.get(e['name'])!=e for e in env)
    if any('persistentVolumeClaim' in v for v in current['spec'].get('volumes',[])):patch['spec']['strategy']={'type':'Recreate','rollingUpdate':None}
    return secret,patch,token,changed

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['context','namespace','deployment','records','token-file']:p.add_argument('--'+name,required=True)
    p.add_argument('--kubeconfig');p.add_argument('--container',default='orce');a=p.parse_args();os.umask(0o077)
    try:
        if a.namespace in {'ocm-wstack','infrastructure','security','kube-system','xfsc-orce-pci-orce'}:raise SourceError('PCI-SOURCE-NAMESPACE')
        if any(not re.fullmatch(r'[a-z0-9][a-z0-9.-]*',v) for v in [a.namespace,a.deployment,a.container]):raise SourceError('PCI-SOURCE-NAME')
        k=['kubectl','--context',a.context]+(['--kubeconfig',a.kubeconfig] if a.kubeconfig else [])+['-n',a.namespace]
        def command(args,value=None):
            return subprocess.run(k+args,input=json.dumps(value) if value is not None else None,text=True,capture_output=True,check=True).stdout
        deployment=json.loads(command(['get','deployment',a.deployment,'-o','json']))
        raw=command(['get','secret',NAME,'--ignore-not-found','-o','json']);existing=json.loads(raw) if raw else None
        out=Path(a.token_file)
        if out.is_symlink():raise SourceError('PCI-SOURCE-TOKEN-FILE')
        if out.exists() and not out.is_file():raise SourceError('PCI-SOURCE-TOKEN-FILE')
        token_candidate=out.read_text().strip() if out.exists() else None
        secret,patch,token,changed=plan(deployment,existing,json.loads(Path(a.records).read_text()),a.container,token_candidate)
        if out.exists():
            if not out.is_file() or out.read_text().strip()!=token:raise SourceError('PCI-SOURCE-TOKEN-FILE')
            out.chmod(0o600)
        else:
            with open(out,'x',opener=lambda path,flags:os.open(path,flags,0o600)) as f:f.write(token)
        if secret!=existing:command(['replace' if existing else 'create','-f','-'],secret)
        if changed:
            patch['metadata']={'uid':deployment['metadata']['uid'],'resourceVersion':deployment['metadata']['resourceVersion']}
            command(['patch','deployment',a.deployment,'--type=strategic','--patch',json.dumps(patch)])
            command(['rollout','status','deployment/'+a.deployment,'--timeout=5m'])
        print(json.dumps({'event':'pci.datasource.configured','status':'configured','namespace':a.namespace,'changed':changed,'flow':'reference/participant-data-source/flows.json','path':'<ORCE base>/participant-test/v1/records','tokenFile':str(out)}));return 0
    except Exception as error:
        print(json.dumps({'event':'pci.datasource.failed','status':'failed','code':str(error) if isinstance(error,SourceError) else 'PCI-SOURCE-CONFIGURATION','nextStep':'Check record format, target ownership, private token file and Kubernetes access. Existing tokens are retained; do not replace them to retry.'}),file=sys.stderr);return 1
if __name__=='__main__':sys.exit(main())
