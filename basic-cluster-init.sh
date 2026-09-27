#!/usr/bin/env bash

PROFILE=""
DOMAIN=""
EMAIL=""
DNSTOKEN=""
DISABLE_EXTERNAL_DNS=false

usage() {
  echo "Usage: $0 --profile <profile> --domain <domain> --email <email> [--dnstoken <token>] [--disable-external-dns]"
}

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
    --disable-external-dns)
      DISABLE_EXTERNAL_DNS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" || -z "$DOMAIN" || -z "$EMAIL" ]]; then
  usage
  exit 1
fi

if [[ "$DISABLE_EXTERNAL_DNS" != "true" && -z "$DNSTOKEN" ]]; then
  echo "Error: --dnstoken is required unless --disable-external-dns is set."
  usage
  exit 1
fi

echo "PROFILE=$PROFILE"
echo "DOMAIN=$DOMAIN"
echo "EXTERNAL_DNS_ENABLED=$([[ "$DISABLE_EXTERNAL_DNS" == "true" ]] && echo false || echo true)"

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

NETWORK_ARGS=()
if [[ "$DISABLE_EXTERNAL_DNS" == "true" ]]; then
  echo "ExternalDNS disabled: INFRA/network/external-dns will be excluded from the network ApplicationSet."
  # 04_network-values.yaml already contains excludes[0]=INFRA/network/bind9.
  # Set the complete list explicitly to make Helm array handling deterministic.
  NETWORK_ARGS+=(--set-string 'excludes[0]=INFRA/network/bind9')
  NETWORK_ARGS+=(--set-string 'excludes[1]=INFRA/network/external-dns')
else
  kubectl create secret generic external-dns \
    -n infrastructure \
    --from-literal=token="$DNSTOKEN"
fi

#helm install -n infrastructure basic XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/02_basic-values.yaml --set storageClass="$STORAGE_CLASS"
#./check-applicationset.sh storage argocd
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/03_storage-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh storage argocd
helm install -n infrastructure network XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/04_network-values.yaml --set storageClass="$STORAGE_CLASS" --set profile="$PROFILE" --set domain="$DOMAIN" --set email="$EMAIL" "${NETWORK_ARGS[@]}"
./check-applicationset.sh network argocd
helm install -n infrastructure core XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/05_core-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh core argocd
