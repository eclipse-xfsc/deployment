
#!/usr/bin/env bash
set -euo pipefail

APPSET_NAME="${1:?Usage: $0 <applicationset-name> [argocd-namespace]}"
ARGOCD_NAMESPACE="${2:-argocd}"

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
REFRESH_TYPE="${REFRESH_TYPE:-normal}"
KUBECTL_TIMEOUT="${KUBECTL_TIMEOUT:-15s}"

START_TIME="$(date +%s)"
REFRESH_COUNTER=0

# Benötigt: bash >= 3.2, kubectl, jq

kctl() {
  kubectl --request-timeout="$KUBECTL_TIMEOUT" "$@"
}

check_timeout() {
  local now elapsed

  now="$(date +%s)"
  elapsed=$((now - START_TIME))

  if (( elapsed >= TIMEOUT_SECONDS )); then
    echo "Timeout nach ${TIMEOUT_SECONDS} Sekunden." >&2
    exit 1
  fi
}

refresh_external_secrets() {
  local namespace="$1"
  local secrets count timestamp

  if [[ -z "$namespace" ]]; then
    echo "WARNUNG: Kein Ziel-Namespace angegeben."
    return 0
  fi

  if ! kctl get namespace "$namespace" >/dev/null 2>&1; then
    echo "Namespace '$namespace' existiert noch nicht."
    return 0
  fi

  if ! secrets="$(
    kctl get externalsecrets.external-secrets.io \
      -n "$namespace" \
      -o json 2>/dev/null
  )"; then
    echo "ExternalSecrets in '$namespace' nicht abrufbar."
    return 0
  fi

  count="$(printf '%s\n' "$secrets" | jq '.items | length')"

  if (( count == 0 )); then
    echo "Keine ExternalSecrets in '$namespace' gefunden."
    return 0
  fi

  REFRESH_COUNTER=$((REFRESH_COUNTER + 1))
  timestamp="$(date +%s)-${REFRESH_COUNTER}"

  echo "Aktualisiere $count ExternalSecret(s) in '$namespace' ..."

  if kctl annotate externalsecrets.external-secrets.io \
    --all \
    -n "$namespace" \
    "force-sync=$timestamp" \
    --overwrite
  then
    echo "ExternalSecrets-Refresh ausgelöst: $namespace"
  else
    echo "WARNUNG: ExternalSecrets-Refresh fehlgeschlagen: $namespace" >&2
  fi
}

refresh_application() {
  local name="$1"

  echo "Argo-CD-Refresh für '$name' ..."

  if kctl annotate applications.argoproj.io "$name" \
    -n "$ARGOCD_NAMESPACE" \
    "argocd.argoproj.io/refresh=$REFRESH_TYPE" \
    --overwrite
  then
    echo "Argo-CD-Refresh ausgelöst: $name"
  else
    echo "WARNUNG: Argo-CD-Refresh fehlgeschlagen: $name" >&2
  fi
}

echo "Warte auf ApplicationSet: $APPSET_NAME"
echo "Timeout: ${TIMEOUT_SECONDS}s"
echo "Intervall: ${INTERVAL_SECONDS}s"

while true; do
  check_timeout

  if ! applications="$(
    kctl get applications.argoproj.io \
      -n "$ARGOCD_NAMESPACE" \
      -o json
  )"; then
    echo "WARNUNG: Applications nicht abrufbar."
    check_timeout
    sleep "$INTERVAL_SECONDS"
    continue
  fi

  appset_applications="$(
    printf '%s\n' "$applications" |
      jq --arg appset "$APPSET_NAME" '
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
      '
  )"

  count="$(
    printf '%s\n' "$appset_applications" | jq 'length'
  )"

  if (( count == 0 )); then
    echo "Noch keine Applications für '$APPSET_NAME' gefunden."
    check_timeout
    sleep "$INTERVAL_SECONDS"
    continue
  fi

  not_ready="$(
    printf '%s\n' "$appset_applications" |
      jq -r '
        .[]
        | select(
            (.status.sync.status // "Unknown") != "Synced"
            or (.status.health.status // "Unknown") != "Healthy"
            or (
              (.status.operationState.phase // "Succeeded")
              != "Succeeded"
            )
          )
        | [
            .metadata.name,
            (.spec.destination.namespace // ""),
            (.status.sync.status // "Unknown"),
            (.status.health.status // "Unknown"),
            (.status.operationState.phase // "Unknown")
          ]
        | @tsv
      '
  )"

  if [[ -z "$not_ready" ]]; then
    echo "Erfolgreich: Alle $count Applications von '$APPSET_NAME' sind Synced und Healthy."
    exit 0
  fi

  echo "Noch nicht bereit:"

  # Bash-3.2-kompatibel: keine assoziativen Arrays.
  REFRESHED_NAMESPACES=" "

  while IFS="$(printf '\t')" read -r name namespace sync health operation; do
    [[ -z "$name" ]] && continue

    echo "  $name namespace=$namespace sync=$sync health=$health operation=$operation"

    # Jeden betroffenen Namespace pro Durchlauf nur einmal refreshen.
    if [[ -n "$namespace" && "$REFRESHED_NAMESPACES" != *" $namespace "* ]]; then
      refresh_external_secrets "$namespace"
      REFRESHED_NAMESPACES="${REFRESHED_NAMESPACES}${namespace} "
    fi

    # Bei jedem fehlerhaften Check Argo CD refreshen.
    refresh_application "$name"

  done <<EOF
$not_ready
EOF

  check_timeout
  sleep "$INTERVAL_SECONDS"
done
