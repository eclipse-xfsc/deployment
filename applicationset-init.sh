
PROFILE=$1
DOMAIN=$2
TOKEN=$3
EMAIL=$4

echo "PROFILE=$PROFILE"
echo "DOMAIN=$DOMAIN"
#echo "TOKEN=$TOKEN"
helm install -n security infrastructure-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/infra-values.yaml
helm install -n security catalogue-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/catalogue-values.yaml
helm install -n security ocm-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/ocm-values.yaml
helm install -n security ocm-wstack-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/ocm-wstack-values.yaml
helm install -n security orce-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/orce-values.yaml
helm install -n security pcm-cloud-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/pcm-cloud-values.yaml
helm install -n security tenant-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/tenant-values.yaml

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

# OCM W- Stack
helm install -n ocm-wstack ocm-wstack XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/06_ocm_wstack-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh ocm-wstack argocd
