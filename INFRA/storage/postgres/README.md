# XFSC PostgreSQL CloudNativePG Chart

This chart replaces the Bitnami PostgreSQL dependency with a native CloudNativePG `Cluster` resource.

## Install the operator first

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

## What this chart creates

- namespaced `SecretStore/infrastructure`
- OpenBao pre-install Job
- `ExternalSecret` for the `postgres` superuser
- CloudNativePG `Cluster`
- XFSC `ResourceProvider` with connection data only

## OpenBao

Default mount: `infrastructure`

Default logical path for release `postgresql`:

```text
postgresql/postgresql
```

Stored data:

```json
{"username":"postgres","password":"<generated>"}
```

No application role or application database is created.

## Install

```bash
helm upgrade --install postgresql . --namespace infrastructure
```

## Services

CloudNativePG creates `postgresql-rw`, `postgresql-ro`, and `postgresql-r` services. The XFSC provider points to `postgresql-rw.infrastructure.svc.cluster.local:5432`.

## HA

```yaml
cluster:
  instances: 3
```

## Image

```yaml
cluster:
  imageName: ghcr.io/cloudnative-pg/postgresql:17.10-202606221003-system-bookworm
```

Pin by digest in production.
