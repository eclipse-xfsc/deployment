#!/usr/bin/env bash

set -euo pipefail

NAMESPACE=$1
KUBECONFIG=$2

kubectl --kubeconfig "$KUBECONFIG" delete namespace $NAMESPACE
