#!/usr/bin/env python3
"""Configure Entra through the tenant-admin API; no global Keycloak mutation."""
import argparse,json,re,ssl,sys,urllib.request,urllib.parse,urllib.error
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--pci-url',required=True);p.add_argument('--pci-tenant-id',required=True);p.add_argument('--session-cookie-file',required=True)
p.add_argument('--tenant-id',required=True,help='Microsoft Entra directory UUID');p.add_argument('--client-id',required=True);p.add_argument('--client-secret-file',required=True)
p.add_argument('--audience',required=True);p.add_argument('--scopes',required=True);p.add_argument('--display-name',default='Organization account');a=p.parse_args()
for value in [a.pci_tenant_id,a.tenant_id,a.client_id]:
    if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}',value):p.error('Tenant and client identifiers must be UUIDs')
u=urllib.parse.urlsplit(a.pci_url)
if u.scheme!='https' or not u.hostname or u.username or u.query or u.fragment:p.error('Use the tenant public HTTPS issuer URL')
cookie=Path(a.session_cookie_file).read_text().strip();secret=Path(a.client_secret_file).read_text().strip()
if '\n' in cookie or '\r' in cookie or not cookie.startswith('fap_pci_session=') or not secret:p.error('Invalid private credential file')
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None
trust=ssl.create_default_context();trust.minimum_version=ssl.TLSVersion.TLSv1_3;trust.maximum_version=ssl.TLSVersion.TLSv1_3
opener=urllib.request.build_opener(urllib.request.HTTPSHandler(context=trust),NoRedirect())
endpoint=a.pci_url.rstrip('/')+'/api/v1/tenants/'+a.pci_tenant_id+'/identity-provider'
def request(method,body=None,version=None):
    headers={'Cookie':cookie,'Accept':'application/json','Origin':'https://'+u.netloc}
    if body is not None:headers['Content-Type']='application/json'
    if version:headers['If-Match']='"'+str(version)+'"'
    value=urllib.request.Request(endpoint,method=method,headers=headers,data=json.dumps(body).encode() if body is not None else None)
    with opener.open(value,timeout=45) as response:return json.loads(response.read(262144))
try:
    current=request('GET');value=request('PUT',{'mode':'oidc','displayName':a.display_name,'issuer':'https://login.microsoftonline.com/'+a.tenant_id+'/v2.0','clientId':a.client_id,'clientSecret':secret,'audience':a.audience,'scopes':a.scopes},current['item']['version'])
    print(json.dumps({'status':'configured','issuer':value['item']['issuer'],'redirectUri':value['redirectUri'],'version':value['item']['version']}))
except urllib.error.HTTPError as e:print(json.dumps({'status':'failed','httpStatus':e.code,'guidance':'Reload identity settings, check tenant admin authentication, discovery and Secret permissions, then retry.'}),file=sys.stderr);sys.exit(1)
except Exception:print(json.dumps({'status':'failed','guidance':'Check the tenant HTTPS endpoint and private fixture files.'}),file=sys.stderr);sys.exit(1)
