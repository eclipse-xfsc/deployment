helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/01_app-namespace-values.yaml
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/02_basic-values.yaml

STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/03_storage-values.yaml --set storageClass="$STORAGE_CLASS"
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/04_network-values.yaml --set storageClass="$STORAGE_CLASS"
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/05_core-values.yaml --set storageClass="$STORAGE_CLASS"
