#!/usr/bin/env bash
# Artifact-only upgrade of an already prepared PCI runtime. No Python required.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${PCI_LIFECYCLE_CONFIG:-$HOME/fap-pci/deployment-private/pci-rc6-lifecycle.json}"
NOTES="${PCI_TEST_NOTES:-$HOME/fap-pci/deployment-test-notes}"
GATEWAY_IP=""; API_IP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2;;
    --notes) NOTES="$2"; shift 2;;
    --gateway-ip) GATEWAY_IP="$2"; shift 2;;
    --api-ip) API_IP="$2"; shift 2;;
    -h|--help) echo 'Usage: bash scripts/upgrade-artifacts.sh [--config FILE] [--notes DIR] [--gateway-ip IPv4] [--api-ip IPv4]'; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
done
for binary in jq curl kubectl node sha256sum; do command -v "$binary" >/dev/null || { echo "Missing $binary" >&2; exit 1; }; done
[[ -f "$CONFIG" ]] || { echo "Missing private configuration: $CONFIG" >&2; exit 1; }
VERSION="$(cat "$ROOT/VERSION")"
(cd "$ROOT" && sha256sum --quiet -c deployment-sha256.txt)
option() {
  jq -er --arg option "$1" '.g0Args as $args | [$args | to_entries[] | select(.value==$option) | .key] as $indexes | if ($indexes|length)==1 then $args[$indexes[0]+1] | select(type=="string" and length>0) else error("Expected one operator option: "+$option) end' "$CONFIG"
}
KUBECONFIG_PATH="$(option --kubeconfig)"; CONTEXT="$(option --context)"
NS="$(option --orce-namespace)"; DEPLOYMENT="$(option --orce-deployment)"; CONTAINER="$(option --orce-container)"
EDITOR="$(jq -er '.editorUrl | select(type=="string" and startswith("https://")) | rtrimstr("/")' "$CONFIG")"
USERNAME="$(jq -er '.editorUsername // "admin"' "$CONFIG")"
PASSWORD_FILE="$(jq -er '.editorPasswordFile | select(type=="string" and length>0)' "$CONFIG")"
[[ -s "$PASSWORD_FILE" && -f "$KUBECONFIG_PATH" ]] || { echo 'Missing editor password or kubeconfig file' >&2; exit 1; }
HOST="${EDITOR#https://}"; HOST="${HOST%%/*}"
[[ "$HOST" =~ ^[A-Za-z0-9.-]+$ ]] || { echo 'Editor must use a DNS hostname on standard HTTPS port' >&2; exit 1; }
for address in "$GATEWAY_IP" "$API_IP"; do
  [[ -z "$address" ]] && continue
  [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo 'IP overrides must be IPv4 addresses' >&2; exit 1; }
  IFS=. read -r a b c d <<<"$address"
  for octet in "$a" "$b" "$c" "$d"; do ((10#$octet <= 255)) || { echo 'Invalid IPv4 octet' >&2; exit 1; }; done
 done
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
K=(kubectl --kubeconfig "$KUBECONFIG_PATH" --context "$CONTEXT" --request-timeout=20s)
read_cluster() {
  local attempt
  for attempt in 1 2 3; do
    if "${K[@]}" "$@"; then return 0; fi
    [[ "$attempt" == 3 ]] && return 1
    sleep 3
  done
}
if [[ -n "$API_IP" ]]; then
  read_cluster config view --minify --flatten --raw -o json > "$TMP/kubeconfig-original.json"
  SERVER="$(jq -er '.clusters[0].cluster.server' "$TMP/kubeconfig-original.json")"
  AUTHORITY="${SERVER#https://}"; AUTHORITY="${AUTHORITY%%/*}"; API_HOST="${AUTHORITY%%:*}"
  API_PORT="${AUTHORITY##*:}"; [[ "$API_PORT" != "$AUTHORITY" ]] || API_PORT=443
  [[ "$SERVER" == https://* && "$API_HOST" =~ ^[A-Za-z0-9.-]+$ && "$API_PORT" =~ ^[0-9]+$ ]] || { echo 'Unsupported API server URL' >&2; exit 1; }
  jq --arg server "https://${API_IP}:${API_PORT}" --arg name "$API_HOST" '.clusters[0].cluster.server=$server | .clusters[0].cluster["tls-server-name"]=(.clusters[0].cluster["tls-server-name"] // $name)' "$TMP/kubeconfig-original.json" > "$TMP/kubeconfig.json"
  KUBECONFIG_PATH="$TMP/kubeconfig.json"
  K=(kubectl --kubeconfig "$KUBECONFIG_PATH" --context "$CONTEXT" --request-timeout=20s)
fi
read_cluster get --raw=/readyz > /dev/null
read_cluster -n "$NS" get deployment "$DEPLOYMENT" -o json > "$TMP/deployment.json"
CURL=(curl --http1.1 --noproxy '*' --tlsv1.3 --tls-max 1.3 --connect-timeout 10 --max-time 30 --silent --show-error)
[[ -z "$GATEWAY_IP" ]] || CURL+=(--resolve "$HOST:443:$GATEWAY_IP")
# Credentials travel in a private request file, never in process arguments or logs.
jq -jnr --arg user "$USERNAME" --rawfile password "$PASSWORD_FILE" '"client_id=node-red-admin&grant_type=password&scope=%2A&username="+($user|@uri)+"&password="+($password|sub("[\\r\\n]+$";"")|@uri)' > "$TMP/auth-form"
HTTP="$("${CURL[@]}" --output "$TMP/token.json" --write-out '%{http_code}' --header 'Content-Type: application/x-www-form-urlencoded' --data-binary "@$TMP/auth-form" "$EDITOR/auth/token")"
[[ "$HTTP" == 200 ]] || { echo "Editor authentication failed: HTTP $HTTP" >&2; exit 1; }
jq -e '.access_token | type=="string" and length>0 and (test("[\\r\\n]")|not)' "$TMP/token.json" > /dev/null || { echo 'Invalid editor token response' >&2; exit 1; }
jq -r '"header = " + ("Authorization: Bearer " + .access_token | tojson)' "$TMP/token.json" > "$TMP/editor.curl"
cat >> "$TMP/editor.curl" <<'CURL'
http1.1
noproxy = "*"
tlsv1.3
tls-max = "1.3"
connect-timeout = 10
max-time = 30
CURL
[[ -z "$GATEWAY_IP" ]] || printf 'resolve = "%s:443:%s"\n' "$HOST" "$GATEWAY_IP" >> "$TMP/editor.curl"
mkdir -p "$NOTES"
cat > "$NOTES/$VERSION-source-fix-record.md" <<NOTE
Release: $VERSION
Upstream source corrections: backend/sr2/native.js decodes the Crypto 2.3.7 single-key endpoint's JWK array and selects a unique key by configured name/DID and JWT algorithm, including RSA algorithm variants. Independent credential signature and binding verification remain mandatory. Previous discovery, public JWKS, VM, catalogue and authentication fixes are retained.
Installer: automation/stage1/install.sh uses Bash/jq with existing Node flow merger, without Python. Reads receive bounded retries. Flow POST is attempted once; ambiguous failure stops for review.
Operation: artifact-only upgrade. Existing tenant records, participant image, infrastructure and operator configuration are retained. Original release files are preserved in their previous directory.
Deployment package: PCI/ in eclipse-xfsc/deployment; application source remains in the PCI repository.
Started: $(date -u +%FT%TZ)
NOTE
export PCI_ORCE_CURL_CONFIG="$TMP/editor.curl"
# A failed POST can have committed. Do not loop or rerun installation automatically.
if bash "$ROOT/automation/stage1/install.sh" --kubeconfig "$KUBECONFIG_PATH" --context "$CONTEXT" --orce-namespace "$NS" --orce-deployment "$DEPLOYMENT" --orce-container "$CONTAINER" --admin-url "$EDITOR" 2>&1 | tee "$NOTES/$VERSION-artifact-upgrade.log"; then
  printf 'Artifact upgrade completed: %s\n' "$(date -u +%FT%TZ)" >> "$NOTES/$VERSION-source-fix-record.md"
else
  printf 'Artifact upgrade failed; review log and live flow revision before retrying.\n' >> "$NOTES/$VERSION-source-fix-record.md"
  exit 1
fi
(cd "$ROOT" && sha256sum --quiet -c deployment-sha256.txt)
"${CURL[@]}" --fail-with-body --retry 3 --retry-delay 3 --retry-max-time 60 "$EDITOR/healthz" > "$TMP/health.json"
jq -e --arg version "$VERSION" '.status=="ok" and .version==$version' "$TMP/health.json" > /dev/null || { echo 'Runtime version verification failed' >&2; exit 1; }
"${CURL[@]}" --fail-with-body --retry 3 --retry-delay 3 --retry-max-time 60 "$EDITOR/readyz" > "$TMP/ready.json"
jq -e --arg version "$VERSION" '.status=="ready" and .version==$version' "$TMP/ready.json" > /dev/null || { echo 'Runtime readiness verification failed' >&2; exit 1; }
printf '\nInstalled %s; health and readiness verified.\n' "$VERSION"
printf 'Next: create a new synthetic Alpha offer, then run scripts/test-alpha-wallet.sh.\n'
