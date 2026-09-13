#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Config
# =========================
readonly NAMESPACE="argocd"
readonly TIMEOUT="300s"
readonly ARGO_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Exit Codes
readonly EXIT_PREREQ_FAILED=10
readonly EXIT_NAMESPACE_FAILED=20
readonly EXIT_INSTALL_FAILED=30
readonly EXIT_ROLLOUT_FAILED=40
readonly EXIT_POD_FAILED=50
readonly EXIT_SECRET_FAILED=60

# =========================
# Helpers
# =========================
log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

trap 'err "Unexpected failure in line $LINENO"; exit 99' ERR

# =========================
# Preconditions
# =========================
command -v kubectl >/dev/null 2>&1 || {
  err "kubectl not found"
  exit "$EXIT_PREREQ_FAILED"
}

kubectl cluster-info >/dev/null 2>&1 || {
  err "No reachable Kubernetes cluster"
  exit "$EXIT_PREREQ_FAILED"
}

# =========================
# Namespace
# =========================
log "Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - \
  || { err "Failed to create namespace"; exit "$EXIT_NAMESPACE_FAILED"; }

# =========================
# Install Argo CD
# =========================
log "Installing Argo CD"
kubectl apply -n "$NAMESPACE" --server-side --force-conflicts -f "$ARGO_MANIFEST" \
  || { err "Failed to install Argo CD"; exit "$EXIT_INSTALL_FAILED"; }

# =========================
# Wait for Rollouts
# =========================
components=(
  "deployment/argocd-server"
  "deployment/argocd-repo-server"
  "deployment/argocd-applicationset-controller"
  "deployment/argocd-notifications-controller"
  "statefulset/argocd-application-controller"
)

for component in "${components[@]}"; do
  log "Waiting for $component"
  kubectl rollout status "$component" -n "$NAMESPACE" --timeout="$TIMEOUT" \
    || {
      err "$component failed rollout"
      kubectl get pods -n "$NAMESPACE" -o wide
      exit "$EXIT_ROLLOUT_FAILED"
    }
done

# =========================
# Verify Pods Healthy
# =========================
log "Verifying all pods are Running/Ready"

not_ready=$(
  kubectl get pods -n "$NAMESPACE" \
    --no-headers \
    | awk '$3 != "Running" && $3 != "Completed" {print}'
)

if [[ -n "$not_ready" ]]; then
  err "Some pods are not healthy:"
  echo "$not_ready"
  exit "$EXIT_POD_FAILED"
fi

# =========================
# Verify Initial Secret Exists
# =========================
if ! kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" >/dev/null 2>&1; then
  err "Initial admin secret missing"
  exit "$EXIT_SECRET_FAILED"
fi

# =========================
# Success
# =========================
log "Argo CD installed successfully"

password=$(
  kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d
)

echo
echo "=================================="
echo "ARGO CD READY"
echo "Namespace: $NAMESPACE"
echo "Admin User: admin"
echo "Admin Password: $password"
echo "UI Port-Forward:"
echo "kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo "=================================="

exit 0
