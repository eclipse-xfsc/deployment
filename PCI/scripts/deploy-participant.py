#!/usr/bin/env python3
"""Deploy the Go/Goa reference repository backed by the ORCE synthetic record flow."""
import argparse
import base64
import hashlib
import json
import os
import re
import ssl
import subprocess
import tempfile
import urllib.request
import urllib.parse
from pathlib import Path
from runtime_ownership import apply as patch_runtime

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--context', required=True)
p.add_argument('--kubeconfig')
p.add_argument('--pci-namespace', required=True)
p.add_argument('--orce-deployment', default='xfsc-orce')
p.add_argument('--orce-container', default='orce')
p.add_argument('--tenant-id', required=True)
p.add_argument('--configuration-id', required=True)
p.add_argument('--image', required=True, help='Built reference image pinned with @sha256:...')
p.add_argument('--source-url', required=True, help='HTTPS URL of the imported ORCE /participant-test/v1/records flow')
p.add_argument('--source-token-file', required=True)
p.add_argument('--jwt-issuer', help='Default: the PCI Keycloak realm. Use the actual Entra issuer for brokered tokens.')
p.add_argument('--jwt-audience', default='participant-data')
p.add_argument('--jwt-scopes', default='credential:issue')
p.add_argument('--crypto-endpoint')
p.add_argument('--crypto-server-name')
p.add_argument('--crypto-cert')
p.add_argument('--crypto-key')
p.add_argument('--crypto-ca')
a = p.parse_args()
os.umask(0o077)
for value in [a.tenant_id, a.configuration_id]:
    if not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', value): p.error('Tenant and configuration IDs must be UUIDs')
if not re.fullmatch(r'[^\s]+@sha256:[0-9a-f]{64}', a.image): p.error('Use an immutable image digest')
if a.pci_namespace in {'ocm-wstack','infrastructure','security','observability','default','kube-system'}: p.error('Use the dedicated PCI namespace')
for value in [a.pci_namespace,a.orce_deployment,a.orce_container]:
    if not re.fullmatch(r'[a-z0-9][a-z0-9.-]*',value): p.error('Invalid Kubernetes name')
source = urllib.parse.urlsplit(a.source_url)
if source.scheme!='https' or not source.hostname or source.username or source.query or source.fragment: p.error('Use the trusted HTTPS datasource URL')
token = Path(a.source_token_file).read_text().strip()
if len(token)<32 or '\n' in token or '\r' in token: p.error('Invalid datasource token file')
if a.crypto_endpoint and not all([a.crypto_server_name,a.crypto_cert,a.crypto_key,a.crypto_ca]): p.error('Participant signing requires the approved Core TLS endpoint and complete client trust material')
k=['kubectl','--context',a.context]
h=['helm','--kube-context',a.context]
if a.kubeconfig: k+=['--kubeconfig',a.kubeconfig]; h+=['--kubeconfig',a.kubeconfig]
def get(namespace,kind,name):
    data=subprocess.check_output(k+['-n',namespace,'get',kind,name,'--ignore-not-found','-o','json'])
    return json.loads(data) if data else None
def apply(obj):
    subprocess.run(k+['apply','--server-side','--field-manager=fap-pci-reference','-f','-'],input=json.dumps(obj),text=True,check=True)
config=get(a.pci_namespace,'configmap','fap-pci-config')['data']
parents=json.loads(subprocess.check_output(k+['-n',a.pci_namespace,'get','configmap','-l','xfsc.org/pci-tenant-id='+a.tenant_id,'-o','json']))['items']
if len(parents)!=1: p.error('Expected one reconciled tenant ConfigMap')
owner=parents[0]['data']['owner_uid']
parent=parents[0]
legacy='pci-participant-'+a.tenant_id[:8]
namespace=parent.get('data',{}).get('participant_namespace') or (legacy if get('', 'namespace',legacy) else 'pci-participant-'+a.tenant_id)
if namespace not in [legacy,'pci-participant-'+a.tenant_id]: p.error('Invalid participant registry')
name='pci-participant'
server=name+'.'+namespace+'.svc.cluster.local'
client_dns='pci-'+a.tenant_id+'.internal'
labels={'app.kubernetes.io/part-of':'fap-pci-reference','xfsc.org/pci-tenant-id':a.tenant_id,'xfsc.org/pci-owner-uid':owner,'xfsc.org/pci-install-uid':parent['metadata']['uid']}
existing=get('', 'namespace',namespace)
if existing and (existing['metadata'].get('labels',{}).get('xfsc.org/pci-tenant-id')!=a.tenant_id or existing['metadata'].get('labels',{}).get('xfsc.org/pci-owner-uid') not in [None,owner]): p.error('Participant namespace belongs to another owner')
role='pci-participant-cleanup-'+a.tenant_id
for kind in ['clusterrole','clusterrolebinding']:
    old=get('',kind,role)
    if old and any(old['metadata'].get('labels',{}).get(k)!=v for k,v in labels.items()): p.error('Cleanup permission belongs to another owner')
def register(data):
    current=get(a.pci_namespace,'configmap',parent['metadata']['name'])
    if current['metadata']['uid']!=parent['metadata']['uid']: p.error('Tenant registry replaced during deployment')
    patch=[{'op':'test','path':'/metadata/uid','value':current['metadata']['uid']},{'op':'test','path':'/metadata/resourceVersion','value':current['metadata']['resourceVersion']},{'op':'replace','path':'/data','value':{**current['data'],**data}}]
    subprocess.run(k+['-n',a.pci_namespace,'patch','configmap',parent['metadata']['name'],'--type=json','--patch',json.dumps(patch)],check=True,stdout=subprocess.DEVNULL)
register({'participant_namespace':namespace,'participant_cleanup_role':role})
apply({'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRole','metadata':{'name':role,'labels':labels},'rules':[{'apiGroups':[''],'resources':['namespaces'],'resourceNames':[namespace],'verbs':['get','delete']},{'apiGroups':['rbac.authorization.k8s.io'],'resources':['clusterroles'],'resourceNames':[role],'verbs':['get','delete']}]})
role_uid=get('', 'clusterrole',role)['metadata']['uid']
apply({'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRoleBinding','metadata':{'name':role,'labels':labels,'ownerReferences':[{'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRole','name':role,'uid':role_uid,'blockOwnerDeletion':True}]},'roleRef':{'apiGroup':'rbac.authorization.k8s.io','kind':'ClusterRole','name':role},'subjects':[{'kind':'ServiceAccount','name':'fap-pci-orce','namespace':a.pci_namespace}]})
apply({'apiVersion':'v1','kind':'Namespace','metadata':{'name':namespace,'labels':labels}})
register({'participant_namespace_uid':get('', 'namespace',namespace)['metadata']['uid']})
issuer=(a.jwt_issuer or config['PCI_KEYCLOAK_PUBLIC_URL']+'/realms/'+config['PCI_KEYCLOAK_REALM']).rstrip('/')
tls=ssl.create_default_context(); tls.minimum_version=ssl.TLSVersion.TLSv1_3
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None
opener=urllib.request.build_opener(urllib.request.HTTPSHandler(context=tls),NoRedirect())
def public_json(url):
    u=urllib.parse.urlsplit(url)
    if u.scheme!='https' or u.username or u.fragment: p.error('Untrusted identity URL')
    with opener.open(url,timeout=10) as response:
        body=response.read(1048577)
    if len(body)>1048576: p.error('Identity response too large')
    return json.loads(body)
discovery=public_json(issuer+'/.well-known/openid-configuration')
if discovery.get('issuer')!=issuer or urllib.parse.urlsplit(discovery['jwks_uri']).netloc!=urllib.parse.urlsplit(issuer).netloc: p.error('Identity discovery mismatch')
jwks=public_json(discovery['jwks_uri'])
if not jwks.get('keys') or any('d' in key or 'k' in key for key in jwks['keys']): p.error('Invalid public JWKS')
def secret(secret_name,data):
    old=get(namespace,'secret',secret_name)
    if old and old['metadata'].get('labels',{}).get('xfsc.org/pci-tenant-id')!=a.tenant_id: p.error('Existing participant Secret has another owner')
    obj={'apiVersion':'v1','kind':'Secret','metadata':{'name':secret_name,'namespace':namespace,'labels':{'app.kubernetes.io/part-of':'fap-pci-reference','xfsc.org/pci-tenant-id':a.tenant_id}},'type':'Opaque','data':{key:base64.b64encode(value if isinstance(value,bytes) else value.encode()).decode() for key,value in data.items()}}
    apply(obj)
with tempfile.TemporaryDirectory(prefix='pci-participant-') as temporary:
    tmp=Path(temporary)
    # Preserve working certificate identities on upgrades.
    server_secret=get(namespace,'secret','participant-tls')
    client_secret=get(a.pci_namespace,'secret','pci-participant-'+a.tenant_id[:8])
    if bool(server_secret)!=bool(client_secret): p.error('Incomplete existing TLS pair; restore its counterpart before upgrading')
    if server_secret:
        if server_secret['metadata'].get('labels',{}).get('xfsc.org/pci-tenant-id')!=a.tenant_id or client_secret['metadata'].get('labels',{}).get('xfsc.org/pci-owner-uid')!=owner: p.error('Existing TLS ownership mismatch')
        for key,filename in [('tls.crt','client.crt'),('tls.key','client.key'),('ca.crt','ca.crt')]: (tmp/filename).write_bytes(base64.b64decode(client_secret['data'][key]))
    else:
        def openssl(*args): subprocess.run(['openssl',*args],cwd=tmp,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
        openssl('req','-x509','-newkey','rsa:2048','-nodes','-days','365','-subj','/CN=PCI participant test CA','-addext','basicConstraints=critical,CA:TRUE','-keyout','ca.key','-out','ca.crt')
        for role,dns,usage in [('server',server,'serverAuth'),('client',client_dns,'clientAuth')]:
            openssl('req','-new','-newkey','rsa:2048','-nodes','-subj','/CN=PCI participant '+role,'-keyout',role+'.key','-out',role+'.csr')
            (tmp/(role+'.ext')).write_text('basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage='+usage+'\nsubjectAltName=DNS:'+dns+'\n')
            openssl('x509','-req','-in',role+'.csr','-CA','ca.crt','-CAkey','ca.key','-CAcreateserial','-days','90','-extfile',role+'.ext','-out',role+'.crt')
        secret('participant-tls',{'tls.crt':(tmp/'server.crt').read_bytes(),'tls.key':(tmp/'server.key').read_bytes(),'ca.crt':(tmp/'ca.crt').read_bytes()})
    root=Path(__file__).resolve().parents[1]
    # The helper uses kubectl's environment, so pass the same explicit context
    # without changing the user's kubeconfig or default context.
    helper_env={**os.environ,'PCI_KUBECTL_CONTEXT':a.context}
    if a.kubeconfig: helper_env['KUBECONFIG']=a.kubeconfig
    trust_name='pci-participant-'+a.tenant_id[:8]
    subprocess.run(['bash',str(root/'scripts/participant-secret.sh'),a.pci_namespace,trust_name,a.tenant_id,owner,str(tmp/'client.crt'),str(tmp/'client.key'),str(tmp/'ca.crt')],env=helper_env,check=True)
    secret('participant-data',{'jwks.json':json.dumps(jwks),'records.json':'{}'})
    secret('participant-source',{'token':token})
    values={'image':a.image,'tenantId':a.tenant_id,'issuer':issuer,'audience':a.jwt_audience,'scopes':a.jwt_scopes,'pciClientDns':client_dns,'tlsSecret':'participant-tls','dataSecret':'participant-data','pciNamespace':a.pci_namespace,'source':{'url':a.source_url,'tokenSecret':'participant-source'},'crypto':{'namespace':config['PCI_OCM_NAMESPACE']}}
    if a.crypto_endpoint:
        secret('participant-crypto',{'tls.crt':Path(a.crypto_cert).read_bytes(),'tls.key':Path(a.crypto_key).read_bytes(),'ca.crt':Path(a.crypto_ca).read_bytes()})
        values['crypto'].update(endpoint=a.crypto_endpoint,serverName=a.crypto_server_name,tlsSecret='participant-crypto')
    # Restart after JWKS/source-token/trust changes: the service reads these at
    # startup. Keep all secret bytes out of Helm values and release history.
    revision=hashlib.sha256()
    for secret_name in ['participant-tls','participant-data','participant-source']+(['participant-crypto'] if a.crypto_endpoint else []):
        revision.update(json.dumps(get(namespace,'secret',secret_name)['data'],sort_keys=True).encode())
    values['trustRevision']=revision.hexdigest()
    values_file=tmp/'values.json'; values_file.write_text(json.dumps(values))
    subprocess.run(h+['upgrade','--install',name,str(root/'deployment/helm/participant'),'-n',namespace,'--values',str(values_file),'--wait','--timeout','5m'],check=True)
    address=get(namespace,'service',name)['spec']['clusterIP']
    deployment=get(a.pci_namespace,'deployment',a.orce_deployment)
    container=next(c for c in deployment['spec']['template']['spec']['containers'] if c['name']==a.orce_container)
    current_env={entry['name']:entry.get('value','') for entry in container.get('env',[])}
    additions={'PCI_PARTICIPANT_ALLOWED_HOSTS':server,'PCI_PARTICIPANT_PRIVATE_ADDRESSES':address,'PCI_PARTICIPANT_JWT_ISSUERS':issuer}
    updated=[]
    for key,value in additions.items():
        previous=current_env.get(key,config.get(key,''))
        updated.append({'name':key,'value':','.join(sorted(set(filter(None,previous.split(',')))|{value}))})
    if any(current_env.get(e['name'])!=e['value'] for e in updated):
        patch_runtime(k+['-n',a.pci_namespace],deployment,a.orce_container,env=updated)
        subprocess.run(k+['-n',a.pci_namespace,'rollout','status','deployment/'+a.orce_deployment,'--timeout=10m'],check=True)
connector={'name':'Participant test repository','configurationIds':[a.configuration_id],'endpoint':'https://'+server+':9443','serverName':server,'protocolVersion':'participant-v1','tlsSecret':{'name':trust_name},'trustSecret':{'name':trust_name},'jwtIssuer':issuer,'jwtAudience':a.jwt_audience,'jwtScopes':a.jwt_scopes.split(),'signingModes':['internal-signing']+(['participant-signed'] if a.crypto_endpoint else []),'timeoutMs':10000,'attempts':1,'ratePerMinute':10,'circuitFailureThreshold':3,'circuitCooldownMs':30000}
print(json.dumps({'status':'deployed','participantNamespace':namespace,'connector':connector},indent=2))
