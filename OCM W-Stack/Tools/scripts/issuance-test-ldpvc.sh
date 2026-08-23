#!/usr/bin/env bash
set -euo pipefail

BASE_URL=$1
echo $1
OFFERING_URL="${BASE_URL}/test/offering/create"
TOKEN_URL="${BASE_URL}/api/auth/token"
ISSUANCE_URL="${BASE_URL}/api/credential"

echo "==> Creating credential offering"

OFFER_RESPONSE="$(
curl -sS \
  -X POST \
  "${OFFERING_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id" : "demo_tenant",
    "identifier": "DeveloperCredential",
    "payload": {
      "given_name": "Ada",
      "family_name": "Lovelace"
    }
  }'
)"


echo "$OFFER_RESPONSE" | jq .

OFFER_URI="$(echo "$OFFER_RESPONSE" | jq -r '.offer.credential_offer')"

ENCODED_OFFER="$(
python3 - "$OFFER_URI" <<'PY'
import sys
import urllib.parse

url = sys.argv[1]
parsed = urllib.parse.urlparse(url)
params = urllib.parse.parse_qs(parsed.query)

print(params["credential_offer"][0])
PY
)"

echo
echo "Credential Offer:"
echo "$ENCODED_OFFER" | jq .

PRE_AUTH_CODE="$(
echo "$ENCODED_OFFER" |
jq -r '.grants["urn:ietf:params:oauth:grant-type:pre-authorized_code"]["pre-authorized_code"]'
)"

echo
echo "==> Requesting access token"

TOKEN_RESPONSE="$(
curl -sS \
  -X POST \
  "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code" \
  --data-urlencode "pre-authorized_code=${PRE_AUTH_CODE}"
)"

echo "$TOKEN_RESPONSE" | jq .

ACCESS_TOKEN="$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')"

echo
echo "==> Requesting credential"

curl -sS \
  -X POST \
  "${ISSUANCE_URL}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "format": "ldp_vc"
  }' 