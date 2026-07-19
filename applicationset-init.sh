helm install -n security infra-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/infra-values.yaml

STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/storage-values.yaml --set storageClass="$STORAGE_CLASS"
