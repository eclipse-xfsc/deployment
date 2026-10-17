#!/usr/bin/env bash
# Read-only checks. Pass the namespace of the existing PCI ORCE deployment.
set -euo pipefail
NS="${1:?Usage: preflight.sh PCI_NAMESPACE [ORCE_DEPLOYMENT] [ORCE_CONTAINER]}"; DEPLOY="${2:-xfsc-orce}"; CONTAINER="${3:-orce}"
for binary in kubectl helm jq openssl python3; do command -v "$binary" >/dev/null || { echo "Missing $binary" >&2; exit 1; }; done
helm upgrade --help | grep -q -- '--take-ownership' || { echo 'Helm >=3.17 is required' >&2; exit 1; }
kubectl -n "$NS" get deployment "$DEPLOY" -o json | jq -e '.spec.replicas == 1' >/dev/null
kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class
kubectl -n ocm-wstack get service -o custom-columns=NAME:.metadata.name,PORT:.spec.ports[*].port
kubectl -n ocm-wstack get networkpolicy -o custom-columns=NAME:.metadata.name
# Socket probes have a hard deadline and disclose only endpoint and outcome.
kubectl -n "$NS" exec -i deploy/"$DEPLOY" -c "$CONTAINER" -- node - <<'JS'
const net=require('net');const endpoints=[['Keycloak','ocm-ui-keycloak.ocm-wstack.svc.cluster.local',8080],['NATS','nats.infrastructure.svc.cluster.local',4222],['Signer','signer.ocm-wstack.svc.cluster.local',8080],['Issuer','issuance-service.ocm-wstack.svc.cluster.local',8080],['WellKnown','well-known-service.ocm-wstack.svc.cluster.local',8080],['Status','status-list-service.ocm-wstack.svc.cluster.local',8080],['PreAuth','pre-authorization-bridge-service.ocm-wstack.svc.cluster.local',8080]];
Promise.all(endpoints.map(([service,host,port])=>new Promise(resolve=>{const socket=net.connect({host,port});let done=false;const finish=ok=>{if(done)return;done=true;socket.destroy();console.log(JSON.stringify({service,host,port,reachable:ok}));if(!ok)process.exitCode=1;resolve();};socket.setTimeout(4000,()=>finish(false));socket.on('connect',()=>finish(true));socket.on('error',()=>finish(false));}))).catch(()=>{process.exitCode=1});
JS
