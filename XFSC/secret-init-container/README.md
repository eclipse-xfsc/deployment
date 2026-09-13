# XFSC Secret Init Container

The XFSC OpenBao Init Container provisions secrets and optional Transit
resources in OpenBao before an application is installed or started.

The container authenticates with the Kubernetes `ServiceAccount` assigned to
its Pod. It obtains a short-lived OpenBao token through Kubernetes Auth and
uses that token only inside the running process.

No static OpenBao token is required or persisted.

## Features

- Authentication through OpenBao Kubernetes Auth
- Short-lived OpenBao tokens
- Automatic KV-v2 engine creation
- Existing engines are not modified or recreated
- Arbitrary key/value secret provisioning
- Random value generation
- UUID generation
- UTC timestamp generation
- Optional Transit engine creation
- Optional Transit key creation
- Idempotent engine and Transit-key provisioning
- No OpenBao token persistence
- No connection metadata stored inside application secrets

## Architecture

```text
Pod
  |
  +-- Kubernetes ServiceAccount token
          |
          v
      OpenBao Kubernetes Auth
          |
          v
      Short-lived OpenBao token
          |
          +-- Ensure KV-v2 engine
          +-- Write application secret
          +-- Optionally ensure Transit engines
          +-- Optionally ensure Transit keys
```

The short-lived OpenBao token exists only in the init process. It is not
written into the KV secret and is removed from the process environment during
cleanup.

## Workflow

```text
Start
  |
  v
Authenticate through Kubernetes Auth
  |
  v
Does the KV engine exist?
  |
  +-- No  --> Create KV-v2 engine
  |
  +-- Yes --> Leave the existing engine unchanged
  |
  v
Resolve generated values
  |
  v
Write the KV secret
  |
  v
Process optional Transit definitions
  |
  v
Done
```

## Required OpenBao permissions

The ServiceAccount's OpenBao policy must allow the operations requested by the
container.

A broad Resource Provisioner policy can look like this:

```hcl
path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/mounts/*" {
  capabilities = [
    "create",
    "read",
    "update",
    "delete",
    "list",
    "sudo"
  ]
}

path "+/data/*" {
  capabilities = [
    "create",
    "read",
    "update",
    "delete",
    "list"
  ]
}

path "+/metadata/*" {
  capabilities = [
    "create",
    "read",
    "update",
    "delete",
    "list"
  ]
}

path "+/delete/*" {
  capabilities = ["update"]
}

path "+/undelete/*" {
  capabilities = ["update"]
}

path "+/destroy/*" {
  capabilities = ["update"]
}

path "+/keys" {
  capabilities = ["read", "list"]
}

path "+/keys/*" {
  capabilities = [
    "create",
    "read",
    "update",
    "delete",
    "list"
  ]
}

path "+/encrypt/*" {
  capabilities = ["update"]
}

path "+/decrypt/*" {
  capabilities = ["update"]
}

path "+/rewrap/*" {
  capabilities = ["update"]
}

path "+/sign/*" {
  capabilities = ["update"]
}

path "+/verify/*" {
  capabilities = ["update"]
}

path "+/hmac/*" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

The exact policy should be reduced when a workload only needs access to a
specific mount or secret path.

## Environment variables

| Variable | Required | Default | Description |
|---|---:|---|---|
| `OPENBAO_ADDR` | yes | — | Internal OpenBao service address |
| `OPENBAO_ROLE` | yes | — | OpenBao Kubernetes Auth role |
| `OPENBAO_AUTH_PATH` | no | `kubernetes` | Kubernetes Auth mount path |
| `KV_MOUNT` | yes | — | KV-v2 engine mount path |
| `KV_SECRET_PATH` | yes | — | Secret path inside the KV-v2 engine |
| `SECRET_VALUES` | yes | — | Multiline list of `KEY=VALUE` entries |
| `TRANSIT_ENGINES` | no | empty | Multiline Transit engine and key definitions |
| `DEFAULT_TRANSIT_KEY_TYPE` | no | `aes256-gcm96` | Default type for Transit keys without an explicit type |
| `SERVICE_ACCOUNT_TOKEN_FILE` | no | `/var/run/secrets/kubernetes.io/serviceaccount/token` | Kubernetes ServiceAccount token path |

`OPENBAO_ADDR` is required for the connection but is not written into the
application secret.

The OpenBao token obtained during login is never accepted as an input
variable and is never persisted.

## Secret values

`SECRET_VALUES` contains one `KEY=VALUE` entry per line.

Example:

```text
USERNAME=application
PASSWORD=$RANDOM_64
HOST=redis-master
PORT=6379
CLIENT_ID=$UUID
CREATED_AT=$TIMESTAMP
```

Empty lines and lines beginning with `#` are ignored.

Values may contain additional `=` characters because only the first `=`
separates the key from the value.

Example:

```text
CONNECTION_OPTIONS=ssl=true&timeout=30
```

## Generated-value markers

The complete value must match one of the supported markers.

| Marker | Result |
|---|---|
| `$RANDOM` | 48-character URL-safe random string |
| `$RANDOM_16` | 16-character URL-safe random string |
| `$RANDOM_32` | 32-character URL-safe random string |
| `$RANDOM_64` | 64-character URL-safe random string |
| `$RANDOM_HEX` | 64 hexadecimal characters |
| `$RANDOM_HEX_16` | 16 hexadecimal characters |
| `$RANDOM_HEX_32` | 32 hexadecimal characters |
| `$UUID` | UUID version 4 |
| `$TIMESTAMP` | Current UTC timestamp |

Examples:

```text
PASSWORD=$RANDOM_64
API_KEY=$RANDOM_HEX
CLIENT_ID=$UUID
CREATED_AT=$TIMESTAMP
```

The following value is treated as a literal string because the marker is not
the complete value:

```text
PREFIX=$RANDOM-suffix
```

## KV-v2 engine behavior

KV-v2 is always the default engine.

Given:

```text
KV_MOUNT=apps
KV_SECRET_PATH=redis/application
```

the container checks whether the following mount exists:

```text
apps/
```

If it does not exist, the container creates it as KV-v2:

```shell
bao secrets enable -path=apps kv-v2
```

If it already exists, the container does not modify or recreate it. It
continues directly with writing the requested secret.

The logical secret path is:

```text
apps/redis/application
```

The corresponding KV-v2 API path is:

```text
apps/data/redis/application
```

## Stored secret content

Given:

```text
SECRET_VALUES=
USERNAME=application
PASSWORD=$RANDOM_64
HOST=redis-master
PORT=6379
```

the stored secret contains only the supplied application values:

```json
{
  "USERNAME": "application",
  "PASSWORD": "<generated value>",
  "HOST": "redis-master",
  "PORT": "6379"
}
```

The secret does not contain:

- the OpenBao address
- the OpenBao mount name
- the authentication role
- the authentication path
- the Kubernetes ServiceAccount token
- the short-lived OpenBao token

## Transit engines

Transit provisioning is optional.

Each non-empty line in `TRANSIT_ENGINES` has this format:

```text
mount:key[:type],key2[:type]
```

Examples:

```text
application-transit:encryption-key
```

```text
application-transit:encryption-key:aes256-gcm96
```

```text
application-transit:encryption-key:aes256-gcm96,signing-key:ed25519
```

Multiple Transit engines can be supplied:

```text
application-transit:encryption-key:aes256-gcm96
identity-transit:signing-key:ed25519
```

When the Transit engine already exists, it is not recreated.

When a Transit key already exists, it is not changed.

## Dockerfile

A compatible image can be built with the following Dockerfile:

```dockerfile
FROM openbao/openbao:2.5

USER root

RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      jq \
      openssl \
      util-linux \
    && mkdir -p /opt/xfsc/bin \
    && chown -R 65532:65532 /opt/xfsc

COPY openbao-init.sh /opt/xfsc/bin/openbao-init.sh

RUN chmod 0755 /opt/xfsc/bin/openbao-init.sh

USER 65532:65532

ENTRYPOINT ["/opt/xfsc/bin/openbao-init.sh"]
```

Build and push:

```shell
docker build \
  --tag registry.example.org/xfsc/openbao-init:0.1.0 \
  .
```

```shell
docker push \
  registry.example.org/xfsc/openbao-init:0.1.0
```

## Kubernetes Job example

Using a separate Job is recommended because only the Job receives the
Resource Provisioner ServiceAccount.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: redis-openbao-init
  namespace: infrastructure
spec:
  backoffLimit: 3

  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis-openbao-init

    spec:
      restartPolicy: OnFailure
      serviceAccountName: infrastructure-resource-provisioner

      containers:
        - name: openbao-init
          image: registry.example.org/xfsc/openbao-init:0.1.0
          imagePullPolicy: IfNotPresent

          env:
            - name: OPENBAO_ADDR
              value: http://openbao.security.svc.cluster.local:8200

            - name: OPENBAO_ROLE
              value: xfsc-infrastructure-resource-provisioner

            - name: OPENBAO_AUTH_PATH
              value: kubernetes

            - name: KV_MOUNT
              value: apps

            - name: KV_SECRET_PATH
              value: redis/application

            - name: SECRET_VALUES
              value: |
                USERNAME=application
                PASSWORD=$RANDOM_64
                HOST=redis-master
                PORT=6379

            - name: TRANSIT_ENGINES
              value: |
                application-transit:encryption-key:aes256-gcm96
                identity-transit:signing-key:ed25519

          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532

          volumeMounts:
            - name: temporary-files
              mountPath: /tmp

      volumes:
        - name: temporary-files
          emptyDir: {}
```

## Helm values example

Markers should be enclosed in single quotes in YAML so they remain literal
until the init container processes them.

```yaml
openbaoInit:
  enabled: true

  image:
    repository: registry.example.org/xfsc/openbao-init
    tag: 0.1.0
    pullPolicy: IfNotPresent

  serviceAccountName: infrastructure-resource-provisioner

  address: http://openbao.security.svc.cluster.local:8200
  authPath: kubernetes
  role: xfsc-infrastructure-resource-provisioner

  kv:
    mount: apps
    path: redis/application

  values:
    USERNAME: application
    PASSWORD: '$RANDOM_64'
    HOST: redis-master
    PORT: "6379"
    CLIENT_ID: '$UUID'
    CREATED_AT: '$TIMESTAMP'

  transit:
    enabled: true

    engines:
      - mount: application-transit
        keys:
          - name: encryption-key
            type: aes256-gcm96

          - name: signing-key
            type: ed25519
```

## Helm Job template

```yaml
{{- if .Values.openbaoInit.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-openbao-init
  namespace: {{ .Release.Namespace }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-20"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded

spec:
  backoffLimit: 3

  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Release.Name }}-openbao-init
        app.kubernetes.io/instance: {{ .Release.Name }}

    spec:
      restartPolicy: OnFailure
      serviceAccountName: {{ .Values.openbaoInit.serviceAccountName }}

      containers:
        - name: openbao-init
          image: "{{ .Values.openbaoInit.image.repository }}:{{ .Values.openbaoInit.image.tag }}"
          imagePullPolicy: {{ .Values.openbaoInit.image.pullPolicy }}

          env:
            - name: OPENBAO_ADDR
              value: {{ .Values.openbaoInit.address | quote }}

            - name: OPENBAO_ROLE
              value: {{ .Values.openbaoInit.role | quote }}

            - name: OPENBAO_AUTH_PATH
              value: {{ .Values.openbaoInit.authPath | quote }}

            - name: KV_MOUNT
              value: {{ .Values.openbaoInit.kv.mount | quote }}

            - name: KV_SECRET_PATH
              value: {{ .Values.openbaoInit.kv.path | quote }}

            - name: SECRET_VALUES
              value: |
                {{- range $name, $value := .Values.openbaoInit.values }}
                {{ $name }}={{ $value }}
                {{- end }}

            - name: TRANSIT_ENGINES
              value: |
                {{- if .Values.openbaoInit.transit.enabled }}
                {{- range .Values.openbaoInit.transit.engines }}
                {{ .mount }}:{{- range $index, $key := .keys }}{{ if $index }},{{ end }}{{ $key.name }}:{{ default "aes256-gcm96" $key.type }}{{- end }}
                {{- end }}
                {{- end }}

          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532

          volumeMounts:
            - name: temporary-files
              mountPath: /tmp

      volumes:
        - name: temporary-files
          emptyDir: {}
{{- end }}
```

## Init container example

An init container uses the ServiceAccount assigned to the entire Pod.

This means the main application container also runs under the same Kubernetes
ServiceAccount identity. For privileged Resource Provisioner permissions, a
separate Job is usually safer.

```yaml
spec:
  serviceAccountName: infrastructure-resource-provisioner

  initContainers:
    - name: openbao-init
      image: registry.example.org/xfsc/openbao-init:0.1.0

      env:
        - name: OPENBAO_ADDR
          value: http://openbao.security.svc.cluster.local:8200

        - name: OPENBAO_ROLE
          value: xfsc-infrastructure-resource-provisioner

        - name: KV_MOUNT
          value: apps

        - name: KV_SECRET_PATH
          value: redis/application

        - name: SECRET_VALUES
          value: |
            USERNAME=application
            PASSWORD=$RANDOM_64
            HOST=redis-master
            PORT=6379

      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532

      volumeMounts:
        - name: temporary-files
          mountPath: /tmp

  containers:
    - name: application
      image: registry.example.org/application:latest

  volumes:
    - name: temporary-files
      emptyDir: {}
```

## External Secrets Operator example

Assume the `ClusterSecretStore` points to the `apps` KV-v2 mount.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: redis-credentials
  namespace: infrastructure

spec:
  refreshInterval: 15m

  secretStoreRef:
    name: apps
    kind: ClusterSecretStore

  target:
    name: redis-credentials
    creationPolicy: Owner

  dataFrom:
    - extract:
        key: redis/application
```

ESO then creates a Kubernetes Secret containing:

```text
USERNAME
PASSWORD
HOST
PORT
```

## Idempotency

Repeated executions behave as follows:

- an existing KV engine is not recreated
- an existing Transit engine is not recreated
- an existing Transit key is not modified
- the KV secret is written on every successful run
- generated markers are resolved again on every run

The final point is important.

Given:

```text
PASSWORD=$RANDOM_64
```

each execution produces a new password and updates the OpenBao secret.

For stable credentials, use one of these patterns:

1. Run the Job only during initial installation.
2. Do not include `pre-upgrade` in the Helm hook.
3. Read and reuse the existing secret before generating a new value.
4. Implement explicit credential rotation as a separate operation.

A bootstrap-only Helm hook can use:

```yaml
annotations:
  helm.sh/hook: pre-install
```

## Security recommendations

- Use a dedicated ServiceAccount for the provisioning Job.
- Do not assign the provisioning ServiceAccount to long-running application
  Pods unless necessary.
- Use short OpenBao token TTLs.
- Do not store OpenBao tokens in KV or Kubernetes Secrets.
- Restrict policies to the required mounts and paths where practical.
- Prefer a separate Job over an init container for highly privileged
  provisioning.
- Use immutable image tags instead of `latest`.
- Run the image as a non-root user.
- Use a read-only root filesystem.
- Mount an `emptyDir` volume at `/tmp`.


