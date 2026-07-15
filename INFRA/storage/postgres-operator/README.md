# XFSC CloudNativePG Operator Wrapper

This chart wraps the official CloudNativePG operator Helm chart.

## What it installs

- CloudNativePG operator deployment
- CloudNativePG CRDs
- Cluster-wide RBAC
- Admission webhooks
- Optional PodMonitor
- Optional wrapper NetworkPolicy

The wrapper does not create a PostgreSQL cluster. PostgreSQL clusters are
installed separately through `postgresql.cnpg.io/v1` `Cluster` resources.

## Chart dependency

```yaml
dependencies:
  - name: cloudnative-pg
    version: "0.29.0"
    repository: "https://cloudnative-pg.github.io/charts"
```

The official chart supports only the latest point release of the operator.

## Install

```bash
helm dependency update
```

```bash
helm upgrade --install cnpg   .   --namespace cnpg-system   --create-namespace
```

## Verify

```bash
kubectl get pods -n cnpg-system
```

```bash
kubectl get crd clusters.postgresql.cnpg.io
```

```bash
kubectl api-resources --api-group postgresql.cnpg.io
```

## Argo CD

Install this wrapper as a separate Argo CD Application before any PostgreSQL
cluster Applications.

Example destination:

```yaml
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: cnpg-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Recommended Application annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-20"
```

The PostgreSQL cluster Application can use a later wave such as `0`.

## CRDs

CRDs are enabled by default:

```yaml
cloudnative-pg:
  crds:
    create: true
```

Do not disable this unless CRDs are managed by a separate platform release.

## Operator image

By default, the upstream chart derives the image tag from its `appVersion`.

```yaml
cloudnative-pg:
  image:
    repository: ghcr.io/cloudnative-pg/cloudnative-pg
    tag: ""
    pullPolicy: IfNotPresent
```

An explicit immutable tag or digest may be configured for controlled
environments.

## Monitoring

Enable a Prometheus Operator PodMonitor:

```yaml
cloudnative-pg:
  monitoring:
    podMonitorEnabled: true
```

This requires the `monitoring.coreos.com` CRDs.

## Namespace scope

By default, CloudNativePG watches all namespaces.

To restrict it:

```yaml
cloudnative-pg:
  watchNamespaces:
    - infrastructure
    - tenant-a
```

For a platform-wide XFSC installation, leaving `watchNamespaces` empty is
usually appropriate.

## Resources

```yaml
cloudnative-pg:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## NetworkPolicy

The wrapper contains an optional NetworkPolicy, disabled by default because
webhook and Kubernetes API connectivity vary between cluster distributions.

```yaml
wrapper:
  networkPolicy:
    enabled: true
    allowIngressFromNamespaces:
      - kube-system
      - argocd
```

Validate this policy against the control-plane networking of the target
cluster before enabling it.

## Uninstall warning

Deleting the operator does not automatically delete existing PostgreSQL
`Cluster` resources or their persistent volumes. Do not remove the operator
while managed clusters are still running.
