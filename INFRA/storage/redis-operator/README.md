# XFSC Redis Operator Wrapper

This chart wraps the actively maintained OpsTree Redis Operator.

The operator supports Redis standalone, replication, Sentinel and Redis
Cluster resources.

## Install

```bash
helm dependency update
helm upgrade --install redis-operator .   --namespace redis-operator   --create-namespace
```

For Argo CD:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

Verify:

```bash
kubectl get crd | grep redis.opstreelabs.in
kubectl get pods -n redis-operator
```

The wrapper pins:

```text
quay.io/opstree/redis-operator:v0.25.0
```
