PROFILE=""
DOMAIN=""
TOKEN=""

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
    --token)
      TOKEN="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" || -z "$DOMAIN" || -z "$TOKEN" ]]; then
  echo "Usage: $0 --profile <profile> --domain <domain> --token <token>"
  exit 1
fi

echo "PROFILE=$PROFILE"
echo "DOMAIN=$DOMAIN"
echo "TOKEN=$TOKEN"

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
./applicationset-init.sh $PROFILE $DOMAIN $TOKEN