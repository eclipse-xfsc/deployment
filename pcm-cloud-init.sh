export TENANT="${TENANT:-yourtenant}"

./ocm-wstack-init.sh "$@" || exit $?

helm install -n security pcm-cloud-namespace \
  INFRA/app-management/app-namespace \
  -f INFRA/app-management/app-namespace-values/pcm-cloud-values.yaml

helm install -n pcm-cloud pcm-cloud XFSC/Applicationsets/chart \
  -f XFSC/Applicationsets/values/07_pcm-cloud-values.yaml \
  --set domain="$DOMAIN" \
  --set tenantId="$TENANT"

./check-applicationset.sh pcm-cloud argocd