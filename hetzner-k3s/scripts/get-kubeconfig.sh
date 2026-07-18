#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONTROL_IP="$(terraform output -raw first_control_plane_ipv4)"

API_IP="$(terraform output -raw kubernetes_api_endpoint)"
API_IP="${API_IP#https://}"

KEY_FILE="${SSH_PRIVATE_KEY_FILE:-$HOME/.ssh/id_ed25519}"
OUTPUT_FILE="${1:-$ROOT_DIR/kubeconfig.yaml}"

if [[ -z "$CONTROL_IP" || "$CONTROL_IP" == "null" ]]; then
  echo "No public control-plane IPv4 is available." >&2
  exit 1
fi

echo "Waiting for K3s..."

for _ in $(seq 1 60); do
  if ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    -i "$KEY_FILE" \
    "root@$CONTROL_IP" \
    test -s /etc/rancher/k3s/k3s.yaml >/dev/null 2>&1
  then
    break
  fi

  sleep 5
done

ssh \
  -o StrictHostKeyChecking=accept-new \
  -i "$KEY_FILE" \
  "root@$CONTROL_IP" \
  sudo cat /etc/rancher/k3s/k3s.yaml \
| sed "s#https://127.0.0.1:6443#https://${API_IP}#g" \
> "$OUTPUT_FILE"

chmod 600 "$OUTPUT_FILE"

echo
echo "Kubeconfig written to:"
echo "  $OUTPUT_FILE"
echo
echo "Run:"
echo "  export KUBECONFIG=$OUTPUT_FILE"