#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONTROL_IP="$(terraform output -raw first_control_plane_ipv4)"

API_ENDPOINT="$(terraform output -raw kubernetes_api_endpoint)"
API_ENDPOINT="${API_ENDPOINT#https://}"

KEY_FILE="$ROOT_DIR/keys/id_xfsc"
OUTPUT_FILE="${1:-$ROOT_DIR/kubeconfig.yaml}"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Private key not found: $KEY_FILE" >&2
  exit 1
fi

if [[ -z "$CONTROL_IP" || "$CONTROL_IP" == "null" ]]; then
  echo "No public control-plane IPv4 is available." >&2
  exit 1
fi

echo "Waiting for K3s..."

ssh-keygen -R "$CONTROL_IP" >/dev/null 2>&1 || true

k3s_ready=false

for attempt in $(seq 1 60); do
  echo "Waiting for K3s... ($attempt/60)"

  if ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    -o BatchMode=yes \
    -i "$KEY_FILE" \
    "root@$CONTROL_IP" \
    'test -s /etc/rancher/k3s/k3s.yaml'
  then
    k3s_ready=true
    break
  fi

  sleep 5
done

if [ "$k3s_ready" != true ]; then
  echo "K3s did not become ready within 300 seconds." >&2

  ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    -o BatchMode=yes \
    -i "$KEY_FILE" \
    "root@$CONTROL_IP" \
    'systemctl status k3s --no-pager; journalctl -u k3s -n 100 --no-pager' \
    >&2 || true

  exit 1
fi

echo "K3s is ready."

ssh \
  -o StrictHostKeyChecking=accept-new \
  -i "$KEY_FILE" \
  "root@$CONTROL_IP" \
  sudo cat /etc/rancher/k3s/k3s.yaml \
| sed "s#https://127.0.0.1:6443#https://${API_ENDPOINT}#g" \
> "$OUTPUT_FILE"

chmod 600 "$OUTPUT_FILE"

echo
echo "Kubeconfig written to:"
echo "  $OUTPUT_FILE"
echo
echo "Run:"
echo "  export KUBECONFIG=$OUTPUT_FILE"