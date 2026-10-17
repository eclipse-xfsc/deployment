# Target deployment inputs

Examples use placeholder hostnames, contexts, email addresses and StorageClasses.
Replace them with values from the intended IONOS, OSC or other Kubernetes target.
Keep the completed lifecycle JSON, kubeconfig, TLS private key, editor password,
SMTP/database credentials and session files outside this directory with private
file permissions. The [lifecycle example](../../automation/lifecycle.example.json)
contains no real credentials.

Run commands from `PCI/`. Set `PCI_RELEASE_ROOT` to its absolute path when using
the separate operator ORCE deployment flow. `PCI_DEPLOY_CONFIG` is the absolute
path to the private lifecycle JSON. Select the real cluster context and installed
StorageClasses; no example name proves availability on a target cluster.

Use [deployment](deployment.md), [automation](automation.md), [transport](transport.md)
and [identity](identity.md) for the prerequisites and options. The optional
synthetic datasource deployment helper currently accepts FACIS subdomains only.
