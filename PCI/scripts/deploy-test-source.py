#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Deploy the separate ORCE synthetic record source with verified Gateway backend TLS."""
import argparse
import hashlib
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = 'fap-pci-record-source'
MANAGER = 'fap-pci-test-source'
SHARED = {'default', 'kube-system', 'infrastructure', 'security', 'observability', 'ocm-wstack', 'xfsc-orce-pci-orce', 'xfsc-orce-deployer'}

class SourceSetupError(Exception):
    pass

def validate(a):
    for value in [a.tenant_id, a.configuration_id, a.subject]:
        if str(uuid.UUID(value)) != value:
            raise SourceSetupError('Use canonical tenant, configuration and subject UUIDs.')
    for value in [a.namespace, a.pci_namespace, a.gateway_namespace, a.gateway, a.listener]:
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,61}[a-z0-9]|[a-z0-9]', value):
            raise SourceSetupError('Invalid Kubernetes name.')
    if a.namespace in SHARED or a.namespace == a.pci_namespace:
        raise SourceSetupError('Use a separate dedicated datasource namespace.')
    if not re.fullmatch(r'[a-z0-9-]+(?:\.[a-z0-9-]+)*\.facis\.cloud', a.host):
        raise SourceSetupError('Use a FACIS subdomain.')
    if not re.fullmatch(r'/[a-z0-9][a-z0-9-]{0,50}', a.path_prefix):
        raise SourceSetupError('Use a separate single-segment path prefix.')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9./:_@-]{0,250}', a.image):
        raise SourceSetupError('Invalid ORCE image reference.')
    if a.node_red_cli != '/data/node_modules/node-red/red.js':
        raise SourceSetupError('This helper targets the inspected ORCE 2.0.13 executable.')
    if not a.context or not a.kubeconfig or not Path(a.kubeconfig).is_file():
        raise SourceSetupError('Supply the intended context and kubeconfig.')

def source_settings(prefix):
    return """const fs=require('fs');
module.exports={
  uiPort:1880,uiHost:'0.0.0.0',userDir:'/work/runtime',
  flowFile:'/etc/pci-test-source/code/flows.json',
  httpAdminRoot:false,httpNodeRoot:%s,
  functionExternalModules:true,credentialSecret:false,
  contextStorage:{default:{module:'memory'}},
  https:{key:fs.readFileSync('/etc/pci-test-source/tls/tls.key'),
    cert:fs.readFileSync('/etc/pci-test-source/tls/tls.crt'),
    minVersion:'TLSv1.3',maxVersion:'TLSv1.3'},
  logging:{console:{level:'warn',metrics:false,audit:false}}
};
""" % json.dumps(prefix)

def build_objects(a, labels, flows):
    meta = lambda name: {'name': name, 'namespace': a.namespace, 'labels': labels}
    nodes = json.loads(json.dumps(flows))
    tabs = [n for n in nodes if n.get('type') == 'tab']
    if len(tabs) != 1 or any(n.get('type') == 'debug' for n in nodes):
        raise SourceSetupError('Unexpected datasource flow; use the authored reference flow.')
    nodes += [
        {'id': 'pci-source-health-in', 'type': 'http in', 'z': tabs[0]['id'], 'name': 'Source health', 'url': '/healthz', 'method': 'get', 'upload': False, 'swaggerDoc': '', 'wires': [['pci-source-health-body']]},
        {'id': 'pci-source-health-body', 'type': 'function', 'z': tabs[0]['id'], 'name': 'Safe source health', 'func': 'msg.statusCode=200;msg.headers={"content-type":"application/json","cache-control":"no-store"};msg.payload={status:"ok",service:"fap-pci-record-source"};return msg;', 'outputs': 1, 'wires': [['pci-source-health-out']]},
        {'id': 'pci-source-health-out', 'type': 'http response', 'z': tabs[0]['id'], 'name': '', 'statusCode': '', 'headers': {}, 'wires': []}
    ]
    code_revision = hashlib.sha256((source_settings(a.path_prefix)+'\0'+json.dumps(nodes)+'\0'+getattr(a, 'certificate_revision', '')).encode()).hexdigest()
    return [
        {'apiVersion': 'v1', 'kind': 'ConfigMap', 'metadata': meta(NAME+'-code'), 'data': {'settings.js': source_settings(a.path_prefix), 'flows.json': json.dumps(nodes)}},
        {'apiVersion': 'apps/v1', 'kind': 'Deployment', 'metadata': meta(NAME), 'spec': {
            'replicas': 1, 'strategy': {'type': 'Recreate'}, 'selector': {'matchLabels': {'app.kubernetes.io/name': NAME}},
            'template': {'metadata': {'labels': {**labels, 'app.kubernetes.io/name': NAME}, 'annotations': {'fap-pci.xfsc.org/source-code-revision': code_revision}}, 'spec': {
                'automountServiceAccountToken': False,
                'securityContext': {'runAsNonRoot': True, 'runAsUser': 1000, 'runAsGroup': 1000, 'fsGroup': 1000, 'seccompProfile': {'type': 'RuntimeDefault'}},
                'containers': [{'name': 'orce', 'image': a.image, 'command': ['node', a.node_red_cli], 'args': ['--settings', '/etc/pci-test-source/code/settings.js', '--userDir', '/work/runtime'],
                    'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True, 'capabilities': {'drop': ['ALL']}},
                    'ports': [{'name': 'https', 'containerPort': 1880}],
                    'resources': {'requests': {'cpu': '50m', 'memory': '128Mi'}, 'limits': {'cpu': '500m', 'memory': '512Mi'}},
                    'readinessProbe': {'httpGet': {'path': a.path_prefix+'/healthz', 'port': 'https', 'scheme': 'HTTPS'}, 'periodSeconds': 5},
                    'startupProbe': {'httpGet': {'path': a.path_prefix+'/healthz', 'port': 'https', 'scheme': 'HTTPS'}, 'periodSeconds': 5, 'failureThreshold': 60},
                    'livenessProbe': {'httpGet': {'path': a.path_prefix+'/healthz', 'port': 'https', 'scheme': 'HTTPS'}, 'periodSeconds': 15},
                    'volumeMounts': [{'name': 'work', 'mountPath': '/work'}, {'name': 'tmp', 'mountPath': '/tmp'}, {'name': 'code', 'mountPath': '/etc/pci-test-source/code', 'readOnly': True}, {'name': 'tls', 'mountPath': '/etc/pci-test-source/tls', 'readOnly': True}]}],
                'volumes': [{'name': 'work', 'emptyDir': {}}, {'name': 'tmp', 'emptyDir': {}}, {'name': 'code', 'configMap': {'name': NAME+'-code'}}, {'name': 'tls', 'secret': {'secretName': NAME+'-tls', 'defaultMode': 0o440}}]
            }}}},
        {'apiVersion': 'v1', 'kind': 'Service', 'metadata': meta(NAME), 'spec': {'selector': {'app.kubernetes.io/name': NAME}, 'ports': [{'name': 'https', 'port': 1880, 'targetPort': 'https'}]}},
        {'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy', 'metadata': meta(NAME), 'spec': {
            'podSelector': {'matchLabels': {'app.kubernetes.io/name': NAME}}, 'policyTypes': ['Ingress', 'Egress'], 'egress': [],
            'ingress': [{'from': [{'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': a.gateway_namespace}}, 'podSelector': {'matchLabels': {'gateway.envoyproxy.io/owning-gateway-name': a.gateway, 'gateway.envoyproxy.io/owning-gateway-namespace': a.gateway_namespace}}}], 'ports': [{'protocol': 'TCP', 'port': 1880}]}]}},
        {'apiVersion': 'gateway.networking.k8s.io/v1', 'kind': 'BackendTLSPolicy', 'metadata': meta(NAME), 'spec': {
            'targetRefs': [{'group': '', 'kind': 'Service', 'name': NAME}], 'validation': {'hostname': a.host, 'wellKnownCACertificates': 'System'}}},
        {'apiVersion': 'gateway.networking.k8s.io/v1', 'kind': 'HTTPRoute', 'metadata': meta(NAME), 'spec': {
            'parentRefs': [{'name': a.gateway, 'namespace': a.gateway_namespace, 'sectionName': a.listener}], 'hostnames': [a.host],
            'rules': [{'matches': [{'path': {'type': 'PathPrefix', 'value': a.path_prefix}}], 'backendRefs': [{'name': NAME, 'port': 1880}]}]}}
    ]

def assert_owned(obj, labels):
    if obj and any(obj.get('metadata', {}).get('labels', {}).get(k) != v for k, v in labels.items()):
        raise SourceSetupError('Existing datasource resource belongs to another owner; no takeover was performed.')

def private_json(path, value):
    if path.is_symlink() or path.exists() and not path.is_file():
        raise SourceSetupError('Private setup path is not a regular file.')
    if path.exists() and json.loads(path.read_text()) != value:
        raise SourceSetupError('Existing private setup file differs; preserve it and choose another private directory.')
    path.write_text(json.dumps(value, indent=2)+'\n'); path.chmod(0o600)

def current_conditions(obj, section, target, namespace, required):
    if not obj:
        return False
    generation = obj['metadata']['generation']
    for parent in obj.get('status', {}).get(section, []):
        ref = parent.get('parentRef', parent.get('ancestorRef', {}))
        if ref.get('name') != target or ref.get('namespace', namespace) != namespace:
            continue
        conditions = {c['type']: c for c in parent.get('conditions', [])}
        if all(conditions.get(t, {}).get('status') == 'True' and conditions[t].get('observedGeneration') == generation for t in required):
            return True
    return False

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['context', 'kubeconfig', 'tenant-id', 'configuration-id', 'subject', 'cert', 'key', 'private-dir']:
        p.add_argument('--'+name, required=True)
    p.add_argument('--namespace', default='xfsc-orce-pci-source')
    p.add_argument('--pci-namespace', default='xfsc-orce-pci-orce')
    p.add_argument('--host', default='pci.facis.cloud')
    p.add_argument('--path-prefix', default='/participant-source')
    p.add_argument('--gateway-namespace', default='infrastructure')
    p.add_argument('--gateway', default='pci-gateway')
    p.add_argument('--listener', default='https')
    p.add_argument('--image', default='ecofacis/xfsc-orce:2.0.13')
    p.add_argument('--node-red-cli', default='/data/node_modules/node-red/red.js')
    a = p.parse_args(); os.umask(0o077)
    try:
        validate(a)
        if any(not shutil.which(tool) for tool in ['kubectl', 'openssl']):
            raise SourceSetupError('kubectl and openssl are required.')
        private = Path(a.private_dir).resolve(); private.mkdir(parents=True, exist_ok=True, mode=0o700)
        records = private/'participant-records.json'; token_file = private/'participant-source.token'
        private_json(records, {a.tenant_id: {a.configuration_id: {a.subject: {}}}})
        certificate = Path(a.cert).resolve(); key = Path(a.key).resolve()
        a.certificate_revision = hashlib.sha256(certificate.read_bytes()).hexdigest()
        ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ssl_context.load_cert_chain(str(certificate), str(key))
        for args in [['x509', '-in', str(certificate), '-noout', '-checkhost', a.host], ['x509', '-in', str(certificate), '-noout', '-checkend', '86400']]:
            subprocess.run(['openssl', *args], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        k = ['kubectl', '--context', a.context, '--kubeconfig', a.kubeconfig, '--request-timeout=60s']
        def get(ns, kind, name):
            out = subprocess.check_output(k+(['-n', ns] if ns else [])+['get', kind, name, '--ignore-not-found', '-o', 'json'], text=True)
            return json.loads(out) if out.strip() else None
        def apply(obj):
            subprocess.run(k+['apply', '--server-side', '--field-manager='+MANAGER, '-f', '-'], input=json.dumps(obj), text=True, check=True)
        parent_items = json.loads(subprocess.check_output(k+['-n', a.pci_namespace, 'get', 'configmap', '-l', 'xfsc.org/pci-tenant-id='+a.tenant_id, '-o', 'json'], text=True))['items']
        if len(parent_items) != 1:
            raise SourceSetupError('Expected one reconciled test tenant ConfigMap.')
        parent = parent_items[0]
        labels = {'app.kubernetes.io/part-of': 'fap-pci-test-source', 'app.kubernetes.io/managed-by': MANAGER, 'xfsc.org/pci-tenant-id': a.tenant_id, 'xfsc.org/pci-owner-uid': parent['data']['owner_uid'], 'xfsc.org/pci-install-uid': parent['metadata']['uid']}
        gateway = get(a.gateway_namespace, 'gateway', a.gateway)
        listeners = [l for l in gateway['spec']['listeners'] if l['name'] == a.listener and l['protocol'] == 'HTTPS'] if gateway else []
        if len(listeners) != 1 or listeners[0].get('allowedRoutes', {}).get('namespaces', {}).get('from') != 'All':
            raise SourceSetupError('Expected the inspected HTTPS Gateway allowing the dedicated source namespace.')
        crd = get('', 'crd', 'backendtlspolicies.gateway.networking.k8s.io')
        if not crd or not any(v['name'] == 'v1' and v['served'] for v in crd['spec']['versions']):
            raise SourceSetupError('BackendTLSPolicy v1 is required.')
        routes = json.loads(subprocess.check_output(k+['get', 'httproute', '-A', '-o', 'json'], text=True))['items']
        for route in routes:
            if route['metadata']['namespace'] == a.namespace and route['metadata']['name'] == NAME:
                continue
            if a.host in route.get('spec', {}).get('hostnames', []) and any(m.get('path', {}).get('value') == a.path_prefix for rule in route['spec'].get('rules', []) for m in rule.get('matches', [])):
                raise SourceSetupError('Another route already owns the selected datasource prefix.')
        # Drop privileges in this short-lived probe only; the running ORCE is untouched.
        subprocess.run(k+['-n', 'xfsc-orce-deployer', 'exec', 'deployment/xfsc-orce', '-c', 'orce', '--', 'node', '-e', "const fs=require('fs');if(process.getuid()===0){process.setgroups([]);process.setgid(1000);process.setuid(1000);}fs.accessSync('/data/node_modules/node-red/red.js',fs.constants.R_OK);require(require.resolve('node-red',{paths:['/data']}));console.log('Source runtime read permissions: OK');"], check=True)
        objects = build_objects(a, labels, json.loads((ROOT/'reference/participant-data-source/flows.json').read_text()))
        # Check ownership of every target before creating or updating any workload.
        assert_owned(get('', 'namespace', a.namespace), labels)
        for obj in objects:
            assert_owned(get(a.namespace, obj['kind'], obj['metadata']['name']), labels)
        assert_owned(get(a.namespace, 'secret', NAME+'-tls'), labels)
        apply({'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {'name': a.namespace, 'labels': labels}})
        tls_secret = json.loads(subprocess.check_output(k+['-n', a.namespace, 'create', 'secret', 'tls', NAME+'-tls', '--cert='+str(certificate), '--key='+str(key), '--dry-run=client', '-o', 'json'], text=True))
        tls_secret['metadata']['labels'] = labels; apply(tls_secret)
        for obj in objects:
            apply(obj)
        subprocess.run([sys.executable, str(ROOT/'scripts/configure-test-source.py'), '--kubeconfig', a.kubeconfig, '--context', a.context, '--namespace', a.namespace, '--deployment', NAME, '--container', 'orce', '--records', str(records), '--token-file', str(token_file)], check=True)
        subprocess.run(k+['-n', a.namespace, 'rollout', 'status', 'deployment/'+NAME, '--timeout=5m'], check=True)
        end = time.monotonic()+90
        while time.monotonic() < end:
            route = get(a.namespace, 'httproute', NAME); policy = get(a.namespace, 'backendtlspolicy', NAME)
            if current_conditions(route, 'parents', a.gateway, a.gateway_namespace, ['Accepted', 'ResolvedRefs']) and current_conditions(policy, 'ancestors', a.gateway, a.gateway_namespace, ['Accepted']):
                break
            time.sleep(2)
        else:
            raise SourceSetupError('Gateway has not accepted the source route and backend TLS policy; inspect their status before retrying.')
        url = 'https://'+a.host+a.path_prefix+'/participant-test/v1/records'
        body = json.dumps({'tenantId': a.tenant_id, 'configurationId': a.configuration_id, 'subject': a.subject}).encode()
        client_tls = ssl.create_default_context(); client_tls.minimum_version = client_tls.maximum_version = ssl.TLSVersion.TLSv1_3
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs): return None
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=client_tls), NoRedirect())
        def request(token):
            req = urllib.request.Request(url, data=body, headers={'Content-Type': 'application/json', 'Authorization': 'Bearer '+token})
            try:
                with opener.open(req, timeout=15) as response:
                    data = response.read(65537)
                    if len(data) > 65536: raise SourceSetupError('Datasource response exceeded its bound.')
                    return response.status, json.loads(data)
            except urllib.error.HTTPError as error:
                return error.code, None
        if request('invalid-source-token')[0] != 401:
            raise SourceSetupError('Unauthenticated datasource access was not rejected with HTTP 401.')
        status, record = request(token_file.read_text().strip())
        if status != 200 or record != {'tenantId': a.tenant_id, 'configurationId': a.configuration_id, 'subject': a.subject, 'claims': {}}:
            raise SourceSetupError('Authenticated datasource scope/readback failed.')
        result = {'tenantId': a.tenant_id, 'configurationId': a.configuration_id, 'subject': a.subject, 'sourceNamespace': a.namespace, 'sourceUrl': url, 'sourceTokenFile': str(token_file)}
        private_json(private/'source-connection.json', result)
        print(json.dumps({'event': 'pci.datasource.ready', 'status': 'ready', 'tls': 'TLSv1.3', 'anonymousHttp': 401, 'authenticatedHttp': 200, 'sourceUrl': url, 'connectionFile': str(private/'source-connection.json')}, indent=2))
        return 0
    except Exception as error:
        detail = str(error) if isinstance(error, SourceSetupError) else 'Datasource setup failed. Inspect the preceding command output and source pod status.'
        print(json.dumps({'event': 'pci.datasource.setup.failed', 'detail': detail}), file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
