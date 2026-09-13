./basic-cluster-init.sh
helm install -n security ocm-wstack-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/ocm-wstack-values.yaml

# OCM W- Stack
helm install -n ocm-wstack ocm-wstack XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/06_ocm_wstack-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh ocm-wstack argocd