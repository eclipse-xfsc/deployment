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
echo "TOKEN=$DNSTOKEN"

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
./applicationset-init.sh $PROFILE $DOMAIN $TOKEN $EMAIL