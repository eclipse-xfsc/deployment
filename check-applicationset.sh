#!/usr/bin/env bash

set -euo pipefail

APPSET_NAME="${1:?Usage: $0 <applicationset-name> [namespace]}"
NAMESPACE="${2:-argocd}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
REFRESH_TYPE="${REFRESH_TYPE:-normal}"

START_TIME="$(date +%s)"
REFRESHED_APPLICATIONS_FILE="$(mktemp)"

cleanup() {
  rm -f "$REFRESHED_APPLICATIONS_FILE"
}
trap cleanup EXIT

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
    degraded_applications="$(
      jq -r '
        .[]
        | select(
            (.status.health.status // "Unknown") == "Degraded"
            and (.status.sync.status // "Unknown") == "Synced"
            and (.status.operationState.phase // "Unknown") == "Succeeded"
          )
        | .metadata.name
      ' <<< "$appset_applications"
    )"

    while IFS= read -r application_name; do
      [[ -z "$application_name" ]] && continue

      if grep -Fxq "$application_name" "$REFRESHED_APPLICATIONS_FILE"; then
        echo "Refresh für '${application_name}' wurde bereits ausgelöst."
        continue
      fi

      echo "Application '${application_name}' ist Degraded, aber Synced und die Operation war erfolgreich."
      echo "Löse ${REFRESH_TYPE}-Refresh aus ..."

      if kubectl annotate application.argoproj.io "$application_name" \
        --namespace "$NAMESPACE" \
        "argocd.argoproj.io/refresh=${REFRESH_TYPE}" \
        --overwrite
      then
        printf '%s\n' "$application_name" >> "$REFRESHED_APPLICATIONS_FILE"
        echo "Refresh für '${application_name}' wurde ausgelöst."
      else
        echo "Refresh für '${application_name}' konnte nicht ausgelöst werden." >&2
      fi
    done <<< "$degraded_applications"

    not_ready="$(
      jq -r '
        .[]
        | select(
            (.status.sync.status // "Unknown") != "Synced"
            or (.status.health.status // "Unknown") != "Healthy"
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
