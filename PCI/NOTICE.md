# Notices for Eclipse XFSC FACIS Principal Credential Issuance

This content is produced and maintained by the Eclipse Cross-Federation Services
Components (XFSC) project as part of the FACIS work.

- Project home: <https://projects.eclipse.org/projects/technology.xfsc>
- Source repository: <https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance>

## Trademarks

Eclipse XFSC and Eclipse Cross-Federation Services Components are trademarks of the
Eclipse Foundation.

## Copyright

All content is the property of the respective authors or of their employers. For more
information regarding authorship of content, consult the commit history of the
repository and the copyright statements in the source files.

## Declared project licence

This program and the accompanying materials are made available under the terms of
the Apache License, Version 2.0, which is available at
<https://www.apache.org/licenses/LICENSE-2.0>.

SPDX-License-Identifier: Apache-2.0

## Third-party content

Runtime dependencies of the ORCE flows and the browser interface, with the versions
pinned in `package.json` and `package-lock.json`:

| Component | Version | Licence |
|---|---|---|
| Vue (`vendor/vue.global.prod.js`, redistributed in `dist/ui/`) | 3.5.43 | MIT, see `vendor/vue-LICENSE.txt` and `vendor/vue-provenance.json` |
| QR code tables and placement conventions (`src/qr-tables.js`) | derived from the QR encoder of ReportLab 4.4.9 | MIT, see `vendor/qr-tables-LICENSE.txt` |
| `pg` (node-postgres) | 8.16.3 | MIT |
| `jsonwebtoken` | 9.0.2 | MIT |
| `jwks-rsa` | 3.2.0 | MIT |
| `nodemailer` | 10.0.9 | MIT-0 |
| `yaml` | 2.9.1 | ISC |

Development dependency, used by the build and the source checks only and not part of
`dist/` or of any image:

| Component | Version | Licence |
|---|---|---|
| `acorn` | 8.15.0 | MIT |

The participant service under `reference/participant-data-repository/` declares its
Go dependencies in its `go.mod` and `go.sum` (Goa 3.28.0, MIT; Eclipse XFSC Crypto
Provider Core 2.3.0, Apache-2.0; `lestrrat-go/jwx` 2.1.6, MIT; gRPC 1.83.2,
Apache-2.0; protobuf 1.36.11, BSD-3-Clause; `piprate/json-gold` 0.8.0, Apache-2.0).
The deployed test suite declares its Python dependencies in `test/bdd/requirements.txt`
and `test/bdd/constraints.txt` (XFSC BDD Executor, Playwright, Pillow and their
transitive dependencies). The Eclipse Dash licence check runs over all three
dependency sets in the `eclipse-dash` workflow; `THIRD_PARTY_NOTICES.md` lists the
components with their use, and `docs/compatibility/compatibility-matrix.md` the
versions of the services the application is deployed with.

The application runs inside XFSC ORCE (Node-RED with `node-red-contrib-uibuilder`,
both Apache-2.0) and integrates with, but does not redistribute, the XFSC OCM W-Stack,
Keycloak, PostgreSQL and Envoy Gateway. Envoy Gateway may be installed from its pinned
upstream release manifest at deployment time when no accepted GatewayClass exists.

The Software Requirements Specification in `docs/specifications/SRS.pdf` is
distributed under CC BY 4.0 with its original attribution; the Technical Development
Requirements keep their original notices. Both are normative reference documents and
are not relicensed as application source. Their original bytes and hashes are
preserved.

## Cryptography

Content may contain encryption software. The country in which you are currently may
have restrictions on the import, possession, and use, and/or re-export to another
country, of encryption software. BEFORE using any encryption software, please check
the country's laws, regulations and policies concerning the import, possession, or
use, and re-export of encryption software, to see if this is permitted.

The application itself implements no cryptographic algorithm. It verifies JSON Web
Signatures (ES256, PS256, RS256) and computes SHA-256 digests through the Node.js
`crypto` module of the ORCE runtime, delegates issuance signing to the OCM/TSA signer
and the participant's Crypto Provider, and uses TLS as provided by the platform.
