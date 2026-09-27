# OCM W-Stack Deployment

This directory contains the Helm charts for the **OCM W-Stack**. The
stack is deployed through **Argo CD ApplicationSets** and depends on the
XFSC cluster infrastructure provided by this repository.

The deployment is split into two stages:

1.  **Cluster bootstrap** using `basic-cluster-init.sh`
2.  **OCM W-Stack bootstrap** using `ocm-wstack-init.sh` / the
    `ocm-wstack` ApplicationSet

`ocm-wstack-init.sh` is the convenient end-to-end entry point. It forwards its CLI options to `basic-cluster-init.sh`, then deploys the OCM W-Stack after the shared cluster infrastructure is ready.

------------------------------------------------------------------------

## Architecture

The deployment follows this flow:

``` text
Kubernetes cluster
       |
       v
basic-cluster-init.sh
       |
       +--> Observability
       |      \- OpenTelemetry / monitoring dependencies
       |
       +--> Security
       |      +-- OpenBao
       |      +-- External Secrets Operator
       |      \- Kyverno
       |
       +--> Argo CD
       |
       +--> infrastructure namespace
       +--> XFSC Kubernetes Operator
       |
       +--> storage ApplicationSet
       +--> network ApplicationSet
       \--> core ApplicationSet
                  |
                  v
          ocm-wstack-init.sh
                  |
                  +--> ocm-wstack namespace
                  +--> OpenBao / ESO access for the namespace
                  \--> ocm-wstack ApplicationSet
                              |
                              v
                    OCM W-Stack services
```

Argo CD discovers the individual Helm charts from the Git repository.
Each directory matched by an ApplicationSet becomes an Argo CD
`Application`.

------------------------------------------------------------------------

## Prerequisites

The scripts assume an existing Kubernetes cluster and local access to
the repository.

Required command-line tools:

-   `kubectl`
-   `helm`
-   `jq`
-   `bash`

The active kubeconfig must provide cluster-admin-level permissions for
the bootstrap because the installation creates namespaces, CRDs,
cluster-scoped resources, Argo CD, security infrastructure and
ApplicationSets.

A default Kubernetes `StorageClass` must exist. `basic-cluster-init.sh`
detects it using:

``` bash
kubectl get storageclass \
  -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

### DNS provider profiles

The network ApplicationSet passes a profile to the infrastructure
charts.

The repository currently contains ExternalDNS profiles for:

-   `hetzner`
-   `ionos`

The selected profile determines the ExternalDNS webhook/provider
configuration.

------------------------------------------------------------------------

# 1. Basic cluster initialization

`basic-cluster-init.sh` prepares the shared XFSC infrastructure required
before the OCM W-Stack can be deployed.

Run the script from the **repository root**, because its Helm chart
paths are relative to that directory.

Current arguments:

``` bash
./basic-cluster-init.sh \
  --profile <profile> \
  --domain <domain> \
  --email <email> \
  [--dnstoken <dns-token>] \
  [--disable-external-dns]
```

Example:

``` bash
./basic-cluster-init.sh \
  --profile hetzner \
  --domain example.org \
  --email admin@example.org \
  --dnstoken "$HETZNER_DNS_TOKEN"
```

## What the script installs

### Observability

The script creates the `observability` namespace and installs the chart
from:

``` text
INFRA/observability/opentelemtry
```

It also registers the OpenTelemetry, Prometheus, Grafana and Jaeger Helm
repositories required by the chart and its dependencies.

### Security infrastructure

The `security` namespace contains the central security services:

``` text
OpenBao
External Secrets Operator
Kyverno
```

The charts are installed from:

``` text
INFRA/security/openbao
INFRA/security/eso
INFRA/security/kyverno
```

### Argo CD

The script executes:

``` bash
./argocd-bootstrap.sh
```

`argocd-bootstrap.sh` installs Argo CD into the `argocd` namespace,
waits for the main Argo CD components and verifies that the initial
admin secret exists.

For local access:

``` bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The bootstrap script prints the initial `admin` password after a
successful installation.

### Infrastructure namespace

The following chart prepares the `infrastructure` namespace:

``` bash
helm install -n security infrastructure-namespace \
  INFRA/app-management/app-namespace \
  -f INFRA/app-management/app-namespace-values/infra-values.yaml
```

The `app-namespace` chart is also responsible for the OpenBao/External
Secrets integration used by application namespaces.

Depending on its values, it can create both a namespaced `SecretStore`
and a `ClusterSecretStore`.

### XFSC Kubernetes Operator

The Kubernetes operator is installed from:

``` text
INFRA/kubernetes-operator
```

### Infrastructure ApplicationSets

The script deploys the infrastructure in dependency order:

``` text
storage
   |
   v
network
   |
   v
core
```

The corresponding values are:

``` text
XFSC/Applicationsets/values/03_storage-values.yaml
XFSC/Applicationsets/values/04_network-values.yaml
XFSC/Applicationsets/values/05_core-values.yaml
```

After every ApplicationSet installation, `check-applicationset.sh` waits
until all generated Argo CD Applications are both:

``` text
Synced
Healthy
```

For `Degraded` but already `Synced` applications, the script
additionally refreshes ExternalSecrets in the target namespace and
requests an Argo CD refresh.

This means later deployment stages do not start until the previous
infrastructure layer is ready.

------------------------------------------------------------------------

# 2. Network and ExternalDNS

The `network` ApplicationSet discovers charts below:

``` text
INFRA/network/*
```

At the moment these include:

``` text
bind9
cert-manager
cluster-issuer
envoy
external-dns
```

`bind9` is already disabled in the default network ApplicationSet
configuration:

``` yaml
excludes:
  - "INFRA/network/bind9"
```

## Disabling ExternalDNS

Yes --- individual components can already be disabled at the
**ApplicationSet generator level**.

The Git directory generator supports excluded paths. To prevent Argo CD
from creating an ExternalDNS Application, add the chart directory to
`XFSC/Applicationsets/values/04_network-values.yaml`:

``` yaml
excludes:
  - "INFRA/network/bind9"
  - "INFRA/network/external-dns"
```

After this change, the network ApplicationSet will continue to deploy
cert-manager, the cluster issuer and Envoy, but it will no longer
generate an Argo CD Application for ExternalDNS.

This is preferable to deploying ExternalDNS with `enabled: false`,
because Argo CD then does not create or manage an unnecessary
ExternalDNS Application at all.

### Recommended improvement

For installations where ExternalDNS is optional, the configuration
should expose this explicitly instead of requiring users to know the
chart path.

For example:

``` yaml
components:
  externalDns:
    enabled: false
```

The ApplicationSet template can translate this option into an excluded
Git directory.

The existing `excludes` mechanism should remain available as the generic
mechanism for disabling arbitrary charts.

This gives two levels of configuration:

``` text
components.*.enabled   -> documented switches for common optional services
excludes               -> generic escape hatch for arbitrary directories
```

### DNS secret

When ExternalDNS is enabled, the bootstrap creates:

``` text
Secret/infrastructure/external-dns
```

with the key:

``` text
token
```

The Hetzner profile consumes it as `HETZNER_TOKEN`; the IONOS profile
consumes the same secret as `IONOS_API_KEY`.

If ExternalDNS is disabled, no DNS provider token should be required and
the bootstrap should skip creation of this secret.

------------------------------------------------------------------------

# 3. OCM W-Stack initialization

After the base infrastructure is healthy, create the OCM W-Stack
application namespace:

``` bash
helm install -n security ocm-wstack-namespace \
  INFRA/app-management/app-namespace \
  -f INFRA/app-management/app-namespace-values/ocm-wstack-values.yaml
```

The namespace configuration creates:

``` text
Namespace:          ocm-wstack
SecretStore:        openbao
ClusterSecretStore: ocm-wstack-openbao
```

and provisions the OpenBao identities required by the W-Stack.

The configuration uses the OpenBao mount:

``` text
ocm-wstack/system
```

and the resource provisioner service account:

``` text
ocm-wstack-resource-provisioner
```

## Deploy the ApplicationSet

Determine the default storage class:

``` bash
STORAGE_CLASS="$(
  kubectl get storageclass \
    -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
)"
```

Then install the OCM W-Stack ApplicationSet:

``` bash
helm install -n ocm-wstack ocm-wstack \
  XFSC/Applicationsets/chart \
  -f XFSC/Applicationsets/values/06_ocm_wstack-values.yaml \
  --set storageClass="$STORAGE_CLASS"
```

Wait for all generated applications:

``` bash
./check-applicationset.sh ocm-wstack argocd
```

------------------------------------------------------------------------

# 4. OCM W-Stack ApplicationSet

The W-Stack ApplicationSet scans:

``` text
OCM W-Stack/*
```

Each non-excluded chart directory becomes an Argo CD Application.

The current configuration excludes:

``` text
OCM W-Stack/tenant
OCM W-Stack/Policies
OCM W-Stack/Didcomm
OCM W-Stack/Tools
```

The same mechanism can be used to disable further W-Stack components.

For example:

``` yaml
excludes:
  - "OCM W-Stack/tenant"
  - "OCM W-Stack/Policies"
  - "OCM W-Stack/Didcomm"
  - "OCM W-Stack/Tools"
  - "OCM W-Stack/Offering Dummy"
```

Because the ApplicationSet has automated synchronization enabled with:

``` yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

removing a directory from generation through `excludes` also allows Argo
CD/ApplicationSet reconciliation to remove the generated Application.

Review this behavior before changing exclusions on an existing
installation.

------------------------------------------------------------------------

# 5. ApplicationSet configuration

The generic ApplicationSet chart is located at:

``` text
XFSC/Applicationsets/chart
```

It supports a Git directory generator and an optional matrix generator.

Important values are:

``` yaml
tag: main
path: INFRA/network/*
name: network
namespace: infrastructure
storageClass: local-path

excludes:
  - INFRA/network/bind9

profile: hetzner
domain: example.org
email: admin@example.org
```

For every generated application the template configures:

``` text
global.storageClass
global.domain
global.profile
global.email
external-dns.domainFilters[0]
acme.email
```

where the corresponding top-level ApplicationSet value exists.

Argo CD deploys all generated applications with:

``` yaml
automated:
  prune: true
  selfHeal: true
```

and:

``` yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

------------------------------------------------------------------------

# 6. Verification

Check the ApplicationSets:

``` bash
kubectl get applicationsets -n argocd
```

Check all generated Applications:

``` bash
kubectl get applications -n argocd
```

Inspect the infrastructure:

``` bash
kubectl get pods -n infrastructure
kubectl get pods -n security
kubectl get pods -n observability
```

Inspect the W-Stack:

``` bash
kubectl get pods -n ocm-wstack
```

Check synchronization and health:

``` bash
./check-applicationset.sh storage argocd
./check-applicationset.sh network argocd
./check-applicationset.sh core argocd
./check-applicationset.sh ocm-wstack argocd
```

------------------------------------------------------------------------

# 7. Bootstrap script behavior

The bootstrap scripts support ExternalDNS as an optional component. By default ExternalDNS remains enabled and `--dnstoken` is required. Passing `--disable-external-dns` skips the DNS token requirement, skips creation of `Secret/infrastructure/external-dns`, and excludes `INFRA/network/external-dns` from the network ApplicationSet.

`ocm-wstack-init.sh` forwards all CLI arguments to `basic-cluster-init.sh` and determines the default StorageClass again before installing the W-Stack ApplicationSet, because shell variables from the child bootstrap process are not inherited by the caller.

The DNS secret uses the parsed `DNSTOKEN` value.

# 8. End-to-end bootstrap interface

`ocm-wstack-init.sh` can be used as the single entry point:

``` bash
./ocm-wstack-init.sh \
  --profile hetzner \
  --domain example.org \
  --email admin@example.org \
  --dnstoken "$HETZNER_DNS_TOKEN"
```

It forwards the infrastructure arguments internally:

``` bash
./basic-cluster-init.sh \
  --profile "$PROFILE" \
  --domain "$DOMAIN" \
  --email "$EMAIL" \
  --dnstoken "$DNSTOKEN"
```

and independently determine the storage class before installing the
W-Stack ApplicationSet.

For installations without automated DNS management, a further option is
recommended:

``` bash
./ocm-wstack-init.sh \
  --profile hetzner \
  --domain example.org \
  --email admin@example.org \
  --disable-external-dns
```

In that mode:

1.  no DNS token is required;
2.  the `external-dns` Secret is not created;
3.  `INFRA/network/external-dns` is excluded from the network
    ApplicationSet.

This makes ExternalDNS genuinely optional instead of merely allowing
advanced users to edit the ApplicationSet values manually.

------------------------------------------------------------------------

# 9. Paradym / Credo integration notes

The current OCM W-Stack integration has been tested with Paradym/Credo
using SD-JWT VC issuance.

Important issuer requirements include:

-   the SD-JWT VC issuer (`iss`) must match the resolvable issuer DID;
-   the JWT `kid` must reference the corresponding DID verification
    method;
-   the public JWK in the DID Document must belong to the actual signing
    key;
-   the issuer signing verification method must be authorized through
    `assertionMethod`;
-   holder binding must propagate the holder key from the OID4VCI proof
    into `cnf.jwk`;
-   status list URLs must be constructed consistently and must not
    duplicate the public origin.

Example issuer relationship:

``` json
{
  "id": "did:web:issuer.example.org",
  "verificationMethod": [
    {
      "id": "did:web:issuer.example.org#eckey",
      "type": "JsonWebKey2020",
      "controller": "did:web:issuer.example.org",
      "publicKeyJwk": {
        "kty": "EC",
        "crv": "P-256",
        "alg": "ES256",
        "kid": "eckey",
        "x": "...",
        "y": "..."
      }
    }
  ],
  "assertionMethod": [
    "did:web:issuer.example.org#eckey"
  ]
}
```

For the tested Paradym/Credo flow, publishing the key only in
`verificationMethod` was not sufficient; the same verification method
also had to be referenced by `assertionMethod`.
