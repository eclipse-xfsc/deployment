# XFSC Shared Envoy Gateway

Installs the Envoy Gateway control plane plus the cluster-wide `GatewayClass/envoy`, an `EnvoyProxy` with Hetzner LoadBalancer annotations, and the shared `Gateway/infrastructure/envoy-gateway`.

The shared Gateway only owns the common HTTP/80 listener used by cert-manager HTTP-01. Tenant HTTPS listeners are added later via tenant-specific `ListenerSet` resources.

`allowedListeners.namespaces.from: All` is required so ListenerSets created in application namespaces can attach to the central Gateway.
