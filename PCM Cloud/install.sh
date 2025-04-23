sudo apt install apache2-utils
rm auth
helm dependency build "./Kong Service";helm install kong-service "./Kong Service" -n kong --create-namespace
helm dependency build "./Plugin Discovery Service";helm install plugin-discovery-service "./Plugin Discovery Service" -n default --create-namespace
helm dependency build "./Configuration Service";helm install configuration-service "./Configuration Service" -n default

DB_USER="accountservice"
DB_NAME="accounts"
DB_HOST=localhost

if ! kubectl get secret "account-db" -n "default" > /dev/null 2>&1; then

POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

UserPW=$(openssl rand -base64 32)
DB_PASSWORD=$UserPW
# PostgreSQL-Admin-Benutzer und Passwort (falls nötig)
DB_ADMIN_USER="postgres"


kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD='$POSTGRES_PASSWORD';psql -U $DB_ADMIN_USER -h $DB_HOST -c \"CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';\""

kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD="$POSTGRES_PASSWORD";psql -U $DB_ADMIN_USER -h $DB_HOST -d postgres -c 'CREATE DATABASE $DB_NAME OWNER $DB_USER;'"

kubectl create secret generic account-db -n default \
--from-literal=postgresql-username=accountservice \
--from-literal=postgresql-password=$DB_PASSWORD
fi 

POSTGRES_PASSWORD=$(kubectl get secret --namespace default account-db -o jsonpath="{.data.postgresql-password}" | base64 -d)

SQL_SCRIPT=$(curl -s https://gitlab.eclipse.org/eclipse/xfsc/personal-credential-manager-cloud/account-service/-/raw/main/sql/init.sql?ref_type=heads)

if [ -z "$SQL_SCRIPT" ]; then
  echo "Fehler: Konnte das SQL-Skript nicht abrufen."
  exit 1
fi

kubectl exec -it postgres-postgresql-0 -n postgres -- bash -c "export PGPASSWORD='$POSTGRES_PASSWORD';psql -U $DB_USER -h $DB_HOST -d $DB_NAME" << EOF
$SQL_SCRIPT
EOF

Auth=$(openssl rand -base64 8)

htpasswd -c -b auth admin-web-ui $Auth

echo $Auth

kubectl create secret generic web-ui-basic-auth -n default --from-file=auth 

helm dependency build "./Account Service";helm install account-service "./Account Service" -n default
helm dependency build "./Web-UI Service";helm install web-ui-service "./Web-UI Service" -n default

KEYCLOAK_URL="http://auth-cloud-wallet.xfsc.dev"  # Ersetze <keycloak-url> durch die URL deines Keycloak-Servers
REALM="master"                             # Der Realm, in dem der Admin-User existiert (normalerweise "master")
USERNAME="admin"                           # Admin-Username (normalerweise "admin")
CLIENT_ID="admin-cli"                      # Admin-Client ID
NAMESPACE="keycloak"                       # Kubernetes Namespace, in dem das Secret liegt
SECRET_NAME="keycloak-init-secrets"        # Name des Kubernetes Secrets, das das Admin-Passwort enthält

# Admin-Passwort aus Kubernetes Secret lesen
PASSWORD=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath="{.data.admin-password}" | base64 --decode)

# Abrufen des Admin Access Tokens
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  | jq -r '.access_token')

# Überprüfen, ob das Token erfolgreich abgerufen wurde
if [ -z "$TOKEN" ]; then
  echo "Fehler: Konnte kein Token abrufen. Überprüfe deine Keycloak-URL, den Benutzernamen und das Passwort."
  exit 1
fi
echo $TOKEN
echo "Access Token erfolgreich abgerufen."

# Client-spezifische Variablen setzen
CLIENT_NAME="webui"                    # Name des neuen Clients
NEW_REALM="cloudpcm"                       # Realm, in dem der neue Client erstellt werden soll

echo Prüfen, ob der Realm existiert
REALM_EXISTS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.[] | select(.realm == "'"${NEW_REALM}"'") | .realm')

if [ "$REALM_EXISTS" == "$NEW_REALM" ]; then
  echo "Realm ${NEW_REALM} existiert bereits."
else
  # Neuen Realm erstellen, wenn er nicht existiert
  echo "Erstelle Realm ${NEW_REALM}..."
  curl -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "realm": "'"${NEW_REALM}"'",
      "enabled": true,
      "registrationAllowed": true,
      "loginTheme":"xfsc"
    }'
fi

# Prüfen, ob der Client bereits existiert
CLIENT_EXISTS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${NEW_REALM}/clients" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.[] | select(.clientId == "'"${CLIENT_NAME}"'") | .clientId')

if [ "$CLIENT_EXISTS" == "$CLIENT_NAME" ]; then
  echo "Client ${CLIENT_NAME} existiert bereits."
else
  # Neuen Client erstellen, wenn er nicht existiert
  echo "Erstelle Client ${CLIENT_NAME}..."
  curl -X POST "${KEYCLOAK_URL}/admin/realms/${NEW_REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "'"${CLIENT_NAME}"'",
      "enabled": true,
      "publicClient": true,
      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": false,
      "serviceAccountsEnabled": false,
      "implicitFlowEnabled": false,
      "attributes": {
        "pkce.code.challenge.method": "S256"
      },
      "redirectUris": ["https://cloud-wallet.xfsc.dev/*","http://localhost:3000/*"],
      "webOrigins": ["https://cloud-wallet.xfsc.dev","*"]
    }'
  echo "Client ${CLIENT_NAME} wurde erfolgreich erstellt."
fi