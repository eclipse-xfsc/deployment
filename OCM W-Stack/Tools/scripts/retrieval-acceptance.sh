#!/usr/bin/env bash
set -euo pipefail

NATS_URL="${NATS_URL:-nats://localhost:4222}"
NATS_SUBJECT="${NATS_SUBJECT:-offering}"

TENANT_ID="${TENANT_ID:-demo_tenant}"
GROUP_ID="${GROUP_ID:-test}"

HOLDER_KEY="${HOLDER_KEY:-eckey}"
HOLDER_NAMESPACE="${HOLDER_NAMESPACE:-ocm-wstack}"
HOLDER_GROUP="${HOLDER_GROUP:-demo-tenant}"
TX_CODE="${TX_CODE:-}"

REQUEST_ID="${1:?Usage: $0 <requestId>}"

EVENT_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
EVENT_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

PAYLOAD=$(cat <<EOF
{
  "specversion": "1.0",
  "id": "${EVENT_ID}",
  "source": "urn:xfsc:credential-retrieval:test-client",
  "type": "retrieval.offering.acceptance",
  "datacontenttype": "application/json",
  "time": "${EVENT_TIME}",
  "data": {
    "tenant_Id": "${TENANT_ID}",
    "group_Id": "${GROUP_ID}",
    "request_Id": "${REQUEST_ID}",
    "result": true,
    "holderKey": "${HOLDER_KEY}",
    "holderNamespace": "${HOLDER_NAMESPACE}",
    "holderGroup": "${HOLDER_GROUP}",
    "tx_code": "${TX_CODE}"
  }
}
EOF
)

echo "========================================"
echo "Accept Offering"
echo "========================================"
echo "NATS URL:         ${NATS_URL}"
echo "NATS Subject:     ${NATS_SUBJECT}"
echo "Tenant ID:        ${TENANT_ID}"
echo "Group ID:         ${GROUP_ID}"
echo "Request ID:       ${REQUEST_ID}"
echo "Holder Key:       ${HOLDER_KEY}"
echo "Holder Namespace: ${HOLDER_NAMESPACE}"
echo "Holder Group:     ${HOLDER_GROUP}"
echo "Tx Code:          ${TX_CODE}"
echo "========================================"
echo
echo "${PAYLOAD}"
echo

nats request \
  --server "${NATS_URL}" \
  "${NATS_SUBJECT}" \
  "${PAYLOAD}"