kubectl create namespace observabilty
helm install -n observability observability INFRA/observability/opentelemtry
kubectl create namespace security
helm install -n security openbao INFRA/security/openbao
helm install -n security eso INFRA/security/eso
helm install -n security kyverno INFRA/security/kyverno
helm dependency build INFRA/app-management/kubernetes-operator
helm install -n default kubernetes-operator INFRA/app-management/kubernetes-operator
./argocd-bootstrap.sh