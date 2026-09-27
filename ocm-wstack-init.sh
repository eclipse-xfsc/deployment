#!/usr/bin/env bash

# Forward all bootstrap options (including --disable-external-dns) to the
# basic cluster initialization.
./basic-cluster-init.sh "$@" || exit $?

helm install -n security ocm-wstack-namespace INFRA/app-management/app-namespace -f INFRA/app-management/app-namespace-values/ocm-wstack-values.yaml

# basic-cluster-init.sh runs in a child process, therefore determine the
# default StorageClass again for the W-Stack ApplicationSet.
STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

# OCM W-Stack
helm install -n ocm-wstack ocm-wstack XFSC/Applicationsets/chart -f XFSC/Applicationsets/values/06_ocm_wstack-values.yaml --set storageClass="$STORAGE_CLASS"
./check-applicationset.sh ocm-wstack argocd
