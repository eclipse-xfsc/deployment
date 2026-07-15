# XFSC MinIO Tenant Chart

Uses the official `minio/tenant` chart and `quay.io/minio/minio`, not Bitnami.

Creates a namespaced OpenBao SecretStore, an ESO-generated `config.env`
Secret containing only root credentials, the official MinIO Tenant, and a
connection-only XFSC ResourceProvider.

Production defaults use 4 servers. For development only, set one server:

```yaml
tenant:
  tenant:
    pools:
      - name: pool-0
        servers: 1
        volumesPerServer: 1
        size: 10Gi
```

MinIO does not support in-place conversion from standalone to distributed.
