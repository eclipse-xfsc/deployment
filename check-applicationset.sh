#!/usr/bin/env bash

set -euo pipefail

APPSET_NAME="${1:?Usage: $0 <applicationset-name> [namespace]}"
NAMESPACE="${2:-argocd}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"

START_TIME="$(date +%s)"

while true; do
  applications="$(
    kubectl get applications.argoproj.io \
      --namespace "$NAMESPACE" \
      --output json
  )"

  appset_applications="$(
    jq \
      --arg appset "$APPSET_NAME" '
        [
          .items[]
          | select(
              any(
                .metadata.ownerReferences[]?;
                .kind == "ApplicationSet"
                and .name == $appset
                and .controller == true
              )
            )
        ]
      ' <<< "$applications"
  )"

  count="$(jq 'length' <<< "$appset_applications")"

  if [[ "$count" -eq 0 ]]; then
    echo "Noch keine Applications für ApplicationSet '${APPSET_NAME}' gefunden."
  else
    not_ready="$(
      jq -r '
        .[]
        | select(
            .status.sync.status != "Synced"
            or .status.health.status != "Healthy"
          )
        | [
            .metadata.name,
            "sync=" + (.status.sync.status // "Unknown"),
            "health=" + (.status.health.status // "Unknown"),
            "operation=" + (.status.operationState.phase // "Unknown")
          ]
        | join(" ")
      ' <<< "$appset_applications"
    )"

    if [[ -z "$not_ready" ]]; then
      echo "Erfolgreich: Alle ${count} Applications von '${APPSET_NAME}' sind Synced und Healthy."
      exit 0
    fi

    echo "Noch nicht bereit:"
    printf '%s\n' "$not_ready"
  fi

  elapsed=$(( $(date +%s) - START_TIME ))

  if (( elapsed >= TIMEOUT_SECONDS )); then
    echo "Timeout nach ${TIMEOUT_SECONDS} Sekunden." >&2
    exit 1
  fi

  sleep "$INTERVAL_SECONDS"
done