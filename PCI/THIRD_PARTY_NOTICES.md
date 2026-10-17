# Third-Party Notices

This file lists direct third-party software intentionally used by the FACIS FAP PCI ORCE/uibuilder delivery. Transitive packages must be resolved from the final `package-lock.json` and included in the release SBOM before a production release.

| Component | Selected version | License | Use |
|---|---:|---|---|
| Node-RED | runtime supplied by the existing ORCE installation | Apache-2.0 | Flow runtime |
| `node-red-contrib-uibuilder` | 7.5.0 minimum/install fallback | Apache-2.0 | ORCE-hosted browser UI |
| Vue | 3.5.43 | MIT | Browser UI runtime |
| `pg` / node-postgres | 8.16.3 | MIT | PostgreSQL client used by ORCE Function nodes |
| Nodemailer | 10.0.9 | MIT-0 | SMTP verification/invitation mail |
| `jsonwebtoken` | 9.0.2 | MIT | OIDC ID-token verification |
| `jwks-rsa` | 3.2.0 | MIT | Keycloak JWKS retrieval/cache |
| `yaml` | 2.9.1 | ISC | Parsing the pinned Envoy install manifest |
| Envoy Gateway / Envoy | 1.9.2 / 1.39.2 for fresh PCI bootstrap | Apache-2.0 | PCI Gateway; existing shared controller remains owner-managed |
| PostgreSQL | operator-selected supported release | PostgreSQL License | Managed PCI state store when managed mode is selected |
| Mailpit | operator-selected supported release | MIT | Review/development SMTP capture when Mailpit mode is selected |
| Keycloak | existing OCM deployment | Apache-2.0 | PCI realm, OIDC and role source |
| Goa | 3.28.0 | MIT | Participant service design/generation |
| Crypto Provider Core | 2.3.0 | Apache-2.0 | Official participant signing gRPC client |
| Go gRPC / protobuf | 1.81.1 / 1.36.11 | Apache-2.0 / BSD-3-Clause | Participant transport |
| lestrrat-go/jwx | 2.1.6 | MIT | Participant JWT/JWK verification |
| Jaeger | 2.22.0 | Apache-2.0 | Private PCI trace collection/query |
| OTEL Collector contrib | 0.162.0 | Apache-2.0 | Trace and metric transport |
| Prometheus | 3.15.0 | Apache-2.0 | Private bounded metric storage/query |

No source from these projects is relicensed by this repository. Each component remains subject to its original copyright and license terms.

## Release requirement

This notice is not a substitute for the Eclipse IP process, a complete dependency inventory, or a machine-generated SBOM. The final release must:

1. generate a complete transitive dependency lock;
2. produce source and container SBOMs tied to immutable digests;
3. run the required Eclipse IP and license workflows;
4. resolve every incompatible or unknown-license result before acceptance.

## Offline SR2 source additions

The Vue 3.5.43 browser runtime is vendored from the npm vue package. Its npm integrity and file SHA-256 are recorded in vendor/vue-provenance.json. The MIT notice is in vendor/vue-LICENSE.txt. Node dependencies are recorded in package-lock.json.

QR numeric tables and placement conventions come from ReportLab 4.4.9's locally installed `qrencoder`, credited to Open End AB (2014) and Kazuhiko Arase (2009), under MIT. See `vendor/qr-tables-LICENSE.txt`. The JavaScript encoder and 40-version reference test require no new runtime package. Both notices are copied into `dist/ui/THIRD_PARTY_LICENSES.txt`. Formal Eclipse review is not claimed.

rc.5 participant linked-data processing adds github.com/piprate/json-gold v0.8.0
(Apache-2.0; https://github.com/piprate/json-gold), and cached W3C VC v1 / JWS2020
JSON-LD contexts. Context provenance and W3C license references are recorded in
reference/participant-data-repository/contexts/README.md. Resolved transitive Go
modules and their license/vulnerability review remain part of the CI/IP receipt.
