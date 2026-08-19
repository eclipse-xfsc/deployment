# credential-offering-bootstrap

Small REST -> XFSC NATS Request/Reply adapter for starting the credential offering flow at the **IssuanceRequest** entry point.

## Correct XFSC flow

The dummy content signer does not start at `credential.offer.url`. Its `CredentialRequest` registers a NATS reply handler on:

```
<credential configuration Subject>.request
```

For the current `oid4-vci-issuer-dummycontentsigner` metadata the Subject is `issuer.dummycontentsigner`, therefore the default topic is:

```
issuer.dummycontentsigner.request
```

The REST service sends an XFSC `messaging.IssuanceRequest` as CloudEvent type `issuance.request`. The dummy signer then internally creates an `OfferingURLReq`, requests `credential.offer.url`, stores/prepares the credential, and finally responds with `messaging.IssuanceReply` containing the credential offer.

Flow:

```
REST client
  -> POST /api/createOffering
  -> CloudEvent(issuance.request)
  -> NATS request issuer.dummycontentsigner.request
  -> dummycontentsigner CredentialRequest
  -> NATS request credential.offer.url
  -> issuer service / authorization bridge
  -> dummycontentsigner stores credential
  <- IssuanceReply { offer, error, ... }
  <- REST response
```

## REST API

### POST /api/createOffering

Body uses the XFSC `IssuanceRequest` contract:

```json
{
  "tenant_id": "tenant_space",
  "request_id": "optional-request-id",
  "group_id": "optional-group-id",
  "identifier": "DeveloperCredential",
  "payload": {
    "given_name": "Ada",
    "family_name": "Lovelace"
  }
}
```

`request_id` is generated when omitted. `tenant_id` falls back to `DEFAULT_TENANT_ID` / `defaultTenantId`.

Example:

```bash
curl -i \
  -X POST http://localhost:8080/api/createOffering \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "DeveloperCredential",
    "payload": {
      "given_name": "Ada",
      "family_name": "Lovelace"
    }
  }'
```

The successful HTTP response is the `messaging.IssuanceReply` returned by the dummy signer, including its `offer` field. A protocol error from `common.Reply.Error` is mapped to its HTTP status. NATS/request timeout errors return 502.

Health endpoints:

- `GET /health`
- `GET /isalive`

## Configuration

| Environment variable | Helm value | Default |
|---|---|---|
| `NATS_URL` | `nats.url` | `nats://nats.infrastructure.svc.cluster.local:4222` |
| `NATS_ISSUANCE_SUBJECT` | `nats.issuanceSubject` | `issuer.dummycontentsigner.request` |
| `CLOUDEVENT_SOURCE` | `cloudEvent.source` | `credential-offering-bootstrap` |
| `DEFAULT_TENANT_ID` | `defaultTenantId` | `tenant_space` |
| `HTTP_PORT` | fixed by deployment | `8080` |

## Build / test

```bash
go test ./...
go build ./cmd/server
```

## Helm

```bash
helm upgrade --install credential-offering-bootstrap \
  ./charts/credential-offering-bootstrap \
  --set image.repository=YOUR_REGISTRY/credential-offering-bootstrap \
  --set image.tag=0.2.0
```

If another credential plugin is used, set its registered metadata subject plus `.request`, e.g.:

```yaml
nats:
  issuanceSubject: "my.credential.plugin.request"
```
