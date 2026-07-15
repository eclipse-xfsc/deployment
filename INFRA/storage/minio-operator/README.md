# XFSC MinIO Operator Wrapper

Installs the official MinIO Operator.

```bash
helm dependency update
helm upgrade --install minio-operator .   --namespace minio-operator   --create-namespace
```

Use `ServerSideApply=true` in Argo CD because the chart installs CRDs.
