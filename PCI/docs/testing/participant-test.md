# Participant data for end-to-end testing

FR-22 requires a Go/Goa service reusing Crypto Provider Core; FR-24 requires gRPC. The importable ORCE flow is the **synthetic record store behind that service**. It receives scoped record identifiers, never the participant access token or a credential. It does not replace OCM offers, signing, metadata, status or wallet callbacks.

The call sequence is PCI → mTLS gRPC Go/Goa repository → HTTPS ORCE record flow. Internal-signing mode sends the validated claims onward to the native OCM signer. Participant-signed mode uses the repository's official Crypto Provider Core gRPC client and a separately approved TLS endpoint. The selected OCM sidecar listens on loopback: do not expose it, change its Deployment or relax OpenBao permissions to make this test pass.

## 1. Prepare the separate ORCE record store

Use a dedicated internet-reachable ORCE instance with a valid TLS 1.3 certificate. Import `reference/participant-data-source/flows.json` there and deploy its tab. This flow uses only core HTTP/Function/Response nodes and Node's built-in `crypto`; Function external modules must be enabled in that ORCE instance. The endpoint is:

```text
https://<datasource-host>/<ORCE-base>/participant-test/v1/records
```

Keep the editor separately authenticated. Use only synthetic employee values. Copy `records.example.json` to a private file and replace its three identifiers with the actual tenant UUID, credential-configuration UUID and **participant token `sub`**. Use the Keycloak subject when the PCI realm issues the participant token; use the actual Entra subject when testing Entra. A username/email or PCI pseudonymous subject hash is not interchangeable with `sub`.

```json
{
  "<tenant UUID>": {
    "<configuration UUID>": {
      "<participant token sub>": {
        "name": "Alex Example",
        "employeeId": "TEST-001",
        "department": "Engineering"
      }
    }
  }
}
```

Create the configuration as a draft first to obtain its UUID. Use the actual tenant and configuration UUIDs from the intended installation. Configure records on the separate datasource ORCE (replace the three datasource deployment arguments):

```bash
python3 scripts/configure-test-source.py \
  --context cluster-admin@ocm-cr \
  --namespace <datasource-namespace> \
  --deployment <datasource-deployment> \
  --container orce \
  --records /private/participant-records.json \
  --token-file /private/participant-source.token
```

This creates a random shared source token, writes a private mode-0600 token file, and patches only that datasource deployment. Repeat the command with the same private token file to update records. It preserves the existing token, checks the Secret's Deployment UID/container ownership, and rolls out only when the record revision or environment binding changes. Identical reapplication performs no rollout. An interrupted initial creation reuses its private token file. A foreign Secret, replacement Deployment or mismatched token file stops the operation. Use `--kubeconfig /private/kubeconfig` when the default kubeconfig is not the approved one. The HTTP endpoint returns 401 without the token and 404 for an absent tenant/configuration/subject. No sample bearer token is shipped.

## 2. Build the required repository

Build and test the participant image in a separate checkout of the [pinned PCI source](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/tree/3fef8e3048f3803b8aecbd99f582a3c4c05295b0), or use its participant CI/release jobs. The Go source and Dockerfile are deliberately absent from this deployment directory. Run the following commands from that separate source checkout:

```bash
bash reference/participant-data-repository/generate.sh
(
  cd reference/participant-data-repository
  go vet -tags=generated ./...
  go test -race -tags=generated ./...
  go build -tags=generated ./cmd/server
)
docker build -f reference/participant-data-repository/Dockerfile \
  -t <approved-registry>/pci-participant:0.5.0-rc.12 .
```

Publish the image only through the participant owner's approved registry process. Record its resulting `@sha256:...` digest and retain `go.sum`, generated source and test output as release evidence. The main PCI application still consists of imported ORCE flows and UI; this container is the service expressly required by the SRS. It was not built or published on your behalf.

## 3. Deploy and obtain exact connector values

```bash
python3 scripts/deploy-participant.py \
  --kubeconfig "$KUBECONFIG" \
  --context cluster-admin@ocm-cr \
  --pci-namespace xfsc-orce-pci-orce \
  --orce-deployment xfsc-orce \
  --orce-container orce \
  --tenant-id <actual-tenant-UUID> \
  --configuration-id <actual-configuration-UUID> \
  --image <approved-registry>/pci-participant@sha256:<digest> \
  --source-url https://<datasource-host>/<ORCE-base>/participant-test/v1/records \
  --source-token-file /private/participant-source.token
```

The helper discovers the tenant's owner, creates a participant-owned namespace, issues distinct test client/server certificates, stores trust material in Secrets and grants PCI read access to only its named client Secret. It discovers public IdP JWKS, pins the service DNS/private address in PCI's allowlist and prints nonsecret connector values. Changes to those allowlists can cause one controlled PCI restart. Reapplying reloads changed JWKS/source trust. It does not alter OCM or the deployer ORCE.

The test certificates expire after 90 days. Review them before expiry and replace the server/client pair together through the participant owner's certificate process; the helper preserves existing identities. These certificates are not a production certificate lifecycle service. Source credentials remain participant-owned. The test namespace and its synthetic records are separately decommissioned after testing; PCI never deletes a participant's independent data repository.

## 4. Fill the PCI connector

Copy the helper's `connector` values into **Connectors → New connector**: endpoint, TLS server name, two Secret names, JWT issuer, audience, scopes, timeout and configuration access. Enable **Internal signing** first. The access list must include the configuration just created. Save and activate.

For **Participant signed**, the participant owner must provide a working Crypto Provider Core endpoint with TLS 1.3, client authentication, the matching issuer key and `ocm-wstack/<tenant UUID>` authorization. Rerun the helper with `--crypto-endpoint`, `--crypto-server-name`, `--crypto-cert`, `--crypto-key` and `--crypto-ca`. Enable this mode only after that endpoint is verified. No alternate mock signing path is provided.

The server loads a public JWKS snapshot at startup. Reapply the helper after IdP key rotation to refresh the snapshot and restart the repository. For an Entra-issued participant token pass its exact `--jwt-issuer`, `--jwt-audience` and `--jwt-scopes`; verify broker mapping and connector trust as described in [identity](../operations/identity.md).

## 5. Complete the real issuance

Use the [acceptance order](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/3fef8e3048f3803b8aecbd99f582a3c4c05295b0/docs/testing/acceptance-walkthrough.md). Publish a journey, select it and the connector on the configuration, set `issuer` as the key reference, validate, publish locally, then publish metadata to OCM. Sign in as the intended principal whose `sub` has synthetic records. Complete the journey and scan the native offer using PCM when available.

An offer/QR is only the start of issuance. PASS requires the native callback, authenticated participant retrieval, OCM signing, wallet import, independent signature/status verification and history entry. Repeat with bad source token, absent record, wrong/expired client certificate, wrong JWT issuer/audience/scope/subject, timeout and cross-tenant requests. Preserve sanitized outcomes; do not attach access tokens, offers or credentials to shared logs.

## Linked-data signing and cleanup in rc.4

All participant-signed formats, including `ldp_vc`, use `--crypto-endpoint`,
`--crypto-server-name`, `--crypto-cert`, `--crypto-key` and `--crypto-ca`.
The rc.4 `--ldp-*` HTTP signer options are removed. The reference signs detached
ES256 JWS2020 through Core gRPC after offline URDNA2015 normalization. Claims
are under `credentialSubject.pciClaims`; envelope terms retain W3C semantics.
Build, race-test and verify against the actual native verifier before acceptance.

Each helper namespace is exclusive to one tenant and registered with Kubernetes UID and owner identities. Re-running the helper enrolls an existing rc.3 short-name namespace. Tenant deletion waits for namespace termination, thereby removing its Helm record, workload and Secrets. Named cleanup grants are then removed. A foreign owner or replacement UID blocks deletion. Uninstall also restores journaled runtime overrides and removes owned telemetry trust; see the [legacy baseline limitation](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/3fef8e3048f3803b8aecbd99f582a3c4c05295b0/docs/operations/upgrade-0.5.0-rc.5.md).
