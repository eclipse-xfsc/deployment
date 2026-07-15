# XFSC Redis OpsTree Chart

This chart replaces the Bitnami Redis dependency with the OpsTree Redis
Operator and compatible images from Quay.

## Prerequisite

Install `xfsc-redis-operator` first.

## What this chart creates

- namespaced `SecretStore/infrastructure`
- OpenBao pre-install Job
- `ExternalSecret` containing the Redis root password
- OpsTree `Redis` custom resource
- XFSC `ResourceProvider` with connection data only

## OpenBao

Default mount:

```text
infrastructure
```

Default path:

```text
redis/<release-name>
```

Stored data:

```json
{
  "password": "<generated>"
}
```

No application ACL user is created. Workload-specific users are created later
by the XFSC provisioner.

## Install

```bash
helm upgrade --install redis . --namespace infrastructure
```

## Image

```yaml
redis:
  image:
    repository: quay.io/opstree/redis
    tag: v8.6.2
```

The OpsTree image is compatible with the operator-generated bootstrap process.

## Test

```bash
kubectl run redis-auth-test   --rm -it   --restart=Never   --namespace infrastructure   --image=redis:8.2-alpine   --env="REDIS_PASSWORD=$(kubectl get secret redis-root-auth -n infrastructure -o jsonpath='{.data.password}' | base64 -d)"   -- sh -ec '
    REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h redis -p 6379 PING
  '
```

Adjust secret and service names when using a different Helm release name.

## Argo CD

Install the operator before this chart and enable:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```
