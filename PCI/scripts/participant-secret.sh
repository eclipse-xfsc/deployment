#!/usr/bin/env bash
# Creates only a PCI-owned client/trust Secret. Never a participant server key.
set -euo pipefail
K=(kubectl)
[[ -z "${PCI_KUBECTL_CONTEXT:-}" ]] || K+=(--context "$PCI_KUBECTL_CONTEXT")
NS="${1:?Usage: participant-secret.sh PCI_NAMESPACE SECRET TENANT_UUID OWNER_UUID CERT KEY CA}"
NAME="${2:?}"; TENANT="${3:?}"; OWNER="${4:?}"; CERT="${5:?}"; KEY="${6:?}"; CA="${7:?}"
[[ "$NS" != ocm-wstack && "$NS" != infrastructure ]] || exit 2
for value in "$NS" "$NAME"; do [[ "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 2; done
for value in "$TENANT" "$OWNER"; do [[ "$value" =~ ^[0-9a-fA-F-]{36}$ ]] || exit 2; done
openssl x509 -in "$CERT" -checkend 86400 -noout >/dev/null
CERT_PUB="$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | openssl sha256)"
KEY_PUB="$(openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | openssl sha256)"
[[ "$CERT_PUB" == "$KEY_PUB" ]] || { echo 'Client certificate/key mismatch' >&2; exit 1; }
EXISTING="$("${K[@]}" -n "$NS" get secret "$NAME" --ignore-not-found -o json)"
if [[ -n "$EXISTING" ]]; then
  jq -e --arg t "$TENANT" --arg o "$OWNER" '.metadata.labels["xfsc.org/pci-tenant-id"]==$t and .metadata.labels["xfsc.org/pci-owner-uid"]==$o' <<<"$EXISTING" >/dev/null || { echo 'Existing Secret has a different owner' >&2; exit 1; }
fi
PARENT="$("${K[@]}" -n "$NS" get configmap -l "xfsc.org/pci-tenant-id=$TENANT,xfsc.org/pci-owner-uid=$OWNER,app.kubernetes.io/managed-by=fap-pci-orce" -o json | jq -ce '.items | if length==1 then .[0] else error("Expected one reconciled tenant ConfigMap") end')"
OWNER_REF="$(jq -c '[{apiVersion:"v1",kind:"ConfigMap",name:.metadata.name,uid:.metadata.uid,blockOwnerDeletion:true}]' <<<"$PARENT")"
"${K[@]}" -n "$NS" create secret generic "$NAME" --from-file=tls.crt="$CERT" --from-file=tls.key="$KEY" --from-file=ca.crt="$CA" --dry-run=client -o json |
 jq --arg t "$TENANT" --arg o "$OWNER" --argjson owner "$OWNER_REF" '.metadata.ownerReferences=$owner | .metadata.labels={"app.kubernetes.io/part-of":"fap-pci","app.kubernetes.io/managed-by":"fap-pci-orce","xfsc.org/pci-tenant-id":$t,"xfsc.org/pci-owner-uid":$o}' |
 "${K[@]}" apply --server-side --field-manager=fap-pci-participant-trust -f -

# Runtime reads only this named participant Secret. The tenant ConfigMap owns
# the Secret and grant; foreground tenant deletion garbage-collects all three. It cannot enumerate
# Secrets or read the database, mail or Keycloak credentials through this grant.
ROLE="pci-trust-$(printf '%s' "$NAME" | sha256sum | cut -c1-16)"
for KIND in role rolebinding; do
  EXISTING="$("${K[@]}" -n "$NS" get "$KIND" "$ROLE" --ignore-not-found -o json)"
  if [[ -n "$EXISTING" ]]; then
    jq -e --arg t "$TENANT" --arg o "$OWNER" '.metadata.labels["xfsc.org/pci-tenant-id"]==$t and .metadata.labels["xfsc.org/pci-owner-uid"]==$o' <<<"$EXISTING" >/dev/null || { echo 'Existing trust grant has a different owner' >&2; exit 1; }
  fi
done
jq -n --arg ns "$NS" --arg name "$NAME" --arg role "$ROLE" --arg t "$TENANT" --arg o "$OWNER" --argjson owner "$OWNER_REF" '
  {name:$role,namespace:$ns,ownerReferences:$owner,labels:{"app.kubernetes.io/part-of":"fap-pci","app.kubernetes.io/managed-by":"fap-pci-orce","xfsc.org/pci-tenant-id":$t,"xfsc.org/pci-owner-uid":$o}} as $m |
  {apiVersion:"v1",kind:"List",items:[
    {apiVersion:"rbac.authorization.k8s.io/v1",kind:"Role",metadata:$m,rules:[
      {apiGroups:[""],resources:["secrets"],resourceNames:[$name],verbs:["get"]}
    ]},
    {apiVersion:"rbac.authorization.k8s.io/v1",kind:"RoleBinding",metadata:$m,subjects:[{kind:"ServiceAccount",name:"fap-pci-orce",namespace:$ns}],roleRef:{apiGroup:"rbac.authorization.k8s.io",kind:"Role",name:$role}}
  ]}' | "${K[@]}" apply --server-side --field-manager=fap-pci-participant-trust -f -
