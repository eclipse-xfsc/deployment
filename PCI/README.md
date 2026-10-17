# PCI deployment integration

Deployment files for `eclipse-xfsc/deployment/PCI/`, based on the PCI source
revision recorded in [SOURCE.json](SOURCE.json). Application source, application
tests, release audit reports, specification PDFs and application CI workflows
remain in the [PCI repository](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance).

## Installation in this repository

Extract the ZIP into the root of a checkout of `eclipse-xfsc/deployment`.
The resulting path is `PCI/`; existing INFRA, XFSC and other components are
unchanged. Run all following commands from that directory:

```bash
cd PCI
sha256sum --strict -c deployment-sha256.txt
```

This distribution includes the three PCI, participant and private observability
Helm charts; ground-zero setup; flow/UI installation; upgrade and ownership-aware
uninstall; identity/participant setup helpers; optional operator ORCE automation;
and required runtime artifacts. The exported flow and UI assets in `dist/` are
inputs to installation, so they are retained without the application build tree.

## Prerequisites and deployment

Follow the deployment repository's established `basic-cluster-init.sh` then
`ocm-wstack-init.sh` sequence for the shared stack, and prepare the existing
dedicated PCI ORCE Deployment, Service and persistent `/data` required by the
[PCI deployment guide](docs/operations/deployment.md). This package adds PCI to
those prerequisites; it does not create a replacement shared OCM installation.

The source profile targets OCM ESB 12.3.9. Confirm actual service names and target
compatibility. Required operator tools include Bash, Python 3, Node.js 20+,
kubectl, Helm 3.17+, jq, curl, OpenSSL, tar, base64 and sha256sum.
The optional mesh inventory tool additionally requires PyYAML 6.0.2.
Supply DNS, a suitable TLS certificate, private kubeconfig and editor credentials,
and a real target StorageClass. Keep completed private inputs outside Git.

Copy [automation/lifecycle.example.json](automation/lifecycle.example.json) to a
private location and replace every placeholder for the target cluster. After the
prerequisites and private inputs are ready, run:

```bash
python3 scripts/lifecycle.py deploy --config /private/pci-lifecycle.json
python3 scripts/lifecycle.py upgrade --config /private/pci-lifecycle.json
python3 scripts/lifecycle.py install-artifacts --config /private/pci-lifecycle.json
```

These are separate operations; select the operation required. For a prepared
runtime, the Bash artifact-only upgrade is also available:

```bash
bash scripts/upgrade-artifacts.sh --config /private/pci-lifecycle.json --notes /private/pci-upgrade-notes
```

See [automation](docs/operations/automation.md) for operator ORCE configuration,
first-time legacy ownership inputs, uninstall authorization and retained PVCs.
Uninstall uses the private lifecycle setting `allowUninstall` and, when tenants
exist, the provider session described in that guide:

```bash
python3 scripts/lifecycle.py uninstall --config /private/pci-lifecycle.json
```

## Participant, identity and transport

Use the [participant setup guide](docs/testing/participant-test.md) and supplied
participant chart with an operator-supplied image pinned to its actual digest.
Build/publish that application image through the PCI source repository; its Go
implementation and Docker build context are not duplicated here. The optional
separate synthetic record source includes the flow consumed by its deployment
helper and synthetic example records.

The [ArgoCD example](deployment/argocd/participant-application.example.yaml)
uses `PCI/deployment/helm/participant`. Replace its project, revision, namespace
and nonsecret values. Select either direct Helm or ArgoCD as the resource owner.
No shared ApplicationSet or automatic cluster sync is enabled by extraction.

Read [identity](docs/operations/identity.md), [transport](docs/operations/transport.md)
and the [mesh enrollment profile](deployment/prerequisites/all-hop-tls/README.md)
before configuring those connections. Shared OCM fixes and approvals remain
upstream-owner dependencies; source-code patches are retained in the PCI source
repository rather than this deployment directory.

## Verification and SRS delivery

The checksum manifest covers every delivered file except itself and is the
manifest used by the artifact-only upgrade. When making reviewed changes to
this directory, regenerate it from `PCI/` before committing:

```bash
find . -type f ! -path './deployment-sha256.txt' ! -path './.private/*' ! -path './deployment-private/*' ! -path './deployment-test-notes/*' ! -path '*/__pycache__/*' ! -name '*.pyc' -print0 | sort -z | xargs -0 sha256sum > deployment-sha256.txt
```

Follow the [runbook](docs/operations/runbook.md) for readiness and sizing and
[observability](docs/operations/observability.md) for private telemetry checks.
Unit/regression checks of packaging and lifecycle behavior do not establish
successful deployment or credential issuance on a target cluster.

This directory supplies deployment integration content for FR-PCI-51, 74, 85
and 92. The required deployment-repository PR publication and maintainer merge
are separate delivery actions. No requirement is marked complete by this ZIP.
