# XSFC Cluster Resource Operator

The **XSFC Cluster Resource Operator** watches Kubernetes resources cluster-wide and detects installed products, infrastructure components, and declarative injection requirements through labels, annotations, and optional custom resources.

The goal is to centrally and declaratively provide cross-product dependencies such as secrets, environment variables, telemetry configuration, database connectivity, or external services without tightly coupling individual Helm charts.

---

## Capabilities

The operator runs cluster-wide and provides the following functionality:

1. **Installation Discovery**
   - detects installed products and components through labels/annotations
   - watches Deployments, StatefulSets, DaemonSets, Services, Secrets, ConfigMaps, ServiceAccounts, and selected CRDs
   - builds an internal index of available resources per namespace and type

2. **Environment Injection**
   - injects environment variables into Deployments, StatefulSets, DaemonSets, and Jobs
   - supports injection from Secrets, ConfigMaps, and operator-generated binding resources
   - can reference ENV blocks using abstract types such as `telemetry`, `database`, `redis`, `s3`, and `vault`

3. **Secret and Config Bindings**
   - detects available Secret/ConfigMap sources
   - optionally creates dedicated Kubernetes Secrets or ConfigMaps per consumer
   - supports integration with External Secrets Operator, OpenBao/Vault, and static Kubernetes Secrets

4. **Dependency Resolution**
   - detects whether a workload requires a specific resource type
   - checks whether matching providers exist in the namespace or cluster-wide
   - sets status conditions on binding CRDs

5. **Product Profiles**
   - describes which exports a product provides
   - describes which imports a product requires
   - enables product-independent coupling through types instead of concrete names

6. **Observability**
   - emits Kubernetes Events
   - writes Conditions to Custom Resources
   - exposes controller metrics for Prometheus

---

## Non-Goals

The operator is initially **not a replacement** for Helm, Argo CD, or Flux.

It does not install large products itself; instead, it reacts to existing installations and declaratively connects resources.

Not in scope for the first version:

- full lifecycle management of third-party Helm releases
- secret rotation in external systems
- database migrations
- complex cross-cluster synchronization
- policy enforcement such as Kyverno or Gatekeeper

---

## Technology Stack

The operator is implemented in **Go**.

Recommended stack:

- Go 1.22+
- Kubebuilder
- controller-runtime
- client-go
- Kubernetes 1.28+
- Helm chart for installation
- CRDs via `apiextensions.k8s.io/v1`
- Prometheus metrics via controller-runtime

(Project structure and all code/YAML examples remain unchanged.)

---

## Core Model

The operator distinguishes between:

- **Provider**: a resource provides something, e.g. Telemetry, Postgres, Redis, S3, Vault.
- **Consumer**: a workload requires something and wants ENVs injected.
- **Binding**: a connection between consumer and provider.
- **Profile**: a description of an installed product or component.

Example:

```text
OpenTelemetry Collector provides telemetry
PowerDNS requires telemetry and database
Postgres Operator provides database/postgres
External Secrets provides secret-store
```
---

## Labels and Annotations

The operator primarily listens for labels and annotations with the prefixes:

```text
xfsc.io/*
inject.xfsc.io/*
resources.xfsc.io/*
```
---

## Provider Labels

A resource is recognized as a provider when it carries the following labels:

```yaml
metadata:
  labels:
    xfsc.io/resource-provider: "true"
    xfsc.io/resource-type: "telemetry"
    xfsc.io/resource-name: "default"
```

### Standardized Provider Types

| Type | Meaning | Typical Resources |
|---|---|---|
| `telemetry` | Logging, metrics, tracing configuration | ConfigMap, Secret, Service |
| `database` | Generic database | Secret, Service, Custom Resource |
| `database.postgres` | PostgreSQL provider | Secret, Service, CNPG Cluster |
| `database.mysql` | MySQL/MariaDB provider | Secret, Service |
| `cache.redis` | Redis provider | Secret, Service |
| `objectstore.s3` | S3-compatible object store | Secret, Service, MinIO Tenant |
| `secret-store` | Secret backend | ClusterSecretStore, SecretStore |
| `vault` | OpenBao/Vault provider | Service, Secret, ClusterSecretStore |
| `messagebus.nats` | NATS provider | Secret, Service |
| `dns.powerdns` | PowerDNS provider | Secret, Service |
| `identity.oidc` | OIDC provider | Secret, ConfigMap |

The remaining YAML examples are unchanged.

---

## Consumer Annotations for ENV Injection

A workload requests injection through annotations.

Supported workloads:

- Deployment
- StatefulSet
- DaemonSet
- Job
- CronJob

---

## ENV Injection Annotations

| Annotation | Description | Example |
|---|---|---|
| `inject.xfsc.io/enabled` | enables injection | `"true"` |
| `inject.xfsc.io/types` | comma-separated resource types | `telemetry,database.postgres` |
| `inject.xfsc.io/resource-name` | optional provider name | `default` |
| `inject.xfsc.io/source-namespace` | optional provider namespace | `observability` |
| `inject.xfsc.io/mode` | injection mode | `envFrom`, `env`, `projected` |
| `inject.xfsc.io/container-selector` | target container | `app` or `*` |
| `inject.xfsc.io/restart-on-change` | rollout on provider changes | `"true"` |
| `inject.xfsc.io/optional` | workload may start without provider | `"false"` |

---

## Operator-Owned Annotations

The operator sets its own markers on patched workloads to detect drift and avoid unnecessary patches.

---

## Custom Resources

### ResourceProfile

Describes an installed product or component.

### ResourceBinding

Describes a concrete connection between a consumer and a provider.

### EnvInjectionPolicy

Defines default rules per namespace or cluster.

---

## Monitored Kubernetes Resources

The operator watches the following resources cluster-wide:

- Namespace
- Deployment
- StatefulSet
- DaemonSet
- Job
- CronJob
- Secret
- ConfigMap
- Service
- ServiceAccount
- Ingress
- PersistentVolumeClaim
- ResourceProfile
- ResourceBinding
- EnvInjectionPolicy
- SecretStore
- ClusterSecretStore
- ExternalSecret

Optional later:

- Certificate
- Issuer / ClusterIssuer
- ServiceMonitor
- PodMonitor
- PostgreSQL/CNPG Cluster
- Redis CRDs
- MinIO Tenant

---

## Injection Strategies

### 1. Direct `envFrom`

For simple ConfigMaps and Secrets.

### 2. Individual Environment Variables

For controlled key mapping.

### 3. Projected Volume

For applications that require configuration files instead of environment variables.

---

## Naming Conventions

Resources generated by the operator follow this pattern:

```text
xsfc-inject-<type-normalized>-<name>
```

Dots in resource types are normalized to hyphens.

---

## RBAC Requirements

The operator requires cluster-wide read access to monitored resources and write access for generated bindings and patches.

Minimum permissions:

- `get`, `list`, `watch` on monitored resources
- `create`, `update`, `patch`, `delete` on operator-owned ConfigMaps/Secrets
- `patch` on Deployments, StatefulSets, DaemonSets, Jobs, CronJobs
- `get`, `list`, `watch` on External Secrets Operator CRDs
- `create`, `patch` on Events
- `update` on status subresources of its own CRDs

---

## Reconciliation Logic

Simplified flow:

```text
1. Workload or provider changes
2. Operator reads labels/annotations
3. Operator determines required resource types
4. Operator searches for a matching provider
5. Operator creates or updates an inject Secret/ConfigMap
6. Operator patches the workload PodTemplateSpec
7. Operator sets a hash annotation
8. Operator writes Events and Status Conditions
```

---

## Conflict Behavior

The operator does not overwrite manually defined environment variables with the same name unless explicitly allowed.

Default:

```yaml
inject.xfsc.io/overwrite-existing: "false"
```

---

## Multi-Namespace Behavior

Providers can be namespaced or cluster-wide.

Allowed values:

- `Namespace`
- `Cluster`

Default is `Namespace`.

---

## Security Model

The operator should not blindly copy secrets into all namespaces.

Recommended security rules:

- Cross-namespace secret injection only through explicit `ResourceBinding`
- Optional namespace allowlist mechanism
- No injection into system namespaces without explicit approval
- No secret values in logs or events
- OwnerReferences only within the same namespace
- Finalizers for cleanup of injected resources

---

## Default Excluded Namespaces

- kube-system
- kube-public
- kube-node-lease
- cert-manager
- kyverno
- gatekeeper-system
- external-secrets

These can be customized through Helm values.

---
## Helm Installation

```bash
helm install xsfc-resource-operator ./charts/xsfc-resource-operator \
  --namespace xsfc-system \
  --create-namespace
```

Beispiel `values.yaml`:

```yaml
replicaCount: 1

manager:
  image:
    repository: ghcr.io/xfsc/xsfc-resource-operator
    tag: latest
  logLevel: info

watch:
  clusterScoped: true
  excludedNamespaces:
    - kube-system
    - kube-public
    - kube-node-lease
    - cert-manager
    - kyverno
    - gatekeeper-system
    - external-secrets

injection:
  enabled: true
  defaultMode: envFrom
  restartOnChange: true
  overwriteExisting: false
  allowCrossNamespace: false

providers:
  externalSecrets:
    enabled: true
  certManager:
    enabled: false
  cnpg:
    enabled: false

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

---

## Go/Kubebuilder Initialisierung

```bash
mkdir xsfc-resource-operator
cd xsfc-resource-operator

go mod init github.com/xfsc/xsfc-resource-operator
kubebuilder init \
  --domain xfsc.io \
  --repo github.com/xfsc/xsfc-resource-operator
```

CRDs anlegen:

```bash
kubebuilder create api \
  --group resources \
  --version v1alpha1 \
  --kind ResourceProfile

kubebuilder create api \
  --group resources \
  --version v1alpha1 \
  --kind ResourceBinding

kubebuilder create api \
  --group resources \
  --version v1alpha1 \
  --kind EnvInjectionPolicy
```

Controller lokal starten:

```bash
make manifests
make install
make run
```

Image bauen:

```bash
make docker-build docker-push IMG=ghcr.io/xfsc/xsfc-resource-operator:latest
```

Deployment:

```bash
make deploy IMG=ghcr.io/xfsc/xsfc-resource-operator:latest
```

---

## MVP Roadmap

### Phase 1

- Define CRDs
- Watch workloads cluster-wide
- Evaluate labels/annotations
- Detect ConfigMap/Secret providers
- `envFrom` injection for Deployment and StatefulSet

### Phase 2

- ResourceBinding status
- Namespace selector support
- Restart-on-change hashing
- External Secrets Operator discovery
- Helm chart

### Phase 3

- Provider plugins for CNPG, Redis, MinIO, cert-manager
- Projected volume injection
- Policy-based automatic bindings
- Prometheus metrics and ServiceMonitor

---

## Design Principles

- Products remain independently installable
- Coupling happens through abstract types instead of concrete names
- Helm charts only need labels/annotations or profiles
- Secrets are never logged
- Cross-namespace access is restrictive by default
- Operator patches are idempotent
- Every automatic change is traceable through hashes and events
