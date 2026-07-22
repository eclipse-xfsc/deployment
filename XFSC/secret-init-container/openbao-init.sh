#!/usr/bin/env bash

set -Eeuo pipefail

log() {
  printf '[openbao-init] %s\n' "$*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    fail "Required environment variable ${name} is missing."
  fi
}

normalize_path() {
  local value="$1"

  value="${value#/}"
  value="${value%/}"

  if [[ -z "$value" ]]; then
    fail "Path must not be empty."
  fi

  if [[ "$value" == *".."* ]]; then
    fail "Path must not contain '..': ${value}"
  fi

  if [[ "$value" =~ [[:space:]] ]]; then
    fail "Path must not contain whitespace: ${value}"
  fi

  printf '%s' "$value"
}

validate_secret_key() {
  local key="$1"

  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]
}

validate_positive_number() {
  local value="$1"

  [[ "$value" =~ ^[0-9]+$ ]] && ((value > 0))
}

validate_env_name() {
  local name="$1"

  [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

generate_random() {
  local length="${1:-48}"
  local random_value

  validate_positive_number "$length" \
    || fail "Random length must be a positive integer: ${length}"

  random_value="$(
    openssl rand -base64 "$((length * 2))" \
      | tr -dc 'A-Za-z0-9_.-'
  )"

  if ((${#random_value} < length)); then
    fail "Could not generate a random value with ${length} characters."
  fi

  printf '%s' "${random_value:0:length}"
}

generate_hex() {
  local length="${1:-64}"
  local byte_count
  local random_value

  validate_positive_number "$length" \
    || fail "Hex length must be a positive integer: ${length}"

  byte_count="$(((length + 1) / 2))"
  random_value="$(openssl rand -hex "$byte_count")"

  printf '%s' "${random_value:0:length}"
}

resolve_value() {
  local value="$1"

  case "$value" in
    '$RANDOM')
      generate_random 48
      ;;

    '$RANDOM_16')
      generate_random 16
      ;;

    '$RANDOM_32')
      generate_random 32
      ;;

    '$RANDOM_64')
      generate_random 64
      ;;

    '$RANDOM_HEX')
      generate_hex 64
      ;;

    '$RANDOM_HEX_16')
      generate_hex 16
      ;;

    '$RANDOM_HEX_32')
      generate_hex 32
      ;;

    '$UUID')
      uuidgen
      ;;

    '$TIMESTAMP')
      date -u '+%Y-%m-%dT%H:%M:%SZ'
      ;;

    *)
      printf '%s' "$value"
      ;;
  esac
}

openbao_login() {
  local kubernetes_token

  if [[ ! -r "$SERVICE_ACCOUNT_TOKEN_FILE" ]]; then
    fail "ServiceAccount token is not readable: ${SERVICE_ACCOUNT_TOKEN_FILE}"
  fi

  kubernetes_token="$(cat "$SERVICE_ACCOUNT_TOKEN_FILE")"

  if [[ -z "$kubernetes_token" ]]; then
    fail "ServiceAccount token is empty."
  fi

  log "Authenticating with OpenBao Kubernetes role ${OPENBAO_ROLE}..."

  OPENBAO_TOKEN="$(
    bao write \
      -field=token \
      "auth/${OPENBAO_AUTH_PATH}/login" \
      role="$OPENBAO_ROLE" \
      jwt="$kubernetes_token"
  )"

  if [[ -z "$OPENBAO_TOKEN" ]]; then
    fail "OpenBao login returned no token."
  fi

  # The token exists only in this process and is never written into KV.
  export BAO_ADDR="$OPENBAO_ADDR"
  export BAO_TOKEN="$OPENBAO_TOKEN"
}

engine_exists() {
  local mount_path="$1"

  bao secrets list -format=json \
    | jq -e \
        --arg mount "${mount_path}/" \
        'has($mount)' \
    >/dev/null
}

ensure_kv_engine() {
  if engine_exists "$KV_MOUNT"; then
    log "Engine ${KV_MOUNT} already exists."
    log "Skipping engine creation and writing only the secret."
    return 0
  fi

  log "Creating KV-v2 engine ${KV_MOUNT}..."

  bao secrets enable \
    -path="$KV_MOUNT" \
    kv-v2
}

ensure_transit_engine() {
  local mount_path="$1"

  if engine_exists "$mount_path"; then
    log "Transit engine ${mount_path} already exists."
    return 0
  fi

  log "Creating Transit engine ${mount_path}..."

  bao secrets enable \
    -path="$mount_path" \
    transit
}

ensure_transit_key() {
  local mount_path="$1"
  local key_name="$2"
  local key_type="$3"

  if bao read "${mount_path}/keys/${key_name}" >/dev/null 2>&1; then
    log "Transit key ${mount_path}/${key_name} already exists."
    return 0
  fi

  log "Creating Transit key ${mount_path}/${key_name} with type ${key_type}..."

  bao write \
    "${mount_path}/keys/${key_name}" \
    type="$key_type" \
    >/dev/null
}

build_secret_json() {
  local input="$1"
  local result='{}'
  local line
  local key
  local raw_value
  local source_value
  local resolved_value

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Leere Zeilen ignorieren.
    [[ -z "$line" ]] && continue

    # Kommentare ignorieren.
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" != *=* ]]; then
      fail "Invalid SECRET_VALUES entry; expected KEY=VALUE_OR_ENV_NAME: ${line}"
    fi

    key="${line%%=*}"
    raw_value="${line#*=}"

    # Nur Leerzeichen um Key und Referenz entfernen.
    # Leerzeichen innerhalb des aufgelösten Secret-Werts bleiben erhalten.
    key="$(
      printf '%s' "$key" \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
    )"

    raw_value="$(
      printf '%s' "$raw_value" \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
    )"

    if ! validate_secret_key "$key"; then
      fail "Invalid secret key: ${key}"
    fi

    if [[ -z "$raw_value" ]]; then
      fail "Secret value or environment reference is empty for key: ${key}"
    fi

    # Falls die rechte Seite ein gültiger Name einer existierenden
    # Umgebungsvariable ist, wird deren Wert verwendet.
    #
    # Beispiel:
    #
    #   ca.crt=CA_CRT
    #
    # liest den Wert aus der Environment-Variable CA_CRT.
    #
    # Existiert keine solche Variable, wird die rechte Seite weiterhin
    # als Literal behandelt. Dadurch bleibt die bisherige Syntax kompatibel.
    if validate_env_name "$raw_value" && [[ -v "$raw_value" ]]; then
      source_value="${!raw_value}"

      log "Resolving secret key ${key} from environment variable ${raw_value}."
    else
      source_value="$raw_value"

      log "Resolving secret key ${key} from literal value."
    fi

    # Unterstützt weiterhin $RANDOM, $UUID, $TIMESTAMP usw.
    resolved_value="$(resolve_value "$source_value")"

    result="$(
      jq \
        --arg key "$key" \
        --arg value "$resolved_value" \
        '. + {($key): $value}' \
        <<<"$result"
    )"
  done <<<"$input"

  printf '%s' "$result"
}

write_kv_secret() {
  local secret_json="$1"
  local temporary_file="/tmp/openbao-secret.json"

  if [[ "$(jq 'length' <<<"$secret_json")" -eq 0 ]]; then
    fail "SECRET_VALUES does not contain any values."
  fi

  # Nur das eigentliche Secret-Objekt schreiben.
  # Kein zusätzlicher {"data": ...}-Wrapper für bao kv put/patch.
  printf '%s' "$secret_json" | jq '.' >"$temporary_file"

  if bao kv get \
    -mount="$KV_MOUNT" \
    "$KV_SECRET_PATH" \
    >/dev/null 2>&1; then

    log "Secret ${KV_MOUNT}/${KV_SECRET_PATH} exists. Patching..."

    bao kv patch \
      -mount="$KV_MOUNT" \
      "$KV_SECRET_PATH" \
      "@${temporary_file}" \
      >/dev/null
  else
    log "Secret ${KV_MOUNT}/${KV_SECRET_PATH} does not exist. Creating..."

    bao kv put \
      -mount="$KV_MOUNT" \
      "$KV_SECRET_PATH" \
      "@${temporary_file}" \
      >/dev/null
  fi

  rm -f "$temporary_file"

  log "Secret successfully written."
}

process_transit_engines() {
  local definitions="${TRANSIT_ENGINES:-}"
  local definition
  local mount_path
  local key_definitions
  local key_definition
  local key_name
  local key_type

  if [[ -z "$definitions" ]]; then
    return 0
  fi

  while IFS= read -r definition || [[ -n "$definition" ]]; do
    [[ -z "$definition" ]] && continue
    [[ "$definition" =~ ^[[:space:]]*# ]] && continue

    # Supported format:
    #
    # mount:key[:type],key2[:type]
    #
    # Examples:
    #
    # application-transit:encryption-key
    # application-transit:encryption-key:aes256-gcm96
    # application-transit:encryption-key:aes256-gcm96,signing-key:ed25519

    if [[ "$definition" != *:* ]]; then
      fail "Invalid Transit definition; expected mount:key[:type]: ${definition}"
    fi

    mount_path="${definition%%:*}"
    key_definitions="${definition#*:}"

    mount_path="$(normalize_path "$mount_path")"

    if [[ -z "$key_definitions" ]]; then
      fail "Transit definition requires at least one key: ${definition}"
    fi

    ensure_transit_engine "$mount_path"

    IFS=',' read -ra transit_keys <<<"$key_definitions"

    for key_definition in "${transit_keys[@]}"; do
      if [[ -z "$key_definition" ]]; then
        fail "Empty Transit key definition in: ${definition}"
      fi

      key_name="${key_definition%%:*}"

      if [[ "$key_definition" == *:* ]]; then
        key_type="${key_definition#*:}"
      else
        key_type="$DEFAULT_TRANSIT_KEY_TYPE"
      fi

      if [[ -z "$key_name" ]]; then
        fail "Transit key name must not be empty: ${definition}"
      fi

      if [[ -z "$key_type" ]]; then
        fail "Transit key type must not be empty: ${definition}"
      fi

      ensure_transit_key \
        "$mount_path" \
        "$key_name" \
        "$key_type"
    done
  done <<<"$definitions"
}

cleanup() {
  unset OPENBAO_TOKEN || true
  unset BAO_TOKEN || true

  rm -f /tmp/openbao-secret.json
}

main() {
  trap cleanup EXIT

  require_env OPENBAO_ADDR
  require_env OPENBAO_ROLE
  require_env KV_MOUNT
  require_env KV_SECRET_PATH

  OPENBAO_AUTH_PATH="${OPENBAO_AUTH_PATH:-kubernetes}"

  SERVICE_ACCOUNT_TOKEN_FILE="${SERVICE_ACCOUNT_TOKEN_FILE:-/var/run/secrets/kubernetes.io/serviceaccount/token}"

  DEFAULT_TRANSIT_KEY_TYPE="${DEFAULT_TRANSIT_KEY_TYPE:-aes256-gcm96}"

  SECRET_VALUES="${SECRET_VALUES:-}"

  KV_MOUNT="$(normalize_path "$KV_MOUNT")"
  KV_SECRET_PATH="$(normalize_path "$KV_SECRET_PATH")"

  export BAO_ADDR="$OPENBAO_ADDR"

  openbao_login

  # KV-v2 is always the default engine.
  #
  # If the engine already exists, it is not changed or recreated.
  # Only the requested secret is written.
  ensure_kv_engine

  secret_json="$(build_secret_json "$SECRET_VALUES")"

  write_kv_secret "$secret_json"

  # Transit engines are optional and are processed only when
  # TRANSIT_ENGINES contains at least one definition.
  process_transit_engines

  log "Provisioning completed."
  log "Secret path: ${KV_MOUNT}/${KV_SECRET_PATH}"
}

main "$@"