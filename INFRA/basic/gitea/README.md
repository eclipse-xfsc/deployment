# Internal Gitea wrapper

Installs a single-replica internal Gitea instance with SQLite and a persistent volume.

The bootstrap job creates:

- user `tenant-controller`
- organization `platform`
- public repository `deployment`
- initial `products/.gitkeep` and `tenants/.gitkeep`
- personal access token
- Kubernetes Secret `git-controller`

Install:

```bash
helm dependency update .
helm upgrade --install git . \
  --namespace infrastructure \
  --create-namespace
```

Internal endpoints:

```text
HTTP service: git-http.infrastructure.svc.cluster.local:3000
SSH service:  git-ssh.infrastructure.svc.cluster.local:22
Repository:   http://git-http.infrastructure.svc.cluster.local:3000/platform/deployment.git
```

The `git-controller` secret contains:

- `username`
- `password`
- `token`
- `url`
- `repository`

The repository is public for anonymous reads by Argo CD. Only the controller user receives write credentials.

For a non-default release namespace, override:

```yaml
gitea:
  gitea:
    config:
      server:
        DOMAIN: git-http.<namespace>.svc.cluster.local
        ROOT_URL: http://git-http.<namespace>.svc.cluster.local:3000/
        SSH_DOMAIN: git-ssh.<namespace>.svc.cluster.local
```
