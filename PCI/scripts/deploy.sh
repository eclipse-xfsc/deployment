#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
MODE="${PCI_OBSERVABILITY_MODE:-managed}"
[[ "$MODE" == managed || "$MODE" == external ]] || { echo 'Invalid PCI_OBSERVABILITY_MODE' >&2; exit 2; }
G0_ARGS=("$@")
# Existing externally managed telemetry may be selected explicitly. Otherwise
# this release supplies the instances required by SRS FR-55/56/57.
if [[ "$MODE" == external ]]; then
  bash ./dist/ground-zero.sh "${G0_ARGS[@]}"
  printf '{"event":"pci.deploy.phase","message":"Using operator-managed telemetry; verify its acceptance evidence"}\n'
  exit 0
fi
TELEMETRY_ARGS=()
while (($#)); do
  case "$1" in
    --kubeconfig|--context|--main-host) TELEMETRY_ARGS+=("$1" "$2"); shift 2;;
    --orce-namespace) TELEMETRY_ARGS+=(--namespace "$2"); shift 2;;
    --orce-deployment) TELEMETRY_ARGS+=(--deployment "$2"); shift 2;;
    --orce-container) TELEMETRY_ARGS+=(--container "$2"); shift 2;;
    --orce-base-path) TELEMETRY_ARGS+=(--base-path "$2"); shift 2;;
    --dry-run|-h|--help) bash ./dist/ground-zero.sh "${G0_ARGS[@]}"; exit 0;;
    *) shift;;
  esac
done
[[ " ${TELEMETRY_ARGS[*]} " == *' --context '* ]] || { echo '--context is required for managed telemetry' >&2; exit 2; }
bash ./dist/ground-zero.sh "${G0_ARGS[@]}"
python3 scripts/deploy-observability.py "${TELEMETRY_ARGS[@]}"
