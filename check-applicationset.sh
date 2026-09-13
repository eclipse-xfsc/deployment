#!/usr/bin/env bash

set -euo pipefail

APPSET_NAME="${1:?Usage: $0 <applicationset-name> [argocd-namespace]}"
ARGOCD_NAMESPACE="${2:-argocd}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
REFRESH_TYPE="${REFRESH_TYPE:-normal}"

START_TIME="$(date +%s)"

refresh_external_secrets() {
  local application_name="$1"
  local target_namespace="$2"
  local refresh_timestamp

  if [[ -z "$target_namespace" ]]; then
    echo "Application '${application_name}' besitzt keinen Ziel-Namespace."
    echo "ExternalSecrets werden nicht aktualisiert."
    return 0
  fi

  if ! kubectl api-resources \
    --api-group=external-secrets.io \
    --namespaced=true \
    --output=name |
    grep -qx "externalsecrets.external-secrets.io"
  then
    echo "ExternalSecret-CRD ist nicht verfügbar."
    return 0
  fi

  if ! kubectl get namespace "$target_namespace" >/dev/null 2>&1; then
    echo "Ziel-Namespace '${target_namespace}' existiert nicht."
    return 0
  fi

  refresh_timestamp="$(date +%s)"

  echo "Aktualisiere ExternalSecrets im Namespace '${target_namespace}' ..."

  external_secret_count="$(
    kubectl get externalsecrets.external-secrets.io \
      --namespace "$target_namespace" \
      --no-headers \
      2>/dev/null |
      wc -l |
      tr -d ' '
  )"

  if [[ "$external_secret_count" -eq 0 ]]; then
    echo "Keine ExternalSecrets im Namespace '${target_namespace}' gefunden."
    return 0
  fi

  if kubectl annotate externalsecrets.external-secrets.io \
    --all \
    --namespace "$target_namespace" \
    "force-sync=${refresh_timestamp}" \
    --overwrite
  then
    echo "${external_secret_count} ExternalSecret(s) im Namespace '${target_namespace}' wurden aktualisiert."
  else
    echo "ExternalSecrets im Namespace '${target_namespace}' konnten nicht aktualisiert werden." >&2
  fi
}

while true; do
  applications="$(
    kubectl get applications.argoproj.io \
      --namespace "$ARGOCD_NAMESPACE" \
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
    degraded_synced_applications="$(
      jq -r '
        .[]
        | select(
            (.status.health.status // "Unknown") == "Degraded"
            and (.status.sync.status // "Unknown") == "Synced"
          )
        | [
            .metadata.name,
            (.spec.destination.namespace // "")
          ]
        | @tsv
      ' <<< "$appset_applications"
    )"

    while IFS=$'\t' read -r application_name target_namespace; do
      [[ -z "$application_name" ]] && continue

      echo "Application '${application_name}' ist Degraded und Synced."

      refresh_external_secrets \
        "$application_name" \
        "$target_namespace"

      echo "Löse ${REFRESH_TYPE}-Refresh für Application '${application_name}' aus ..."

      if kubectl annotate application.argoproj.io "$application_name" \
        --namespace "$ARGOCD_NAMESPACE" \
        "argocd.argoproj.io/refresh=${REFRESH_TYPE}" \
        --overwrite
      then
        echo "Refresh für '${application_name}' wurde ausgelöst."
      else
        echo "Refresh für '${application_name}' konnte nicht ausgelöst werden." >&2
      fi
    done <<< "$degraded_synced_applications"

    not_ready="$(
      jq -r '
        .[]
        | select(
            (.status.sync.status // "Unknown") != "Synced"
            or (.status.health.status // "Unknown") != "Healthy"
          )
        | [
            .metadata.name,
            "namespace=" + (.spec.destination.namespace // "Unknown"),
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