#!/usr/bin/env bash

set -euo pipefail

# ./uninstall.sh OCMNAMESPACE KUBECONFIG

NAMESPACE=$1
KUBECONFIG=$2

kubectl --kubeconfig "$KUBECONFIG" delete namespace $NAMESPACE
