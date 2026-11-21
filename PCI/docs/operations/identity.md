# Tenant identity providers

Browser login uses Keycloak authorization code + PKCE. Access tokens remain in process memory; restarting ORCE requires fresh issuance authentication. A tenant administrator configures organization sign-in under **Tenant settings → Organization sign-in**, or uses the tenant API. The native administrator sign-in remains available for repair.

## The Organization sign-in tab

**Tenant settings** has six tabs: Branding, Signing keys, Organization sign-in, Issuer
metadata, Issuance limits and Lifecycle. The Organization sign-in tab shows the state
and version of the tenant's identity configuration and one form:

| Field | Meaning |
|---|---|
| Identity provider | `PCI Keycloak accounts` for invited local accounts, or `Microsoft Entra or approved OIDC` for a brokered organization directory |
| Sign-in display name | The name shown on the sign-in page for this organization (at most 100 characters) |
| OIDC issuer URL | Only for OIDC: the HTTPS issuer, for Entra `https://login.microsoftonline.com/<directory UUID>/v2.0`; other issuers must be on the operator's allow list |
| OIDC client ID | The confidential client registered at the provider |
| Client secret | Write-only; left blank, the stored secret is kept. It is never shown again and is cleared from the form after every save |
| Participant API audience | The audience of the external API token that the participant repository verifies |
| OIDC scopes | Must include `openid profile email`; add the participant API scope |
| Register this redirect URI | Read-only: the exact redirect URI to register at the provider |

**Save identity provider** sends `PUT /api/v1/tenants/{tenantId}/identity-provider` with
the current version as `If-Match`; a change made elsewhere in the meantime is reported
as a conflict and the form is reloaded with the new version. On success the
configuration is `active` with the next version and the user is asked to sign in again
to use it. If the broker write fails, the revision stays `pending` and can be saved
again; principal issuance is blocked while a revision is pending. New organization
accounts receive principal access only; issuer administration is granted under
**Access & members**. The button is disabled while a request is running and until the
current configuration has been loaded.

## Configuration

G0 creates the signed `pci_identity_provider` session-note mapper, the `pci_tenant_identity` table, and the named `fap-pci-identity` Kubernetes Secret with narrowly scoped read/patch permissions. The Secret is maintained outside Helm values/history and preserved during upgrades. Broker credentials are rooted in this Secret and copied to Keycloak's broker configuration. GET responses, audit records and database metadata never include the client secret. Client-secret backup/encryption and Keycloak token retention remain operator responsibilities.

The API is `GET` / `PUT /api/v1/tenants/{tenantId}/identity-provider`. PUT requires the current quoted `If-Match`, a same-origin JSON request, and an enabled tenant-admin membership. Alias `pci-<full tenant UUID>` is server-controlled. A durable pending revision blocks principal issuance before external changes; failures remain pending and can be retried from the UI with the new revision. A blank secret retains the matching stored credential. Changing issuer/client requires a new secret. Concurrent writes cannot silently replace each other.

Select PCI Keycloak for invited local accounts. For Entra, create a single-tenant confidential web application, register the exact redirect URI displayed in the UI, and grant its delegated participant API scope. Enter `https://login.microsoftonline.com/<directory UUID>/v2.0`, client ID, secret, the participant API audience and scopes including `openid profile email`. Tokens for Microsoft Graph do not satisfy the participant API audience.

For another OIDC provider, the operator must add its exact HTTPS issuer to `PCI_IDENTITY_ALLOWED_ISSUERS` before G0. Discovery authorization, token and JWKS URLs must remain on that issuer's approved origin. HTTP and redirects are refused. No tenant can choose an arbitrary broker alias or supply administrative claim mappings.

```bash
python3 scripts/configure-entra.py \
  --pci-url https://alpha-pci.example.com/pci-orce \
  --pci-tenant-id <PCI-tenant-UUID> \
  --session-cookie-file /private/tenant-admin-cookie \
  --tenant-id <Entra-directory-UUID> \
  --client-id <Entra-application-UUID> \
  --client-secret-file /private/entra-secret \
  --audience <participant-API-audience> \
  --scopes 'openid profile email api://<API-application-ID>/credential:issue'
```

The cookie file contains `fap_pci_session=<private value>`. The CLI uses the same tenant-admin API and authorization as the UI. The rc.3 global `entra` alias and `PCI_ENTRA_ISSUERS` configuration are superseded; reconfigure each tenant using this API.

## Admission and authorization

The signed Keycloak session note must identify this tenant's active broker. PCI retrieves and cryptographically verifies the external API token, exact issuer, audience, subject and expiry before admitting a fresh account. A foreign tenant membership, disabled membership or brokered provider-admin role is rejected. A new brokered account receives only `principal`; administrative rights come from existing local membership and explicit delegation. Default Keycloak first-broker-login verification is retained; email alone does not authorize account linking. The runtime uses the configured tenant alias when retrieving a participant token and repeats session/revision checks before issuance. Provider changes invalidate principal sessions and old pending offers.

External roles/groups become eligibility entitlements (`role:<value>`, `group:<value>`); they do not grant PCI administrative roles. The participant repository repeats token signature, audience, issuer and scope verification over mTLS. Permission changes in the external IdP require token expiry/re-authentication unless revocation is propagated.

## MFA and passkeys

G0 and invitations require temporary-password change and TOTP enrollment. G0 enables passwordless WebAuthn, discoverable credentials and user verification for the selected Keycloak baseline. The RP host is Keycloak's host. Existing passwords are preserved. Test recovery and physical authenticators in addition to the authored browser virtual-authenticator regression.

Run `test/bdd/features/fresh-identity.feature` with private, version-specific selectors and credential files. Fresh contexts must not import saved sessions. Entra conditional access and real provider/network setup are acceptance prerequisites.

References: [Keycloak session notes](https://github.com/keycloak/keycloak/blob/main/docs/documentation/server_admin/topics/identity-broker/session-data.adoc), [Keycloak administration](https://www.keycloak.org/docs/latest/server_admin/index.html), [Microsoft OIDC](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc).
