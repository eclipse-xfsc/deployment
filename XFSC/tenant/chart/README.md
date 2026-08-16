# XFSC Tenant Gateway

Creates one isolated Gateway API stack per tenant:

- one `Gateway`
- one HTTPS listener
- one cert-manager `Certificate`
- one `HTTPRoute` with any number of path rules

It assumes Envoy Gateway, Gateway API CRDs, cert-manager and optionally ExternalDNS are already installed.

## Install

```bash
helm upgrade --install tenant-a ./xfsc-tenant-gateway \
  --namespace tenant-a \
  --create-namespace \
  --set hostname=tenant-a.example.com
```

## Route configuration

Each entry in `routes` supports:

- `path`
- `pathType`
- optional `rewrite`
- backend Service name and port
- optional request headers using `set`, `add`, and `remove`

Backend Services must be in the same namespace as the release.

## ExternalDNS

Configure ExternalDNS with the Gateway HTTPRoute source, commonly:

```yaml
sources:
  - gateway-httproute
```

It can then discover the hostname from `HTTPRoute.spec.hostnames`.

## Prerequisites

cert-manager must have Gateway API support enabled when using Gateway-derived functionality. This chart creates an explicit `Certificate`, so certificate issuance itself does not depend on the Gateway annotation shim.
