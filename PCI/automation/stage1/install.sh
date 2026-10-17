#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KUBECONFIG_PATH=""; CONTEXT=""; ORCE_NS=""; ORCE_DEPLOYMENT=""; ORCE_CONTAINER=""; ADMIN_URL=""; INSECURE=false
usage(){
  cat <<'USAGE'
Usage: install.sh --orce-namespace NS --orce-deployment NAME [options]

Post-ground-zero artifact installer. It consumes the tracked dist/ release:
  1. hot-deploys dist/fap-pci-flow.json through Node-RED Admin API v2,
  2. copies dist/ui/* to the persistent uibuilder source directory.

It NEVER restarts or rolls out ORCE.

Options:
  --kubeconfig FILE
  --context NAME
  --orce-container NAME   auto-discovered when omitted
  --admin-url URL         auto-derived from PCI_ORCE_EDITOR_PATH
  --insecure              allow curl -k for test certificates
  -h, --help
USAGE
}
while [[ $# -gt 0 ]];do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2";shift 2;;
    --context) CONTEXT="$2";shift 2;;
    --orce-namespace) ORCE_NS="$2";shift 2;;
    --orce-deployment) ORCE_DEPLOYMENT="$2";shift 2;;
    --orce-container) ORCE_CONTAINER="$2";shift 2;;
    --admin-url) ADMIN_URL="$2";shift 2;;
    --insecure) INSECURE=true;shift;;
    -h|--help) usage;exit 0;;
    *) echo "Unknown argument: $1" >&2;usage >&2;exit 2;;
  esac
done
[[ -n "$ORCE_NS" && -n "$ORCE_DEPLOYMENT" ]]||{ echo "--orce-namespace and --orce-deployment are required" >&2;exit 2; }
for binary in kubectl node curl jq;do command -v "$binary">/dev/null 2>&1||{ echo "$binary is required" >&2;exit 1; };done
absolute_path(){ local v="$1";[[ -n "$v" ]]||return 0;[[ "$v" = /* ]]&&printf '%s\n' "$v"||printf '%s/%s\n' "$(cd "$(dirname "$v")"&&pwd)" "$(basename "$v")"; }
KUBECONFIG_PATH="$(absolute_path "$KUBECONFIG_PATH")"
K=(kubectl --request-timeout=20s);[[ -z "$KUBECONFIG_PATH" ]]||K+=(--kubeconfig "$KUBECONFIG_PATH");[[ -z "$CONTEXT" ]]||K+=(--context "$CONTEXT")
CURL=(curl -fsS --connect-timeout 10 --max-time 30);$INSECURE&&CURL+=(-k)
[[ -z "${PCI_ORCE_CURL_CONFIG:-}" ]] || CURL+=(--config "$PCI_ORCE_CURL_CONFIG")

# Retry only reads. In particular, never automatically replay the flow POST.
kread(){ local attempt; for attempt in 1 2 3; do if "${K[@]}" "$@"; then return 0; fi; [[ "$attempt" == 3 ]] && return 1; sleep 3; done; }
curl_read(){ "${CURL[@]}" --retry 3 --retry-delay 3 --retry-max-time 60 --retry-all-errors "$@"; }

[[ -f "$ROOT/dist/fap-pci-flow.json" && -d "$ROOT/dist/ui" ]]||{ echo "deployment dist/ artifacts are missing; restore this PCI package or obtain a complete release from the PCI source repository" >&2;exit 1; }
DEPLOY_JSON="$(kread -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" -o json)"
[[ -n "$ORCE_CONTAINER" ]]||ORCE_CONTAINER="$(jq -r '.spec.template.spec.containers[0].name' <<<"$DEPLOY_JSON")"
MAIN_HOST="$(kread -n "$ORCE_NS" get configmap fap-pci-config -o jsonpath='{.data.PCI_MAIN_HOST}')"
BASE_PATH="$(kread -n "$ORCE_NS" get configmap fap-pci-config -o jsonpath='{.data.PCI_ORCE_BASE_PATH}')"
EDITOR_PATH="$(kread -n "$ORCE_NS" get configmap fap-pci-config -o jsonpath='{.data.PCI_ORCE_EDITOR_PATH}')"
[[ -n "$MAIN_HOST" ]]||{ echo "ground-zero has not prepared fap-pci-config" >&2;exit 2; }
[[ -n "$ADMIN_URL" ]]||ADMIN_URL="https://${MAIN_HOST}${EDITOR_PATH}"
ADMIN_URL="${ADMIN_URL%/}"

SELECTOR="$(kread -n "$ORCE_NS" get deploy "$ORCE_DEPLOYMENT" -o go-template='{{range $k,$v := .spec.selector.matchLabels}}{{printf "%s=%s," $k $v}}{{end}}'|sed 's/,$//')"
POD="$(kread -n "$ORCE_NS" get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}')";[[ -n "$POD" ]]||{ echo "ORCE pod not found" >&2;exit 1; }
"${K[@]}" -n "$ORCE_NS" exec "$POD" -c "$ORCE_CONTAINER" -- sh -lc 'test -d /data/uibuilder && node -e "for(const m of [\"pg\",\"nodemailer\",\"jsonwebtoken\",\"jwks-rsa\",\"yaml\",\"node-red-contrib-uibuilder\"])require.resolve(m,{paths:[\"/data\"]})"' || { echo "ORCE was not fully prepared by ground-zero" >&2;exit 1; }

TMP="$(mktemp -d)";trap 'rm -rf "$TMP"' EXIT
curl_read -H 'Node-RED-API-Version: v2' "$ADMIN_URL/flows">"$TMP/current-envelope.json"
jq -e 'type=="object" and (.rev|type=="string" and length>0) and (.flows|type=="array")' "$TMP/current-envelope.json" >/dev/null || { echo 'Node-RED Admin API v2 envelope expected' >&2; exit 1; }
jq '.flows' "$TMP/current-envelope.json" > "$TMP/current-flows.json"
jq -r '"current revision: " + .rev, "current nodes: " + (.flows|length|tostring)' "$TMP/current-envelope.json"
# Capture only files owned by this release, before uibuilder can seed them.
# Existing PCI installations are adopted; their previous UI is not an ORCE baseline.
PCI_ADOPTED="$(jq -r '[.flows[] | select(.type=="tab" and ((.label//"")=="PCI_Interface" or ((.label//"")|test("^M[0-9]+_PCI-"))))] | length>0' "$TMP/current-envelope.json")"
PCI_UI_FILES="$(find "$ROOT/dist/ui" -maxdepth 1 -type f -printf '%f\0' | jq -Rs 'split("\u0000") | map(select(length>0)) | sort')"
"${K[@]}" -n "$ORCE_NS" exec -i "$POD" -c "$ORCE_CONTAINER" -- node --input-type=module - snapshot-ui /data/fap-pci/install /data/uibuilder/ui/src "$PCI_UI_FILES" "$PCI_ADOPTED" < "$ROOT/automation/stage1/artifacts.mjs"
"${K[@]}" -n "$ORCE_NS" exec "$POD" -c "$ORCE_CONTAINER" -- node -e 'const f=require("fs");const p="/data/fap-pci/install/flows.json";process.stdout.write(f.existsSync(p)?f.readFileSync(p):"{\"version\":1,\"nodes\":[]}")' > "$TMP/previous-ownership.json"
jq -e 'type=="object" and .version==1 and (.nodes|type=="array") and all(.nodes[];type=="string")' "$TMP/previous-ownership.json" >/dev/null || { echo 'Invalid artifact ownership record' >&2; exit 1; }
jq -n --slurpfile incoming "$ROOT/dist/fap-pci-flow.json" --slurpfile previous "$TMP/previous-ownership.json" '{version:1,nodes:([$previous[0].nodes[], $incoming[0][].id] | unique | sort)}' > "$TMP/ownership.json"
node "$ROOT/automation/stage1/merge-flows.mjs" --existing "$TMP/current-flows.json" --incoming "$ROOT/dist/fap-pci-flow.json" --output "$TMP/merged.json"
jq -n --slurpfile current "$TMP/current-envelope.json" --slurpfile merged "$TMP/merged.json" '{rev:$current[0].rev,flows:$merged[0]}' > "$TMP/deploy.json"
jq -r '"deploying nodes: " + (.flows|length|tostring)' "$TMP/deploy.json"
"${K[@]}" -n "$ORCE_NS" cp -c "$ORCE_CONTAINER" "$TMP/ownership.json" "$ORCE_NS/$POD:/data/fap-pci/install/flows.json"
set +e
HTTP_CODE="$("${CURL[@]}" -o "$TMP/response.txt" -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H 'Node-RED-API-Version: v2' -H 'Node-RED-Deployment-Type: flows' --data-binary "@$TMP/deploy.json" "$ADMIN_URL/flows")"
CURL_RC=$?
set -e
[[ "$CURL_RC" == 0 && ("$HTTP_CODE" == 200 || "$HTTP_CODE" == 204) ]]||{ echo "flow hot-deploy failed (curl=$CURL_RC HTTP=$HTTP_CODE)" >&2;exit 1; }
curl_read -H 'Node-RED-API-Version: v2' "$ADMIN_URL/flows">"$TMP/verify.json"
jq -e --slurpfile incoming "$ROOT/dist/fap-pci-flow.json" '
  (.flows|type=="array") and (.rev|type=="string" and length>0) and
  ([.flows[] | select(.type=="tab") | .label] as $labels |
   all($incoming[0][] | select(.type=="tab"); .label as $tab_name | $labels | index($tab_name)!=null))
' "$TMP/verify.json" >/dev/null || { echo 'Missing PCI tabs or invalid live envelope' >&2; exit 1; }
jq -r '"live revision: " + .rev, "total nodes: " + (.flows|length|tostring)' "$TMP/verify.json"

# Copy UI only after the uibuilder node exists so its first deployment cannot seed over our assets.
"${K[@]}" -n "$ORCE_NS" exec "$POD" -c "$ORCE_CONTAINER" -- mkdir -p /data/uibuilder/ui/src
"${K[@]}" -n "$ORCE_NS" cp -c "$ORCE_CONTAINER" "$ROOT/dist/ui/." "$ORCE_NS/$POD:/data/uibuilder/ui/src/"
"${K[@]}" -n "$ORCE_NS" exec "$POD" -c "$ORCE_CONTAINER" -- sh -lc 'test -s /data/uibuilder/ui/src/index.html && test -s /data/uibuilder/ui/src/index.js && test -s /data/uibuilder/ui/src/vue.global.prod.js'

"${K[@]}" -n "$ORCE_NS" exec -i "$POD" -c "$ORCE_CONTAINER" -- node --input-type=module - record-ui /data/fap-pci/install /data/uibuilder/ui/src < "$ROOT/automation/stage1/artifacts.mjs"

printf '{"event":"pci.artifacts.installed","restarted":false}\n'
echo "UI: https://${MAIN_HOST}${BASE_PATH}/ui/"
