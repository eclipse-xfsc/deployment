# XFSC K8ssandra Operator Wrapper

Installs the official K8ssandra Operator cluster-wide.

## Prerequisite

K8ssandra requires cert-manager. Install cert-manager before this chart.

## Install

```bash
helm dependency update
helm upgrade --install k8ssandra-operator .   --namespace k8ssandra-operator   --create-namespace
```

For Argo CD use `ServerSideApply=true`, because the operator installs large
CRDs.

Verify:

```bash
kubectl get crd k8ssandraclusters.k8ssandra.io
kubectl get pods -n k8ssandra-operator
```
