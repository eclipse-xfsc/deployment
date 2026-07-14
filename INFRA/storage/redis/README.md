# XFSC Redis OpenBao Helm Chart

This wrapper chart installs Bitnami Redis and provisions its credentials in
OpenBao.

## Flow

1. A `pre-install` Job runs with the existing Resource Provisioner
   ServiceAccount.
2. The OpenBao init image creates the configured KV-v2 mount if necessary.
3. It writes:
   - `redis-password` for Redis' default/admin user
   - `username` for the application ACL user
   - `password` for the application ACL user
4. ESO synchronizes the values into the Kubernetes Secret `redis-auth`.
5. Bitnami Redis starts with `auth.existingSecret=redis-auth`.
6. A `post-install` Job waits for Redis and creates the named ACL user.

The OpenBao init container generates credentials. The separate ACL Job creates
the actual named account inside Redis.

## Prerequisites

- OpenBao is available.
- Kubernetes Auth is configured in OpenBao.
- The namespace already contains the ServiceAccount configured in
  `openbaoInit.serviceAccountName`.
- That ServiceAccount is bound to the OpenBao role configured in
  `openbaoInit.role`.
- ESO is installed.
- The referenced `ClusterSecretStore` or `SecretStore` exists.
- Helm dependencies have been downloaded.

## Install

```shell
helm dependency update
```

```shell
helm upgrade --install redis \
  . \
  --namespace infrastructure \
  --create-namespace
```

## Important values

```yaml
openbaoInit:
  serviceAccountName: infrastructure-resource-provisioner
  address: http://openbao.security.svc.cluster.local:8200
  role: xfsc-infrastructure-resource-provisioner
  kv:
    mount: apps
    path: redis/infrastructure

externalSecret:
  store:
    name: apps
    kind: ClusterSecretStore
  target:
    name: redis-auth

redis:
  auth:
    existingSecret: redis-auth
    existingSecretPasswordKey: redis-password
```

`externalSecret.target.name` and `redis.auth.existingSecret` must be identical.

## OpenBao result

With `KV_MOUNT=apps` and `KV_SECRET_PATH=redis/infrastructure`, the secret is
stored at:

```text
apps/redis/infrastructure
```

It contains:

```json
{
  "redis-password": "<generated>",
  "username": "application",
  "password": "<generated>"
}
```

## Redis ACL permissions

The default example grants:

```text
~*
+@all
```

Restrict this in production:

```yaml
redisAcl:
  keyPattern: "~application:*"
  commands:
    - "+get"
    - "+set"
    - "+del"
    - "+expire"
    - "+ping"
```

## Upgrade behavior

The OpenBao Job is intentionally only a `pre-install` hook. This prevents
`$RANDOM_64` from rotating credentials on every Helm upgrade.

The ACL Job runs on install and upgrade, so it re-applies the desired ACL
configuration using the existing synchronized credentials.

To rotate credentials, update the OpenBao secret through a dedicated rotation
process and restart/reconcile the affected workloads deliberately.

## Verify

```shell
kubectl get externalsecret,secret -n infrastructure
```

```shell
kubectl get pods -n infrastructure
```

```shell
kubectl logs -n infrastructure job/redis-acl-provision
```

The actual Job name is prefixed with the Helm release name.
