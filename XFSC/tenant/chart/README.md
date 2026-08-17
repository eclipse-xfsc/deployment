# XFSC Tenant Gateway

Gateway API chart for one XFSC tenant.

The public hostname is always derived from:

```yaml
tenant:
  subdomain: dieserTenant
  domain: domain.com
```

which produces `dieserTenant.domain.com`. Public endpoints live below that hostname, normally under `/api/...` or `/.well-known/...`.

## Routing conventions

- HTTPRoute path matching is always `Exact`.
- `/api/<path>` automatically rewrites to `/v1/tenants/<tenant.id>/<path>`.
- `targetPath` overrides that convention for exceptional backends.
- Non-`/api` routes without `targetPath` are forwarded unchanged.
- `X-NAMESPACE` is injected automatically unless disabled per route.
- Header profiles add the remaining service-specific XFSC headers.

The authorization token endpoint is exposed as `/api/auth/token` and rewritten to `/token` on the pre-authorization bridge. The bridge's OpenID configuration must advertise the public URL `https://<subdomain>.<domain>/api/auth/token`.


## OpenBao Transit bootstrap

When `openbao.enabled=true`, a Helm post-install/post-upgrade Job authenticates to OpenBao using the Job ServiceAccount and Kubernetes auth. It creates one Transit secrets engine whose mount path defaults to `tenant.id`, then creates `tenant.keys.verification` and `tenant.keys.status`. Additional keys can be configured under `openbao.transit.additionalKeys`.

The OpenBao Kubernetes auth role configured in `openbao.auth.role` must already exist and must grant the Job enough policy permissions to inspect/create the tenant mount and read/create its Transit keys. Example for tenant `tenant_space`:

```hcl
path "sys/mounts" {
  capabilities = ["read"]
}
path "sys/mounts/tenant_space" {
  capabilities = ["create", "read", "update"]
}
path "tenant_space/keys/*" {
  capabilities = ["create", "read", "update"]
}
```

The Job is idempotent: an existing Transit mount or key is retained. Helm runs it after installs and upgrades.

## DID

The DID is not configurable separately. It is always derived from the public tenant host:

```text
did:web:<tenant.subdomain>.<tenant.domain>
```

For example, `tenant.subdomain=alice` and `tenant.domain=example.com` results in `did:web:alice.example.com`. The public DID document remains at `https://alice.example.com/.well-known/did.json`.
