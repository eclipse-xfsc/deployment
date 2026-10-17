# Deployment and upgrade

Domains, mailbox addresses, private file paths, contexts and StorageClasses in this guide are examples. Supply target deployment values as described in [neutral configuration](neutral-configuration.md).

PCI uses one active ORCE replica. PostgreSQL stores configuration and safe history; live access tokens, wallet offers and proof nonces stay in process memory. A restart invalidates pending offers and requires affected users to sign in again. Do not enable HPA or multiple ORCE replicas without a reviewed privacy-preserving coordination design.

## Before G0

- Existing dedicated PCI ORCE Deployment, Service and `/data`; OCM ESB 12.3.9 already installed.
- Kubernetes 1.33–1.36, Helm 3.17+ (`--take-ownership`), kubectl, Python 3, jq, OpenSSL, curl, tar, base64 and sha256sum.
- A certificate covering the provider, tenant hostnames and Mailpit if exposed. `*.example.com` covers `alpha-pci.example.com`; `*.pci.example.com` does not.
- DNS A records for `pci.example.com`, `mailpit-pci.example.com` when used, and each `<slug>-pci.example.com`, pointing to the PCI Gateway address printed by G0.
- G0 automatically adds a separately owned NetworkPolicy in the OCM namespace for PCI ORCE → Keycloak and Keycloak → PCI Mailpit/SMTP. It discovers the Keycloak Service selector and target port, preserves existing policies, and does not newly isolate unrestricted directions. The deployment kubeconfig must allow reading Services, Pods and NetworkPolicies and creating/updating that policy. Runtime service-account permissions are unchanged. External OIDC broker egress remains an OCM-owner configuration; the optional prerequisite file documents it.

Run `scripts/preflight.sh xfsc-orce-pci-orce xfsc-orce orce`. It checks the selected ESB service names and socket reachability from ORCE. This is read-only and does not prove native API compatibility. For an older OCM layout, use explicit G0 service/URL arguments after inspecting the actual Services.

## G0 for the supplied new OCM layout

From the repository root, with the kubeconfig already set:

```bash
./scripts/deploy.sh \
  --kubeconfig "$KUBECONFIG" \
  --context cluster-admin@ocm-cr \
  --orce-namespace xfsc-orce-pci-orce \
  --orce-deployment xfsc-orce \
  --orce-service xfsc-orce-service-pci-orce \
  --orce-container orce \
  --orce-base-path /pci-orce \
  --main-host pci.example.com \
  --cert /private/fullchain.pem \
  --key /private/privkey.pem \
  --provider-email provider@example.com \
  --ocm-namespace ocm-wstack \
  --keycloak-service-name ocm-ui-keycloak \
  --keycloak-internal-url http://ocm-ui-keycloak.ocm-wstack.svc.cluster.local:8080/orce/identity \
  --infrastructure-namespace infrastructure \
  --envoy-namespace infrastructure \
  --gateway-class-name envoy \
  --gateway-name pci-gateway \
  --orce-data-storage-class ionos-cloud-essential \
  --postgres-storage-class ionos-cloud-essential \
  --mail-mode mailpit
```

`--keycloak-public-url` is discovered from the selected Keycloak workload's public hostname; set it explicitly if discovery is ambiguous. The previous cluster used `keycloak` on port 80 and no `/orce/identity` prefix. Do not copy that old URL onto ESB 12.3.9.

StorageClass names are cluster-specific; the current IONOS cluster uses `ionos-cloud-essential`. Select the actual installed class on the second cluster. External PostgreSQL is supported with `--database-mode external --database-url ...`; manage that credential privately.

G0 reuses the selected Envoy 1.9 controller and validates its GatewayClass. A new installation uses v1.9.2 with the official release asset SHA-256. Its PCI-only EnvoyProxy pins v1.39.2, one replica and bounded resources, following the upstream TLS security fix. An existing shared controller and other Gateways require their owner's upgrade review. Recheck PCI Gateway/xDS acceptance after the proxy rollout. PCI owns its own Gateway, not OCM's Gateway. A second public IP is permitted. G0 creates no duplicate Keycloak, NATS or signer. Mailpit mode scales the unused SMTP relay to zero; production SMTP mode scales Mailpit to zero unless explicitly exposed.

`scripts/deploy.sh` also installs the private [telemetry instances](observability.md) required by FR-55/56/57. For the exact current-cluster command and one-shot flow/UI upload see [historical rc.4 upgrade](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/3fef8e3048f3803b8aecbd99f582a3c4c05295b0/docs/operations/upgrade-0.5.0-rc.4.md).

## Import and verify

For a disposable development cluster, this procedure requires no backup. For retained environments, follow the owner's recovery policy. G0 preserves `/data`, persists generated passwords, initializes the additive schema and patches ORCE only if its runtime configuration changed. It excludes dependency caches during storage migration. It records PCI prerequisite objects in Helm release `fap-pci`; it refuses adoption of another release's objects.

Import **the new** `dist/fap-pci-flow.json` and replace the existing PCI nodes using their stable IDs. Copy all `dist/ui/*` into `/data/uibuilder/ui/src/`. Earlier uploaded 0.4.1 flow/UI files do not contain these native adapters. Use the editor's modified-flows deployment; do not restart ORCE just to import files. The optional `automation/stage1/install.sh` performs the established merge workflow—read its `--help` and provide the correct editor authorization.

Check `/pci-orce/readyz`, `/pci-orce/api/v1/platform/status`, the provider UI and tenant routes. Readiness includes the native NATS subscription; G0's final `Ready` means prerequisite setup, not successful wallet issuance.

## Additional runtime settings

Set these environment variables before G0; its configmap records them:

| Variable | Purpose |
|---|---|
| `PCI_NATS_URL` | Selected native NATS endpoint; ESB default is `nats.infrastructure:4222` |
| `PCI_PARTICIPANT_ALLOWED_HOSTS` | Comma-separated approved repository DNS names |
| `PCI_PARTICIPANT_PRIVATE_ADDRESSES` | Exact approved private addresses for participant DNS pinning |
| `PCI_PARTICIPANT_JWT_ISSUERS` | Approved issuer URLs; default PCI Keycloak realm |
| `PCI_ENTRA_ISSUERS` | Approved Entra v2 tenant issuer URLs |
| `PCI_OTLP_HTTP_ENDPOINT` | Existing OTLP/HTTP Collector base URL |

NATS authentication is supported in runtime variables `PCI_NATS_USER`, `PCI_NATS_PASSWORD` or `PCI_NATS_TOKEN`; provision them through an operator-controlled Secret/environment, never a UI field. Selected ESB uses plain internal NATS/HTTP. End-to-end transport encryption requires an OCM-owner deployment change; see FR-PCI-42.

G0 restricts direct ORCE ingress to the PCI Gateway. Check and remove any independently managed permissive NetworkPolicies that would add an alternate allowed path. Kubernetes policies are additive.

For full non-interactive deployment and ownership-aware uninstall see [automation](automation.md). For TLS endpoint overrides, native Secret mounts, database/SMTP client settings and the distinction between external and all-hop encryption see [transport](transport.md). G0 preserves Kubernetes credentials; local plaintext bootstrap export is disabled unless `PCI_EXPORT_BOOTSTRAP_CREDENTIALS=true` is explicitly selected.
