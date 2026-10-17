# Transport configuration and acceptance

FR-42 requires TLS 1.3 for external connections. The Technical Development Requirements additionally require TLS 1.3 across all endpoints. Those are distinct acceptance scopes. PCI ships strict client/server settings for its supported encrypted links; the selected ESB still exposes some plaintext internal services. The compatibility deployment must not be recorded as passing the all-endpoint criterion.

| Link | Source enforcement | Operator input / evidence |
|---|---|---|
| Browser/wallet → PCI Gateway | ClientTrafficPolicy min/max TLS 1.3; static Secret | Certificate covering each host; reject TLS 1.2; rotation/readiness |
| PCI → participant gRPC | HTTP/2 mTLS, TLS 1.3, peer name and configured trust; bounded DNS/egress | Per-connector client/trust Secrets and actual participant endpoint |
| Participant → record source / Core signer | Verified HTTPS or gRPC TLS 1.3 with configured trust | Participant chart Secret/configuration; external ORCE HTTPS source |
| PCI → native OCM HTTP | `pciNativeTransport`, min/max TLS 1.3 on HTTPS | Explicit service HTTPS URLs and CA/client Secret |
| PCI → NATS | TLS 1.3; verified name; INFO upgrade or handshake-first | `tls://` endpoint; optional authentication and mTLS Secret |
| PCI → Keycloak | Verified HTTPS, TLS 1.3; strict profile refuses HTTP | Real HTTPS identity URL, CA where required |
| PCI → PostgreSQL | `PCI_DATABASE_TLS` or `sslmode=verify-full`; explicit min/max TLS 1.3 | TLS-enabled database and Secret trust/client files; schema-job trust setup |
| PCI → SMTP | Verified TLS 1.3 for TLS/STARTTLS; optional required STARTTLS | TLS-capable relay; `PCI_SMTP_REQUIRE_TLS=true` or secure port |
| PCI/Collector/Prometheus/Jaeger | Supplied telemetry chart TLS settings and bounded runtime exporter | Telemetry Secret and negative-cipher tests |
| Gateway → ORCE, managed PostgreSQL/Mailpit, shared ESB internals | Compatibility chart uses cluster-local plaintext | Supplied all-hop TLS overlay and G0 mesh enrollment; owner-applied rollout and all-hop capture tests |

The last row is **not fixed by enabling client flags**. A service mesh must enforce TLS 1.3, cover workload, job and gateway paths, and not silently fall back to plaintext. Its configuration belongs to the cluster owner. Retain the policy, image digests and observed handshakes as acceptance evidence. G0 does not change shared OCM images or security policies to force this switch.

## Native TLS profile

G0 records these environment settings. Provision the named Secret in the PCI namespace first; G0 mounts it read-only at `/var/run/fap-pci-native-tls`.

```bash
export PCI_NATIVE_TRANSPORT_PROFILE=tls13
export PCI_NATIVE_TLS_SECRET=pci-native-tls
export PCI_NATIVE_TLS_CA_FILE=/var/run/fap-pci-native-tls/ca.crt
export PCI_NATIVE_TLS_CERT_FILE=/var/run/fap-pci-native-tls/tls.crt
export PCI_NATIVE_TLS_KEY_FILE=/var/run/fap-pci-native-tls/tls.key
export PCI_NATS_TLS_CA_FILE=/var/run/fap-pci-native-tls/ca.crt
export PCI_NATS_TLS_CERT_FILE=/var/run/fap-pci-native-tls/tls.crt
export PCI_NATS_TLS_KEY_FILE=/var/run/fap-pci-native-tls/tls.key
```

Set `PCI_SIGNER_URL`, `PCI_WELLKNOWN_URL`, `PCI_STATUS_URL`, `PCI_PREAUTH_URL`, `PCI_ISSUANCE_URL` to actual HTTPS service URLs and `PCI_NATS_URL` to the approved `tls://host:port`. Set `--keycloak-internal-url` to its HTTPS endpoint. Client cert/key are optional together; never supply just one. The strict profile refuses native plaintext endpoints. Blank URL overrides retain discovered defaults, which must then be replaced before using this profile. The default `cluster` profile permits only cluster-local native HTTP; all HTTPS requests still use verified TLS 1.3.

`PCI_NATS_TLS_HANDSHAKE_FIRST=true` selects handshake-first servers. Otherwise the client reads NATS INFO, requires its TLS support, upgrades the socket and only then sends CONNECT/authentication. It never sends a token before TLS on a `tls://` URL. Preserve the configured NATS DNS name in its certificate.

For PostgreSQL, `PCI_DATABASE_TLS=true` and `PCI_DATABASE_TLS_CA_FILE`, `PCI_DATABASE_TLS_CERT_FILE`, `PCI_DATABASE_TLS_KEY_FILE` configure the Node client. Alternatively a `sslmode=verify-full` URL with `sslrootcert`/`sslcert`/`sslkey` is normalized to the same verified Node TLS policy; unsafe URL modes are rejected. G0 mounts the same `PCI_NATIVE_TLS_SECRET` in its PostgreSQL schema/bootstrap jobs and configures libpq with peer verification and TLS 1.3 when `PCI_DATABASE_TLS=true`. Use the mounted paths consistently in both URL and environment settings. Managed PostgreSQL does not become TLS-enabled through client settings alone.

SMTP uses `PCI_SMTP_REQUIRE_TLS` and `PCI_SMTP_TLS_CA_FILE`, `PCI_SMTP_TLS_CERT_FILE`, `PCI_SMTP_TLS_KEY_FILE`. Mailpit mode remains a synthetic test transport. Keycloak's mail configuration is a separate connection and must be configured and tested by the owner when replacing the compatibility mail transport.

Use certificate verification for acceptance. G0's explicit `--keycloak-insecure` diagnostic override cannot be part of compliant deployment evidence. Never use `NODE_TLS_REJECT_UNAUTHORIZED=0`, insecure gRPC, or an unverified NATS URL to clear a failed test.

## rc.5 deployment overlay

The complete owner-inventory renderer, STRICT workload policy, TLS 1.3 mesh
configuration and G0 job injection are supplied under
[all-hop-tls](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/main/deployment/prerequisites/all-hop-tls/README.md).
Set `PCI_MESH_REVISION` during G0 after the owner installs the approved mesh.
This applies to managed workloads and schema/bootstrap jobs. Enroll existing
ORCE, the Gateway data plane and all shared native dependencies using the
UID-bound inventory tool. Keep the cluster transport profile when sidecars
provide TLS; forcing application TLS against HTTP listeners is not equivalent.
