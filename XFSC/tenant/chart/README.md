# XFSC Tenant Gateway

This chart creates tenant-specific resources against the shared `Gateway/infrastructure/envoy-gateway`:

- one `ListenerSet` with an HTTPS listener for the tenant hostname
- one `Certificate` and TLS Secret per tenant/subdomain
- one `HTTPRoute` attached to that ListenerSet
- optional OpenBao Transit bootstrap for the tenant ID and shared X-KEY

The chart does **not** create a Gateway or GatewayClass.

## Routing defaults

All matches use `Exact`. `/api/foo` automatically rewrites to `/v1/tenants/<tenant.id>/foo`. Special routes can use `targetPath`.

Every route always gets these request headers: `X-NAMESPACE`, `X-DID`, `X-KEY`, `X-GROUP`, `X-HOST`, `X-TYPE`, `X-ORIGIN`.

The DID is always `did:web:<tenant-subdomain>.<domain>`.

## Shared Gateway prerequisites

The central Gateway must be `infrastructure/envoy-gateway` and allow ListenerSets from tenant namespaces. The central port-80 listener remains available for cert-manager HTTP-01.

ExternalDNS using `gateway-httproute` must also enable ListenerSet traversal (`--gateway-listener-sets`).
