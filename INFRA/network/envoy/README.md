# XFSC Envoy Gateway

Minimal wrapper chart for installing the Envoy Gateway control plane without creating a `Gateway`, listener, or route.

## Contents

The chart installs the official Envoy Gateway Helm chart as an OCI dependency:

```text
oci://docker.io/envoyproxy/gateway-helm
```

No tenant-facing Gateway API resources are included.

## Install

```bash
helm dependency build ./xfsc-envoy-gateway

helm upgrade --install envoy-gateway ./xfsc-envoy-gateway \
  --namespace envoy-gateway-system \
  --create-namespace
```

## Verify

```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
kubectl get gateways -A
```

The final command should return no tenant `Gateway` resources until you create them separately.

## Uninstall

```bash
helm uninstall envoy-gateway -n envoy-gateway-system
```

## Scope

This chart does not install cert-manager or ExternalDNS. Install those as separate platform components. They remain idle for tenant traffic until suitable `Gateway`, `HTTPRoute`, `Certificate`, or DNS source resources exist.
