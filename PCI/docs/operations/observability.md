# PCI telemetry

Domains, mailbox addresses, private file paths, contexts and StorageClasses in this guide are examples. Supply target deployment values as described in [neutral configuration](neutral-configuration.md).

FR-55/56/57 require supplied instances of Jaeger, Prometheus and an OTEL Collector. `deployment/helm/observability/` supplies them in one private Pod in the PCI namespace. `scripts/deploy.sh` installs it after G0, unless `PCI_OBSERVABILITY_MODE=external` explicitly selects an already provisioned equivalent. It does not modify the shared observability installation.

| Interface | Route |
|---|---|
| Operation spans | ORCE → HTTPS OTLP/HTTP Collector on 4318 → HTTPS Jaeger on Pod loopback |
| Metrics | Collector → public PCI `/pci-orce/metrics` with the internal service token → HTTPS Prometheus remote write |
| Jaeger UI | Private Service port 16686; access with Kubernetes port-forward |
| Prometheus UI/API | Private Service port 9090; access with Kubernetes port-forward |

All these TLS endpoints require TLS 1.3. The ORCE trust mount contains only the public telemetry CA; the Collector reads only the required key from the runtime Secret. NetworkPolicy admits OTLP only from the selected ORCE pods. UI ports are not publicly exposed. An outage or unavailable telemetry CA does not change a business operation's result.

The chart requests 100m CPU and 256 MiB memory in total, with explicit upper limits. Jaeger keeps at most 5,000 traces in memory. Prometheus retains six hours/512 MB in an ephemeral volume. A Pod replacement can discard that data; export the acceptance evidence before restarting. Durable retention, HA and production sizing remain operator choices.

## Install separately or rotate certificates

```bash
python3 scripts/deploy-observability.py \
  --kubeconfig "$KUBECONFIG" --context cluster-admin@ocm-cr \
  --namespace xfsc-orce-pci-orce --deployment xfsc-orce --container orce \
  --main-host pci.example.com --base-path /pci-orce
```

The helper preserves its certificates on reapply. Its test server certificate expires after 90 days; add `--rotate-certificate` before expiry. Rotation changes the certificate hash to roll the telemetry Pod and updates ORCE's public CA ConfigMap. It does not renew the separate public Gateway certificate.

## Verify actual collection

1. Perform a synthetic PCI API operation. Inspect `kubectl -n xfsc-orce-pci-orce logs deploy/fap-pci-observability -c collector --tail=50` for export failures.
2. Save the public telemetry CA, then forward the two private ports in another terminal:

```bash
umask 077
kubectl -n xfsc-orce-pci-orce get secret fap-pci-observability-tls \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > /private/pci-telemetry-ca.crt
kubectl -n xfsc-orce-pci-orce port-forward \
  service/fap-pci-observability 16686:16686 9090:9090
```

```bash
curl --fail --cacert /private/pci-telemetry-ca.crt \
  'https://localhost:9090/api/v1/query?query=fap_pci_operations_total'
curl --fail --cacert /private/pci-telemetry-ca.crt \
  'https://localhost:16686/api/services'
```

Expect actual operation counters and service `fap-pci`. In the Jaeger UI, inspect the recorded operation and its success/error result. Spans carry operation, result, service version and timing only; they do not carry tenant identities, subject claims, access tokens, offers or credentials. Check failure paths as well as success.

The chart uses public HTTPS DNS to scrape PCI, so the cluster must be able to reach that Gateway address. If scraping fails, inspect DNS, public certificate validity, NetworkPolicy and load-balancer routing. Never switch to unauthenticated metrics or disable TLS verification as a fix.

The source includes configuration and helpers. Helm rendering, image startup, metric ingestion and trace collection were not executed in the authoring workspace; record those results on the test cluster. PCI operation tracing does not claim distributed tracing across unmodified OCM components.
