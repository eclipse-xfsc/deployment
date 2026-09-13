# orce-clusteradmin

Goa-v3-basierter REST-Service für Remote-Kubernetes-Cluster-Administration per übergebener Base64-kodierter kubeconfig.

## Endpoints

- `GET /health`
- `POST /install`
- `POST /uninstall`
- `POST /installations`
- `POST /checkComponentStatus`

Alle fachlichen Fehler werden im JSON-Response zurückgegeben (`success=false`, `errors`, `stdout`, `stderr`). HTTP 200 ist bewusst möglich, damit Node-RED die Response sauber auswerten kann.

## Helm-Repositories

Der Service bekommt Helm-Repositories über `config.yaml`. Vor jedem Install wird intern ein temporäres Helm-Repo-File erzeugt und die Repos werden wie bei `helm repo add && helm repo update` vorbereitet.

```yaml
server:
  address: ":8080"
helm:
  repositories:
    - name: argo
      url: https://argoproj.github.io/argo-helm
    - name: bitnami
      url: https://charts.bitnami.com/bitnami
```

Dann funktionieren Chart-Refs wie:

```json
"chartRef": "argo/argo-cd"
```

## Generieren und Starten

```bash
go install goa.design/goa/v3/cmd/goa@latest
go mod tidy
goa gen orce-clusteradmin/design
go run ./cmd/orce-clusteradmin --config ./config.example.yaml
```

Oder:

```bash
make gen
make run
```

## Install-Beispiel

```bash
KUBECONFIG_B64=$(base64 -w0 ~/.kube/config)

curl -X POST http://localhost:8080/install \
  -H 'Content-Type: application/json' \
  -d "{
    \"kubeconfigBase64\": \"$KUBECONFIG_B64\",
    \"namespace\": \"argocd\",
    \"releaseName\": \"argocd\",
    \"chartRef\": \"argo/argo-cd\",
    \"chartVersion\": \"\",
    \"createNamespace\": true,
    \"valuesYaml\": \"server:\\n  service:\\n    type: ClusterIP\\n\"
  }"
```

## Uninstall-Beispiel

```bash
curl -X POST http://localhost:8080/uninstall \
  -H 'Content-Type: application/json' \
  -d "{
    \"kubeconfigBase64\": \"$KUBECONFIG_B64\",
    \"namespace\": \"argocd\",
    \"releaseName\": \"argocd\"
  }"
```

## Installations-Beispiel

```bash
curl -X POST http://localhost:8080/installations \
  -H 'Content-Type: application/json' \
  -d "{
    \"kubeconfigBase64\": \"$KUBECONFIG_B64\",
    \"namespace\": \"argocd\"
  }"
```

## Component-Status-Beispiel

```bash
curl -X POST http://localhost:8080/checkComponentStatus \
  -H 'Content-Type: application/json' \
  -d "{
    \"kubeconfigBase64\": \"$KUBECONFIG_B64\",
    \"namespace\": \"argocd\",
    \"components\": [
      \"deployment/argocd-server\",
      \"deployment/argocd-repo-server\",
      \"deployment/argocd-applicationset-controller\",
      \"deployment/argocd-notifications-controller\",
      \"statefulset/argocd-application-controller\"
    ]
  }"
```

## Hinweise

- Die Rechte kommen aus der übergebenen kubeconfig.
- Für ArgoCD-Installationen braucht diese kubeconfig typischerweise clusterweite Rechte, weil CRDs, ClusterRoles und ClusterRoleBindings angelegt werden.
- Kubeconfigs sollten nicht in Node-RED-Flows dauerhaft gespeichert werden.
