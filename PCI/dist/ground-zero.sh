#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.5.0-rc.12"
ENVOY_VERSION="v1.9.2"
ENVOY_URL="https://github.com/envoyproxy/gateway/releases/download/${ENVOY_VERSION}/install.yaml"
ENVOY_SHA256="0412a72907e57ff9b73c56a7bf6df5190bf0f6e4f8bb4bba34e38630bbab5778"
POSTGRES_IMAGE="postgres:17.4-alpine3.21"
MAILPIT_IMAGE="axllent/mailpit:v1.31.4"
SMTP_RELAY_IMAGE="boky/postfix:v5.1.0"
UIBUILDER_VERSION="7.5.0"

usage() {
  cat <<'USAGE'
FACIS FAP PCI ground-zero 0.5.0-rc.12

Prepares the complete PCI cluster/runtime baseline before flow/UI import.
It never imports the flow or copies UI assets. OCM W-Stack must already exist
and only a separately owned Keycloak integration policy is added in its namespace.

Required:
  --orce-namespace NS
  --orce-deployment NAME
  --main-host HOST
  --cert FILE
  --key FILE
  --provider-email EMAIL

Optional / auto-discovered when omitted:
  --kubeconfig FILE
  --context NAME
  --orce-service NAME
  --orce-container NAME
  --orce-service-port PORT
  --orce-base-path PATH
  --orce-editor-path PATH
  --ocm-namespace NS                 default: ocm-wstack
  --base-domain DOMAIN               derived from main-host
  --tenant-host-suffix VALUE         default: pci
  --registration-mode public|private default: public
  --infrastructure-namespace NS      default: infrastructure
  --envoy-namespace NS               default: envoy-gateway-system
  --gateway-class-name NAME          default: eg
  --gateway-name NAME                default: pci-gateway
  --gateway-listener-name NAME       default: https
  --tls-secret-name NAME             default: pci-wildcard-tls
  --envoy-manifest-file FILE
  --orce-data-pvc NAME               default: fap-pci-orce-data
  --orce-data-storage-size SIZE      default: 5Gi
  --orce-data-storage-class NAME
  --database-mode managed|external   default: managed
  --database-url URL                 required for external mode
  --postgres-storage-size SIZE       default: 4Gi
  --postgres-storage-class NAME
  --mail-mode mailpit|smtp           default: mailpit; both paths are prepared
  --mailpit-host HOST                default: mailpit-pci.<base-domain>
  --expose-mailpit auto|true|false      default: auto (public only when mail-mode=mailpit)
  --smtp-from EMAIL
  --smtp-relay-host HOST[:PORT]      optional upstream; empty = direct delivery
  --smtp-relay-username USER
  --smtp-relay-password-file FILE
  --keycloak-internal-url URL
  --keycloak-public-url URL
  --keycloak-service-name NAME
  --keycloak-admin-secret-name NAME
  --keycloak-admin-password-key KEY
  --keycloak-admin-username VALUE
  --keycloak-admin-username-key KEY  default: username
  --keycloak-realm NAME              default: fap-pci
  --keycloak-client-id NAME          default: fap-pci-ui
  --provider-username VALUE          default: provider-admin
  --provider-password-file FILE
  --keycloak-insecure
  --dry-run
  -h, --help

G0 is idempotent and non-interactive. It prepares persistent ORCE /data,
Envoy/Gateway API, PostgreSQL schema, Mailpit, production SMTP relay, Keycloak,
the main/editor routes and bounded runtime RBAC. It performs at most one ORCE
rollout when the runtime contract changes. Persistent /data preserves installed artifacts; G0 never performs a blind restart.
USAGE
}

KUBECONFIG_PATH=""; CONTEXT=""; DRY_RUN=false
ORCE_NS=""; ORCE_DEPLOYMENT=""; ORCE_SERVICE=""; ORCE_CONTAINER=""; ORCE_SERVICE_PORT=""; ORCE_BASE_PATH=""; ORCE_EDITOR_PATH=""
OCM_NS="ocm-wstack"; MAIN_HOST=""; BASE_DOMAIN=""; TENANT_SUFFIX="pci"; REGISTRATION_MODE="public"
CERT_FILE=""; KEY_FILE=""; TLS_SECRET="pci-wildcard-tls"
INFRA_NS="infrastructure"; ENVOY_NS=""; GATEWAY_CLASS="eg"; GATEWAY_NAME="pci-gateway"; GATEWAY_LISTENER="https"; ENVOY_MANIFEST_FILE=""
ORCE_DATA_PVC="fap-pci-orce-data"; ORCE_DATA_SIZE="5Gi"; ORCE_DATA_CLASS=""
DB_MODE="managed"; DB_URL=""; POSTGRES_SIZE="4Gi"; POSTGRES_CLASS=""
MAIL_MODE="mailpit"; MAILPIT_HOST=""; EXPOSE_MAILPIT="auto"; MAILPIT_PUBLIC=false; SMTP_FROM=""; SMTP_RELAY_HOST=""; SMTP_RELAY_USERNAME=""; SMTP_RELAY_PASSWORD_FILE=""
KC_INTERNAL=""; KC_PUBLIC=""; KC_SERVICE=""; KC_SECRET=""; KC_PASSWORD_KEY=""; KC_ADMIN_USERNAME=""; KC_USERNAME_KEY="username"; KC_REALM="fap-pci"; KC_CLIENT_ID="fap-pci-ui"; KC_INSECURE=false
PROVIDER_USERNAME="provider-admin"; PROVIDER_EMAIL=""; PROVIDER_PASSWORD_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2;;
    --context) CONTEXT="$2"; shift 2;;
    --orce-namespace) ORCE_NS="$2"; shift 2;;
    --orce-deployment) ORCE_DEPLOYMENT="$2"; shift 2;;
    --orce-service) ORCE_SERVICE="$2"; shift 2;;
    --orce-container) ORCE_CONTAINER="$2"; shift 2;;
    --orce-service-port) ORCE_SERVICE_PORT="$2"; shift 2;;
    --orce-base-path) ORCE_BASE_PATH="$2"; shift 2;;
    --orce-editor-path) ORCE_EDITOR_PATH="$2"; shift 2;;
    --ocm-namespace) OCM_NS="$2"; shift 2;;
    --main-host) MAIN_HOST="$2"; shift 2;;
    --base-domain) BASE_DOMAIN="$2"; shift 2;;
    --tenant-host-suffix) TENANT_SUFFIX="$2"; shift 2;;
    --registration-mode) REGISTRATION_MODE="$2"; shift 2;;
    --cert) CERT_FILE="$2"; shift 2;;
    --key) KEY_FILE="$2"; shift 2;;
    --tls-secret-name) TLS_SECRET="$2"; shift 2;;
    --infrastructure-namespace) INFRA_NS="$2"; shift 2;;
    --envoy-namespace) ENVOY_NS="$2"; shift 2;;
    --gateway-class-name) GATEWAY_CLASS="$2"; shift 2;;
    --gateway-name) GATEWAY_NAME="$2"; shift 2;;
    --gateway-listener-name) GATEWAY_LISTENER="$2"; shift 2;;
    --envoy-manifest-file) ENVOY_MANIFEST_FILE="$2"; shift 2;;
    --orce-data-pvc) ORCE_DATA_PVC="$2"; shift 2;;
    --orce-data-storage-size) ORCE_DATA_SIZE="$2"; shift 2;;
    --orce-data-storage-class) ORCE_DATA_CLASS="$2"; shift 2;;
    --database-mode) DB_MODE="$2"; shift 2;;
    --database-url) DB_URL="$2"; shift 2;;
    --postgres-storage-size) POSTGRES_SIZE="$2"; shift 2;;
    --postgres-storage-class) POSTGRES_CLASS="$2"; shift 2;;
    --mail-mode) MAIL_MODE="$2"; shift 2;;
    --mailpit-host) MAILPIT_HOST="$2"; shift 2;;
    --expose-mailpit) EXPOSE_MAILPIT="$2"; shift 2;;
    --smtp-from) SMTP_FROM="$2"; shift 2;;
    --smtp-relay-host) SMTP_RELAY_HOST="$2"; shift 2;;
    --smtp-relay-username) SMTP_RELAY_USERNAME="$2"; shift 2;;
    --smtp-relay-password-file) SMTP_RELAY_PASSWORD_FILE="$2"; shift 2;;
    --keycloak-internal-url) KC_INTERNAL="$2"; shift 2;;
    --keycloak-public-url) KC_PUBLIC="$2"; shift 2;;
    --keycloak-service-name) KC_SERVICE="$2"; shift 2;;
    --keycloak-admin-secret-name) KC_SECRET="$2"; shift 2;;
    --keycloak-admin-password-key) KC_PASSWORD_KEY="$2"; shift 2;;
    --keycloak-admin-username) KC_ADMIN_USERNAME="$2"; shift 2;;
    --keycloak-admin-username-key) KC_USERNAME_KEY="$2"; shift 2;;
    --keycloak-realm) KC_REALM="$2"; shift 2;;
    --keycloak-client-id) KC_CLIENT_ID="$2"; shift 2;;
    --provider-username) PROVIDER_USERNAME="$2"; shift 2;;
    --provider-email) PROVIDER_EMAIL="$2"; shift 2;;
    --provider-password-file) PROVIDER_PASSWORD_FILE="$2"; shift 2;;
    --keycloak-insecure) KC_INSECURE=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

for name in ORCE_NS ORCE_DEPLOYMENT MAIN_HOST CERT_FILE KEY_FILE PROVIDER_EMAIL; do [[ -n "${!name}" ]] || {            echo "Missing required argument: $name" >&2; exit 2; }; done
[[ "$DB_MODE" == managed || "$DB_MODE" == external ]] || {            echo "invalid database mode" >&2; exit 2; }
[[ "$MAIL_MODE" == mailpit || "$MAIL_MODE" == smtp ]] || {            echo "invalid mail mode" >&2; exit 2; }
[[ "$EXPOSE_MAILPIT" == auto || "$EXPOSE_MAILPIT" == true || "$EXPOSE_MAILPIT" == false ]] || { echo "invalid --expose-mailpit value" >&2; exit 2; }
[[ "$REGISTRATION_MODE" == public || "$REGISTRATION_MODE" == private ]] || {            echo "invalid registration mode" >&2; exit 2; }
[[ "$DB_MODE" != external || -n "$DB_URL" ]] || {            echo "--database-url required for external DB" >&2; exit 2; }
for binary in kubectl curl jq openssl python3 sha256sum base64 tar helm; do command -v "$binary" >/dev/null 2>&1 || {            echo "$binary is required" >&2; exit 1; }; done

absolute_path(){ local value="$1"; [[ -n "$value" ]] || return 0; [[ "$value" = /* ]] && printf '%s\n' "$value" || printf '%s/%s\n' "$(cd "$(dirname "$value")" && pwd)" "$(basename "$value")"; }
KUBECONFIG_PATH="$(absolute_path "$KUBECONFIG_PATH")"; CERT_FILE="$(absolute_path "$CERT_FILE")"; KEY_FILE="$(absolute_path "$KEY_FILE")"
[[ -z "$SMTP_RELAY_PASSWORD_FILE" ]] || SMTP_RELAY_PASSWORD_FILE="$(absolute_path "$SMTP_RELAY_PASSWORD_FILE")"
[[ -z "$PROVIDER_PASSWORD_FILE" ]] || PROVIDER_PASSWORD_FILE="$(absolute_path "$PROVIDER_PASSWORD_FILE")"
[[ -z "$ENVOY_MANIFEST_FILE" ]] || ENVOY_MANIFEST_FILE="$(absolute_path "$ENVOY_MANIFEST_FILE")"
[[ -f "$CERT_FILE" && -f "$KEY_FILE" ]] || {            echo "TLS certificate/key missing" >&2; exit 2; }
[[ -z "$SMTP_RELAY_PASSWORD_FILE" || -f "$SMTP_RELAY_PASSWORD_FILE" ]] || {            echo "SMTP password file missing" >&2; exit 2; }
[[ -z "$PROVIDER_PASSWORD_FILE" || -f "$PROVIDER_PASSWORD_FILE" ]] || {            echo "provider password file missing" >&2; exit 2; }
MAIN_HOST="${MAIN_HOST,,}"; TENANT_SUFFIX="${TENANT_SUFFIX,,}"; [[ -n "$BASE_DOMAIN" ]] || BASE_DOMAIN="${MAIN_HOST#*.}"; BASE_DOMAIN="${BASE_DOMAIN,,}"
MAILPIT_HOST="${MAILPIT_HOST:-mailpit-${TENANT_SUFFIX}.${BASE_DOMAIN}}"; MAILPIT_HOST="${MAILPIT_HOST,,}"; SMTP_FROM="${SMTP_FROM:-no-reply@${BASE_DOMAIN}}"
case "$EXPOSE_MAILPIT" in true) MAILPIT_PUBLIC=true;; false) MAILPIT_PUBLIC=false;; auto) [[ "$MAIL_MODE" == mailpit ]] && MAILPIT_PUBLIC=true || MAILPIT_PUBLIC=false;; esac

K=(kubectl); [[ -z "$KUBECONFIG_PATH" ]] || K+=(--kubeconfig "$KUBECONFIG_PATH"); [[ -z "$CONTEXT" ]] || K+=(--context "$CONTEXT")
helm upgrade --help | grep -q -- '--take-ownership' || { echo 'Helm 3.17 or newer is required' >&2; exit 2; }
TMP_DIR="$(mktemp -d)"; mkdir -p "$TMP_DIR/manifests"; chmod 700 "$TMP_DIR"; trap 'rm -rf "$TMP_DIR"' EXIT
log(){ jq -nc --arg message "$*" '{event:"pci.deploy.phase",message:$message}' >&2; }; die(){ jq -nc --arg message "$*" '{event:"pci.deploy.failed",message:$message}' >&2; exit 1; }
apply_stdin(){
  local file; file="$(mktemp "$TMP_DIR/manifests/object-XXXXXX.yaml")"; cat > "$file"
  "${K[@]}" create --dry-run=client -f "$file" -o json | jq -s '{apiVersion:"v1",kind:"List",items:[.[] | if .kind == "List" then .items[] else . end]} | .items |= map(.metadata.labels["app.kubernetes.io/managed-by"] = "Helm")' > "$file.json"
  # Schema/bootstrap jobs use the same mounted trust as the runtime. libpq
  # enforces peer verification and TLS 1.3 when database TLS is selected.
  python3 - "$file.json" <<'PYDBTLS'
import json,os
from pathlib import Path
p=Path(__import__('sys').argv[1]);value=json.loads(p.read_text())
secret=os.getenv('PCI_NATIVE_TLS_SECRET','');enabled=os.getenv('PCI_DATABASE_TLS','false').lower()=='true'
settings={'PGSSLMODE':'verify-full','PGSSLMINPROTOCOLVERSION':'TLSv1.3','PGSSLMAXPROTOCOLVERSION':'TLSv1.3'}
for env,key in [('PCI_DATABASE_TLS_CA_FILE','PGSSLROOTCERT'),('PCI_DATABASE_TLS_CERT_FILE','PGSSLCERT'),('PCI_DATABASE_TLS_KEY_FILE','PGSSLKEY')]:
    if os.getenv(env):settings[key]=os.environ[env]
for obj in value['items']:
    if obj.get('kind')!='Job' or obj['metadata']['name'] not in ['fap-pci-schema-init','fap-pci-platform-state']:continue
    spec=obj['spec']['template']['spec']
    if secret:
        spec.setdefault('volumes',[]).append({'name':'pci-database-tls','secret':{'secretName':secret,'defaultMode':256}})
    for container in spec['containers']:
        if secret:container.setdefault('volumeMounts',[]).append({'name':'pci-database-tls','mountPath':'/var/run/fap-pci-native-tls','readOnly':True})
        if enabled:container.setdefault('env',[]).extend({'name':key,'value':val} for key,val in settings.items())
revision=os.getenv('PCI_MESH_REVISION','')
if revision:
    import re
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,62}',revision):raise SystemExit('Invalid PCI_MESH_REVISION')
    namespaces=set()
    for obj in value['items']:
        if obj.get('kind')=='EnvoyProxy':
            # Persist injection on the owning CR, not its reconciled Deployment.
            # Envoy's HTTPS listener already enforces public TLS 1.3; only its
            # outbound traffic enters the mesh. Public clients do not hold mesh certificates.
            pod=obj['spec']['provider']['kubernetes'].setdefault('envoyDeployment',{}).setdefault('pod',{})
            pod.setdefault('labels',{}).update({'sidecar.istio.io/inject':'true','istio.io/rev':revision})
            pod.setdefault('annotations',{}).update({'traffic.sidecar.istio.io/includeInboundPorts':'','sidecar.istio.io/nativeSidecar':'true','proxy.istio.io/config':json.dumps({'holdApplicationUntilProxyStarts':True})})
            continue
        kind=obj.get('kind');template=obj if kind=='Pod' else obj.get('spec',{}).get('template') if kind in ['Deployment','StatefulSet','DaemonSet','Job'] else None
        if template is None:continue
        ns=obj['metadata'].get('namespace');namespaces.add(ns)
        meta=template.setdefault('metadata',{});meta.setdefault('labels',{}).update({'sidecar.istio.io/inject':'true','istio.io/rev':revision,'fap-pci.xfsc.org/tls-workload':'pci-runtime'})
        meta.setdefault('annotations',{}).update({'sidecar.istio.io/nativeSidecar':'true','proxy.istio.io/config':json.dumps({'holdApplicationUntilProxyStarts':True})})
    policies=[{'apiVersion':'security.istio.io/v1','kind':'PeerAuthentication','metadata':{'name':'fap-pci-runtime-tls','namespace':ns},'spec':{'selector':{'matchLabels':{'fap-pci.xfsc.org/tls-workload':'pci-runtime'}},'mtls':{'mode':'STRICT'}}} for ns in sorted(namespaces) if ns]
    value['items']=policies+value['items']
p.write_text(json.dumps(value))
PYDBTLS
  if $DRY_RUN; then
    "${K[@]}" apply --dry-run=client -f "$file.json"
  else
    python3 - "$file.json" "$ORCE_NS" "$INFRA_NS" "${K[@]}" <<'PYPCIAPPLY'
# BEGIN PCI RESOURCE APPLY
#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Apply PCI manifests; migrate only matching Helm-owned fields on conflict.

Embedded in dist/ground-zero.sh by build.js, so the G0 artifact stays standalone.
Kubernetes output is never forwarded: an admission error can contain Secret data.
"""
import copy
import json
import re
import subprocess
import sys


class ApplyError(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def emit(event, **values):
    print(json.dumps({'event': event, **values}), flush=True)


def apply_resources(manifest, namespace, infrastructure, command, run=subprocess.run):
    items = manifest.get('items') if manifest.get('kind') == 'List' else [manifest]
    if not isinstance(items, list) or not items:
        raise ApplyError('PCI-APPLY-MANIFEST')

    def execute(args, body=None):
        try:
            return run(command + args, input=body, text=True, capture_output=True,
                       timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            raise ApplyError('PCI-APPLY-TRANSPORT') from None

    def matching_release(meta):
        annotations = meta.get('annotations', {})
        return (annotations.get('meta.helm.sh/release-name') == 'fap-pci'
                and annotations.get('meta.helm.sh/release-namespace') == namespace)

    def inspect(obj):
        meta = obj['metadata']
        kind, name, ns = obj['kind'], meta['name'], meta.get('namespace', '')
        if kind == 'Namespace':
            if name not in (namespace, infrastructure):
                raise ApplyError('PCI-APPLY-BOUNDARY')
        elif ns:
            if ns not in (namespace, infrastructure):
                raise ApplyError('PCI-APPLY-BOUNDARY')
        elif kind != 'GatewayClass' and (kind not in ('ClusterRole', 'ClusterRoleBinding') or name != 'fap-pci-orce-discovery'):
            raise ApplyError('PCI-APPLY-BOUNDARY')
        result = execute((['-n', ns] if ns else []) + [
            'get', kind, name, '--ignore-not-found', '--show-managed-fields=true', '-o', 'json'])
        if result.returncode:
            raise ApplyError('PCI-APPLY-READ')
        if not result.stdout.strip():
            return None
        try:
            current = json.loads(result.stdout)['metadata']
        except (ValueError, KeyError, TypeError):
            raise ApplyError('PCI-APPLY-READ') from None
        if current.get('name') != name or current.get('namespace', '') != ns:
            raise ApplyError('PCI-APPLY-IDENTITY')
        if kind == 'Namespace':
            return current
        annotations = current.get('annotations', {})
        if any(k in annotations for k in ('meta.helm.sh/release-name', 'meta.helm.sh/release-namespace')):
            if not matching_release(current):
                raise ApplyError('PCI-APPLY-FOREIGN-RELEASE')
        owned = (matching_release(current)
                 or current.get('labels', {}).get('app.kubernetes.io/part-of') == 'fap-pci'
                 or any(x.get('manager') == 'fap-pci-ground-zero'
                        for x in current.get('managedFields', [])))
        if not owned:
            raise ApplyError('PCI-APPLY-UNOWNED')
        if not current.get('uid') or not current.get('resourceVersion'):
            raise ApplyError('PCI-APPLY-IDENTITY')
        return current

    # Check the entire batch before writing any of it.
    initial = [inspect(obj) for obj in items]
    for obj, previous in zip(items, initial):
        desired = copy.deepcopy(obj)
        meta = desired['metadata']
        kind, name, ns = desired['kind'], meta['name'], meta.get('namespace', '')
        target = (['-n', ns] if ns else []) + [
            'apply', '--server-side', '--field-manager=fap-pci-ground-zero']
        result = execute(target + ['-f', '-'], json.dumps(desired))
        if result.returncode:
            conflicts = re.findall(r'conflict with "([^"]+)"', result.stderr)
            eligible = (kind not in ('Namespace', 'GatewayClass') and previous is not None
                        and matching_release(previous) and conflicts
                        and set(conflicts) == {'helm'})
            if not eligible:
                raise ApplyError('PCI-APPLY-CONFLICT' if conflicts else 'PCI-APPLY-REJECTED')
            current = inspect(obj)
            if (current is None or not matching_release(current)
                    or current.get('uid') != previous.get('uid')
                    or current.get('resourceVersion') != previous.get('resourceVersion')):
                raise ApplyError('PCI-APPLY-LIVE-DRIFT')
            meta['resourceVersion'] = current['resourceVersion']
            meta['uid'] = current['uid']
            # One object only. A resourceVersion conflict or any second failure
            # stops; there is no unbounded retry or blanket batch takeover.
            result = execute(target + ['--force-conflicts', '-f', '-'], json.dumps(desired))
            if result.returncode:
                raise ApplyError('PCI-APPLY-MIGRATION-FAILED')
            emit('pci.deploy.ownership-migrated', kind=kind, name=name, namespace=ns,
                 previousManager='helm')
        emit('pci.deploy.resource-applied', kind=kind, name=name, namespace=ns)


def main():
    try:
        path, namespace, infrastructure, *command = sys.argv[1:]
        if not command:
            raise ApplyError('PCI-APPLY-COMMAND')
        with open(path) as stream:
            manifest = json.load(stream)
        apply_resources(manifest, namespace, infrastructure, command)
    except (ApplyError, OSError, ValueError, KeyError, TypeError) as error:
        emit('pci.deploy.failed', code=getattr(error, 'code', 'PCI-APPLY-INPUT'),
             message='PCI resource application failed; inspect ownership and admission events.')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
# END PCI RESOURCE APPLY
PYPCIAPPLY
  fi
}
wait_rollout(){ $DRY_RUN || "${K[@]}" -n "$1" rollout status "$2" --timeout="${3:-10m}"; }
read_secret_key(){ local ns="$1" secret="$2" key="$3" encoded; encoded="$("${K[@]}" -n "$ns" get secret "$secret" -o "jsonpath={.data.${key}}" 2>/dev/null || true)"; [[ -z "$encoded" ]] || printf '%s' "$encoded" | base64 --decode; }
preserve_or_generate(){ local key="$1" command="$2" value; value="$(read_secret_key "$ORCE_NS" fap-pci-runtime "$key")"; [[ -n "$value" ]] && printf '%s' "$value" || eval "$command"; }
normalize_path(){ python3 - "$1" <<'PY'
import re,sys
v=(sys.argv[1] or '').strip()
if v in ('','/'): print(''); raise SystemExit
if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:',v) or v.startswith('//') or re.search(r'[?#\\\s\x00-\x1f\x7f]',v): raise SystemExit(2)
v=('/'+v.lstrip('/')).rstrip('/')
if any((not p) or p in ('.','..') or '%' in p or not re.fullmatch(r'[A-Za-z0-9._~-]+',p) for p in v[1:].split('/')): raise SystemExit(2)
print(v)
PY
}

log "Validate cluster, ORCE and preinstalled OCM"
[[ "$ORCE_NS" != "$OCM_NS" && "$INFRA_NS" != "$OCM_NS" ]] || die "PCI and infrastructure namespaces must be separate from OCM"
"${K[@]}" cluster-info >/dev/null
SERVER_MINOR="$("${K[@]}" version -o json | jq -er 'select(.serverVersion.major=="1") | .serverVersion.minor | capture("^(?<minor>[0-9]+)").minor | tonumber')"
(( SERVER_MINOR >= 33 && SERVER_MINOR <= 36 )) || die "This Envoy 1.9 baseline requires Kubernetes 1.33 through 1.36"
"${K[@]}" get ns "$ORCE_NS" >/dev/null; "${K[@]}" get ns "$OCM_NS" >/dev/null || die "OCM namespace ${OCM_NS} missing"
"${K[@]}" -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" >/dev/null; DEPLOY_JSON="$("${K[@]}" -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" -o json)"
if ! $DRY_RUN && ! "${K[@]}" -n "$ORCE_NS" get secret fap-pci-original-orce >/dev/null 2>&1; then
  printf '%s' "$DEPLOY_JSON" > "$TMP_DIR/original.json"
  "${K[@]}" -n "$ORCE_NS" create secret generic fap-pci-original-orce --from-file=deployment.json="$TMP_DIR/original.json" >/dev/null
fi
[[ "$(jq -r '.spec.replicas//1'<<<"$DEPLOY_JSON")" == 1 ]] || die "PCI requires one active ORCE replica for volatile token and callback state"
[[ -n "$ORCE_CONTAINER" ]] || ORCE_CONTAINER="$(jq -r '.spec.template.spec.containers[0].name' <<<"$DEPLOY_JSON")"
DEPLOY_LABELS="$(jq -c '.spec.template.metadata.labels // {}' <<<"$DEPLOY_JSON")"
if [[ -z "$ORCE_SERVICE" ]]; then ORCE_SERVICE="$("${K[@]}" -n "$ORCE_NS" get svc -o json | jq -r --argjson labels "$DEPLOY_LABELS" '[.items[] | select((.spec.selector // {}) as $s | ($s|length)>0 and all($s|to_entries[]; $labels[.key]==.value)) | .metadata.name] | unique | if length==1 then .[0] else empty end')"; [[ -n "$ORCE_SERVICE" ]] || die "Could not uniquely auto-discover ORCE Service; pass --orce-service"; fi
"${K[@]}" -n "$ORCE_NS" get svc "$ORCE_SERVICE" >/dev/null; [[ -n "$ORCE_SERVICE_PORT" ]] || ORCE_SERVICE_PORT="$("${K[@]}" -n "$ORCE_NS" get svc "$ORCE_SERVICE" -o jsonpath='{.spec.ports[0].port}')"
SELECTOR="$("${K[@]}" -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" -o go-template='{{range $k,$v := .spec.selector.matchLabels}}{{printf "%s=%s," $k $v}}{{end}}'|sed 's/,$//')"; ORCE_POD="$("${K[@]}" -n "$ORCE_NS" get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}')"; [[ -n "$ORCE_POD" ]] || die "No ORCE pod found"
ORCE_IMAGE="$(jq -r --arg c "$ORCE_CONTAINER" '.spec.template.spec.containers[]|select(.name==$c)|.image' <<<"$DEPLOY_JSON")"
discover_setting(){ "${K[@]}" -n "$ORCE_NS" exec -i "$ORCE_POD" -c "$ORCE_CONTAINER" -- node - "$1" "$2" <<'NODE'
const fs=require('fs');const [key,fallback]=process.argv.slice(2);for(const f of ['/data/settings.js','/usr/src/node-red/settings.js']){if(!fs.existsSync(f))continue;try{const s=require(f);const v=s[key]??(key==='httpNodeRoot'?s.httpRoot:undefined);if(typeof v==='string'){process.stdout.write(v);process.exit(0)}}catch{}}process.stdout.write(fallback||'');
NODE
}
[[ -n "$ORCE_BASE_PATH" ]] || ORCE_BASE_PATH="$(discover_setting httpNodeRoot '')"; [[ -n "$ORCE_EDITOR_PATH" ]] || ORCE_EDITOR_PATH="$(discover_setting httpAdminRoot "$ORCE_BASE_PATH")"
ORCE_BASE_PATH="$(normalize_path "$ORCE_BASE_PATH")" || die "Invalid ORCE base path"; ORCE_EDITOR_PATH="$(normalize_path "$ORCE_EDITOR_PATH")" || die "Invalid editor path"
python3 - "$BASE_DOMAIN" "$MAIN_HOST" "$TENANT_SUFFIX" <<'PY'
import re,sys
base,host,suffix=sys.argv[1:]; label=re.compile(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$')
if any(not label.fullmatch(x) for x in base.split('.')): raise SystemExit('invalid base domain')
if not host.endswith('.'+base): raise SystemExit('main host outside base domain')
if not label.fullmatch(suffix): raise SystemExit('invalid tenant suffix')
PY
CERT_PUB="$(openssl x509 -in "$CERT_FILE" -pubkey -noout|openssl pkey -pubin -outform der 2>/dev/null|openssl sha256)"; KEY_PUB="$(openssl pkey -in "$KEY_FILE" -pubout -outform der 2>/dev/null|openssl sha256)"; [[ "$CERT_PUB" == "$KEY_PUB" ]] || die "TLS certificate/key mismatch"
for host in "$MAIN_HOST" "probe-${TENANT_SUFFIX}.${BASE_DOMAIN}"; do openssl x509 -in "$CERT_FILE" -noout -checkhost "$host" >/dev/null || die "TLS certificate does not cover $host"; done
$MAILPIT_PUBLIC && openssl x509 -in "$CERT_FILE" -noout -checkhost "$MAILPIT_HOST" >/dev/null || { $MAILPIT_PUBLIC && die "TLS certificate does not cover $MAILPIT_HOST" || true; }

# Prefer the installed controller in the new OCM infrastructure namespace.
if [[ -z "$ENVOY_NS" ]]; then
  ENVOY_NS="$("${K[@]}" get deployments -A -o json | jq -r '[.items[]|select(.metadata.name=="envoy-gateway")|.metadata.namespace]|unique|if length==1 then .[0] elif length==0 then "envoy-gateway-system" else empty end')"
  [[ -n "$ENVOY_NS" ]] || die "Multiple Envoy controllers; pass --envoy-namespace"
fi
log "Validate PCI infrastructure namespace"
if ! "${K[@]}" get namespace "$INFRA_NS" >/dev/null 2>&1; then
  "${K[@]}" create namespace "$INFRA_NS" --dry-run=client -o yaml | apply_stdin
fi

log "Discover Keycloak wiring from OCM"
KC_WORKLOADS="$("${K[@]}" -n "$OCM_NS" get deploy,statefulset -o json)"
if [[ -z "$KC_SECRET" || -z "$KC_PASSWORD_KEY" ]]; then KC_REF="$(jq -r '[.items[].spec.template.spec.containers[]?.env[]?|select(.name=="KEYCLOAK_ADMIN_PASSWORD" or .name=="KC_BOOTSTRAP_ADMIN_PASSWORD")|select(.valueFrom.secretKeyRef!=null)|[.valueFrom.secretKeyRef.name,.valueFrom.secretKeyRef.key]|@tsv]|unique|if length==1 then .[0] else empty end'<<<"$KC_WORKLOADS")"; [[ -n "$KC_REF" ]] || die "Could not uniquely discover Keycloak admin Secret/key"; KC_SECRET="${KC_SECRET:-$(cut -f1<<<"$KC_REF")}"; KC_PASSWORD_KEY="${KC_PASSWORD_KEY:-$(cut -f2<<<"$KC_REF")}"; fi
KC_ADMIN_PASSWORD="$(read_secret_key "$OCM_NS" "$KC_SECRET" "$KC_PASSWORD_KEY")"; [[ -n "$KC_ADMIN_PASSWORD" ]] || die "Keycloak admin password empty"
[[ -n "$KC_ADMIN_USERNAME" ]] || KC_ADMIN_USERNAME="$(jq -r '[.items[].spec.template.spec.containers[]?.env[]?|select(.name=="KEYCLOAK_ADMIN" or .name=="KC_BOOTSTRAP_ADMIN_USERNAME")|.value//empty]|unique|if length==1 then .[0] else empty end'<<<"$KC_WORKLOADS")"; [[ -n "$KC_ADMIN_USERNAME" ]] || KC_ADMIN_USERNAME="$(read_secret_key "$OCM_NS" "$KC_SECRET" "$KC_USERNAME_KEY")"; KC_ADMIN_USERNAME="${KC_ADMIN_USERNAME:-admin}"
KC_SERVICES="$("${K[@]}" -n "$OCM_NS" get svc -o json)"; [[ -n "$KC_SERVICE" ]] || KC_SERVICE="$(jq -r '([.items[]|select((.metadata.name|test("(^|-)keycloak$")) and .spec.clusterIP!="None")|.metadata.name]+[.items[]|select(.spec.clusterIP!="None" and ((.metadata.labels["app.kubernetes.io/name"]//"")|ascii_downcase)=="keycloak")|.metadata.name]|unique)|if length==1 then .[0] else empty end'<<<"$KC_SERVICES")"; [[ -n "$KC_SERVICE" ]] || die "Could not uniquely discover Keycloak Service"
KC_SVC="$(jq -c --arg n "$KC_SERVICE" '.items[]|select(.metadata.name==$n)'<<<"$KC_SERVICES")"
KC_RELATIVE="$(jq -r '[.items[].spec.template.spec.containers[]?.env[]?|select(.name=="KC_HTTP_RELATIVE_PATH")|.value//empty]|unique|if length==1 then .[0] else "" end'<<<"$KC_WORKLOADS")"
KC_RELATIVE="${KC_RELATIVE%/}"
[[ -n "$KC_PUBLIC" ]] || KC_PUBLIC="$(jq -r '[.items[].spec.template.spec.containers[]?.env[]?|select(.name=="KC_HOSTNAME")|.value//empty|select(startswith("https://"))]|unique|if length==1 then .[0] else empty end'<<<"$KC_WORKLOADS")"
if [[ -z "$KC_INTERNAL" ]]; then KC_PORT="$(jq -r '([.spec.ports[]|select((.name//""|ascii_downcase)=="http")]+[.spec.ports[]|select(.port==80)]+[.spec.ports[]|select((.name//""|ascii_downcase)=="https")]+[.spec.ports[]|select(.port==443)])|.[0].port//empty'<<<"$KC_SVC")"; [[ -n "$KC_PORT" ]] || die "Keycloak Service has no HTTP/HTTPS port"; KC_SCHEME=http; [[ "$KC_PORT" == 443 ]]&&KC_SCHEME=https; KC_SUFFIX=""; [[ "$KC_PORT" == 80 || "$KC_PORT" == 443 ]]||KC_SUFFIX=":$KC_PORT"; KC_INTERNAL="${KC_SCHEME}://${KC_SERVICE}.${OCM_NS}.svc.cluster.local${KC_SUFFIX}${KC_RELATIVE}"; fi
if [[ -z "$KC_PUBLIC" ]]; then KC_HOST="$("${K[@]}" -n "$OCM_NS" get ingress -o json 2>/dev/null|jq -r --arg svc "$KC_SERVICE" '[.items[] as $i|$i.spec.rules[]? as $r|$r.http.paths[]?|select(.backend.service.name==$svc)|$r.host]|unique|if length==1 then .[0] else empty end'||true)"; [[ -n "$KC_HOST" ]] || KC_HOST="$("${K[@]}" -n "$OCM_NS" get httproute -o json 2>/dev/null|jq -r --arg svc "$KC_SERVICE" '[.items[] as $i|$i.spec.rules[]?.backendRefs[]?|select(.name==$svc)|$i.spec.hostnames[]?]|unique|if length==1 then .[0] else empty end'||true)"; [[ -n "$KC_HOST" ]] || die "Could not discover public Keycloak host; pass --keycloak-public-url"; KC_PUBLIC="https://${KC_HOST}${KC_RELATIVE}"; fi
KC_INTERNAL="${KC_INTERNAL%/}"; KC_PUBLIC="${KC_PUBLIC%/}"

PROVIDER_PASSWORD="$(read_secret_key "$ORCE_NS" fap-pci-runtime PCI_BOOTSTRAP_PROVIDER_PASSWORD)"; [[ -n "$PROVIDER_PASSWORD" ]] || {            [[ -n "$PROVIDER_PASSWORD_FILE" ]]&&PROVIDER_PASSWORD="$(<"$PROVIDER_PASSWORD_FILE")"||PROVIDER_PASSWORD="$(openssl rand -base64 32|tr -d '\n')"; }
VERIFY_PEPPER="$(preserve_or_generate PCI_VERIFICATION_TOKEN_PEPPER 'openssl rand -hex 32')"; INTERNAL_TOKEN="$(preserve_or_generate PCI_INTERNAL_SERVICE_TOKEN 'openssl rand -hex 32')"; POSTGRES_PASSWORD="$(read_secret_key "$ORCE_NS" fap-pci-runtime PCI_POSTGRES_PASSWORD)"; [[ -n "$POSTGRES_PASSWORD" ]] || POSTGRES_PASSWORD="$(read_secret_key "$ORCE_NS" fap-pci-managed-postgres password)"; [[ -n "$POSTGRES_PASSWORD" ]] || POSTGRES_PASSWORD="$(openssl rand -base64 32|tr -d "\n"|tr "/+" "_-")"; SMTP_RELAY_PASSWORD=""; [[ -z "$SMTP_RELAY_PASSWORD_FILE" ]]||SMTP_RELAY_PASSWORD="$(<"$SMTP_RELAY_PASSWORD_FILE")"; [[ "$DB_MODE" != managed ]]||DB_URL="postgresql://fap_pci:${POSTGRES_PASSWORD}@fap-pci-postgres.${ORCE_NS}.svc.cluster.local:5432/fap_pci"

log "Prepare persistent ORCE /data and Function-node prerequisites"
CURRENT_DATA_VOLUME="$(jq -r --arg c "$ORCE_CONTAINER" '.spec.template.spec.containers[]|select(.name==$c)|[.volumeMounts[]?|select(.mountPath=="/data")|.name][0]//empty'<<<"$DEPLOY_JSON")"; CURRENT_DATA_CLAIM="$(jq -r --arg v "$CURRENT_DATA_VOLUME" '.spec.template.spec.volumes[]?|select(.name==$v)|.persistentVolumeClaim.claimName//empty'<<<"$DEPLOY_JSON")"; DATA_CLAIM="${CURRENT_DATA_CLAIM:-$ORCE_DATA_PVC}"; DATA_VOLUME="${CURRENT_DATA_VOLUME:-fap-pci-data}"
if [[ -z "$CURRENT_DATA_CLAIM" ]]; then SC=""; [[ -z "$ORCE_DATA_CLASS" ]]||SC="  storageClassName: ${ORCE_DATA_CLASS}"; cat <<YAML | apply_stdin
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: ${DATA_CLAIM}, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec:
  accessModes: [ReadWriteOnce]
${SC}
  resources: {requests: {storage: ${ORCE_DATA_SIZE}}}
YAML
fi
UID_NOW="$("${K[@]}" -n "$ORCE_NS" exec "$ORCE_POD" -c "$ORCE_CONTAINER" -- id -u)"; GID_NOW="$("${K[@]}" -n "$ORCE_NS" exec "$ORCE_POD" -c "$ORCE_CONTAINER" -- id -g)"
install_modules(){ local pod="$1" container="$2"; "${K[@]}" -n "$ORCE_NS" exec "$pod" -c "$container" -- sh -lc "set -eu;cd /data;[ -f package.json ]||npm init -y>/dev/null;npm install --save-exact --no-audit --no-fund pg@8.16.3 nodemailer@10.0.9 jsonwebtoken@9.0.2 jwks-rsa@3.2.0 yaml@2.9.1 node-red-contrib-uibuilder@${UIBUILDER_VERSION};mkdir -p /data/fap-pci /data/uibuilder/ui/src"; }
if ! $DRY_RUN; then if [[ -n "$CURRENT_DATA_CLAIM" ]]; then install_modules "$ORCE_POD" "$ORCE_CONTAINER"; else "${K[@]}" -n "$ORCE_NS" delete pod fap-pci-data-prep --ignore-not-found --wait=true>/dev/null 2>&1||true; cat <<YAML | apply_stdin
apiVersion: v1
kind: Pod
metadata: {name: fap-pci-data-prep, namespace: ${ORCE_NS}}
spec:
  restartPolicy: Never
  securityContext: {fsGroup: ${GID_NOW}}
  initContainers: [{name: permissions, image: alpine:3.20, resources: {requests: {cpu: 10m, memory: 32Mi}, limits: {cpu: 100m, memory: 128Mi}}, command: [sh,-lc,"chown -R ${UID_NOW}:${GID_NOW} /data"], securityContext: {runAsUser: 0}, volumeMounts: [{name: data, mountPath: /data}]}]
  containers: [{name: prep, image: ${ORCE_IMAGE}, resources: {requests: {cpu: 100m, memory: 256Mi}, limits: {cpu: "1", memory: 1Gi}}, command: [sh,-lc,"sleep 3600"], securityContext: {runAsUser: ${UID_NOW}, runAsGroup: ${GID_NOW}}, volumeMounts: [{name: data, mountPath: /data}]}]
  volumes: [{name: data, persistentVolumeClaim: {claimName: ${DATA_CLAIM}}}]
YAML
"${K[@]}" -n "$ORCE_NS" wait --for=condition=Ready pod/fap-pci-data-prep --timeout=5m; "${K[@]}" -n "$ORCE_NS" exec "$ORCE_POD" -c "$ORCE_CONTAINER" -- tar -C /data --exclude=node_modules --exclude=.npm --exclude=.cache -cf - .|"${K[@]}" -n "$ORCE_NS" exec -i fap-pci-data-prep -c prep -- tar -C /data -xf -; install_modules fap-pci-data-prep prep; "${K[@]}" -n "$ORCE_NS" delete pod fap-pci-data-prep --wait=true; fi; fi

log "Install or validate pinned Envoy Gateway and GatewayClass"
if ! "${K[@]}" -n "$ENVOY_NS" get deploy envoy-gateway >/dev/null 2>&1; then
  for cap in "create namespaces" "create customresourcedefinitions.apiextensions.k8s.io" "create clusterroles.rbac.authorization.k8s.io" "create clusterrolebindings.rbac.authorization.k8s.io" "create validatingadmissionpolicies.admissionregistration.k8s.io" "create validatingadmissionpolicybindings.admissionregistration.k8s.io"; do read -r verb resource<<<"$cap"; [[ "$("${K[@]}" auth can-i "$verb" "$resource")" == yes ]]||die "Current kubeconfig cannot $cap"; done
  ENVOY_FILE="$TMP_DIR/envoy.yaml"; [[ -z "$ENVOY_MANIFEST_FILE" ]]&&curl -fL --retry 3 "$ENVOY_URL" -o "$ENVOY_FILE"||cp "$ENVOY_MANIFEST_FILE" "$ENVOY_FILE"; [[ "$(sha256sum "$ENVOY_FILE"|awk '{print $1}')" == "$ENVOY_SHA256" ]]||die "Envoy manifest digest mismatch"
  "${K[@]}" get crd -o json|jq -r '.items[].metadata.name|select(endswith(".gateway.networking.k8s.io"))'>"$TMP_DIR/existing-crds"
  python3 - "$ENVOY_FILE" "$TMP_DIR/existing-crds" "$TMP_DIR/envoy-filtered.yaml" <<'PY'
import re,sys
src,names,out=sys.argv[1:];existing={x.strip() for x in open(names) if x.strip()};kept=[]
for d in re.split(r'(?m)^---\s*$',open(src).read()):
 if not d.strip():continue
 k=re.search(r'(?m)^kind:\s*([^\s#]+)',d);n=re.search(r'(?m)^\s{2}name:\s*["\']?([^"\'#\s]+)',d)
 if k and n and k.group(1)=='CustomResourceDefinition' and n.group(1) in existing:continue
 kept.append(d.strip())
open(out,'w').write(''.join('---\n'+d+'\n' for d in kept))
PY
  if $DRY_RUN; then "${K[@]}" apply --dry-run=client -f "$TMP_DIR/envoy-filtered.yaml">/dev/null; else "${K[@]}" apply --server-side --force-conflicts --field-manager=fap-pci-envoy-bootstrap -f "$TMP_DIR/envoy-filtered.yaml";wait_rollout "$ENVOY_NS" deploy/envoy-gateway 10m;fi
else wait_rollout "$ENVOY_NS" deploy/envoy-gateway 10m;fi
EXISTING_CONTROLLER="$("${K[@]}" get gatewayclass "$GATEWAY_CLASS" -o jsonpath='{.spec.controllerName}' 2>/dev/null||true)";[[ -z "$EXISTING_CONTROLLER"||"$EXISTING_CONTROLLER" == gateway.envoyproxy.io/gatewayclass-controller ]]||die "GatewayClass collision"
if [[ -z "$EXISTING_CONTROLLER" ]]; then
cat <<YAML | apply_stdin
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: {name: ${GATEWAY_CLASS}}
spec: {controllerName: gateway.envoyproxy.io/gatewayclass-controller}
YAML
fi
$DRY_RUN||"${K[@]}" wait --for=condition=Accepted gatewayclass/"$GATEWAY_CLASS" --timeout=5m

log "Prepare PostgreSQL"
if [[ "$DB_MODE" == managed ]]; then
"${K[@]}" -n "$ORCE_NS" create secret generic fap-pci-managed-postgres --from-literal=username=fap_pci --from-literal=password="$POSTGRES_PASSWORD" --from-literal=database=fap_pci --dry-run=client -o yaml|apply_stdin
PSC="";[[ -z "$POSTGRES_CLASS" ]]||PSC="      storageClassName: ${POSTGRES_CLASS}"
cat <<YAML | apply_stdin
apiVersion: v1
kind: Service
metadata: {name: fap-pci-postgres, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
spec: {selector: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}, ports: [{name: postgresql, port: 5432, targetPort: 5432}]}
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: fap-pci-postgres, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
spec:
  serviceName: fap-pci-postgres
  replicas: 1
  selector: {matchLabels: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
  template:
    metadata: {labels: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
    spec:
      securityContext: {fsGroup: 70, fsGroupChangePolicy: OnRootMismatch, seccompProfile: {type: RuntimeDefault}}
      containers:
      - name: postgresql
        image: ${POSTGRES_IMAGE}
        resources: {requests: {cpu: 100m, memory: 256Mi}, limits: {cpu: "1", memory: 1Gi}}
        imagePullPolicy: IfNotPresent
        securityContext: {allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 70, runAsGroup: 70, capabilities: {drop: [ALL]}}
        env:
        - {name: POSTGRES_USER, valueFrom: {secretKeyRef: {name: fap-pci-managed-postgres, key: username}}}
        - {name: POSTGRES_PASSWORD, valueFrom: {secretKeyRef: {name: fap-pci-managed-postgres, key: password}}}
        - {name: POSTGRES_DB, valueFrom: {secretKeyRef: {name: fap-pci-managed-postgres, key: database}}}
        - {name: PGDATA, value: /var/lib/postgresql/data/pgdata}
        ports: [{name: postgresql, containerPort: 5432}]
        volumeMounts: [{name: data, mountPath: /var/lib/postgresql/data}]
        readinessProbe: {exec: {command: [sh,-c,'pg_isready -U "\$POSTGRES_USER" -d "\$POSTGRES_DB"']}, periodSeconds: 5, timeoutSeconds: 3, failureThreshold: 12}
        livenessProbe: {exec: {command: [sh,-c,'pg_isready -U "\$POSTGRES_USER" -d "\$POSTGRES_DB"']}, periodSeconds: 10, timeoutSeconds: 3, failureThreshold: 6}
  volumeClaimTemplates:
  - metadata: {name: data, labels: {app.kubernetes.io/name: fap-pci-postgres, app.kubernetes.io/part-of: fap-pci}}
    spec:
      accessModes: [ReadWriteOnce]
${PSC}
      resources: {requests: {storage: ${POSTGRES_SIZE}}}
YAML
if ! $DRY_RUN&&! "${K[@]}" -n "$ORCE_NS" rollout status sts/fap-pci-postgres --timeout=5m;then CURRENT_REV="$("${K[@]}" -n "$ORCE_NS" get sts fap-pci-postgres -o jsonpath='{.status.currentRevision}')";UPDATE_REV="$("${K[@]}" -n "$ORCE_NS" get sts fap-pci-postgres -o jsonpath='{.status.updateRevision}')";[[ -n "$UPDATE_REV"&&"$CURRENT_REV" != "$UPDATE_REV" ]]||die "PostgreSQL not ready";"${K[@]}" -n "$ORCE_NS" delete pod fap-pci-postgres-0 --wait=true;"${K[@]}" -n "$ORCE_NS" rollout status sts/fap-pci-postgres --timeout=5m;fi
fi

log "Prepare configured mail transport"
MAILPIT_REPLICAS=0; SMTP_RELAY_REPLICAS=0
[[ "$MAIL_MODE" != mailpit ]] || MAILPIT_REPLICAS=1
$MAILPIT_PUBLIC && MAILPIT_REPLICAS=1
[[ "$MAIL_MODE" != smtp ]] || SMTP_RELAY_REPLICAS=1
"${K[@]}" -n "$ORCE_NS" create secret generic fap-pci-smtp-relay --from-literal=username="$SMTP_RELAY_USERNAME" --from-literal=password="$SMTP_RELAY_PASSWORD" --dry-run=client -o yaml|apply_stdin
SMTP_SENDER_DOMAIN="${SMTP_FROM##*@}"
[[ "$SMTP_SENDER_DOMAIN" != "$SMTP_FROM" && "$SMTP_SENDER_DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] || die "Invalid SMTP sender domain"
SMTP_ENV="          - {name: ALLOWED_SENDER_DOMAINS, value: '${SMTP_SENDER_DOMAIN}'}"
if [[ -n "$SMTP_RELAY_HOST" ]];then SMTP_ENV+=$'\n'; SMTP_ENV+="          - {name: RELAYHOST, value: '${SMTP_RELAY_HOST}'}";if [[ -n "$SMTP_RELAY_USERNAME" ]];then SMTP_ENV+=$'\n          - {name: RELAYHOST_USERNAME, valueFrom: {secretKeyRef: {name: fap-pci-smtp-relay, key: username}}}\n          - {name: RELAYHOST_PASSWORD, valueFrom: {secretKeyRef: {name: fap-pci-smtp-relay, key: password}}}';fi;fi
cat <<YAML | apply_stdin
apiVersion: v1
kind: Service
metadata: {name: fap-pci-mailpit, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-mailpit, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
spec: {selector: {app.kubernetes.io/name: fap-pci-mailpit, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}, ports: [{name: smtp, port: 1025, targetPort: 1025},{name: http, port: 8025, targetPort: 8025}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: fap-pci-mailpit, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-mailpit, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
spec:
  replicas: ${MAILPIT_REPLICAS}
  selector: {matchLabels: {app.kubernetes.io/name: fap-pci-mailpit, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
  template:
    metadata: {labels: {app.kubernetes.io/name: fap-pci-mailpit, app.kubernetes.io/part-of: fap-pci, app.kubernetes.io/managed-by: fap-pci-orce}}
    spec:
      securityContext: {seccompProfile: {type: RuntimeDefault}}
      containers:
      - name: mailpit
        image: ${MAILPIT_IMAGE}
        resources: {requests: {cpu: 10m, memory: 32Mi}, limits: {cpu: 250m, memory: 128Mi}}
        imagePullPolicy: IfNotPresent
        securityContext: {allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 70, runAsGroup: 70, capabilities: {drop: [ALL]}}
        ports: [{name: smtp, containerPort: 1025},{name: http, containerPort: 8025}]
        readinessProbe: {httpGet: {path: /livez, port: http}, periodSeconds: 5, failureThreshold: 12}
---
apiVersion: v1
kind: Service
metadata: {name: fap-pci-smtp-relay, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-smtp-relay, app.kubernetes.io/part-of: fap-pci}}
spec: {selector: {app.kubernetes.io/name: fap-pci-smtp-relay}, ports: [{name: submission, port: 587, targetPort: 587}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: fap-pci-smtp-relay, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/name: fap-pci-smtp-relay, app.kubernetes.io/part-of: fap-pci}}
spec:
  replicas: ${SMTP_RELAY_REPLICAS}
  selector: {matchLabels: {app.kubernetes.io/name: fap-pci-smtp-relay}}
  template:
    metadata: {labels: {app.kubernetes.io/name: fap-pci-smtp-relay, app.kubernetes.io/part-of: fap-pci}}
    spec:
      containers:
      - name: postfix
        image: ${SMTP_RELAY_IMAGE}
        resources: {requests: {cpu: 10m, memory: 32Mi}, limits: {cpu: 250m, memory: 128Mi}}
        imagePullPolicy: IfNotPresent
        env:
${SMTP_ENV}
        ports: [{name: submission, containerPort: 587}]
        readinessProbe: {tcpSocket: {port: submission}, periodSeconds: 5, failureThreshold: 12}
YAML
wait_rollout "$ORCE_NS" deploy/fap-pci-mailpit 5m;wait_rollout "$ORCE_NS" deploy/fap-pci-smtp-relay 5m
ACTIVE_SMTP_HOST="fap-pci-mailpit.${ORCE_NS}.svc.cluster.local";ACTIVE_SMTP_PORT=1025;[[ "$MAIL_MODE" == mailpit ]]|| {            ACTIVE_SMTP_HOST="fap-pci-smtp-relay.${ORCE_NS}.svc.cluster.local";ACTIVE_SMTP_PORT=587; }

log "Restrict ORCE ingress to this PCI Gateway"
ORCE_TARGET_PORT="$("${K[@]}" -n "$ORCE_NS" get svc "$ORCE_SERVICE" -o json | jq -c --argjson port "$ORCE_SERVICE_PORT" '.spec.ports[]|select(.port==$port)|(.targetPort//.port)')"
[[ -n "$ORCE_TARGET_PORT" ]] || die "ORCE Service port has no target"
jq -nc --arg ns "$ORCE_NS" --arg ens "$ENVOY_NS" --arg gateway "$GATEWAY_NAME" --arg infra "$INFRA_NS" --argjson labels "$DEPLOY_LABELS" --argjson port "$ORCE_TARGET_PORT" '{apiVersion:"networking.k8s.io/v1",kind:"NetworkPolicy",metadata:{name:"fap-pci-orce-ingress",namespace:$ns,labels:{"app.kubernetes.io/part-of":"fap-pci"}},spec:{podSelector:{matchLabels:$labels},policyTypes:["Ingress"],ingress:[{from:[{namespaceSelector:{matchLabels:{"kubernetes.io/metadata.name":$ens}},podSelector:{matchLabels:{"gateway.envoyproxy.io/owning-gateway-name":$gateway,"gateway.envoyproxy.io/owning-gateway-namespace":$infra}}}],ports:[{protocol:"TCP",port:$port}]}]}}' | apply_stdin

log "Apply PCI-owned workload NetworkPolicies"
cat <<YAML | apply_stdin
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: fap-pci-postgres-ingress, namespace: ${ORCE_NS}}
spec:
  podSelector: {matchLabels: {app.kubernetes.io/name: fap-pci-postgres}}
  policyTypes: [Ingress]
  ingress: [{from: [{podSelector: {}}], ports: [{protocol: TCP, port: 5432}]}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: fap-pci-mailpit-ingress, namespace: ${ORCE_NS}}
spec:
  podSelector: {matchLabels: {app.kubernetes.io/name: fap-pci-mailpit}}
  policyTypes: [Ingress]
  ingress:
  - {from: [{podSelector: {}}, {namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: ${OCM_NS}}}}], ports: [{protocol: TCP, port: 1025}]}
  - {from: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: ${ENVOY_NS}}}}], ports: [{protocol: TCP, port: 8025}]}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: fap-pci-smtp-relay-ingress, namespace: ${ORCE_NS}}
spec:
  podSelector: {matchLabels: {app.kubernetes.io/name: fap-pci-smtp-relay}}
  policyTypes: [Ingress]
  ingress: [{from: [{podSelector: {}}, {namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: ${OCM_NS}}}}], ports: [{protocol: TCP, port: 587}]}]
YAML

log "Create runtime config/secrets and bounded runtime RBAC"
"${K[@]}" -n "$ORCE_NS" create secret tls "$TLS_SECRET" --cert="$CERT_FILE" --key="$KEY_FILE" --dry-run=client -o yaml|apply_stdin
"${K[@]}" -n "$ORCE_NS" create configmap fap-pci-config --from-literal=PCI_DATABASE_TLS="${PCI_DATABASE_TLS:-false}" --from-literal=PCI_DATABASE_TLS_CA_FILE="${PCI_DATABASE_TLS_CA_FILE:-}" --from-literal=PCI_DATABASE_TLS_CERT_FILE="${PCI_DATABASE_TLS_CERT_FILE:-}" --from-literal=PCI_DATABASE_TLS_KEY_FILE="${PCI_DATABASE_TLS_KEY_FILE:-}" --from-literal=PCI_SMTP_REQUIRE_TLS="${PCI_SMTP_REQUIRE_TLS:-false}" --from-literal=PCI_SMTP_TLS_CA_FILE="${PCI_SMTP_TLS_CA_FILE:-}" --from-literal=PCI_SMTP_TLS_CERT_FILE="${PCI_SMTP_TLS_CERT_FILE:-}" --from-literal=PCI_SMTP_TLS_KEY_FILE="${PCI_SMTP_TLS_KEY_FILE:-}" --from-literal=PCI_NATIVE_TRANSPORT_PROFILE="${PCI_NATIVE_TRANSPORT_PROFILE:-cluster}" --from-literal=PCI_SIGNER_URL="${PCI_SIGNER_URL:-}" --from-literal=PCI_WELLKNOWN_URL="${PCI_WELLKNOWN_URL:-}" --from-literal=PCI_STATUS_URL="${PCI_STATUS_URL:-}" --from-literal=PCI_PREAUTH_URL="${PCI_PREAUTH_URL:-}" --from-literal=PCI_ISSUANCE_URL="${PCI_ISSUANCE_URL:-}" --from-literal=PCI_NATIVE_TLS_CA_FILE="${PCI_NATIVE_TLS_CA_FILE:-}" --from-literal=PCI_NATIVE_TLS_CERT_FILE="${PCI_NATIVE_TLS_CERT_FILE:-}" --from-literal=PCI_NATIVE_TLS_KEY_FILE="${PCI_NATIVE_TLS_KEY_FILE:-}" --from-literal=PCI_NATS_TLS_HANDSHAKE_FIRST="${PCI_NATS_TLS_HANDSHAKE_FIRST:-false}" --from-literal=PCI_NATS_TLS_CA_FILE="${PCI_NATS_TLS_CA_FILE:-}" --from-literal=PCI_NATS_TLS_CERT_FILE="${PCI_NATS_TLS_CERT_FILE:-}" --from-literal=PCI_NATS_TLS_KEY_FILE="${PCI_NATS_TLS_KEY_FILE:-}" --from-literal=PCI_OCM_EMPTY_CATALOGUE_SUPPORTED="${PCI_OCM_EMPTY_CATALOGUE_SUPPORTED:-false}" --from-literal=PCI_NATS_URL="${PCI_NATS_URL:-nats://nats.${INFRA_NS}.svc.cluster.local:4222}" --from-literal=PCI_PARTICIPANT_PRIVATE_ADDRESSES="${PCI_PARTICIPANT_PRIVATE_ADDRESSES:-}" --from-literal=PCI_PARTICIPANT_JWT_ISSUERS="${PCI_PARTICIPANT_JWT_ISSUERS:-${KC_PUBLIC}/realms/${KC_REALM}}" --from-literal=PCI_IDENTITY_ALLOWED_ISSUERS="${PCI_IDENTITY_ALLOWED_ISSUERS:-}" --from-literal=PCI_OTLP_HTTP_ENDPOINT="${PCI_OTLP_HTTP_ENDPOINT:-}" --from-literal=PCI_PARTICIPANT_ALLOWED_HOSTS="${PCI_PARTICIPANT_ALLOWED_HOSTS:-}" --from-literal=PCI_INTERNAL_ALLOWED_IPS="${PCI_INTERNAL_ALLOWED_IPS:-}" --from-literal=PCI_BASE_DOMAIN="$BASE_DOMAIN" --from-literal=PCI_MAIN_HOST="$MAIN_HOST" --from-literal=PCI_TENANT_HOST_SUFFIX="$TENANT_SUFFIX" --from-literal=PCI_ORCE_BASE_PATH="$ORCE_BASE_PATH" --from-literal=PCI_ORCE_EDITOR_PATH="$ORCE_EDITOR_PATH" --from-literal=PCI_REGISTRATION_MODE="$REGISTRATION_MODE" --from-literal=PCI_ORCE_NAMESPACE="$ORCE_NS" --from-literal=PCI_ORCE_SERVICE="$ORCE_SERVICE" --from-literal=PCI_ORCE_SERVICE_PORT="$ORCE_SERVICE_PORT" --from-literal=PCI_OCM_NAMESPACE="$OCM_NS" --from-literal=PCI_OCM_CREDENTIAL_ISSUANCE_SERVICE=issuance-service --from-literal=PCI_OCM_WELL_KNOWN_SERVICE=well-known-service --from-literal=PCI_OCM_PREAUTH_SERVICE=pre-authorization-bridge-service --from-literal=PCI_OCM_SIGNER_SERVICE=signer --from-literal=PCI_SIGNER_TOPIC="${PCI_SIGNER_TOPIC:-signer-topic}" --from-literal=PCI_INFRASTRUCTURE_NAMESPACE="$INFRA_NS" --from-literal=PCI_ENVOY_NAMESPACE="$ENVOY_NS" --from-literal=PCI_GATEWAY_NAME="$GATEWAY_NAME" --from-literal=PCI_GATEWAY_CLASS_NAME="$GATEWAY_CLASS" --from-literal=PCI_GATEWAY_LISTENER_NAME="$GATEWAY_LISTENER" --from-literal=PCI_GATEWAY_ADDRESS_TYPE=IPAddress --from-literal=PCI_DATABASE_MODE="$DB_MODE" --from-literal=PCI_MAIL_MODE="$MAIL_MODE" --from-literal=PCI_SMTP_HOST="$ACTIVE_SMTP_HOST" --from-literal=PCI_SMTP_PORT="$ACTIVE_SMTP_PORT" --from-literal=PCI_SMTP_FROM="$SMTP_FROM" --from-literal=PCI_SMTP_SECURE=false --from-literal=PCI_SMTP_USERNAME= --from-literal=PCI_KEYCLOAK_INTERNAL_URL="$KC_INTERNAL" --from-literal=PCI_KEYCLOAK_PUBLIC_URL="$KC_PUBLIC" --from-literal=PCI_KEYCLOAK_REALM="$KC_REALM" --from-literal=PCI_KEYCLOAK_UI_CLIENT_ID="$KC_CLIENT_ID" --from-literal=PCI_KEYCLOAK_ADMIN_USERNAME="$KC_ADMIN_USERNAME" --from-literal=PCI_KEYCLOAK_ADMIN_PASSWORD_FILE=/var/run/fap-pci-secrets/PCI_KEYCLOAK_ADMIN_PASSWORD --from-literal=PCI_BOOTSTRAP_PROVIDER_USERNAME="$PROVIDER_USERNAME" --from-literal=PCI_BOOTSTRAP_PROVIDER_EMAIL="$PROVIDER_EMAIL" --from-literal=PCI_TLS_SECRET_NAME="$TLS_SECRET" --dry-run=client -o yaml|apply_stdin
"${K[@]}" -n "$ORCE_NS" create secret generic fap-pci-runtime --from-literal=PCI_DATABASE_URL="$DB_URL" --from-literal=PCI_POSTGRES_PASSWORD="$POSTGRES_PASSWORD" --from-literal=PCI_VERIFICATION_TOKEN_PEPPER="$VERIFY_PEPPER" --from-literal=PCI_INTERNAL_SERVICE_TOKEN="$INTERNAL_TOKEN" --from-literal=PCI_KEYCLOAK_ADMIN_PASSWORD="$KC_ADMIN_PASSWORD" --from-literal=PCI_BOOTSTRAP_PROVIDER_PASSWORD="$PROVIDER_PASSWORD" --from-literal=PCI_SMTP_PASSWORD= --dry-run=client -o yaml|apply_stdin
cat <<YAML | apply_stdin
apiVersion: v1
kind: ServiceAccount
metadata: {name: fap-pci-orce, namespace: ${ORCE_NS}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: fap-pci-orce-runtime, namespace: ${ORCE_NS}}
rules:
- {apiGroups: [''], resources: [configmaps], verbs: [get,list,watch,create,update,patch,delete]}
- {apiGroups: [gateway.networking.k8s.io], resources: [httproutes,referencegrants], verbs: [get,list,watch,create,update,patch,delete]}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: fap-pci-orce-runtime, namespace: ${ORCE_NS}}
subjects: [{kind: ServiceAccount, name: fap-pci-orce, namespace: ${ORCE_NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: fap-pci-orce-runtime}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: fap-pci-orce-gateway-reader, namespace: ${INFRA_NS}}
rules: [{apiGroups: [gateway.networking.k8s.io], resources: [gateways], verbs: [get,list,watch]}]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: fap-pci-orce-gateway-reader, namespace: ${INFRA_NS}}
subjects: [{kind: ServiceAccount, name: fap-pci-orce, namespace: ${ORCE_NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: fap-pci-orce-gateway-reader}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: fap-pci-orce-discovery}
rules:
- {apiGroups: [''], resources: [namespaces], verbs: [get,list,watch]}
- {apiGroups: [rbac.authorization.k8s.io], resources: [clusterroles], verbs: [get]}
- {apiGroups: [gateway.networking.k8s.io], resources: [gatewayclasses], verbs: [get,list,watch]}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: fap-pci-orce-discovery}
subjects: [{kind: ServiceAccount, name: fap-pci-orce, namespace: ${ORCE_NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: fap-pci-orce-discovery}
YAML

# A single named Secret stores tenant broker credentials. Runtime access is
# confined to this Secret; tenant administrators never receive its contents.
if ! $DRY_RUN && ! "${K[@]}" -n "$ORCE_NS" get secret fap-pci-identity >/dev/null 2>&1;then
  "${K[@]}" -n "$ORCE_NS" create secret generic fap-pci-identity --dry-run=client -o json | jq --arg uid "$(jq -er .metadata.uid <<< "$DEPLOY_JSON")" '.metadata.labels={"app.kubernetes.io/part-of":"fap-pci","fap-pci.xfsc.org/runtime-uid":$uid}' | "${K[@]}" apply --server-side --field-manager=fap-pci-identity -f -
fi
cat <<YAML | apply_stdin
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: fap-pci-identity, namespace: ${ORCE_NS}}
rules:
- {apiGroups: [''], resources: [secrets], resourceNames: [fap-pci-identity], verbs: [get,patch]}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: fap-pci-identity, namespace: ${ORCE_NS}}
subjects: [{kind: ServiceAccount, name: fap-pci-orce, namespace: ${ORCE_NS}}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: fap-pci-identity}
YAML

log "Initialize PCI schema before ORCE modules run"
cat <<'SQL' >"$TMP_DIR/schema.sql"
BEGIN;
CREATE TABLE IF NOT EXISTS tenant_registrations (registration_id UUID PRIMARY KEY,organization_identifier TEXT NOT NULL,organization_name TEXT NOT NULL,contact_name TEXT NOT NULL,contact_email TEXT NOT NULL,requested_slug TEXT NOT NULL,requested_domain TEXT NOT NULL,registration_mode TEXT NOT NULL CHECK(registration_mode IN('public','private')),state TEXT NOT NULL CHECK(state IN('requested','pending_approval','approved','rejected','expired')),verification_token_hash TEXT,verification_expires_at TIMESTAMPTZ,email_verified_at TIMESTAMPTZ,email_delivery_status TEXT NOT NULL CHECK(email_delivery_status IN('pending','sent','failed')),reviewed_by TEXT,reviewed_at TIMESTAMPTZ,decision_reason TEXT,version INTEGER NOT NULL DEFAULT 1 CHECK(version>0),created_at TIMESTAMPTZ NOT NULL,updated_at TIMESTAMPTZ NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS uq_registration_active_organization ON tenant_registrations(lower(organization_identifier)) WHERE state NOT IN('rejected','expired');
CREATE UNIQUE INDEX IF NOT EXISTS uq_registration_active_slug ON tenant_registrations(requested_slug) WHERE state NOT IN('rejected','expired');
CREATE TABLE IF NOT EXISTS tenants (tenant_id UUID PRIMARY KEY,registration_id UUID NOT NULL UNIQUE REFERENCES tenant_registrations(registration_id),tenant_slug TEXT NOT NULL UNIQUE,owner_uid UUID NOT NULL UNIQUE,organization_identifier TEXT NOT NULL UNIQUE,organization_name TEXT NOT NULL,primary_domain TEXT NOT NULL UNIQUE,state TEXT NOT NULL CHECK(state IN('provisioning','active','suspended','deleting','deleted','failed')),desired_generation BIGINT NOT NULL DEFAULT 1 CHECK(desired_generation>0),observed_generation BIGINT NOT NULL DEFAULT 0 CHECK(observed_generation>=0),conditions JSONB NOT NULL DEFAULT '[]'::jsonb,identity_state TEXT NOT NULL DEFAULT 'pending',created_at TIMESTAMPTZ NOT NULL,updated_at TIMESTAMPTZ NOT NULL);
CREATE TABLE IF NOT EXISTS auth_sessions (session_id UUID PRIMARY KEY,token_hash TEXT NOT NULL UNIQUE,keycloak_subject TEXT NOT NULL,username TEXT NOT NULL,display_name TEXT,email TEXT,roles JSONB NOT NULL DEFAULT '[]'::jsonb,tenant_id UUID,tenant_slug TEXT,issued_at TIMESTAMPTZ NOT NULL,expires_at TIMESTAMPTZ NOT NULL,last_seen_at TIMESTAMPTZ NOT NULL,revoked_at TIMESTAMPTZ);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_token ON auth_sessions(token_hash) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_auth_sessions_subject ON auth_sessions(keycloak_subject,expires_at DESC);
CREATE TABLE IF NOT EXISTS tenant_members (tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,keycloak_subject TEXT NOT NULL,username TEXT NOT NULL,email TEXT,first_name TEXT,last_name TEXT,roles JSONB NOT NULL DEFAULT '[]'::jsonb,enabled BOOLEAN NOT NULL DEFAULT TRUE,invited_by TEXT,invited_at TIMESTAMPTZ,updated_at TIMESTAMPTZ NOT NULL,PRIMARY KEY(tenant_id,keycloak_subject));
CREATE TABLE IF NOT EXISTS audit_events (event_id BIGSERIAL PRIMARY KEY,event_type TEXT NOT NULL,actor TEXT NOT NULL,registration_id UUID,tenant_id UUID,reason TEXT,safe_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS platform_state (state_key TEXT PRIMARY KEY,state_value JSONB NOT NULL,updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS email_outbox (email_id UUID PRIMARY KEY,template TEXT NOT NULL,recipient TEXT NOT NULL,payload JSONB NOT NULL,state TEXT NOT NULL CHECK(state IN('pending','sent','failed')),attempts INTEGER NOT NULL DEFAULT 0,last_error TEXT,next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_email_outbox_pending ON email_outbox(state,next_attempt_at);
CREATE INDEX IF NOT EXISTS idx_registrations_state_created ON tenant_registrations(state,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tenants_state_generation ON tenants(state,desired_generation,observed_generation);
CREATE INDEX IF NOT EXISTS idx_audit_registration ON audit_events(registration_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_tenant ON audit_events(tenant_id,created_at DESC);
-- BEGIN SR2 SCHEMA
-- Additive SR2 migration, embedded verbatim in the single ground-zero artifact.
-- Each independently versioned issuer object is one row; no tenant-wide config blob.
CREATE TABLE IF NOT EXISTS pci_issuer_resources (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
 kind TEXT NOT NULL CHECK(kind IN ('metadata','branding','configuration','flow','connector','asset','settings')),
 resource_id UUID NOT NULL,
 configuration_id UUID,
 identifier TEXT,
 document JSONB NOT NULL,
 PRIMARY KEY(tenant_id,kind,resource_id),
 UNIQUE(tenant_id,kind,identifier)
);
CREATE TABLE IF NOT EXISTS pci_issuer_versions (
 tenant_id UUID NOT NULL,
 kind TEXT NOT NULL,
 resource_id UUID NOT NULL,
 version INTEGER NOT NULL CHECK(version>0),
 snapshot JSONB NOT NULL,
 content_hash TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,kind,resource_id,version),
 FOREIGN KEY(tenant_id,kind,resource_id) REFERENCES pci_issuer_resources(tenant_id,kind,resource_id)
);
CREATE TABLE IF NOT EXISTS pci_issuer_assignments (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
 assignment_id UUID NOT NULL,
 subject TEXT NOT NULL,
 configuration_ids JSONB NOT NULL,
 revoked BOOLEAN NOT NULL DEFAULT false,
 PRIMARY KEY(tenant_id,assignment_id)
);
CREATE INDEX IF NOT EXISTS pci_assignments_subject ON pci_issuer_assignments(tenant_id,subject) WHERE revoked=false;
CREATE TABLE IF NOT EXISTS pci_issuance_requests (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
 request_id UUID NOT NULL,
 configuration_id UUID NOT NULL,
 subject_hash TEXT NOT NULL,
 idempotency_hash TEXT NOT NULL,
 state TEXT NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL,
 document JSONB NOT NULL,
 PRIMARY KEY(tenant_id,request_id),
 UNIQUE(tenant_id,idempotency_hash)
);
CREATE INDEX IF NOT EXISTS pci_requests_expiry ON pci_issuance_requests(tenant_id,expires_at);
CREATE TABLE IF NOT EXISTS pci_credential_events (
 event_id BIGSERIAL PRIMARY KEY,
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
 configuration_id UUID,
 request_id UUID,
 subject_hash TEXT,
 event_type TEXT NOT NULL,
 actor_hash TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pci_events_history ON pci_credential_events(tenant_id,configuration_id,event_id DESC);
CREATE TABLE IF NOT EXISTS pci_reissuance_blocks (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id), configuration_id UUID NOT NULL, subject_hash TEXT NOT NULL,
 PRIMARY KEY(tenant_id,configuration_id,subject_hash)
);
CREATE TABLE IF NOT EXISTS pci_rate_limits (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id), bucket TEXT NOT NULL, window_start BIGINT NOT NULL, count INTEGER NOT NULL,
 PRIMARY KEY(tenant_id,bucket,window_start)
);
CREATE TABLE IF NOT EXISTS pci_registration_rates (
 bucket_hash TEXT PRIMARY KEY, window_start BIGINT NOT NULL, count INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS pci_metadata_publication (
 tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id), desired BIGINT NOT NULL DEFAULT 0, observed BIGINT NOT NULL DEFAULT 0,
 state TEXT NOT NULL DEFAULT 'draft', error_code TEXT, last_attempt TIMESTAMPTZ, last_success TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS pci_schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pci_schema_migrations WHERE version='0.4.0-delegations') THEN
  INSERT INTO pci_issuer_assignments(tenant_id,assignment_id,subject,configuration_ids)
  SELECT tenant_id,gen_random_uuid(),keycloak_subject,'null'::jsonb FROM tenant_members
  WHERE enabled AND roles ? 'issuer_admin';
  INSERT INTO pci_schema_migrations(version) VALUES('0.4.0-delegations');
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS pci_status_allocations (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id), request_id UUID NOT NULL, configuration_id UUID NOT NULL,
 status_hash TEXT NOT NULL, handle TEXT NOT NULL,
 PRIMARY KEY(tenant_id,request_id), UNIQUE(tenant_id,status_hash), UNIQUE(tenant_id,handle)
);
CREATE TABLE IF NOT EXISTS pci_participant_circuits (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id), connector_id UUID NOT NULL,
 document JSONB NOT NULL, PRIMARY KEY(tenant_id,connector_id)
);

CREATE TABLE IF NOT EXISTS pci_issuer_retirements (
 tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id),
 issuer JSONB NOT NULL, state TEXT NOT NULL CHECK(state IN('pending','withdrawn')),
 requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), withdrawn_at TIMESTAMPTZ
);

-- Only links existing IAM administrative identities. No participant claims/tokens.
CREATE TABLE IF NOT EXISTS pci_issuance_principals (
 tenant_id UUID NOT NULL REFERENCES tenants(tenant_id), subject_hash TEXT NOT NULL,
 keycloak_subject TEXT NOT NULL, PRIMARY KEY(tenant_id,subject_hash),
 FOREIGN KEY(tenant_id,keycloak_subject) REFERENCES tenant_members(tenant_id,keycloak_subject) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_pci_request_credential ON pci_issuance_requests(tenant_id,(document->>'credentialId')) WHERE document->>'credentialId' IS NOT NULL;

-- Public tenant IAM configuration; the broker client secret remains in Keycloak.
CREATE TABLE IF NOT EXISTS pci_tenant_identity (
 tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id) ON DELETE CASCADE,
 document JSONB NOT NULL
);

-- Reconcile the changed LDP context/claim paths once on an rc.5 upgrade.
-- Atomic marker insertion ensures a repeated bootstrap does not churn revisions.
WITH migration AS (
 INSERT INTO pci_schema_migrations(version) VALUES('0.5.0-rc.5-linked-data')
 ON CONFLICT DO NOTHING RETURNING version
)
INSERT INTO pci_metadata_publication(tenant_id,desired,state)
SELECT DISTINCT r.tenant_id,1,'pending' FROM pci_issuer_resources r
JOIN pci_issuer_versions v ON v.tenant_id=r.tenant_id AND v.kind=r.kind
 AND v.resource_id=r.resource_id AND v.version=(r.document->>'activeVersion')::integer
WHERE EXISTS(SELECT 1 FROM migration) AND r.kind='configuration'
 AND r.document->>'state'<>'archived' AND v.snapshot->>'format'='ldp_vc'
ON CONFLICT(tenant_id) DO UPDATE SET desired=pci_metadata_publication.desired+1,state='pending',error_code=NULL;
-- END SR2 SCHEMA
COMMIT;
SQL
"${K[@]}" -n "$ORCE_NS" create configmap fap-pci-schema --from-file=schema.sql="$TMP_DIR/schema.sql" --dry-run=client -o yaml|apply_stdin
if ! $DRY_RUN;then "${K[@]}" -n "$ORCE_NS" delete job fap-pci-schema-init --ignore-not-found --wait=true>/dev/null 2>&1||true;cat <<YAML | apply_stdin
apiVersion: batch/v1
kind: Job
metadata: {name: fap-pci-schema-init, namespace: ${ORCE_NS}}
spec:
 backoffLimit: 6
 template:
  spec:
   restartPolicy: OnFailure
   containers:
   - name: psql
     image: ${POSTGRES_IMAGE}
     resources: {requests: {cpu: 50m, memory: 32Mi}, limits: {cpu: 500m, memory: 256Mi}}
     env: [{name: DATABASE_URL, valueFrom: {secretKeyRef: {name: fap-pci-runtime, key: PCI_DATABASE_URL}}}]
     command: [sh,-lc,'psql "\$DATABASE_URL" -v ON_ERROR_STOP=1 -f /schema/schema.sql']
     volumeMounts: [{name: schema, mountPath: /schema, readOnly: true}]
   volumes: [{name: schema, configMap: {name: fap-pci-schema}}]
YAML
"${K[@]}" -n "$ORCE_NS" wait --for=condition=complete job/fap-pci-schema-init --timeout=5m|| {           "${K[@]}" -n "$ORCE_NS" logs job/fap-pci-schema-init >&2||true;die "Schema initialization failed";};fi

# This separately owned policy is the sole G0 Kubernetes write in OCM.
log "Allow PCI identity and mail traffic through existing Keycloak isolation"
python3 - "$OCM_NS" "$ORCE_NS" "$KC_SERVICE" "$KC_INTERNAL" "$DEPLOY_LABELS" "$DRY_RUN" "${K[@]}" <<'PYKCPOLICY'
import hashlib,json,subprocess,sys,urllib.parse
ocm,pci,service,url,orce_labels,dry=sys.argv[1:7]; command=sys.argv[7:]
def get(kind,name=None,selector=None):
    args=command+['-n',ocm,'get',kind]
    if name: args += [name,'--ignore-not-found']
    if selector: args += ['-l',selector]
    result=subprocess.run(args+['-o','json'],capture_output=True,text=True,check=True)
    return json.loads(result.stdout) if result.stdout.strip() else None
def matches(selector,labels):
    if any(labels.get(k)!=v for k,v in selector.get('matchLabels',{}).items()): return False
    for expr in selector.get('matchExpressions',[]):
        k,op,values=expr['key'],expr['operator'],expr.get('values',[])
        if op=='In' and labels.get(k) not in values: return False
        if op=='NotIn' and k in labels and labels[k] in values: return False
        if op=='Exists' and k not in labels: return False
        if op=='DoesNotExist' and k in labels: return False
        if op not in ('In','NotIn','Exists','DoesNotExist'): raise SystemExit('Unknown NetworkPolicy selector operator')
    return True
svc=get('service',service)
selector=(svc or {}).get('spec',{}).get('selector',{})
if not selector: raise SystemExit('Keycloak Service must select pods for bounded policy generation')
pods=get('pods',selector=','.join(k+'='+v for k,v in sorted(selector.items())))['items']
if not pods: raise SystemExit('No selected Keycloak pods; policy not changed')
parsed=urllib.parse.urlsplit(url)
service_port=parsed.port or (443 if parsed.scheme=='https' else 80)
ports=[p for p in svc['spec']['ports'] if p['port']==service_port and p.get('protocol','TCP')=='TCP']
if len(ports)!=1: raise SystemExit('Keycloak URL port does not uniquely match selected Service')
target=ports[0].get('targetPort',service_port)
if isinstance(target,str):
    resolved=[]
    for pod in pods:
        values={p['containerPort'] for c in pod['spec']['containers'] for p in c.get('ports',[]) if p.get('name')==target and p.get('protocol','TCP')=='TCP'}
        if len(values)!=1: raise SystemExit('Ambiguous Keycloak target port; policy not changed')
        resolved.append(values.pop())
    if len(set(resolved))!=1: raise SystemExit('Keycloak pods disagree on target port')
    target=resolved[0]
name='fap-pci-keycloak-'+hashlib.sha256(pci.encode()).hexdigest()[:12]
manager='fap-pci-keycloak-network'
existing=get('networkpolicy',name)
if existing:
    meta=existing['metadata']; labels=meta.get('labels',{})
    if (labels.get('app.kubernetes.io/managed-by')!=manager or labels.get('fap-pci.xfsc.org/namespace')!=pci or meta.get('annotations',{}).get('meta.helm.sh/release-name')):
        raise SystemExit('Keycloak integration policy ownership collision; existing policy unchanged')
# Do not newly isolate a direction that ESB currently leaves unrestricted.
policies=get('networkpolicy')['items']; directions=None
for pod in pods:
    isolated=set()
    for policy in policies:
        spec=policy['spec']
        if matches(spec.get('podSelector',{}),pod['metadata'].get('labels',{})):
            isolated.update(spec.get('policyTypes',['Ingress']+(['Egress'] if spec.get('egress') else [])))
    if directions is None: directions=isolated
    elif directions!=isolated: raise SystemExit('Selected Keycloak pods have different isolation; policy not changed')
if not directions:
    print('Keycloak network directions unrestricted; no integration policy needed')
else:
    labels=json.loads(orce_labels)
    if not labels: raise SystemExit('PCI ORCE labels empty; policy not changed')
    peer={'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':pci}}}
    spec={'podSelector':{'matchLabels':selector},'policyTypes':sorted(directions)}
    if 'Ingress' in directions:
        spec['ingress']=[{'from':[{**peer,'podSelector':{'matchLabels':labels}}],'ports':[{'protocol':'TCP','port':target}]}]
    if 'Egress' in directions:
        spec['egress']=[{'to':[{**peer,'podSelector':{'matchLabels':{'app.kubernetes.io/name':app}}}],'ports':[{'protocol':'TCP','port':port}]} for app,port in [('fap-pci-mailpit',1025),('fap-pci-smtp-relay',587)]]
    obj={'apiVersion':'networking.k8s.io/v1','kind':'NetworkPolicy','metadata':{'name':name,'namespace':ocm,'labels':{'app.kubernetes.io/managed-by':manager,'fap-pci.xfsc.org/namespace':pci}},'spec':spec}
    args=['apply','--dry-run=client'] if dry=='true' else ['apply','--server-side','--field-manager='+manager]
    subprocess.run(command+args+['-f','-'],input=json.dumps(obj),text=True,check=True)
PYKCPOLICY

log "Reconcile Keycloak realm/client/ID-token roles/provider"
if ! $DRY_RUN;then KC_CURL=(curl -fsS --tlsv1.3 --tls-max 1.3 --connect-timeout 10 --max-time 30);$KC_INSECURE&&KC_CURL+=(-k);TOKEN="$("${KC_CURL[@]}" -X POST "$KC_PUBLIC/realms/master/protocol/openid-connect/token" -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode grant_type=password --data-urlencode client_id=admin-cli --data-urlencode "username=$KC_ADMIN_USERNAME" --data-urlencode "password=$KC_ADMIN_PASSWORD"|jq -r .access_token)";[[ -n "$TOKEN"&&"$TOKEN" != null ]]||die "Keycloak admin token failed";AUTH=(-H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json');API="$KC_PUBLIC/admin/realms";ENC_REALM="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$KC_REALM")";CODE="$("${KC_CURL[@]}" -o /dev/null -w '%{http_code}' "${AUTH[@]}" "$API/$ENC_REALM"||true)";if [[ "$CODE" == 404 ]];then "${KC_CURL[@]}" -X POST "${AUTH[@]}" --data "$(jq -nc --arg r "$KC_REALM" --arg h "$ACTIVE_SMTP_HOST" --arg p "$ACTIVE_SMTP_PORT" --arg f "$SMTP_FROM" '{realm:$r,enabled:true,displayName:"FACIS FAP PCI",sslRequired:"external",registrationAllowed:false,loginWithEmailAllowed:true,verifyEmail:true,bruteForceProtected:true,smtpServer:{host:$h,port:$p,from:$f,fromDisplayName:"FACIS FAP PCI",ssl:"false",starttls:"false",auth:"false"}}')" "$API">/dev/null;else EXISTING_REALM="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM")";UPDATED_REALM="$(jq --arg h "$ACTIVE_SMTP_HOST" --arg p "$ACTIVE_SMTP_PORT" --arg f "$SMTP_FROM" '.enabled=true|.displayName="FACIS FAP PCI"|.loginWithEmailAllowed=true|.verifyEmail=true|.bruteForceProtected=true|.smtpServer={host:$h,port:$p,from:$f,fromDisplayName:"FACIS FAP PCI",ssl:"false",starttls:"false",auth:"false"}'<<<"$EXISTING_REALM")";"${KC_CURL[@]}" -X PUT "${AUTH[@]}" --data "$UPDATED_REALM" "$API/$ENC_REALM">/dev/null;fi
# Configure PCI tenant attributes as administrator-managed profile fields.
KC_PROFILE="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/users/profile")"
KC_PROFILE_UPDATED="$(jq '
  .attributes = (
    ((.attributes // []) |
      map(select(.name != "tenant_id" and .name != "tenant_slug")))
    + [
      {
        name: "tenant_id",
        multivalued: false,
        permissions: {view: ["admin"], edit: ["admin"]}
      },
      {
        name: "tenant_slug",
        multivalued: false,
        permissions: {view: ["admin"], edit: ["admin"]}
      }
    ]
  )
' <<<"$KC_PROFILE")"
"${KC_CURL[@]}" -X PUT "${AUTH[@]}" \
  --data "$KC_PROFILE_UPDATED" "$API/$ENC_REALM/users/profile" >/dev/null

# Only the PCI realm is changed. Passkeys use the Keycloak public hostname as
# RP ID; password + TOTP remains available for accounts without a passkey.
REALM_SETTINGS="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM")"
PASSKEY_SETTINGS="$(jq '.webAuthnPolicyPasswordlessPasskeysEnabled=true | .webAuthnPolicyPasswordlessUserVerificationRequirement="required" | .webAuthnPolicyPasswordlessResidentKey="required" | .webAuthnPolicyPasswordlessRpEntityName="FACIS PCI"' <<<"$REALM_SETTINGS")"
"${KC_CURL[@]}" -X PUT "${AUTH[@]}" --data "$PASSKEY_SETTINGS" "$API/$ENC_REALM" >/dev/null
PASSKEY_ACTION="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/authentication/required-actions/webauthn-register-passwordless")"
"${KC_CURL[@]}" -X PUT "${AUTH[@]}" --data "$(jq '.enabled=true | .defaultAction=false' <<<"$PASSKEY_ACTION")" "$API/$ENC_REALM/authentication/required-actions/webauthn-register-passwordless" >/dev/null
for role in provider_admin participant_tenant_admin issuer_admin principal;do RC="$("${KC_CURL[@]}" -o /dev/null -w '%{http_code}' "${AUTH[@]}" "$API/$ENC_REALM/roles/$role"||true)";[[ "$RC" != 404 ]]||"${KC_CURL[@]}" -X POST "${AUTH[@]}" --data "$(jq -nc --arg n "$role" '{name:$n}')" "$API/$ENC_REALM/roles">/dev/null;done
UI_PATH="${ORCE_BASE_PATH}/ui/";[[ -n "$ORCE_BASE_PATH" ]]||UI_PATH="/ui/";UI_URL="https://${MAIN_HOST}${UI_PATH}";CLIENTS="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/clients?clientId=$KC_CLIENT_ID")";CLIENT_INTERNAL_ID="$(jq -r '.[0].id//empty'<<<"$CLIENTS")";CLIENT_DEF="$(jq -nc --arg cid "$KC_CLIENT_ID" --arg ui "$UI_URL" --arg origin "https://${MAIN_HOST}" '{clientId:$cid,name:"FAP PCI uibuilder",enabled:true,protocol:"openid-connect",publicClient:true,standardFlowEnabled:true,directAccessGrantsEnabled:false,implicitFlowEnabled:false,serviceAccountsEnabled:false,frontchannelLogout:true,redirectUris:[$ui,($ui+"*")],webOrigins:[$origin],attributes:{"pkce.code.challenge.method":"S256","post.logout.redirect.uris":$ui},protocolMappers:[{name:"pci-identity-provider",protocol:"openid-connect",protocolMapper:"oidc-usersessionmodel-note-mapper",config:{"user.session.note":"identity_provider","claim.name":"pci_identity_provider","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true"}},{name:"participant-groups",protocol:"openid-connect",protocolMapper:"oidc-group-membership-mapper",consentRequired:false,config:{"claim.name":"groups","full.path":"true","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true"}},{name:"participant-audience",protocol:"openid-connect",protocolMapper:"oidc-audience-mapper",consentRequired:false,config:{"included.custom.audience":"participant-data","access.token.claim":"true","id.token.claim":"false"}},{name:"realm-roles",protocol:"openid-connect",protocolMapper:"oidc-usermodel-realm-role-mapper",consentRequired:false,config:{multivalued:"true","claim.name":"realm_access.roles","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true"}},{name:"tenant-id",protocol:"openid-connect",protocolMapper:"oidc-usermodel-attribute-mapper",consentRequired:false,config:{"user.attribute":"tenant_id","claim.name":"tenant_id","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true",multivalued:"false"}},{name:"tenant-slug",protocol:"openid-connect",protocolMapper:"oidc-usermodel-attribute-mapper",consentRequired:false,config:{"user.attribute":"tenant_slug","claim.name":"tenant_slug","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true",multivalued:"false"}}]}')";if [[ -z "$CLIENT_INTERNAL_ID" ]];then "${KC_CURL[@]}" -X POST "${AUTH[@]}" --data "$CLIENT_DEF" "$API/$ENC_REALM/clients">/dev/null;CLIENT_INTERNAL_ID="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/clients?clientId=$KC_CLIENT_ID"|jq -r '.[0].id')";else CURRENT_CLIENT="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/clients/$CLIENT_INTERNAL_ID")";MERGED_CLIENT="$(jq -s '.[0] as $old | .[1] as $new | ($old*$new) | .redirectUris=(($old.redirectUris//[])+$new.redirectUris|unique) | .webOrigins=(($old.webOrigins//[])+$new.webOrigins|unique) | .attributes["post.logout.redirect.uris"]=(.redirectUris|join("##"))' <(printf '%s' "$CURRENT_CLIENT") <(printf '%s' "$CLIENT_DEF"))";"${KC_CURL[@]}" -X PUT "${AUTH[@]}" --data "$MERGED_CLIENT" "$API/$ENC_REALM/clients/$CLIENT_INTERNAL_ID">/dev/null;fi
SCOPES_JSON="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/client-scopes")"
SCOPE_ID="$(jq -r '[.[]|select(.name=="credential:issue")][0].id//empty'<<<"$SCOPES_JSON")"
if [[ -z "$SCOPE_ID" ]]; then
  "${KC_CURL[@]}" -X POST "${AUTH[@]}" --data '{"name":"credential:issue","protocol":"openid-connect","attributes":{"include.in.token.scope":"true","display.on.consent.screen":"false"}}' "$API/$ENC_REALM/client-scopes" >/dev/null
  SCOPE_ID="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/client-scopes"|jq -r '[.[]|select(.name=="credential:issue")][0].id')"
fi
"${KC_CURL[@]}" -X PUT "${AUTH[@]}" "$API/$ENC_REALM/clients/$CLIENT_INTERNAL_ID/default-client-scopes/$SCOPE_ID" >/dev/null
USERS="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/users?username=$PROVIDER_USERNAME&exact=true")";PROVIDER_ID="$(jq -r '.[0].id//empty'<<<"$USERS")";if [[ -z "$PROVIDER_ID" ]];then "${KC_CURL[@]}" -X POST "${AUTH[@]}" --data "$(jq -nc --arg u "$PROVIDER_USERNAME" --arg e "$PROVIDER_EMAIL" --arg p "$PROVIDER_PASSWORD" '{username:$u,email:$e,enabled:true,emailVerified:true,requiredActions:["UPDATE_PASSWORD","CONFIGURE_TOTP"],credentials:[{type:"password",value:$p,temporary:true}]}')" "$API/$ENC_REALM/users">/dev/null;PROVIDER_ID="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/users?username=$PROVIDER_USERNAME&exact=true"|jq -r '.[0].id')";fi;ROLE="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/roles/provider_admin")";CURRENT_ROLES="$("${KC_CURL[@]}" "${AUTH[@]}" "$API/$ENC_REALM/users/$PROVIDER_ID/role-mappings/realm")";jq -e 'map(.name)|index("provider_admin")!=null'<<<"$CURRENT_ROLES">/dev/null||"${KC_CURL[@]}" -X POST "${AUTH[@]}" --data "[$ROLE]" "$API/$ENC_REALM/users/$PROVIDER_ID/role-mappings/realm">/dev/null
fi

log "Create single Gateway plus main/editor and public demo Mailpit routes"
cat <<YAML | apply_stdin
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata: {name: fap-pci-gateway-tls, namespace: ${ORCE_NS}}
spec: {from: [{group: gateway.networking.k8s.io, kind: Gateway, namespace: ${INFRA_NS}}], to: [{group: '', kind: Secret, name: ${TLS_SECRET}}]}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata: {name: fap-pci-proxy, namespace: ${INFRA_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: LoadBalancer
        externalTrafficPolicy: Cluster
      envoyDeployment:
        replicas: 1
        container:
          image: docker.io/envoyproxy/envoy:distroless-v1.39.2
          resources: {requests: {cpu: 100m, memory: 128Mi}, limits: {cpu: "1", memory: 512Mi}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: ${GATEWAY_NAME}, namespace: ${INFRA_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec: {gatewayClassName: ${GATEWAY_CLASS}, infrastructure: {parametersRef: {group: gateway.envoyproxy.io, kind: EnvoyProxy, name: fap-pci-proxy}}, listeners: [{name: ${GATEWAY_LISTENER}, protocol: HTTPS, port: 443, hostname: '*.${BASE_DOMAIN}', tls: {mode: Terminate, certificateRefs: [{name: ${TLS_SECRET}, namespace: ${ORCE_NS}}]}, allowedRoutes: {namespaces: {from: All}}}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: fap-pci-main, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec:
 parentRefs: [{name: ${GATEWAY_NAME}, namespace: ${INFRA_NS}, sectionName: ${GATEWAY_LISTENER}}]
 hostnames: [${MAIN_HOST}]
 rules:
 - matches: [{path: {type: PathPrefix, value: '${ORCE_BASE_PATH:-/}'}}]
   filters: [{type: RequestHeaderModifier, requestHeaderModifier: {set: [{name: X-PCI-Public-Request, value: "1"}], remove: [X-PCI-Tenant-ID,X-PCI-Tenant-Slug,X-PCI-Tenant-Domain,X-NAMESPACE,X-DID,X-ISSUERKID,X-KEY,X-GROUP,X-GROUPID,X-TYPE,X-ENGINE,X-Issuer,X-JWKS-URL,X-TOKENENDPOINT,x-audience-url,x-signerkey]}}]
   backendRefs: [{name: ${ORCE_SERVICE}, port: ${ORCE_SERVICE_PORT}}]
YAML
if $MAILPIT_PUBLIC; then
cat <<YAML | apply_stdin
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: fap-pci-mailpit, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/part-of: fap-pci, xfsc.org/demo-only: 'true'}}
spec: {parentRefs: [{name: ${GATEWAY_NAME}, namespace: ${INFRA_NS}, sectionName: ${GATEWAY_LISTENER}}], hostnames: [${MAILPIT_HOST}], rules: [{backendRefs: [{name: fap-pci-mailpit, port: 8025}]}]}
YAML
elif ! $DRY_RUN; then
  "${K[@]}" -n "$ORCE_NS" delete httproute fap-pci-mailpit --ignore-not-found >/dev/null
fi
if [[ "$ORCE_EDITOR_PATH" != "$ORCE_BASE_PATH" ]];then cat <<YAML | apply_stdin
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: fap-pci-orce-editor, namespace: ${ORCE_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec: {parentRefs: [{name: ${GATEWAY_NAME}, namespace: ${INFRA_NS}, sectionName: ${GATEWAY_LISTENER}}], hostnames: [${MAIN_HOST}], rules: [{matches: [{path: {type: PathPrefix, value: '${ORCE_EDITOR_PATH:-/}'}}], filters: [{type: RequestHeaderModifier, requestHeaderModifier: {set: [{name: X-PCI-Public-Request, value: '1'}]}}], backendRefs: [{name: ${ORCE_SERVICE}, port: ${ORCE_SERVICE_PORT}}]}]}
YAML
fi
if ! $DRY_RUN;then "${K[@]}" -n "$INFRA_NS" wait --for=condition=Programmed gateway/"$GATEWAY_NAME" --timeout=10m;GW_ADDR="$("${K[@]}" -n "$INFRA_NS" get gateway "$GATEWAY_NAME" -o jsonpath='{.status.addresses[0].value}')";[[ -n "$GW_ADDR" ]]||die "Gateway has no address";else GW_ADDR="DRY-RUN";fi

log "Enforce TLS 1.3 on the PCI Gateway"
cat <<YAML | apply_stdin
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata: {name: fap-pci-tls, namespace: ${INFRA_NS}, labels: {app.kubernetes.io/part-of: fap-pci}}
spec:
  targetRefs: [{group: gateway.networking.k8s.io, kind: Gateway, name: ${GATEWAY_NAME}}]
  tls: {minVersion: '1.3', maxVersion: '1.3'}
YAML

log "Persist ground-zero platform state"
DNS_READY=false
if ! $DRY_RUN;then DNS_READY="$(python3 - "$MAIN_HOST" "$GW_ADDR" <<'PY'
import socket,sys
try:v={x[4][0] for x in socket.getaddrinfo(sys.argv[1],None)}
except Exception:v=set()
print('true' if sys.argv[2] in v else 'false')
PY
)";STATUS=DNSPending;[[ "$DNS_READY" == true ]]&&STATUS=Ready;PLATFORM_JSON="$(jq -nc --arg status "$STATUS" --argjson ready "$DNS_READY" --arg version "$VERSION" --arg main "$MAIN_HOST" --arg base "$ORCE_BASE_PATH" --arg domain "$BASE_DOMAIN" --arg suffix "$TENANT_SUFFIX" --arg ocm "$OCM_NS" --arg ons "$ORCE_NS" --arg ins "$INFRA_NS" --arg gn "$GATEWAY_NAME" --arg gc "$GATEWAY_CLASS" --arg ga "$GW_ADDR" --arg mailmode "$MAIL_MODE" --arg mailhost "$ACTIVE_SMTP_HOST" --arg mailpit "$MAILPIT_HOST" --arg kcp "$KC_PUBLIC" --arg realm "$KC_REALM" --arg client "$KC_CLIENT_ID" '{status:$status,ready:$ready,version:$version,mainHost:$main,orceBasePath:$base,ocmNamespace:$ocm,orceNamespace:$ons,gateway:{namespace:$ins,name:$gn,className:$gc,address:$ga},database:{mode:"ground-zero-prepared"},mail:{mode:$mailmode,host:$mailhost,mailpitUi:("https://"+$mailpit+"/")},keycloak:{realm:$realm,clientId:$client,publicUrl:$kcp},tenantHostnameTemplate:("{slug}-"+$suffix+"."+$domain),conditions:[{type:"OCMNamespaceValidated",status:"True",reason:"ExistingOCMNamespace"},{type:"EnvoyGatewayReady",status:"True",reason:"GroundZeroPrepared"},{type:"DatabaseReady",status:"True",reason:"SchemaInitialized"},{type:"KeycloakReady",status:"True",reason:"RealmReconciled"},{type:"GatewayReady",status:"True",reason:"GatewayProgrammed"},{type:"MainDNSReady",status:(if $ready then "True" else "False" end),reason:(if $ready then "DNSMatchesGateway" else "DNSPending" end)}]}')";printf '%s' "$PLATFORM_JSON">"$TMP_DIR/platform.json";"${K[@]}" -n "$ORCE_NS" create configmap fap-pci-platform-bootstrap --from-file=platform.json="$TMP_DIR/platform.json" --dry-run=client -o yaml|apply_stdin;"${K[@]}" -n "$ORCE_NS" delete job fap-pci-platform-state --ignore-not-found --wait=true>/dev/null 2>&1||true;cat <<YAML | apply_stdin
apiVersion: batch/v1
kind: Job
metadata: {name: fap-pci-platform-state, namespace: ${ORCE_NS}}
spec:
 backoffLimit: 4
 template:
  spec:
   restartPolicy: OnFailure
   containers:
   - name: psql
     image: ${POSTGRES_IMAGE}
     resources: {requests: {cpu: 50m, memory: 32Mi}, limits: {cpu: 500m, memory: 256Mi}}
     env: [{name: DATABASE_URL, valueFrom: {secretKeyRef: {name: fap-pci-runtime, key: PCI_DATABASE_URL}}}]
     command:
     - sh
     - -ec
     - |
       payload="\$(cat /state/platform.json)"
       psql "\$DATABASE_URL" -v ON_ERROR_STOP=1 -v payload="\$payload" -f - <<'SQL'
       INSERT INTO platform_state(state_key,state_value,updated_at)
       VALUES ('platform', :'payload'::jsonb, now())
       ON CONFLICT(state_key) DO UPDATE
       SET state_value=EXCLUDED.state_value, updated_at=now();
       SQL
     volumeMounts: [{name: state, mountPath: /state, readOnly: true}]
   volumes: [{name: state, configMap: {name: fap-pci-platform-bootstrap}}]
YAML
"${K[@]}" -n "$ORCE_NS" wait --for=condition=complete job/fap-pci-platform-state --timeout=5m|| {           "${K[@]}" -n "$ORCE_NS" logs job/fap-pci-platform-state >&2||true;die "platform state persistence failed";};fi

log "Patch ORCE once, before PCI artifacts are imported"
# These are resource quantities, never shell fragments. Existing non-PCI
# containers are preserved; explicit PCI_ORCE_* settings resize only ORCE.
ORCE_RESOURCES="$(jq -c --arg c "$ORCE_CONTAINER" '.spec.template.spec.containers[]|select(.name==$c)|.resources//{}' <<< "$DEPLOY_JSON")"
ORCE_RESOURCES="$(python3 - "$ORCE_RESOURCES" <<'PYRESOURCES'
import json,os,re,sys
r=json.loads(sys.argv[1]);defaults={'requests':{'cpu':'100m','memory':'256Mi'},'limits':{'cpu':'2','memory':'1Gi'}}
for group,values in defaults.items():
 for key,default in values.items():
  env='PCI_ORCE_'+key.upper()+'_'+('REQUEST' if group=='requests' else 'LIMIT')
  value=os.environ.get(env) or r.get(group,{}).get(key) or default
  if not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?(?:m|Ki|Mi|Gi|Ti)?',str(value)):raise SystemExit('Invalid resource quantity '+env)
  r.setdefault(group,{})[key]=value
print(json.dumps(r))
PYRESOURCES
)"

if $DRY_RUN; then
  CONFIG_HASH="dry-run"
else
  CONFIG_DATA_JSON="$("${K[@]}" -n "$ORCE_NS" get configmap fap-pci-config -o json | jq -cS '.data')"
  RUNTIME_DATA_JSON="$("${K[@]}" -n "$ORCE_NS" get secret fap-pci-runtime -o json | jq -cS '.data')"
  CONFIG_HASH="$(printf '%s\0' "$VERSION" "$CONFIG_DATA_JSON" "$RUNTIME_DATA_JSON" "$DATA_CLAIM" "$ORCE_CONTAINER" "$ORCE_RESOURCES" "${PCI_NATIVE_TLS_SECRET:-}"|sha256sum|awk '{print $1}')"
  unset CONFIG_DATA_JSON RUNTIME_DATA_JSON
fi
if ! $DRY_RUN;then DEPLOY_JSON="$("${K[@]}" -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" -o json)";CURRENT_HASH="$(jq -r '.spec.template.metadata.annotations["fap-pci.xfsc.org/config-hash"]//""'<<<"$DEPLOY_JSON")";if [[ "$CURRENT_HASH" != "$CONFIG_HASH" || "$(jq -r ' .spec.strategy.type//""'<<<"$DEPLOY_JSON")" != Recreate ]];then PATCH="$(jq -c --arg c "$ORCE_CONTAINER" --arg v "$DATA_VOLUME" --arg claim "$DATA_CLAIM" --arg h "$CONFIG_HASH" --argjson resources "$ORCE_RESOURCES" --argjson gid "$GID_NOW" --arg nativeTls "${PCI_NATIVE_TLS_SECRET:-}" '.spec.template.spec as $s|($s.containers|map(if .name==$c then .resources=$resources|.volumeMounts=((.volumeMounts//[])|map(select(.mountPath!="/data" and .name!="fap-pci-secrets" and .name!="fap-pci-native-tls"))+[{name:$v,mountPath:"/data"},{name:"fap-pci-secrets",mountPath:"/var/run/fap-pci-secrets",readOnly:true}]+(if $nativeTls!="" then [{name:"fap-pci-native-tls",mountPath:"/var/run/fap-pci-native-tls",readOnly:true}] else [] end))|.envFrom=((.envFrom//[])|map(select((.configMapRef.name//"")!="fap-pci-config" and (.secretRef.name//"")!="fap-pci-runtime"))+[{configMapRef:{name:"fap-pci-config"}},{secretRef:{name:"fap-pci-runtime"}}]) else . end)) as $containers|($s.volumes//[]|map(select(.name!=$v and .name!="fap-pci-secrets" and .name!="fap-pci-native-tls"))+[{name:$v,persistentVolumeClaim:{claimName:$claim}},{name:"fap-pci-secrets",secret:{secretName:"fap-pci-runtime",defaultMode:288,items:[{key:"PCI_KEYCLOAK_ADMIN_PASSWORD",path:"PCI_KEYCLOAK_ADMIN_PASSWORD"}]}}]+(if $nativeTls!="" then [{name:"fap-pci-native-tls",secret:{secretName:$nativeTls,defaultMode:288}}] else [] end)) as $volumes|{spec:{strategy:{type:"Recreate",rollingUpdate:null},template:{metadata:{annotations:{"fap-pci.xfsc.org/version":"0.5.0-rc.12","fap-pci.xfsc.org/config-hash":$h}},spec:{securityContext:(($s.securityContext//{})|.fsGroup=(.fsGroup//$gid)),serviceAccountName:"fap-pci-orce",automountServiceAccountToken:true,containers:$containers,volumes:$volumes}}}}'<<<"$DEPLOY_JSON")";"${K[@]}" -n "$ORCE_NS" patch deploy "$ORCE_DEPLOYMENT" --type=merge -p "$PATCH";"${K[@]}" -n "$ORCE_NS" rollout status deploy/"$ORCE_DEPLOYMENT" --timeout=10m;else log "ORCE already prepared; no rollout";fi;fi

# Migrate the old PVC-backed admin password only after the new mount is usable.
if ! $DRY_RUN;then
  "${K[@]}" -n "$ORCE_NS" exec deploy/"$ORCE_DEPLOYMENT" -c "$ORCE_CONTAINER" -- sh -lc 'test -r /var/run/fap-pci-secrets/PCI_KEYCLOAK_ADMIN_PASSWORD && rm -f /data/fap-pci/keycloak-admin-password'
fi

log "Record PCI prerequisites in the release Helm chart"
if ! $DRY_RUN; then
  mkdir -p "$TMP_DIR/chart/templates"
  cat > "$TMP_DIR/chart/Chart.yaml" <<'CHART'
apiVersion: v2
name: fap-pci
description: PCI prerequisites generated by ground-zero for an existing ORCE runtime
type: application
version: 0.5.0-rc.12
appVersion: 0.5.0-rc.12
kubeVersion: '>=1.33.0-0 <1.37.0-0'
CHART
  cat > "$TMP_DIR/chart/templates/resources.yaml" <<'TEMPLATE'
{{- range .Values.objects }}
{{- if and .metadata.namespace (not (has .metadata.namespace $.Values.allowedNamespaces)) }}
{{- fail "PCI object outside approved namespaces" }}
{{- end }}
{{- if or (eq .kind "Namespace") (eq .kind "GatewayClass") (eq .kind "CustomResourceDefinition") (eq .kind "Job") (eq .kind "Pod") }}
{{- fail "Shared infrastructure and one-shot jobs are not owned by the PCI chart" }}
{{- end }}
---
{{ toYaml . }}
{{- end }}
TEMPLATE
  python3 - "$TMP_DIR" "$ORCE_NS" "$INFRA_NS" <<'PYMANIFEST'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);namespaces=sys.argv[2:];objects={}
for file in sorted((p/'manifests').glob('*.json'),key=lambda f:f.stat().st_mtime_ns):
    obj=json.loads(file.read_text())
    for item in obj.get('items',[obj]):
        if item.get('kind') in ('Namespace','GatewayClass','CustomResourceDefinition','Job','Pod'):continue
        meta=item['metadata'];ns=meta.get('namespace','')
        if ns and ns not in namespaces:raise SystemExit('Manifest outside PCI namespaces')
        for key in ('creationTimestamp','resourceVersion','uid','managedFields'):meta.pop(key,None)
        meta.setdefault('labels',{})['app.kubernetes.io/part-of']='fap-pci'
        if item['kind']=='PersistentVolumeClaim':meta.setdefault('annotations',{})['helm.sh/resource-policy']='keep'
        item.pop('status',None);objects[(item['kind'],ns,meta['name'])]=item
(p/'helm-values.json').write_text(json.dumps({'objects':list(objects.values()),'allowedNamespaces':namespaces}))
PYMANIFEST
  H=(helm); [[ -z "$KUBECONFIG_PATH" ]] || H+=(--kubeconfig "$KUBECONFIG_PATH"); [[ -z "$CONTEXT" ]] || H+=(--kube-context "$CONTEXT")
  HELM_APPLY=(); [[ "$(helm version --short)" != v4.* ]] || HELM_APPLY+=(--server-side=false)
  "${H[@]}" upgrade --install fap-pci "$TMP_DIR/chart" -n "$ORCE_NS" --take-ownership "${HELM_APPLY[@]}" --values "$TMP_DIR/helm-values.json" --wait --timeout 10m
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fap-pci";CREDENTIAL_FILE="";if ! $DRY_RUN && [[ "${PCI_EXPORT_BOOTSTRAP_CREDENTIALS:-false}" == true ]];then mkdir -p "$STATE_DIR";chmod 700 "$STATE_DIR";CREDENTIAL_FILE="$STATE_DIR/${ORCE_NS}-${ORCE_DEPLOYMENT}.env";umask 077;printf 'PCI_BOOTSTRAP_PROVIDER_USERNAME=%s\nPCI_BOOTSTRAP_PROVIDER_PASSWORD=%s\nPCI_INTERNAL_SERVICE_TOKEN=%s\n' "$PROVIDER_USERNAME" "$PROVIDER_PASSWORD" "$INTERNAL_TOKEN">"$CREDENTIAL_FILE";chmod 600 "$CREDENTIAL_FILE";fi
jq -nc --arg status "$($DRY_RUN&&echo Planned||echo Ready)" --arg ui "https://${MAIN_HOST}${ORCE_BASE_PATH}/ui/" --arg editor "https://${MAIN_HOST}${ORCE_EDITOR_PATH}/" --arg mailpit "https://${MAILPIT_HOST}/" --arg gateway "$GW_ADDR" --arg credentials "$CREDENTIAL_FILE" '{status:$status,version:"0.5.0-rc.12",ocmModified:true,ocmChanges:["PCI Keycloak realm configuration","Dedicated Keycloak integration NetworkPolicy when isolated"],gatewayAddress:$gateway,mainUi:$ui,orceEditor:$editor,mailpitUi:$mailpit,credentialsFile:(if $credentials=="" then null else $credentials end),credentialsSecret:"fap-pci-runtime",artifactContract:["dist/fap-pci-flow.json","dist/ground-zero.sh","dist/ui/"],next:["Import dist/fap-pci-flow.json without restarting ORCE.","Copy dist/ui/* into /data/uibuilder/ui/src/ without restarting ORCE."]}'
