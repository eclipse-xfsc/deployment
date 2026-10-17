# Non-interactive deployment lifecycle

Domains, mailbox addresses, private file paths, contexts and StorageClasses in this guide are examples. Supply target deployment values as described in [neutral configuration](neutral-configuration.md).

`scripts/lifecycle.py` performs deploy, upgrade and uninstall with an administrator-provided configuration. `automation/flows/pci-deployment.json` exposes the same operations inside a separate **operator ORCE**, using manual Inject nodes. It never installs itself in PCI's public runtime or accepts an arbitrary command from an HTTP request.

## Operator configuration

Install Python 3, Bash, kubectl, Helm, jq, curl, OpenSSL, Node.js and this PCI deployment directory on the operator host. Mount the approved kubeconfig, certificate/key and editor password as private files. In an operator pod use Kubernetes Secret volumes. `PCI_RELEASE_ROOT` is the absolute path to eclipse-xfsc/deployment/PCI; `PCI_DEPLOY_CONFIG` is an absolute private JSON file. The Function node needs `child_process` and `path`, as declared by its imported library entries. Limit editor access to deployment operators.

Create this file outside the source tree with mode 0600; replace paths and the complete G0 argument list for the target cluster:

```json
{
  "g0Args": [
    "--kubeconfig", "/private/kubeconfig",
    "--context", "cluster-admin@ocm-cr",
    "--orce-namespace", "xfsc-orce-pci-orce",
    "--orce-deployment", "xfsc-orce",
    "--orce-service", "xfsc-orce-service-pci-orce",
    "--orce-container", "orce",
    "--orce-base-path", "/pci-orce",
    "--main-host", "pci.example.com",
    "--cert", "/private/fullchain.pem",
    "--key", "/private/privkey.pem",
    "--provider-email", "provider@example.com",
    "--ocm-namespace", "ocm-wstack",
    "--keycloak-service-name", "ocm-ui-keycloak",
    "--keycloak-internal-url", "http://ocm-ui-keycloak.ocm-wstack.svc.cluster.local:8080/orce/identity",
    "--infrastructure-namespace", "infrastructure",
    "--envoy-namespace", "infrastructure",
    "--gateway-class-name", "envoy",
    "--gateway-name", "pci-gateway",
    "--orce-data-storage-class", "ionos-cloud-essential",
    "--postgres-storage-class", "ionos-cloud-essential",
    "--mail-mode", "mailpit"
  ],
  "editorUrl": "https://pci.example.com/pci-orce/",
  "editorUsername": "admin",
  "editorPasswordFile": "/private/orce-editor-password",
  "environment": {"PCI_OBSERVABILITY_MODE": "managed"},
  "allowUninstall": false
}
```

The shown ESB internal HTTP endpoint is the compatibility profile. Use the approved HTTPS endpoint and [transport settings](transport.md) for encrypted dependency connections. The runner does not invent certificates or rewrite OCM services.

After provisioning those inputs, the following commands require no interactive password prompt:

```bash
python3 scripts/lifecycle.py deploy --config /private/pci-lifecycle.json
python3 scripts/lifecycle.py upgrade --config /private/pci-lifecycle.json
```

To resume after completed prerequisites without rerunning G0, use `python3 scripts/lifecycle.py install-artifacts --config /private/pci-lifecycle.json`. This uses the same password-file authentication and imports only flow/UI artifacts.

The runner pins a private kubeconfig to the requested context, runs G0/telemetry, obtains editor authorization, and installs the flow/UI with optimistic revision checks. Child output is kept off ORCE context; JSON failures expose the phase, safe error code, detail, next step and child exit code without copying potentially sensitive output. Failures stop the run with a nonzero exit code. The configuration lock prevents overlapping runs. Child process groups have bounded deadlines and are terminated on cancellation. An interrupted prerequisite phase can be rerun; it is not a transactional cluster rollback.

## Artifact ownership and uninstall

The installer records imported PCI node IDs and prior UI file hashes under `/data/fap-pci/install/`. It retains non-PCI nodes, snapshots overwritten UI assets and refuses symlink/traversal paths. Uninstall removes only recorded PCI nodes; a foreign node referring to a managed node stops removal. It restores prior UI files only when the installed copy still matches its recorded hash. A user-modified file stops removal for review.

For a disposable deployment, set `allowUninstall` to true. With active tenants, provide `providerCurlConfig` pointing to a private curl configuration containing an authenticated **provider** session. The runner calls the normal confirmed tenant-deletion API, waits for reconciliation, removes managed artifacts, removes PCI-owned runtime references, and uninstalls the PCI releases. The runtime patch checks both the original Deployment UID and current resource version. It preserves later image, resource, replica, probe, sidecar and annotation changes, plus the migrated persistent data volume; it refuses foreign references to a PCI volume. The snapshot supplies baseline values for owned fields, not a replacement for the live Deployment. Without that provider credential, delete tenants in the UI first. A G0-only installation with no imported PCI tabs can also be removed; untracked manual imports are refused.

```bash
python3 scripts/lifecycle.py uninstall --config /private/pci-lifecycle.json
```

The migrated ORCE PVC, PostgreSQL PVC and backups are retained. Uninstall is not a data-erasure operation. Existing shared OCM deployments and the operator ORCE are outside its ownership. Run lifecycle acceptance in a dedicated test environment before operating the production instance. See [completion tests](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/3fef8e3048f3803b8aecbd99f582a3c4c05295b0/docs/testing/completion.md).
