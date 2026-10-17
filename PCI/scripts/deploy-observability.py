#!/usr/bin/env python3
"""Install private PCI telemetry without changing shared observability or OCM."""
import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from runtime_ownership import apply as patch_runtime

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--kubeconfig')
p.add_argument('--context', required=True)
p.add_argument('--namespace', required=True)
p.add_argument('--deployment', required=True)
p.add_argument('--container', default='orce')
p.add_argument('--main-host', required=True)
p.add_argument('--base-path', default='/pci-orce')
p.add_argument('--rotate-certificate', action='store_true')
a = p.parse_args()
os.umask(0o077)
if a.namespace in {'ocm-wstack', 'infrastructure', 'observability', 'security', 'default', 'kube-system'}:
    p.error('Use the dedicated PCI namespace')
for value in [a.namespace, a.deployment, a.container, a.main_host]:
    if not re.fullmatch(r'[a-z0-9][a-z0-9.-]*', value): p.error('Invalid resource name or hostname')
if a.base_path and not re.fullmatch(r'(?:/[a-zA-Z0-9_-]+)+', a.base_path): p.error('Invalid ORCE base path')
k = ['kubectl', '--context', a.context, '-n', a.namespace]
h = ['helm', '--kube-context', a.context]
if a.kubeconfig:
    k += ['--kubeconfig', a.kubeconfig]; h += ['--kubeconfig', a.kubeconfig]
name = 'fap-pci-observability'
server = name + '.' + a.namespace + '.svc.cluster.local'
def read(kind, resource):
    value = subprocess.check_output(k + ['get', kind, resource, '--ignore-not-found', '-o', 'json'])
    return json.loads(value) if value else None
def owned(obj):
    if obj and (obj.get('metadata', {}).get('labels', {}).get('app.kubernetes.io/part-of') != 'fap-pci' or obj['metadata'].get('labels',{}).get('fap-pci.xfsc.org/runtime-uid') not in (None,deployment['metadata']['uid'])):
        raise SystemExit('Existing telemetry resource has a different owner')
def apply(obj):
    subprocess.run(k + ['apply', '--server-side', '--field-manager=fap-pci-observability', '-f', '-'], input=json.dumps(obj), text=True, check=True)
deployment = read('deployment', a.deployment)
if not deployment or not any(c['name'] == a.container for c in deployment['spec']['template']['spec']['containers']):
    p.error('PCI ORCE deployment/container not found')
runtime = read('secret', 'fap-pci-runtime')
if not runtime or not runtime.get('data', {}).get('PCI_INTERNAL_SERVICE_TOKEN'):
    p.error('Run G0 before installing telemetry')
runtime = None
secret = read('secret', name + '-tls'); owned(secret)
trust = read('configmap', name + '-trust'); owned(trust)
with tempfile.TemporaryDirectory(prefix='pci-telemetry-') as temporary:
    tmp = Path(temporary)
    if not secret or a.rotate_certificate:
        def openssl(*args):
            subprocess.run(['openssl', *args], cwd=tmp, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '365', '-subj', '/CN=PCI telemetry CA', '-addext', 'basicConstraints=critical,CA:TRUE', '-keyout', 'ca.key', '-out', 'ca.crt')
        openssl('req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=' + server, '-keyout', 'tls.key', '-out', 'tls.csr')
        (tmp / 'extensions').write_text('basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:' + server + ',DNS:localhost,IP:127.0.0.1\n')
        openssl('x509', '-req', '-in', 'tls.csr', '-CA', 'ca.crt', '-CAkey', 'ca.key', '-CAcreateserial', '-days', '90', '-extfile', 'extensions', '-out', 'tls.crt')
        secret = {'apiVersion':'v1', 'kind':'Secret', 'type':'kubernetes.io/tls', 'metadata':{'name':name+'-tls', 'namespace':a.namespace, 'labels':{'app.kubernetes.io/part-of':'fap-pci','fap-pci.xfsc.org/runtime-uid':deployment['metadata']['uid']}}, 'data':{key:base64.b64encode((tmp/key).read_bytes()).decode() for key in ['tls.crt','tls.key','ca.crt']}}
        apply(secret)
    secret['metadata'].setdefault('labels',{})['fap-pci.xfsc.org/runtime-uid']=deployment['metadata']['uid']
    apply(secret)
    cert = base64.b64decode(secret['data']['tls.crt'])
    result = subprocess.run(['openssl', 'x509', '-noout', '-checkend', '604800', '-checkhost', server], input=cert, stdout=subprocess.DEVNULL)
    if result.returncode: p.error('Telemetry certificate expires soon or has the wrong name; rerun with --rotate-certificate')
    ca = base64.b64decode(secret['data']['ca.crt']).decode()
    apply({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':name+'-trust','namespace':a.namespace,'labels':{'app.kubernetes.io/part-of':'fap-pci','fap-pci.xfsc.org/runtime-uid':deployment['metadata']['uid']}},'data':{'ca.crt':ca}})
    values = {'serverName':server, 'pciHost':a.main_host, 'pciBasePath':a.base_path, 'orceSelector':deployment['spec']['selector']['matchLabels'], 'certificateHash':hashlib.sha256(cert).hexdigest()}
    values_file = tmp / 'values.json'; values_file.write_text(json.dumps(values))
    chart = Path(__file__).resolve().parents[1] / 'deployment/helm/observability'
    subprocess.run(h + ['upgrade', '--install', name, str(chart), '-n', a.namespace, '--values', str(values_file), '--wait', '--timeout', '5m'], check=True)
    # Explicit env overrides the G0 envFrom defaults. The certificate is public;
    # no telemetry private key or metrics token is mounted into ORCE.
    container = next(c for c in deployment['spec']['template']['spec']['containers'] if c['name'] == a.container)
    desired_env = {'PCI_OTLP_HTTP_ENDPOINT':'https://'+server+':4318', 'PCI_OTLP_CA_FILE':'/etc/pci-telemetry/ca.crt'}
    current_env = {e['name']:e.get('value') for e in container.get('env',[])}
    desired_mount = {'name':'pci-telemetry-trust','mountPath':'/etc/pci-telemetry','readOnly':True}
    if any(current_env.get(key)!=value for key,value in desired_env.items()) or desired_mount not in container.get('volumeMounts',[]):
        patch_runtime(k,deployment,a.container,env=[{'name':key,'value':value} for key,value in desired_env.items()],mounts=[desired_mount],volumes=[{'name':'pci-telemetry-trust','configMap':{'name':name+'-trust'}}])
        subprocess.run(k + ['rollout','status','deployment/'+a.deployment,'--timeout=10m'], check=True)
print(json.dumps({'status':'configured','service':server,'jaegerPort':16686,'prometheusPort':9090,'otlpPort':4318,'publicIngress':False}))
