#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${1:?Usage: uninstall.sh PCI_NAMESPACE ORCE_DEPLOYMENT [--delete-tenants]}"
DEPLOYMENT="${2:?ORCE deployment name required}"
shift 2
DELETE_TENANTS=false
while (($#)); do case "$1" in --delete-tenants) DELETE_TENANTS=true;shift;; *) echo 'Unknown uninstall option' >&2;exit 2;; esac;done
for value in "$NS" "$DEPLOYMENT"; do [[ "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 2; done
[[ "$NS" != ocm-wstack && "$NS" != infrastructure ]] || { echo 'Refusing shared namespace' >&2; exit 2; }
for command in kubectl helm curl node jq python3;do command -v "$command" >/dev/null;done
TMP="$(mktemp -d)";trap 'rm -rf "$TMP"' EXIT
# KUBECONFIG and current context select the cluster. Both identities below must match.
kubectl -n "$NS" get secret fap-pci-original-orce -o json > "$TMP/original.json"
kubectl -n "$NS" get deploy "$DEPLOYMENT" -o json > "$TMP/current.json"
kubectl -n "$NS" get configmap fap-pci-config -o json > "$TMP/config.json"
CONTAINER="$(jq -er '.spec.template.spec.containers[] | select(any(.envFrom[]?; .configMapRef.name=="fap-pci-config")) | .name' "$TMP/current.json")"
[[ "$(wc -l <<< "$CONTAINER")" == 1 ]] || { echo 'Ambiguous PCI container' >&2;exit 1; }
EDITOR_URL="https://$(jq -r .data.PCI_MAIN_HOST "$TMP/config.json")$(jq -r .data.PCI_ORCE_EDITOR_PATH "$TMP/config.json")"
API_URL="https://$(jq -r .data.PCI_MAIN_HOST "$TMP/config.json")$(jq -r .data.PCI_ORCE_BASE_PATH "$TMP/config.json")/api/v1"
CURL=(curl --tlsv1.3 --tls-max 1.3 --fail --silent --show-error --connect-timeout 10 --max-time 30)
[[ -n "${PCI_ORCE_CURL_CONFIG:-}" ]] || { echo 'PCI_ORCE_CURL_CONFIG is required for ownership-aware flow removal' >&2;exit 2; }
EDITOR_CURL=("${CURL[@]}" --config "$PCI_ORCE_CURL_CONFIG")
"${EDITOR_CURL[@]}" -H 'Node-RED-API-Version: v2' "$EDITOR_URL/flows" > "$TMP/flows.json"
kubectl -n "$NS" exec deploy/"$DEPLOYMENT" -c "$CONTAINER" -- sh -c 'if test -f /data/fap-pci/install/flows.json;then cat /data/fap-pci/install/flows.json;else printf "null\n";fi' > "$TMP/ownership.json"
node "$ROOT/automation/stage1/artifacts.mjs" uninstall-flows "$TMP/flows.json" "$TMP/ownership.json" "$TMP/remove.json"
UI_INSTALLED=false
if kubectl -n "$NS" exec deploy/"$DEPLOYMENT" -c "$CONTAINER" -- test -f /data/fap-pci/install/ui.json;then
  UI_INSTALLED=true
  kubectl -n "$NS" exec -i deploy/"$DEPLOYMENT" -c "$CONTAINER" -- node --input-type=module - check-ui /data/fap-pci/install /data/uibuilder/ui/src < "$ROOT/automation/stage1/artifacts.mjs"
fi
node "$ROOT/automation/stage1/restore-runtime.mjs" "$TMP/original.json" "$TMP/current.json" "$TMP/patch.json" "$NS" "$DEPLOYMENT" "$CONTAINER"
python3 "$ROOT/automation/stage1/helper-cleanup.py" plan "$NS" "$DEPLOYMENT" "$TMP/helpers.json"
if $DELETE_TENANTS;then
  [[ -n "${PCI_PROVIDER_CURL_CONFIG:-}" ]] || { echo 'PCI_PROVIDER_CURL_CONFIG must contain an authenticated provider session' >&2;exit 2; }
  PROVIDER_CURL=("${CURL[@]}" --config "$PCI_PROVIDER_CURL_CONFIG")
  "${PROVIDER_CURL[@]}" "$API_URL/provider/tenants" > "$TMP/tenants.json"
  jq -c '.items[] | select(.state!="deleted") | {id:.tenantId,slug:.tenantSlug}' "$TMP/tenants.json" > "$TMP/remaining.jsonl"
  while IFS= read -r tenant;do
    id="$(jq -er '.id' <<< "$tenant")"
    jq -c '{state:"deleting",confirmation:.slug}' <<< "$tenant" > "$TMP/delete.json"
    "${PROVIDER_CURL[@]}" -X POST -H 'Content-Type: application/json' --data-binary "@$TMP/delete.json" "$API_URL/provider/tenants/$id/lifecycle" > /dev/null
  done < "$TMP/remaining.jsonl"
  PCI_DELETE_DEADLINE=$((SECONDS+600))
  while :;do
    "${PROVIDER_CURL[@]}" "$API_URL/provider/tenants" > "$TMP/tenants.json"
    [[ "$(jq '[.items[] | select(.state!="deleted")]|length' "$TMP/tenants.json")" == 0 ]] && break
    ((SECONDS<PCI_DELETE_DEADLINE)) || { echo 'Tenant deletion incomplete; infrastructure retained' >&2;exit 1; }
    sleep 5
  done
fi
# Refuse incomplete deletion even when HTTPRoutes have already disappeared.
kubectl -n "$NS" exec -i deploy/"$DEPLOYMENT" -c "$CONTAINER" -- node --input-type=module - < "$ROOT/automation/stage1/check-tenant-removal.mjs"
python3 "$ROOT/automation/stage1/helper-cleanup.py" check "$NS" "$DEPLOYMENT" "$TMP/helpers.json"
# Refresh the revision after tenant decommission and preserve all unrelated nodes.
"${EDITOR_CURL[@]}" -H 'Node-RED-API-Version: v2' "$EDITOR_URL/flows" > "$TMP/flows.json"
node "$ROOT/automation/stage1/artifacts.mjs" uninstall-flows "$TMP/flows.json" "$TMP/ownership.json" "$TMP/remove.json"
"${EDITOR_CURL[@]}" -X POST -H 'Content-Type: application/json' -H 'Node-RED-API-Version: v2' -H 'Node-RED-Deployment-Type: flows' --data-binary "@$TMP/remove.json" "$EDITOR_URL/flows" > /dev/null
if $UI_INSTALLED;then kubectl -n "$NS" exec -i deploy/"$DEPLOYMENT" -c "$CONTAINER" -- node --input-type=module - restore-ui /data/fap-pci/install /data/uibuilder/ui/src < "$ROOT/automation/stage1/artifacts.mjs";fi
kubectl -n "$NS" get deploy "$DEPLOYMENT" -o json > "$TMP/current.json"
node "$ROOT/automation/stage1/restore-runtime.mjs" "$TMP/original.json" "$TMP/current.json" "$TMP/patch.json" "$NS" "$DEPLOYMENT" "$CONTAINER"
kubectl -n "$NS" patch deployment "$DEPLOYMENT" --type=json --patch-file "$TMP/patch.json"
kubectl -n "$NS" rollout status deployment/"$DEPLOYMENT" --timeout=10m
helm uninstall fap-pci -n "$NS" --wait --timeout=10m
if helm status fap-pci-observability -n "$NS" >/dev/null 2>&1;then helm uninstall fap-pci-observability -n "$NS" --wait --timeout=5m;fi
python3 "$ROOT/automation/stage1/helper-cleanup.py" apply "$NS" "$DEPLOYMENT" "$TMP/helpers.json"
printf '{"event":"pci.uninstalled","namespace":"%s","data":"retained","unrelatedFlows":"preserved","ocmDeleted":false}\n' "$NS"
