#!/bin/bash

# Parameter 1 is email

sudo apt update

sudo apt-get install openssl

sudo apt-get install git

sudo apt-get install helm

sudo snap install cqlsh

helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo add jetstack https://charts.jetstack.io --force-update

helm repo update

kubectl patch configmap ingress-nginx-controller -n ingress-nginx -p '{"data":{"allow-snippet-annotations":"true"}}'

if ! kubectl get namespace "cert-manager" &> /dev/null; then
    echo "############### Install Cert Manager"
    helm dependency build ./Cert-Manager; helm install cert-manager ./Cert-Manager  --create-namespace --namespace cert-manager
    helm dependency build ./Cluster-Issuer; helm install cluster-issuer ./Cluster-Issuer  --create-namespace --namespace cert-manager --set email=$1

fi 

if ! kubectl get namespace "cassandra" &> /dev/null; then

    kubectl create namespace cassandra

    NAMESPACE="cassandra"
    SECRET_NAME="cassandra"

    helm install cassandra oci://registry-1.docker.io/bitnamicharts/cassandra --namespace cassandra -f ./Cassandra/values.yaml

    PASSWORD=$(kubectl get secret $SECRET_NAME --namespace=$NAMESPACE -o jsonpath="{.data.cassandra-password}" | base64 --decode)

    kubectl create secret generic "cassandra" -n default \
        --from-literal=cassandra-password=$PASSWORD

    echo "Wait for cassandra to be finished"

    # Namespace und Secret Namen festlegen

    USERNAME="cassandra"

    echo "Versuche, eine Verbindung zu Cassandra herzustellen..."

    # Schleife, um Verbindung zu versuchen
    while true; do

        kubectl port-forward services/cassandra 9042:9042 -n cassandra &
        PID=$!

        echo $PID

        # Überprüfen ob cqlsh erfolgreich eine Verbindung herstellen kann
        cqlsh -u $USERNAME -p $PASSWORD -e "SHOW HOST;" &> /dev/null
        
        if [ $? -eq 0 ]; then
            echo "Erfolgreich mit Cassandra verbunden!"
        else
            echo "Verbindung fehlgeschlagen. Versuche es in 5 Sekunden erneut..."
            sleep 5
            kill $PID
            continue
        fi

        curl https://gitlab.eclipse.org/eclipse/xfsc/organisational-credential-manager-w-stack/storage-service/-/raw/main/scripts/cql/initialize.cql?ref_type=heads > storage.cql
        curl https://gitlab.eclipse.org/eclipse/xfsc/organisational-credential-manager-w-stack/credential-verification-service/-/raw/main/scripts/cql/initialize.cql?ref_type=heads > verification.cql
        curl https://gitlab.eclipse.org/eclipse/xfsc/organisational-credential-manager-w-stack/credential-retrieval-service/-/raw/main/scripts/cql/initialize.cql?ref_type=heads > retrieval.cql

        cqlsh -u $USERNAME -p $PASSWORD -f ./retrieval.cql
        cqlsh -u $USERNAME -p $PASSWORD -f ./storage.cql
        cqlsh -u $USERNAME -p $PASSWORD -f ./verification.cql

        kill $PID
        break;
    done
fi 

if ! kubectl get namespace "nats" &> /dev/null; then

    helm dependency build "./Nats Chart"; helm install nats "./Nats Chart" --create-namespace --namespace nats
fi 


if ! kubectl get namespace "keycloak" &> /dev/null; then
    echo "########### Install Keycloak#########"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout tls.key \
      -out tls.crt \
      -subj "/CN=auth-cloud-wallet.xfsc.dev/O=yourorganization"

    kubectl create namespace keycloak

    kubectl create secret tls xfsc-wildcard \
      --cert=tls.crt \
      --key=tls.key \
      --namespace keycloak

    helm dependency build "./Keycloak";helm install keycloak "./Keycloak" --create-namespace --namespace keycloak
fi

if ! kubectl get namespace "vault" &> /dev/null; then

    echo "######### Install Vault" 

    helm dependency build "./Vault";helm install vault "./Vault" --create-namespace --namespace vault
    sleep 10
      NAMESPACE="vault"              # Ersetze mit dem Namespace, in dem Vault läuft
      VAULT_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}")
      VAULT_PORT=8200                  # Standardport für Vault
      LOCAL_PORT=8200                  # Lokaler Port für Port-Forwarding
      VAULT_TOKEN="test"       # Ersetze mit deinem Vault-Token

      # Starte kubectl port-forward im Hintergrund
      echo "Starte kubectl port-forward zum Vault-Pod..."
      # Loop zur Überprüfung der Vault-Verbindung
      while true; do

          kubectl port-forward -n $NAMESPACE $VAULT_POD $LOCAL_PORT:$VAULT_PORT &

          PID=$!

          echo $PID
          # Überprüfe, ob der Vault-Server erreichbar ist
          if curl --silent --fail --output /dev/null "http://127.0.0.1:$LOCAL_PORT/v1/sys/health"; then
              echo "Erfolgreich mit Vault verbunden."
              break
          else
              echo "Warte auf Vault-Verbindung..."
              sleep 2  # Warte 2 Sekunden, bevor du es erneut versuchst
              continue
          fi
          kill $PID
          break
      done

     curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"type":"transit"}' http://127.0.0.1:8200/v1/sys/mounts/tenant_space
     curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"type":"ed25519"}' http://127.0.0.1:8200/v1/tenant_space/keys/signerkey
     curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"type":"ecdsa-p256"}' http://127.0.0.1:8200/v1/tenant_space/keys/eckey 

      # Beende das Port-Forwarding
      kill %1


fi 

# PostgreSQL-Admin-Benutzer und Passwort (falls nötig)
DB_ADMIN_USER="postgres"
DB_HOST=localhost


if ! kubectl get namespace "postgres" &> /dev/null; then
    echo "######### Install Postgres" 
    kubectl create namespace postgres

    helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql -n postgres
   
    POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

   kubectl delete secret statuslist-db-secret -n default

   kubectl delete secret wellknown-db-secret -n default

    while true; do

      kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD='$POSTGRES_PASSWORD';psql -h $DB_HOST -U $DB_ADMIN_USER -d postgres -c 'SELECT'"

      if [ $? -eq 0 ]; then
            echo "Erfolgreich mit Postgres verbunden!"
      else
            echo "Verbindung fehlgeschlagen. Versuche es in 5 Sekunden erneut..."
            sleep 5
            continue
      fi
      break
    done 
fi 

POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

if ! kubectl get secret "wellknown-db-secret" -n "default" > /dev/null 2>&1; then
  
    DB_WELLKNOWN_USER="wellknown"
    DB_WELLKNOWN_PASSWORD=$(openssl rand -hex 32)
    DB_WELLKNOWN_NAME="wellknown"

    kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD='$POSTGRES_PASSWORD';psql -U $DB_ADMIN_USER -h $DB_HOST -c \"CREATE USER $DB_WELLKNOWN_USER WITH PASSWORD '$DB_WELLKNOWN_PASSWORD';\""
    kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD="$POSTGRES_PASSWORD";psql -U $DB_ADMIN_USER -h $DB_HOST -d postgres -c 'CREATE DATABASE $DB_WELLKNOWN_NAME OWNER $DB_WELLKNOWN_USER;'"
    
    kubectl create secret generic wellknown-db-secret -n default \
    --from-literal=postgresql-username=wellknown \
    --from-literal=postgresql-password=$DB_WELLKNOWN_PASSWORD

fi 

if ! kubectl get secret "statuslist-db-secret" -n "default" > /dev/null 2>&1; then

    DB_STATUS_USER="statuslist"
    DB_STATUS_NAME="status"
    DB_STATUS_PASSWORD=$(openssl rand -hex 32)
    

    kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD='$POSTGRES_PASSWORD';psql -U $DB_ADMIN_USER -h $DB_HOST -c \"CREATE USER $DB_STATUS_USER WITH PASSWORD '$DB_STATUS_PASSWORD';\""
    kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD="$POSTGRES_PASSWORD";psql -U $DB_ADMIN_USER -h $DB_HOST -d postgres -c 'CREATE DATABASE $DB_STATUS_NAME OWNER $DB_STATUS_USER;'"

    kubectl create secret generic statuslist-db-secret -n default \
    --from-literal=postgresql-username=statuslist \
    --from-literal=postgresql-password=$DB_STATUS_PASSWORD
fi




echo "######### Install Universalresolver" 

helm dependency build "./Universal Resolver";helm install universal-resolver "./Universal Resolver" --create-namespace --namespace default



echo "####### Install Services"


openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout tls.key \
-out tls.crt \
-subj "/CN=cloud-wallet.xfsc.dev/O=yourorganization"

if ! kubectl get service "pre-authorization-bridge-service" &> /dev/null; then
    
      echo "####### Install Pre Auth Bridge Client"
      RELEASENAMESPACE="default"
      kubectl create namespace $RELEASENAMESPACE


      ADMIN_SECRET_NAMESPACE="keycloak"   # Namespace für das Admin-Secret
      ADMIN_SECRET_NAME=" keycloak-init-secrets"  # Name des Kubernetes-Secrets für Admin
      NEW_CLIENT_SECRET_NAME="preauthbridge-oauth"  # Name des neuen Kubernetes-Secrets für den Client
      KEYCLOAK_URL="https://auth-cloud-wallet.xfsc.dev"  # Keycloak-URL
      REALM="master"  # Keycloak-Realm
      NEW_CLIENT_ID="bridge"  # Neue Client-ID
      REDIRECT_URI="http://localhost"  # Redirect-URI

      ADMIN_USERNAME=$(kubectl get secret $ADMIN_SECRET_NAME -n $ADMIN_SECRET_NAMESPACE -o jsonpath='{.data.username}' | base64 --decode)
      ADMIN_PASSWORD=$(kubectl get secret $ADMIN_SECRET_NAME -n $ADMIN_SECRET_NAMESPACE -o jsonpath='{.data.admin-password}' | base64 --decode)

      ACCESS_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        -d "username=$ADMIN_USERNAME" \
        -d "password=$ADMIN_PASSWORD" \
        | jq -r '.access_token')
      echo $ACCESS_TOKEN
      # Überprüfe, ob das Access Token erfolgreich geholt wurde
      if [ -z "$ACCESS_TOKEN" ]; then
        echo "Fehler: Konnte kein Access Token erhalten."
        exit 1
      fi

      CLIENT_EXISTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" | jq --arg CLIENT_ID "$NEW_CLIENT_ID" '.[] | select(.clientId == $CLIENT_ID) | .id' | tr -d '"')

      if [ -n "$CLIENT_EXISTS" ]; then
        echo "Der Client '$NEW_CLIENT_ID' existiert bereits mit der ID: $CLIENT_EXISTS"
        URL="$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_EXISTS"
        echo $URL
        curl -X DELETE $URL \
        -H "Authorization: Bearer $ACCESS_TOKEN"
      fi
    

      NEW_CLIENT_SECRET=$(openssl rand -hex 32)

      # Erstelle den neuen Client in Keycloak
      RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
              \"clientId\": \"$NEW_CLIENT_ID\",
              \"enabled\": true,
              \"clientAuthenticatorType\": \"client-secret\",
              \"secret\": \"$NEW_CLIENT_SECRET\",
              \"redirectUris\": [\"$REDIRECT_URI\"],
              \"standardFlowEnabled\": false,
              \"directAccessGrantsEnabled\": false,
              \"serviceAccountsEnabled\": true,
              \"authorizationServicesEnabled\": false
            }")

      # Überprüfe, ob der Client erfolgreich erstellt wurde
      if echo "$RESPONSE" | grep -q "error"; then
        echo "Fehler beim Erstellen des Clients: $RESPONSE"
        exit 1
      fi

      # Hole die ID des erstellten Clients
      CLIENT_UUID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        | jq -r ".[] | select(.clientId == \"$NEW_CLIENT_ID\") | .id")

      if [ -z "$CLIENT_UUID" ]; then
        echo "Fehler: Konnte die Client-ID nicht abrufen."
        exit 1
      fi
 
      # Schreibe Client-ID und Secret in ein neues Kubernetes-Secret im separaten Namespace für den Client
      kubectl create secret generic $NEW_CLIENT_SECRET_NAME -n $RELEASENAMESPACE \
        --from-literal=id=$NEW_CLIENT_ID \
        --from-literal=secret=$NEW_CLIENT_SECRET

      echo "######## Install Redis"

      REDISPW=$(openssl rand -hex 32)

      kubectl create secret generic "preauthbridge-redis" -n $RELEASENAMESPACE \
        --from-literal=redis-user=default \
        --from-literal=redis-password=$REDISPW

      helm install redis bitnami/redis -n $RELEASENAMESPACE -f "./Redis/values.yaml"

      kubectl create secret tls xfsc-wildcard \
        --cert=tls.crt \
        --key=tls.key \
        --namespace $RELEASENAMESPACE

      helm dependency build "./Pre Authorization Bridge Chart"; helm install preauthbridge "./Pre Authorization Bridge Chart" -n $RELEASENAMESPACE

fi

echo "######### Install TSA Stuff" 

helm dependency build "./Policy Chart"; helm install policy-service "./Policy Chart" --create-namespace --namespace default

rm -rf signer
rm -rf sd-jwt-service
git clone https://gitlab.eclipse.org/eclipse/xfsc/tsa/signer.git 
git clone https://gitlab.eclipse.org/eclipse/xfsc/common-services/sd-jwt-service.git

helm dependency build "./signer/deployment/helm";helm install signer "./signer/deployment/helm" --namespace default
helm dependency build "./sd-jwt-service/deployment/helm";helm install signer "./sd-jwt-service/deployment/helm" --namespace default

 kubectl create secret generic vault -n default \
        --from-literal=token=test

kubectl create secret tls xfsc-wildcard \
  --cert=tls.crt \
  --key=tls.key \
  --namespace default

echo "###################Install Well Known Routes"

helm dependency build "./Well Known Ingress Rules";helm install well-known-rules "./Well Known Ingress Rules" -n default

helm dependency build "./Well Known Chart";helm install well-known "./Well Known Chart" -n default

helm dependency build "./Didcomm";helm install didcomm-connector "./Didcomm" -n default

helm dependency build "./Credential Issuance";helm install credential-issuance "./Credential Issuance" -n default

helm dependency build "./Credential Retrieval";helm install credential-retrieval "./Credential Retrieval" -n default

echo "Create a signing key for credential verification service"
openssl ecparam -genkey  -name prime256v1 -noout -out signing_key.pem
kubectl create secret -n default generic signing --from-file=signing-key=signing_key.pem

helm dependency build "./Credential Verification Service Chart";helm install credential-verification "./Credential Verification Service Chart" -n default

helm dependency build "./Storage Service";helm install storage-service "./Storage Service" -n default

helm dependency build "./Status List Service Chart";helm install statuslist-service "./Status List Service Chart" -n default

helm dependency build "./Dummy Content Signer";helm install dummy-contentsigner "./Dummy Content Signer" -n default
