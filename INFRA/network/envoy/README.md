# XFSC Shared Envoy Gateway

This chart installs Envoy Gateway and owns the shared infrastructure resources used by all later tenant releases:

- `GatewayClass/envoy`
- `EnvoyProxy/infrastructure/envoy` with the Hetzner LoadBalancer annotations
- `Gateway/infrastructure/envoy-gateway`
- one shared HTTP listener on port 80 for ACME HTTP-01
- `allowedListeners: All` so future tenant `ListenerSet` resources can attach
- `allowedRoutes: All` on the shared HTTP listener so cert-manager solver routes can attach

Tenant HTTPS listeners are NOT known at infrastructure-install time. They are added later through tenant-owned `ListenerSet` resources.

Requirements:
- Gateway API v1.5+ Standard CRDs so `ListenerSet` and `Gateway.spec.allowedListeners` exist.
- Envoy Gateway 1.8.x.
- If ExternalDNS follows tenant HTTPRoutes through ListenerSets, enable `--gateway-listener-sets`.
