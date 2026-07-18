#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONTROL_IP="$(terraform output -raw first_control_plane_ipv4)"
API_IP="$(terraform output -raw load_balancer_ipv4)"
KEY_FILE="$(terraform output -raw ssh_private_key_file)"
KEY_FILE="${KEY_FILE/#\~/$HOME}"
OUTPUT_FILE="${1:-$ROOT_DIR/kubeconfig.yaml}"

if [[ -z "$CONTROL_IP" || "$CONTROL_IP" == "null" ]]; then
  echo "No public control-plane IPv4 is available. Set enable_node_public_ipv4=true or retrieve kubeconfig through a bastion/VPN." >&2
  exit 1
fi

for _ in $(seq 1 60); do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "$KEY_FILE" "root@$CONTROL_IP" test -s /etc/rancher/k3s/k3s.yaml 2>/dev/null; then
    break
  fi
  sleep 5
done

ssh -o StrictHostKeyChecking=accept-new -i "$KEY_FILE" "root@$CONTROL_IP" sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed "s#https://127.0.0.1:6443#https://${API_IP}:6443#" > "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE"
echo "Kubeconfig written to $OUTPUT_FILE"
echo "Use it with: export KUBECONFIG=$OUTPUT_FILE"
