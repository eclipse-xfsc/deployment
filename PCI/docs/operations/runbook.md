# Operations

## Health and diagnostics

`<provider-base>/healthz` is liveness. `<provider-base>/readyz` checks the configured dependencies, including native NATS subscription. G0's setup result is not application acceptance. Test full registration/issuance after flow import.

```bash
kubectl -n xfsc-orce-pci-orce get pods,pvc,httproute
kubectl -n infrastructure get gateway pci-gateway
kubectl -n xfsc-orce-pci-orce logs deploy/xfsc-orce -c orce --since=10m
```

Never enable a Node-RED debug node on an issuance message. Use stable PCI error codes, safe request IDs and tenant conditions. For a missing tenant route, inspect its database conditions and bounded reconciler logs before changing DNS. For email timeout, check both Mailpit ingress and Keycloak egress; a ready Mailpit Pod alone is insufficient.

## Monitoring

`/metrics` requires the internal service token as Bearer authorization. Store the token in the monitoring system's Secret; do not embed it in dashboards. Counters and duration sums use bounded operation/outcome labels, never subject/configuration IDs or tokens. OTLP/HTTP exports operation spans to an existing Collector when `PCI_OTLP_HTTP_ENDPOINT` is set. The default deployment supplies private Jaeger, Prometheus and Collector instances through `deployment/helm/observability/`; [telemetry operations](observability.md) describes verification, sizing and certificate rotation. The older fragments under `deployment/observability/` are examples for an existing managed stack.

These spans measure PCI operations. Demonstrate collection in Jaeger and Prometheus for FR-55/57 acceptance. Unmodified OCM components do not automatically participate in a distributed trace. Do not enable raw request/response tracing to obtain that evidence.

## Back up and restore

Back up PostgreSQL, ORCE `/data`, ownership/configuration Secrets and the long-lived HMAC pepper through the platform's protected backup service. Retrieved participant claims, complete credentials and live access tokens must not appear in PCI database backups; required registration and IAM metadata do remain. Preserve image/chart digests and native source mappings separately.

Before migration, take a database snapshot and flow/UI export. Apply G0 then import generated artifacts. For rollback, restore the prior flow/UI and compatible runtime configuration; additive database tables do not require dropping newer tables. Never rotate the persisted database password just because G0 is rerun. The initial live mismatch was repaired by aligning the database role with the persisted Secrets, not by deleting the volume.

After restore, pending offers and tokens are invalid: require fresh login/new requests. Validate DB connectivity, tenant routing, metadata, public status and a synthetic issuance before returning to service.

## Secret and key rotation

Participant client/trust Secrets are re-read on each call; retain overlap while replacing CA/certificates and test rejection of the old trust after cutover. Native issuer key rotation must retain old verification keys for issued credential lifetimes. Keep key references stable for pinned requests or expire them deliberately. Test Keycloak/JWKS cache and reference participant restarts during IdP rotation.

Static Gateway TLS replacement uses the same owned Secret and configured policy. ACME/cert-manager installation and renewal remain platform-owned; do not install a second controller from PCI. Public TLS is restricted to 1.3.

## Uninstall

Use the [non-interactive lifecycle runner](automation.md) with an explicitly enabled disposable target. The direct shell entrypoint also requires `PCI_ORCE_CURL_CONFIG` with private editor authorization. `--delete-tenants` additionally requires `PCI_PROVIDER_CURL_CONFIG`; it uses confirmed tenant-deletion APIs and waits for reconciliation.

Uninstall refuses active/deleting tenants, foreign references to PCI nodes, modified managed UI files and mismatched original Deployment UID. It removes the recorded PCI flow nodes, restores recorded pre-install UI files and the original ORCE spec, and uninstalls PCI/telemetry Helm releases. Migrated `/data`, PostgreSQL PVCs and backups are retained. It does not delete shared namespaces, OCM or the operator instance. Untracked manual PCI imports require review before removal.

The original Deployment snapshot reflects the first G0 adoption of that installation, not a reconstructed historical pre-PCI state. Artifact ownership starts at the first rc.3 installer run. Test redeploy, upgrade, uninstall and preserved unrelated flows/UI in a disposable environment before final acceptance.

## Incident recovery

Pause affected tenant/configuration issuance when status, identity or signature checks fail. Preserve safe correlation IDs and image versions. Resolve upstream state before retrying an indeterminate signing/revocation operation. Restore service only after a synthetic success and a negative isolation test. Retention, legal holds and deletion of audit associations require an operator-approved policy; this candidate does not invent a purge date. The public route lifetime after confirmed tenant deletion is defined by FR-27/66: those routes are removed.

## Resource sizing

The runtime is intentionally one active ORCE replica because offers, wallet correlation and access tokens are volatile. Keep `replicas: 1` and `Recreate` with the RWO PVC. Do not scale the Deployment horizontally to clear a capacity alarm. Adjust `PCI_ORCE_CPU_REQUEST`, `PCI_ORCE_MEMORY_REQUEST`, `PCI_ORCE_CPU_LIMIT` and `PCI_ORCE_MEMORY_LIMIT` before G0 if the existing bounds are unsuitable. Existing ORCE resource settings are preserved unless an override is supplied; missing values receive bounded defaults. Participant and telemetry chart values expose their own resources. Managed PostgreSQL requests 100m/256Mi with 1 CPU/1Gi limits; edit the packaged dist/ground-zero.sh deployment manifest through review and regenerate deployment-sha256.txt. Scale down by pausing issuance and scheduling maintenance before reducing limits. Record saturation/recovery and memory results under the agreed target load.
