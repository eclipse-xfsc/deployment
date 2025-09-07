#! /bin/bash
set -euo pipefail

# ./deploy.sh PCMNAMESPACE, OCMNAMESPACE, DOMAIN, CERTIFICATEPATH, KEYPATH, KUBECONFIG
#               REGISTRYREPO, REGISTRYUSERNAME, REGISTRYPASS,
#               WUIINGRESSUSER, WUIINGRESSPASS

NAMESPACE="$1"
OCMNAMESPACE="$2"
DOMAIN="$3"
CERT_PATH="$4"
KEY_PATH="$5"   
KUBE="$6"
TLS_SECRET="xfsc-wildcard"
REGISTRY_REPO="$7"
REGISTRY_USERNAME="$8"
REGISTRY_PASSWORD="$9"
WUI_ING_USER="$10"
WUI_ING_PASS="$11"

helm repo add kong https://charts.konghq.com
helm repo update

export KUBECONFIG="$KUBE"
kubectl create ns $NAMESPACE
kubectl create secret tls "${TLS_SECRET}" \
    --cert="${CERT_PATH}" \
    --key="${KEY_PATH}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

reown_from_chart() {
  local chart_dir="$1" rel="$2" ns="$3"
  helm dependency build "$chart_dir" >/dev/null 2>&1 || true
  helm template "$rel" "$chart_dir" -n "$ns" -o json \
  | jq -r '
      .[]
      | select(.kind != null and .metadata != null and .metadata.name != null)
      | [.kind, (.metadata.namespace // ""), .metadata.name]
      | @tsv
    ' \
  | while IFS=$'\t' read -r kind rns name; do
      if [[ -z "$rns" ]]; then
        if kubectl get "$kind" "$name" >/dev/null 2>&1; then
          echo "Reowning $kind/$name (cluster-scoped)"
          kubectl annotate "$kind" "$name" \
            meta.helm.sh/release-name="$rel" \
            meta.helm.sh/release-namespace="$ns" --overwrite || true
          kubectl label "$kind" "$name" \
            app.kubernetes.io/managed-by=Helm --overwrite || true
        fi
      else
        if kubectl -n "$rns" get "$kind" "$name" >/dev/null 2>&1; then
          echo "Reowning $kind/$rns/$name"
          kubectl -n "$rns" annotate "$kind" "$name" \
            meta.helm.sh/release-name="$rel" \
            meta.helm.sh/release-namespace="$ns" --overwrite || true
          kubectl -n "$rns" label "$kind" "$name" \
            app.kubernetes.io/managed-by=Helm --overwrite || true
        fi
      fi
    done
  for kind in clusterrole clusterrolebinding validatingwebhookconfiguration mutatingwebhookconfiguration apiservice crd ingressclass priorityclass storageclass; do
    kubectl get "$kind" -o name 2>/dev/null \
    | grep -i "$rel" \
    | while read -r r; do
        echo "Reowning $kind $r (cluster-scoped sweep)"
        kubectl annotate "$r" \
          meta.helm.sh/release-name="$rel" \
          meta.helm.sh/release-namespace="$ns" --overwrite || true
        kubectl label "$r" app.kubernetes.io/managed-by=Helm --overwrite || true
      done
  done
  for kind in role rolebinding; do
    kubectl -n "$ns" get "$kind" -o name 2>/dev/null \
    | grep -i "$rel" \
    | while read -r r; do
        echo "Reowning $kind $ns/$r (namespaced sweep)"
        kubectl -n "$ns" annotate "$r" \
          meta.helm.sh/release-name="$rel" \
          meta.helm.sh/release-namespace="$ns" --overwrite || true
        kubectl -n "$ns" label "$r" app.kubernetes.io/managed-by=Helm --overwrite || true
      done
  done
}
reown_from_chart "./Kong Service"                "kong-service"          "$NAMESPACE" || true
reown_from_chart "./Configuration Service"       "configuration-service" "$NAMESPACE" || true
reown_from_chart "./Plugin Discovery Service"    "plugin-discovery-service" "$NAMESPACE" || true
reown_from_chart "./Account Service"             "account-service"       "$NAMESPACE" || true
reown_from_chart "./Web-UI Service"              "web-ui-service"        "$NAMESPACE" || true


### Configuration Service
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Configuration Service/values.yaml"
helm dependency build "./Configuration Service";helm install configuration-service "./Configuration Service" -n $NAMESPACE
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Configuration Service/values.yaml"


### Kong
kubectl annotate ingressclass kong \
  meta.helm.sh/release-name=kong-service \
  meta.helm.sh/release-namespace=$NAMESPACE --overwrite || true
kubectl label ingressclass kong \
  app.kubernetes.io/managed-by=Helm --overwrite || true
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Kong Service/values.yaml"
helm dependency build "./Kong Service";helm install kong-service "./Kong Service" -n $NAMESPACE
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Kong Service/values.yaml"


### Plugin Discovery Service
sed -i.bak 's/\<'"PCMNAMESPACE"'\>/'"$NAMESPACE"'/g' "./Plugin Discovery Service/values.yaml"
helm dependency build "./Plugin Discovery Service";helm install plugin-discovery-service "./Plugin Discovery Service" -n $NAMESPACE
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"PCMNAMESPACE"'/g' "./Plugin Discovery Service/values.yaml"

### OCM-W-Stack Connection (same cluster, different Namespace)
export POSTGRES_ADMIN_PASSWORD=$(
  kubectl get secret -n "${OCMNAMESPACE}" postgres-postgresql \
    -o jsonpath="{.data.postgres-password}" | base64 -d)
export POSTGRES_POD=$(
  kubectl get pod -n "${OCMNAMESPACE}" \
    -l app.kubernetes.io/instance=postgres,app.kubernetes.io/component=primary \
    -o jsonpath='{.items[0].metadata.name}')
kubectl create secret generic postgres-postgresql \
  --namespace "${NAMESPACE}" \
  --from-literal=postgresql-username="postgres" \
  --from-literal=postgresql-password="${POSTGRES_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic account-db \
  --namespace "${NAMESPACE}" \
  --from-literal=postgresql-username="postgres" \
  --from-literal=postgresql-password="${POSTGRES_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic vault --namespace "${NAMESPACE}" \
  --from-literal=token="root" \
  --dry-run=client -o yaml | kubectl apply -f -

### DB Migrations
kubectl exec -i -n "$OCMNAMESPACE" "$POSTGRES_POD" -- \
  env PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" \
  psql -U postgres -c "CREATE DATABASE accounts;" || true
kubectl exec -i -n "$OCMNAMESPACE" "$POSTGRES_POD" -- \
  env PGPASSWORD="$POSTGRES_ADMIN_PASSWORD" \
  psql -U postgres -d accounts -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS accounts CASCADE; CREATE SCHEMA IF NOT EXISTS accounts;
CREATE TABLE IF NOT EXISTS accounts.user_secrets (id SERIAL, user_id text PRIMARY KEY, secret_id text, created_at timestamp, updated_at timestamp, deleted_at timestamp);
CREATE TABLE IF NOT EXISTS accounts.user_configs (id SERIAL PRIMARY KEY, user_id VARCHAR(255) UNIQUE, attributes JSONB NOT NULL DEFAULT '{}'::JSONB, created_at timestamp, updated_at timestamp, deleted_at timestamp);
CREATE TABLE IF NOT EXISTS accounts.history_records (id SERIAL PRIMARY KEY, user_id VARCHAR(255), event_type text, message text, created_at timestamp, updated_at timestamp, deleted_at timestamp);
CREATE TABLE IF NOT EXISTS accounts.backups (id SERIAL PRIMARY KEY, user_id VARCHAR(255),credentials bytea, created_at timestamp, updated_at timestamp, deleted_at timestamp);
CREATE TABLE IF NOT EXISTS accounts.presentation_requests (id SERIAL PRIMARY KEY, user_id VARCHAR(255),request_id text, proof_request_id text, created_at timestamp, updated_at timestamp, deleted_at timestamp, ttl integer);
CREATE TABLE IF NOT EXISTS accounts.user_connections (id SERIAL PRIMARY KEY, user_id text, remote_did text, created_at timestamp, updated_at timestamp, deleted_at timestamp);" || true


### Account Service
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Account Service/values.yaml"
sed -i.bak 's/\<'"PCMNAMESPACE"'\>/'"$NAMESPACE"'/g' "./Account Service/values.yaml"
sed -i.bak 's/\<'"OCMNAMESPACE"'\>/'"$OCMNAMESPACE"'/g' "./Account Service/values.yaml"
helm dependency build "./Account Service";helm install account-service "./Account Service" -n $NAMESPACE
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Account Service/values.yaml"
sed -i.bak 's/\<'"$NAMESPACE"'\>/'"PCMNAMESPACE"'/g' "./Account Service/values.yaml"
sed -i.bak 's/\<'"$OCMNAMESPACE"'\>/'"OCMNAMESPACE"'/g' "./Account Service/values.yaml"


### OCM-W-Stack Keycloak Credentials Sharing
export KEYCLOAK_ADMIN_PASSWORD=$(
  kubectl get secret -n "${OCMNAMESPACE}" keycloak-init-secrets \
    -o jsonpath="{.data.admin-password}" | base64 -d)
export KEYCLOAK_PASSWORD=$(
  kubectl get secret -n "${OCMNAMESPACE}" keycloak-init-secrets \
    -o jsonpath="{.data.password}" | base64 -d)
export KEYCLOAK_POSTGRES_PASSWORD=$(
  kubectl get secret -n "${OCMNAMESPACE}" keycloak-init-secrets \
    -o jsonpath="{.data.postgres-password}" | base64 -d)
export KEYCLOAK_USERNAME=$(
  kubectl get secret -n "${OCMNAMESPACE}" keycloak-init-secrets \
    -o jsonpath="{.data.username}" | base64 -d)
kubectl create secret generic keycloak-init-secrets \
  --namespace "${NAMESPACE}" \
  --from-literal=admin-password="${KEYCLOAK_ADMIN_PASSWORD}" \
  --from-literal=password="${KEYCLOAK_PASSWORD}" \
  --from-literal=postgres-password="${KEYCLOAK_POSTGRES_PASSWORD}" \
  --from-literal=username="${KEYCLOAK_USERNAME}" \
  --dry-run=client -o yaml | kubectl apply -f -


### Web-UI
echo "$REGISTRY_PASSWORD" | docker login index.docker.io -u "$REGISTRY_USERNAME" --password-stdin
sed -i.bak "s/\<DOMAIN\>/$DOMAIN/g" "./web-ui_image_build/cloud-wallet-web-ui/.env.production"
docker build -f "./web-ui_image_build/cloud-wallet-web-ui/deployment/docker/Dockerfile" \
  -t "$REGISTRY_REPO:custom-webui" "./web-ui_image_build/cloud-wallet-web-ui/"
mv "./web-ui_image_build/cloud-wallet-web-ui/.env.production.bak" "./web-ui_image_build/cloud-wallet-web-ui/.env.production"
docker push "$REGISTRY_REPO:custom-webui"
kubectl -n "$NAMESPACE" delete secret regcred 2>/dev/null || true
kubectl -n "$NAMESPACE" create secret docker-registry regcred \
  --docker-server="https://index.docker.io/v1/" \
  --docker-username="$REGISTRY_USERNAME" \
  --docker-password="$REGISTRY_PASSWORD"
printf "$WUI_ING_USER:$(openssl passwd -apr1 $WUI_ING_PASS)\n" > auth
kubectl create secret generic web-ui-basic-auth \
  --from-file=auth -n $NAMESPACE
sed -i.bak 's/\<'"DOMAIN"'\>/'"$DOMAIN"'/g' "./Web-UI Service/values.yaml"
sed -i "s|REGISTRY_REPO|${REGISTRY_REPO}|g" "./Web-UI Service/values.yaml"
helm dependency build "./Web-UI Service";helm install web-ui-service "./Web-UI Service" -n $NAMESPACE --wait --timeout 5m --debug
sed -i.bak 's/\<'"$DOMAIN"'\>/'"DOMAIN"'/g' "./Web-UI Service/values.yaml"
sed -i "s|${REGISTRY_REPO}|REGISTRY_REPO|g" "./Web-UI Service/values.yaml"


### Web-UI Client Creation
KC_POD="$(kubectl -n "$OCMNAMESPACE" get pods -l app.kubernetes.io/name=keycloak -o jsonpath='{.items[0].metadata.name}')"
PASS="$(kubectl -n "$OCMNAMESPACE" get secret keycloak-init-secrets -o jsonpath='{.data.password}' | base64 -d)"
KCADM_DIR="/tmp/kcadm"
KCADM_CFG="$KCADM_DIR/kcadm.config"
ok=""
for i in {1..60}; do
  if kubectl -n "$OCMNAMESPACE" exec -i "$KC_POD" -- sh -lc "
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
kubectl -n "$OCMNAMESPACE" exec -i "$KC_POD" -- sh -lc "
  HOME='$KCADM_DIR' /opt/bitnami/keycloak/bin/kcadm.sh create clients -r master \
    --config '$KCADM_CFG' \
    -s clientId=webui \
    -s name=webui \
    -s protocol=openid-connect \
    -s enabled=true \
    -s publicClient=true \
    -s standardFlowEnabled=true \
    -s frontchannelLogout=true \
    -s rootUrl=https://cloud-wallet.$DOMAIN \
    -s baseUrl=https://cloud-wallet.$DOMAIN \
    -s adminUrl=https://cloud-wallet.$DOMAIN \
    -s 'redirectUris=[\"https://cloud-wallet.'$DOMAIN'/*\",\"http://localhost:3000/*\"]' \
    -s 'webOrigins=[\"https://cloud-wallet.'$DOMAIN'\",\"http://localhost:3000\"]' \
    -s 'attributes.\"pkce.code.challenge.method\"=S256' \
    -s 'attributes.\"access.token.signed.response.alg\"=RS256'
    
"

echo "######################################################"
echo "###################### ALL DONE ######################"
echo "######################################################"
