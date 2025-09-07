#! /bin/bash

set -euo pipefail

# ./deploy.sh OCMNAMESPACE DOMAIN FULLCHAINCERT KEYPATH EMAIL KUECONFIG

NAMESPACE="$1"
DOMAIN="$2"
CERT_PATH="$3"
KEY_PATH="$4"
EMAIL="$5"
KUBE="$6"
TLS_SECRET="xfsc-wildcard"

export KUBECONFIG=$KUBE

helm repo add jetstack https://charts.jetstack.io
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

kubectl get ns ingress-nginx >/dev/null 2>&1 || kubectl create namespace ingress-nginx
kubectl -n ingress-nginx delete job -l app.kubernetes.io/component=admission-webhook --ignore-not-found
NGINX_ING_VER="controller-v1.11.1"
ING_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${NGINX_ING_VER}/deploy/static/provider/cloud/deploy.yaml"
curl -fsSL "$ING_URL" | kubectl apply -f -
for i in {1..30}; do
  kubectl -n ingress-nginx get deploy/ingress-nginx-controller >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=5m
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found
kubectl -n ingress-nginx create configmap ingress-nginx-controller --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ingress-nginx patch configmap ingress-nginx-controller \
  --type merge \
  -p '{"data":{"allow-snippet-annotations":"true","annotations-risk-level":"Critical"}}' || true
kubectl -n ingress-nginx rollout restart deploy/ingress-nginx-controller
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=5m || true

kubectl create ns $NAMESPACE || true
kubectl create secret tls "${TLS_SECRET}" \
    --cert="${CERT_PATH}" \
    --key="${KEY_PATH}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic signing --from-file=signing-key="${KEY_PATH}" -n "${NAMESPACE}"


### NATS
helm dependency build "./Nats Chart"
helm upgrade --install nats "./Nats Chart" --namespace "${NAMESPACE}"


### Cert-Manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml
kubectl get clusterrole,clusterrolebinding,validatingwebhookconfiguration,mutatingwebhookconfiguration,apiservice,crd -o name \
  | grep -E '(^|/)(cert-?manager|cm-)' \
  | while read -r r; do
      kubectl annotate "$r" \
        meta.helm.sh/release-name=cert-manager \
        meta.helm.sh/release-namespace="$NAMESPACE" \
        --overwrite  || true
      kubectl label "$r" app.kubernetes.io/managed-by=Helm \
        --overwrite  || true
    done || true
for kind in role rolebinding; do
  kubectl -n kube-system get "$kind" -o name \
    | grep -E '(^|/)(cert-?manager|cm-).*(leaderelection|dynamic-serving)' \
    | while read -r r; do
        kubectl -n kube-system annotate "$r" \
          meta.helm.sh/release-name=cert-manager \
          meta.helm.sh/release-namespace="$NAMESPACE" \
          --overwrite  || true
        kubectl -n kube-system label "$r" app.kubernetes.io/managed-by=Helm \
          --overwrite  || true
      done || true
done
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace "$NAMESPACE" \
  --version v1.11.0 \
  --set installCRDs=false


### Cassandra
helm upgrade --install cassandra bitnami/cassandra --namespace "${NAMESPACE}" -f ./Cassandra/values.yaml --wait


### Redis
export REDIS_PASSWORD=$(openssl rand -hex 16)
kubectl create secret generic preauthbridge-redis \
   --from-literal=redis-password="${REDIS_PASSWORD}" \
   --from-literal=redis-user="default" \
   -n "${NAMESPACE}" \
   --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install redis bitnami/redis --namespace "${NAMESPACE}" -f ./Redis/values.yaml


### Cassandra II
sleep 20
CASSANDRA_PASSWORD="$(kubectl -n "$NAMESPACE" get secret cassandra -o jsonpath='{.data.cassandra-password}' | base64 -d)"
kubectl -n "$NAMESPACE" wait --for=condition=ready pod cassandra-0 --timeout=10m
ok=""
echo TESTING CASSANDRA AUTH AVAILABILITY
for i in {1..60}; do
  if kubectl -n "$NAMESPACE" exec cassandra-0 -c cassandra -- \
    bash -lc "/opt/bitnami/cassandra/bin/cqlsh 127.0.0.1 9042 -u cassandra -p '$CASSANDRA_PASSWORD' -e 'SHOW VERSION'" >/dev/null 2>&1; then
    ok="y"; break
  fi
  sleep 5
done
[ -n "$ok" ] || { echo "Cassandra auth not ready"; exit 1; }
kubectl -n "$NAMESPACE" exec -i cassandra-0 -c cassandra -- \
  bash -lc "/opt/bitnami/cassandra/bin/cqlsh 127.0.0.1 9042 -u cassandra -p '$CASSANDRA_PASSWORD'" <<'CQL'
CREATE KEYSPACE IF NOT EXISTS tenant_space
  WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };

CREATE TABLE IF NOT EXISTS tenant_space.offerings (
  partition text,
  region text,
  country text,
  groupId text,
  requestId text,
  last_update_timestamp timestamp,
  type text,
  metadata text,
  offerParams text,
  status text,
  PRIMARY KEY ((partition, region, country), groupId, requestId)
) WITH default_time_to_live = 17800;

CREATE TABLE IF NOT EXISTS tenant_space.credentials (
  accountPartition text,
  region text,
  country text,
  account text,
  last_update_timestamp timestamp,
  metadata map<text,text>,
  credentials map<text,text>,
  presentations map<text,text>,
  id text,
  recovery_nonce text,
  device_key text,
  nonce text,
  locked boolean,
  signature text,
  PRIMARY KEY ((accountPartition, region, country), account)
);

CREATE INDEX IF NOT EXISTS credentials_locked_idx ON tenant_space.credentials (locked);
CREATE INDEX IF NOT EXISTS credentials_id_idx ON tenant_space.credentials (id);
CQL


### Postgres
helm upgrade --install postgres oci://registry-1.docker.io/bitnamicharts/postgresql --namespace "${NAMESPACE}"
export POSTGRES_ADMIN_PASSWORD=$(
  kubectl get secret -n "${NAMESPACE}" postgres-postgresql \
    -o jsonpath="{.data.postgres-password}" | base64 -d)
export POSTGRES_POD=$(
  kubectl get pod -n "${NAMESPACE}" \
    -l app.kubernetes.io/instance=postgres,app.kubernetes.io/component=primary \
    -o jsonpath='{.items[0].metadata.name}')


### Policy Charts
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Policy Chart/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Policy Chart/values.yaml"
helm dependency build "./Policy Chart"
helm upgrade --install policy-service "./Policy Chart" --namespace "${NAMESPACE}"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Policy Chart/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Policy Chart/values.yaml"


### Cluster Issuer
kubectl annotate clusterissuer letsencrypt-prod \
  meta.helm.sh/release-namespace=${NAMESPACE} \
  meta.helm.sh/release-name=cluster-issuer --overwrite || true
helm dependency build "./Cluster-Issuer"
helm upgrade --install cluster-issuer "./Cluster-Issuer" --set email="$EMAIL" --namespace "${NAMESPACE}"


### Keycloak
sed -i.bak 's/\<DOMAIN\>/'"$DOMAIN"'/g' ./Keycloak/values.yaml
helm dependency build "./Keycloak"
helm upgrade --install keycloak "./Keycloak" \
  --namespace "$NAMESPACE" \
  -f "./Keycloak/values.yaml" \
  --set keycloak.auth.adminUser=admin \
  --wait
mv ./Keycloak/values.yaml.bak ./Keycloak/values.yaml
KC_POD="$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/name=keycloak -o jsonpath='{.items[0].metadata.name}')"
PASS="$(kubectl -n "$NAMESPACE" get secret keycloak-init-secrets -o jsonpath='{.data.password}' | base64 -d)"
KCADM_DIR="/tmp/kcadm"
KCADM_CFG="$KCADM_DIR/kcadm.config"
ok=""
for i in {1..60}; do
  if kubectl -n "$NAMESPACE" exec -i "$KC_POD" -- sh -lc "
    mkdir -p '$KCADM_DIR' &&
    HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh config credentials \
      --config '$KCADM_CFG' \
      --server http://localhost:8080/ \
      --realm master \
      --user admin \
      --password '$PASS'
  " >/dev/null 2>&1; then
    ok="y"; break
  fi
  sleep 5
done
[ -n "$ok" ] || { echo 'Keycloak admin not ready'; exit 1; }
kubectl -n "$NAMESPACE" exec -i "$KC_POD" -- sh -lc "
  HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh update realms/master \
    --config '$KCADM_CFG' \
    -s registrationAllowed=true
"
kubectl -n "$NAMESPACE" exec -i "$KC_POD" -- sh -lc "
  HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh create clients -r master \
    --config '$KCADM_CFG' \
    -s clientId=bridge \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s clientAuthenticatorType=client-secret \
    -s serviceAccountsEnabled=true
"
CID="$(
  kubectl -n "$NAMESPACE" exec "$KC_POD" -- sh -lc "
    HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh get clients -r master -q clientId=bridge --config '$KCADM_CFG'
  " | jq -r '.[0].id'
)"
SECRET="$(
  kubectl -n "$NAMESPACE" exec "$KC_POD" -- sh -lc "
    HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh get clients/$CID/client-secret -r master --config '$KCADM_CFG'
  " | jq -r .value
)"
export BRIDGE_CLIENT_SECRET="$SECRET"
echo "BRIDGE_CLIENT_SECRET=$BRIDGE_CLIENT_SECRET"


### Vault
kubectl delete clusterrolebinding vault-agent-injector-binding || true
kubectl delete clusterrolebinding vault-server-binding || true
kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg || true
kubectl delete clusterrole vault-agent-injector-clusterrole || true
helm upgrade --install vault hashicorp/vault --namespace "${NAMESPACE}" \
  -f "./Vault/values.yaml" --set "server.dev.enabled=true" --wait
kubectl create secret generic vault --namespace "${NAMESPACE}" \
  --from-literal=token="root" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" wait --for=condition=ready pod vault-0 --timeout=10m
VAULT_ENV='VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root'
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault secrets enable -path=tenant_space transit || true"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault secrets enable transit || true"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault write -f tenant_space/keys/DeveloperCredential type=ecdsa-p256"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault write -f tenant_space/keys/SDJWTCredential type=ecdsa-p256"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault write -f tenant_space/keys/signerkey type=ecdsa-p256"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault write -f transit/keys/DeveloperCredential type=ecdsa-p256"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "$VAULT_ENV vault write -f transit/keys/SDJWTCredential type=ecdsa-p256"
kubectl -n "$NAMESPACE" exec vault-0 -- sh -lc "
  cat > /tmp/crypto-engine.hcl <<'EOF'
path \"transit/sign/DeveloperCredential\" { capabilities = [\"update\"] }
path \"transit/verify/DeveloperCredential\" { capabilities = [\"update\"] }
path \"transit/keys/DeveloperCredential\" { capabilities = [\"read\",\"list\"] }
path \"transit/sign/SDJWTCredential\" { capabilities = [\"update\"] }
path \"transit/verify/SDJWTCredential\" { capabilities = [\"update\"] }
path \"transit/keys/SDJWTCredential\" { capabilities = [\"read\",\"list\"] }
EOF
  $VAULT_ENV vault policy write crypto-engine-policy /tmp/crypto-engine.hcl
"


### Storage Service
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Storage Service/values.yaml"
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Storage Service/values.yaml"
helm dependency build "./Storage Service"
helm upgrade --install storage-service "./Storage Service" --namespace "${NAMESPACE}" -f "./Storage Service/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Storage Service/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Storage Service/values.yaml"
kubectl set env deployment/storage-service STORAGESERVICE_MESSAGING_URL=nats.$NAMESPACE.svc.cluster.local:4222 -n "${NAMESPACE}"


### Status List Service
kubectl exec -i -n "$NAMESPACE" "$POSTGRES_POD" -- \
  env PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" \
  psql -U postgres -c "CREATE DATABASE status;"
kubectl create secret generic statuslist-db-secret \
  --namespace "${NAMESPACE}" \
  --from-literal=postgresql-username="postgres" \
  --from-literal=postgresql-password="${POSTGRES_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Status List Service Chart/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Status List Service Chart/values.yaml"
helm dependency build "./Status List Service Chart"
helm upgrade --install status-list-service-chart "./Status List Service Chart" \
  --namespace "${NAMESPACE}" \
  --set database.autoMigrate=true\
  --set status-list-service.database.secretName=statuslist-db-secret \
  -f "./Status List Service Chart/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Status List Service Chart/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Status List Service Chart/values.yaml"
kubectl patch ing status-list-service -n "${NAMESPACE}" --type='json' -p='[
  {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"status-list-service-chart-service"},
  {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":8080}
]'


### Universal Resolver
helm dependency build "./Universal Resolver"
helm upgrade --install universal-resolver "./Universal Resolver" --namespace "${NAMESPACE}"


### Signer
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./signer/deployment/helm/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./signer/deployment/helm/values.yaml"
helm dependency build "./signer/deployment/helm"
helm upgrade --install signer "./signer/deployment/helm" --namespace "${NAMESPACE}" -f "./signer/deployment/helm/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./signer/deployment/helm/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./signer/deployment/helm/values.yaml"
kubectl set env deployment/signer \
  -n $NAMESPACE \
  VAULT_ADDR="https://vault.${NAMESPACE}.svc:8200" \
  TRANSIT_MOUNT_PATH=transit \
  TRANSIT_KEY_NAME=SDJWTCredential


### SD-JWT
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./SdJwt Service/values.yaml"
helm dependency build "./SdJwt Service"
helm upgrade --install sdjwt "./SdJwt Service" --namespace "${NAMESPACE}" -f "./SdJwt Service/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./SdJwt Service/values.yaml"


### Dummy Content Signer
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Dummy Content Signer/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Dummy Content Signer/values.yaml"
helm dependency build "./Dummy Content Signer"
helm upgrade --install dummy-content-signer "./Dummy Content Signer" \
  --namespace "${NAMESPACE}" -f "./Dummy Content Signer/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Dummy Content Signer/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Dummy Content Signer/values.yaml"


### Pre-Auth Bridge
kubectl create secret generic preauthbridge-oauth \
  -n "${NAMESPACE}" \
  --from-literal=secret="$BRIDGE_CLIENT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Pre Authorization Bridge Chart/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Pre Authorization Bridge Chart/values.yaml"
helm dependency build "./Pre Authorization Bridge Chart"
helm upgrade --install preauthbridge "./Pre Authorization Bridge Chart" \
  --namespace "${NAMESPACE}" \
  --set keycloak.email="${EMAIL}" \
  --set pre-authorization-bridge.config.database.password="${REDIS_PASSWORD}" \
  -f "./Pre Authorization Bridge Chart/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Pre Authorization Bridge Chart/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Pre Authorization Bridge Chart/values.yaml"


### Credential Issuance
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Credential Issuance/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Credential Issuance/values.yaml"
helm dependency build "./Credential Issuance"
helm upgrade --install credential-issuance-service "./Credential Issuance" \
  --namespace "${NAMESPACE}" --values "./Credential Issuance/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Credential Issuance/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Credential Issuance/values.yaml"


### Credential Retrieval Service
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Credential Retrieval/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Credential Retrieval/values.yaml"
helm dependency build "./Credential Retrieval"
helm upgrade --install credential-retrieval-service "./Credential Retrieval" \
  --values "./Credential Retrieval/values.yaml" --namespace "${NAMESPACE}"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Credential Retrieval/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Credential Retrieval/values.yaml"


### Credential Verification Service
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Credential Verification Service Chart/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Credential Verification Service Chart/values.yaml"
helm dependency build "./Credential Verification Service Chart"
helm upgrade --install credential-verification-service "./Credential Verification Service Chart" \
  --values "./Credential Verification Service Chart/values.yaml" --namespace "${NAMESPACE}"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Credential Verification Service Chart/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Credential Verification Service Chart/values.yaml"
kubectl -n "$NAMESPACE" patch deploy/credential-verification-service --type=strategic -p "$(cat <<EOF
{
  "spec": { "template": { "spec": {
    "containers": [{
      "name": "$(kubectl -n "$NAMESPACE" get deploy credential-verification-service -o jsonpath='{.spec.template.spec.containers[0].name}')",
      "env": [{ "name": "CREDENTIALVERIFICATION_MESSAGING_NATS_URL", "value": "nats.${NAMESPACE}.svc.cluster.local:4222" }]
    }]
  } } }
}
EOF
)"


### Wellknown DB
kubectl exec -i -n "$NAMESPACE" "$POSTGRES_POD" -- \
  env PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" \
  psql -U postgres -c "CREATE DATABASE wellknown;"


### Well Known Chart
kubectl create secret generic wellknown-db-secret \
  --namespace "${NAMESPACE}" \
  --from-literal=postgresql-username="postgres" \
  --from-literal=postgresql-password="${POSTGRES_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Well Known Chart/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Well Known Chart/values.yaml"
helm dependency build "./Well Known Chart"
helm upgrade --install well-known-service "./Well Known Chart" \
  --namespace "${NAMESPACE}" -f "./Well Known Chart/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Well Known Chart/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Well Known Chart/values.yaml"


### Well Known Ingress Rules
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Well Known Ingress Rules/values.yaml"
helm dependency build "./Well Known Ingress Rules"
helm upgrade --install well-known-ingress-rules "./Well Known Ingress Rules" --namespace "${NAMESPACE}"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Well Known Ingress Rules/values.yaml"


### DIDComm
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Didcomm/values.yaml"
sed -i.bak 's/\<'"NAMESPACE"'\>/'"$NAMESPACE"'/g' "./Didcomm/values.yaml"
helm dependency build "./Didcomm"
helm upgrade --install didcomm "./Didcomm" --namespace "${NAMESPACE}" -f "./Didcomm/values.yaml"
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Didcomm/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"NAMESPACE"'/g' "./Didcomm/values.yaml"

echo "######################################################"
echo "###################### ALL DONE ######################"
echo "######################################################"
