#!/usr/bin/env bash
set -euo pipefail

OFFER_LINK="${1:?Usage: $0 '<offering-link>'}"

NATS_SERVER="${NATS_SERVER:-nats://localhost:4222}"
NATS_TOPIC="${NATS_TOPIC:-offering}"

TENANT_ID="${TENANT_ID:-demo_tenant}"
GROUP_ID="${GROUP_ID:-test}"
REQUEST_ID="${REQUEST_ID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"

DATA=$(jq -nc \
  --arg tenant "$TENANT_ID" \
  --arg request "$REQUEST_ID" \
  --arg group "$GROUP_ID" \
  --arg offer "$OFFER_LINK" \
  '{
    tenant_Id: $tenant,
    request_Id: $request,
    group_Id: $group,
    offer: {
      credential_offer: $offer
    }
  }')

EVENT=$(jq -nc \
  --arg id "$REQUEST_ID" \
  --argjson data "$DATA" \
  '{
    specversion: "1.0",
    id: $id,
    source: "credential-offer-shell",
    type: "retrieval.offering.external",
    datacontenttype: "application/json",
    data: $data
  }')

echo "Sending credential offering"
echo "  NATS:      $NATS_SERVER"
echo "  Topic:     $NATS_TOPIC"
echo "  RequestID: $REQUEST_ID"

nats \
  --server "$NATS_SERVER" \
  pub "$NATS_TOPIC" "$EVENT"

echo "Done."