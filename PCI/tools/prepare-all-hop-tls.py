#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Render exact workload mesh enrollment and STRICT policy from owner inventory.
Does not change the shared stack. --apply enrolls only supplied UID-bound
workloads after the owner has installed mesh.yaml with its pinned mesh release.
"""
import argparse,copy,json,os,re,subprocess
import yaml
from pathlib import Path
ROLES={'gateway','orce','keycloak','postgres','smtp','nats','signer','status','wellKnown','preAuth','issuance','verification','cryptoCore'}
def render(inventory,objects):
    if set(inventory['roles'])!=ROLES:raise ValueError('Inventory must cover every required service role')
    if set(inventory['roles'].values())-set(inventory['workloads']):raise ValueError('Unknown workload reference')
    policies=[];patches=[]
    for key,w in inventory['workloads'].items():
        live=objects[key];m=live['metadata'];gateway=w['kind']=='EnvoyProxy'
        if key==inventory['roles']['gateway'] and not gateway:raise ValueError('Enroll the owning EnvoyProxy CR for the Gateway role')
        if gateway and key!=inventory['roles']['gateway']:raise ValueError('EnvoyProxy is only valid for the Gateway role')
        pod={} if gateway else live['spec']['template']['spec'];meta=live['spec']['provider']['kubernetes'].get('envoyDeployment',{}).get('pod',{}) if gateway else live['spec']['template'].get('metadata',{})
        if w['kind'] not in ['Deployment','StatefulSet','EnvoyProxy'] or live['kind']!=w['kind'] or any(m[k]!=w[k] for k in ['name','namespace','uid']):raise ValueError('Workload identity mismatch')
        if pod.get('hostNetwork'):raise ValueError('Host-network workloads cannot use this strict sidecar profile')
        annotations=meta.get('annotations',{})
        if any(k.startswith('traffic.sidecar.istio.io/exclude') or k.startswith('traffic.sidecar.istio.io/include') and v!='*' and not (gateway and k=='traffic.sidecar.istio.io/includeInboundPorts' and v=='') for k,v in annotations.items()):raise ValueError('Traffic bypass annotation requires explicit removal')
        if annotations.get('sidecar.istio.io/inject')=='false':raise ValueError('Workload explicitly disables sidecar injection')
        label='pci-'+re.sub('[^a-z0-9-]','-',key.lower())
        spec=copy.deepcopy(live['spec']);t=spec['provider']['kubernetes'].setdefault('envoyDeployment',{}).setdefault('pod',{}) if gateway else spec['template'].setdefault('metadata',{});t.setdefault('labels',{})['fap-pci.xfsc.org/tls-workload']=label;t['labels']['sidecar.istio.io/inject']='true';t['labels']['istio.io/rev']=inventory['meshRevision']
        settings=yaml.safe_load(annotations.get('proxy.istio.io/config','{}')) or {}
        if not isinstance(settings,dict):raise ValueError('Invalid proxy configuration')
        settings['holdApplicationUntilProxyStarts']=True;t.setdefault('annotations',{})['proxy.istio.io/config']=json.dumps(settings)
        # PostgreSQL/Mailpit/NATS/native HTTP remain local application protocols;
        # sidecars authenticate and encrypt every cross-pod TCP connection.
        patches.append({'workload':w,'patch':[{'op':'test','path':'/metadata/uid','value':m['uid']},{'op':'test','path':'/metadata/resourceVersion','value':m['resourceVersion']},{'op':'replace','path':'/spec','value':spec}]})
        if gateway:t['annotations']['traffic.sidecar.istio.io/includeInboundPorts']=''
        else:policies.append({'apiVersion':'security.istio.io/v1','kind':'PeerAuthentication','metadata':{'name':label,'namespace':m['namespace']},'spec':{'selector':{'matchLabels':{'fap-pci.xfsc.org/tls-workload':label}},'mtls':{'mode':'STRICT'}}})
    return {'policies':policies,'patches':patches}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--inventory',required=True);p.add_argument('--context',required=True);p.add_argument('--kubeconfig',required=True);p.add_argument('--output',required=True);p.add_argument('--apply',action='store_true');a=p.parse_args();os.umask(0o077)
    i=json.loads(Path(a.inventory).read_text());k=['kubectl','--context',a.context,'--kubeconfig',a.kubeconfig];objects={}
    for key,w in i['workloads'].items():objects[key]=json.loads(subprocess.check_output(k+['-n',w['namespace'],'get',w['kind'],w['name'],'-o','json']))
    result=render(i,objects);out=Path(a.output);out.mkdir(parents=True,exist_ok=True);(out/'plan.json').write_text(json.dumps(result,indent=2)+'\n')
    if a.apply:
        # Apply policy before enrollment so an incomplete rollout fails closed.
        subprocess.run(k+['apply','--server-side','--field-manager=fap-pci-tls','-f','-'],input=json.dumps({'apiVersion':'v1','kind':'List','items':result['policies']}),text=True,check=True)
        for row in result['patches']:
            w=row['workload'];subprocess.run(k+['-n',w['namespace'],'patch',w['kind'],w['name'],'--type=json','--patch',json.dumps(row['patch'])],check=True,stdout=subprocess.DEVNULL)
        for w in i['workloads'].values():
            if w['kind']!='EnvoyProxy':subprocess.run(k+['-n',w['namespace'],'rollout','status',w['kind'].lower()+'/'+w['name'],'--timeout=10m'],check=True)
    print(json.dumps({'status':'APPLIED_VALIDATION_PENDING' if a.apply else 'PLAN_READY','workloads':len(objects),'roles':len(ROLES)}))
if __name__=='__main__':main()
