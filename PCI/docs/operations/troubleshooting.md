# Troubleshooting and FAQ

This page collects the questions operators, tenant administrators and principals ask
most often, and what to check for each. Error responses carry a stable `code` and a
`correlation_id`; quote both when you report a problem. Logs contain the code and the
correlation reference, never tokens, credentials or participant data.

## Readiness

`<provider-base>/healthz` answers as soon as the ORCE flows are loaded.
`<provider-base>/readyz` checks the dependencies one after the other and stops at the
first that fails; the log line `pci.readiness.failed` names that step:

| `check` in the log | What failed | What to look at |
|---|---|---|
| `database` | `SELECT 1` on the PCI database | the `fap-pci-postgres` pod or the managed database, `PCI_DATABASE_URL` and its TLS settings (`sslmode=verify-full` or `PCI_DATABASE_TLS`) |
| `native-listener` | the NATS subscription for native callbacks | `PCI_NATS_URL`, the NATS service of OCM, NATS credentials; see the NATS codes below |
| `platform-state` | the ground-zero platform record | G0 has not completed for this installation; rerun G0 |
| `gateway` | the PCI Gateway is missing or not `Programmed` | `kubectl -n infrastructure get gateway pci-gateway -o yaml`, the Envoy Gateway controller |
| `dns` | the main host does not resolve to the Gateway address | the DNS record of `PCI_MAIN_HOST` |
| `keycloak-discovery` | Keycloak's OIDC discovery is unreachable or names another issuer | `PCI_KEYCLOAK_INTERNAL_URL`, `PCI_KEYCLOAK_PUBLIC_URL`, the realm |

```bash
kubectl -n xfsc-orce-pci-orce logs deploy/xfsc-orce --since=10m | grep pci.readiness.failed
```

## Error codes

| Code | Meaning | What to do |
|---|---|---|
| `PCI-AUTHN-401-001` | no valid session | sign in again; the session lasts `PCI_SESSION_TTL_MINUTES` (default 480) |
| `PCI-AUTHZ-403-001`, `PCI-SR2-FORBIDDEN` | the role or membership does not allow the action | ask the tenant administrator for issuer access under **Access & members** |
| `PCI-TENANT-403-001` | the routed host and the requested tenant do not match | use the tenant's own address; a proxy must not rewrite `Host` |
| `PCI-SR2-INELIGIBLE` | the configuration is not available to this principal | check the eligibility rules of the configuration |
| `PCI-SR2-PRECONDITION` (412, 428) | the resource changed since it was loaded, or no version was sent | reload and save again |
| `PCI-SR2-CONFLICT` | the identifier already exists in the tenant | choose another identifier |
| `PCI-CONFIG-PREREQUISITES` | the configuration cannot be published yet | the message names what is missing: participant connector, issuance journey, issuer metadata |
| `PCI-METADATA-NOT-ACTIVE` | publication before issuer metadata was activated | save and activate the issuer metadata first |
| `PCI-SR2-RATE` (429) | the tenant or configuration rate limit is reached | wait; the limits are under **Tenant settings → Issuance limits** |
| `PCI-SR2-EXPIRED` (410) | the issuance request expired (ten minutes) | start a new request |
| `PCI-SR2-REPLAY` | the offer was already prepared or the request consumed | start a new request if the offer was lost |
| `PCI-SR2-INPUT-LOST` | journey input was lost because ORCE restarted | the interface returns to the input step; enter the values again |
| `PCI-SR2-TENANT-INACTIVE` | the tenant is suspended, provisioning or being deleted | check the tenant state in the provider view |
| `PCI-SR2-REISSUANCE-BLOCKED` | reissuance is blocked after a revocation | an issuer administrator removes the block in the history view |
| `PCI-REVOCATION-IN-PROGRESS`, `PCI-REVOCATION-PENDING` | a revocation is still being reconciled with the status service | reload the history after a short while |
| `PCI-PROOF-INVALID` | the wallet's proof is malformed or its key invalid | update the wallet; check the wallet's supported proof types |
| `PCI-VP-*` | presentation verification failed (malformed response, replay, wrong confirmation code, capacity) | start a new presentation request; the message names the reason |
| `PCI-NATS-NO-RESPONDER` | no OCM service listens on the configured NATS subject | check the OCM service and its subject configuration |
| `PCI-NATS-TIMEOUT` | OCM did not answer before the deadline | check OCM's logs before retrying a signing or issuance operation |
| `PCI-NATS-CONNECT-TIMEOUT`, `PCI-NATS-DISCONNECTED`, `PCI-NATS-TLS-REQUIRED`, `PCI-NATS-UNEXPECTED-PLAINTEXT` | the NATS connection failed or its transport does not match the configuration | check `PCI_NATS_URL` and whether the NATS endpoint uses TLS |
| `PCI-OCM-HTTP` (502) | a native OCM service rejected the operation | check the OCM service's logs with the correlation reference |
| `PCI-INTERNAL-500-001` | an unexpected internal error | the log line `pci.operation.failed` with the correlation reference names the code and the function node |

## Questions

**The tenant page shows "No active tenant is assigned to this host."**
The host is not the primary domain of a tenant in the state `provisioning` or `active`.
Check the tenant state in the provider view (suspended, deleting or deleted tenants are
not served) and the tenant's DNS record.

**Sign-in returns to the sign-in page.**
Check that the browser accepts the `fap_pci_session` cookie for the PCI host (it is
`Secure`, `HttpOnly`, `SameSite=Lax`, path = the ORCE base path) and that the clock of
the client is correct. On the provider host only provider administrators can sign in;
organization accounts sign in on their tenant's host.

**Organization sign-in (Entra or another OIDC provider) fails.**
The redirect URI registered at the provider must be exactly the one shown under
**Tenant settings → Organization sign-in**. The issuer must be on the operator's allow
list. See [tenant identity providers](identity.md).

**A configuration cannot be published.**
The validation message names the missing prerequisites. Activate the participant
connector, publish a journey and activate the issuer metadata, then validate again.

**The wallet shows an error after scanning the QR code.**
Check the issuer metadata publication under **Tenant settings → Issuer metadata**
(native Well-Known publication), the signing key of the configuration and the
participant connector; then start a new request, because an offer is consumed once.

**After an ORCE restart, a principal has to start again.**
Offers, callbacks and journey input live in process memory for at most the request
lifetime; a restart discards them by design. Requests in progress return to their last
safe step.

**The branding does not change.**
Branding applies after **Activate branding**. Colors are refused if they would make
text unreadable (at least 4.5:1 contrast). The provider and registration pages always
use the FACIS standard.

**How do I install or upgrade?**
See [deployment](deployment.md) and, for the application image, [deploying the
application image](deployment.md#deploying-the-application-image). Take the backup of
[backup and rollback](backup-rollback.md) before an upgrade.

**Where do I report a problem?**
Non-sensitive problems: the issue tracker of the repository, with the code, the
correlation reference and the version from `/healthz`. Security problems: see
`SECURITY.md`.
