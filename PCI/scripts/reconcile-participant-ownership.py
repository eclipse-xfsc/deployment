#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Recover interrupted helper cleanup grants using exact tenant/install identities.
Requires the cluster owner's kubeconfig; does not deploy an image or read secrets.
Use before retrying a tenant deletion blocked by a pre-binding helper crash.
"""
import argparse,json,re,subprocess

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--context',required=True);p.add_argument('--kubeconfig',required=True);p.add_argument('--pci-namespace',required=True);p.add_argument('--tenant-id',required=True);p.add_argument('--apply',action='store_true');a=p.parse_args()
    if not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}',a.tenant_id):p.error('Tenant UUID required')
    k=['kubectl','--context',a.context,'--kubeconfig',a.kubeconfig]
    def get(kind,name,ns=None):
        raw=subprocess.check_output(k+(['-n',ns] if ns else [])+['get',kind,name,'--ignore-not-found','-o','json']);return json.loads(raw) if raw.strip() else None
    parents=json.loads(subprocess.check_output(k+['-n',a.pci_namespace,'get','configmaps','-l','xfsc.org/pci-tenant-id='+a.tenant_id,'-o','json']))['items']
    if len(parents)!=1:raise ValueError('Expected one tenant registry')
    parent=parents[0];data=parent['data'];labels={'app.kubernetes.io/part-of':'fap-pci-reference','xfsc.org/pci-tenant-id':a.tenant_id,'xfsc.org/pci-owner-uid':data['owner_uid'],'xfsc.org/pci-install-uid':parent['metadata']['uid']}
    names=['pci-participant-'+a.tenant_id,'pci-participant-'+a.tenant_id[:8]];found=[];role='pci-participant-cleanup-'+a.tenant_id
    for name in names:
        obj=get('namespace',name)
        if obj:
            if any(obj['metadata'].get('labels',{}).get(key)!=value for key,value in labels.items()):raise ValueError('Namespace ownership differs')
            found.append(obj)
    if len(found)>1:raise ValueError('Ambiguous participant namespace')
    name=data.get('participant_namespace') or (found[0]['metadata']['name'] if found else names[0])
    if name not in names or found and found[0]['metadata']['name']!=name:raise ValueError('Registry differs from namespace')
    if found and data.get('participant_namespace_uid') not in [None,found[0]['metadata']['uid']]:raise ValueError('Namespace replaced')
    for kind in ['clusterrole','clusterrolebinding']:
        obj=get(kind,role)
        if obj and any(obj['metadata'].get('labels',{}).get(key)!=value for key,value in labels.items()):raise ValueError('Grant ownership differs')
    if a.apply:
        patch=[{'op':'test','path':'/metadata/uid','value':parent['metadata']['uid']},{'op':'test','path':'/metadata/resourceVersion','value':parent['metadata']['resourceVersion']},{'op':'replace','path':'/data','value':{**data,'participant_namespace':name,'participant_cleanup_role':role,**({'participant_namespace_uid':found[0]['metadata']['uid']} if found else {})}}]
        subprocess.run(k+['-n',a.pci_namespace,'patch','configmap',parent['metadata']['name'],'--type=json','--patch',json.dumps(patch)],check=True,stdout=subprocess.DEVNULL)
        def apply(obj):subprocess.run(k+['apply','--server-side','--field-manager=fap-pci-reference','-f','-'],input=json.dumps(obj),text=True,check=True,stdout=subprocess.DEVNULL)
        apply({'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRole','metadata':{'name':role,'labels':labels},'rules':[{'apiGroups':[''],'resources':['namespaces'],'resourceNames':[name],'verbs':['get','delete']},{'apiGroups':['rbac.authorization.k8s.io'],'resources':['clusterroles'],'resourceNames':[role],'verbs':['get','delete']}]})
        role_uid=get('clusterrole',role)['metadata']['uid']
        apply({'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRoleBinding','metadata':{'name':role,'labels':labels,'ownerReferences':[{'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRole','name':role,'uid':role_uid,'blockOwnerDeletion':True}]},'roleRef':{'apiGroup':'rbac.authorization.k8s.io','kind':'ClusterRole','name':role},'subjects':[{'kind':'ServiceAccount','name':'fap-pci-orce','namespace':a.pci_namespace}]})
    print(json.dumps({'status':'RECONCILED' if a.apply else 'PLAN_VALID','tenantId':a.tenant_id,'namespace':name}))
if __name__=='__main__':main()
