helm install -n security infra-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/infra-values.yaml
helm install -n infrastructure storage XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/storage-values.yaml
