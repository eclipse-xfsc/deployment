PROFILE=""
DOMAIN=""
EMAIL=""
DNSTOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    --dnstoken)
      DNSTOKEN="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Usage: $0 --profile <profile> --domain <domain> --email <email> --token <token>"
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" || -z "$DOMAIN" || -z "$EMAIL" || -z "$DNSTOKEN" ]]; then
  echo "Usage: $0 --profile <profile> --domain <domain> --email <email> --dnstoken <token>"
  exit 1
fi

echo "PROFILE=$PROFILE"
echo "DOMAIN=$DOMAIN"
#echo "TOKEN=$DNSTOKEN"

kubectl create namespace observability
helm repo add otel https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prom https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaeger https://jaegertracing.github.io/helm-charts
helm dependency build INFRA/observability/opentelemtry
helm install -n observability observability INFRA/observability/opentelemtry
kubectl create namespace security
helm repo add openbao https://openbao.github.io/openbao-helm
helm dependency build INFRA/security/openbao
helm install -n security openbao INFRA/security/openbao
helm repo add eso https://charts.external-secrets.io
helm dependency build INFRA/security/eso
helm install -n security eso INFRA/security/eso
helm repo add kyverno https://kyverno.github.io/kyverno/
helm dependency build INFRA/security/kyverno
helm install -n security kyverno INFRA/security/kyverno
./argocd-bootstrap.sh

helm install -n security infrastructure-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/infra-values.yaml

helm dependency build INFRA/kubernetes-operator
helm install -n security kubernetes-operator INFRA/kubernetes-operator

STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

kubectl create secret generic external-dns \
  -n infrastructure \
  --from-literal=token="$TOKEN"

#helm install -n infrastructure basic XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/02_basic-values.yaml --set storageClass="$STORAGE_CLASS"
#./check-applicationset.sh storage argocd
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/03_storage-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh storage argocd
helm install -n infrastructure network XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/04_network-values.yaml --set storageClass="$STORAGE_CLASS" --set profile="$PROFILE" --set domain="$DOMAIN" --set email="$EMAIL" 
./check-applicationset.sh network argocd
helm install -n infrastructure core XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/05_core-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh core argocd