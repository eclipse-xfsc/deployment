# XFSC ExternalDNS

Minimal wrapper around the official ExternalDNS chart.

Designed for:
- Envoy Gateway
- Gateway API
- HTTPRoute
- cert-manager
- RFC2136 (BIND)

Configure only values.yaml and run:

helm dependency update
helm install external-dns .
