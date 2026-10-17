# Mandatory TDC-070 deployment profile

The default ground-zero installation is a functional integration profile. It is
not an all-hop TLS sign-off profile. Use this supplied overlay for sign-off.
It encrypts cross-pod application traffic with authenticated TLS 1.3, including
Gateway→ORCE, ORCE→PostgreSQL/SMTP/NATS and native service/Core connections.
TLS terminates in each pod's sidecar; loopback application traffic remains local.
External identity, participant, wallet and telemetry connections retain their
existing certificate-verified TLS 1.3 application configuration.

1. The shared-stack owner installs `mesh.yaml` using its approved, version-pinned
   Istio release. Use a named revision, sidecar injection and a trusted cluster CA.
   This is a deployment overlay, not a modification to mandated service code.
2. Create a private inventory JSON containing `meshRevision`, `roles` (every key
   from `ROLES` in tools/prepare-all-hop-tls.py), and `workloads`. Each role maps
   to a workload key. Each workload supplies exact kind (Deployment/StatefulSet; EnvoyProxy for the Gateway),
   name, namespace, uid. Several roles may use one workload. Include all replicas
   of each service and the gateway data plane. Also enroll any other clients
   needing access before enabling STRICT, to avoid outage during migration.
3. Set `PCI_MESH_REVISION` to that revision for ground-zero deploy/upgrade.
   G0 adds injection, native-sidecar lifecycle and STRICT policies to its managed
   workloads and one-shot schema/bootstrap jobs. Native sidecars must be supported
   by the approved Kubernetes/Istio versions. Existing ORCE and shared dependencies still need the owner-inventory
   enrollment below. G0 persists Gateway injection on its EnvoyProxy CR.
   Run `python3 tools/prepare-all-hop-tls.py --inventory PRIVATE.json --context
   CONTEXT --kubeconfig KUBECONFIG --output PRIVATE_PLAN`. Review exact CAS
   patches and policies, then rerun with `--apply` in the approved change window.
   Rerender after any resource-version change; do not remove CAS checks.
4. Verify all pods include a ready `istio-proxy`, have no excluded ports/IP ranges,
   no host network, and no conflicting port-level/workload PeerAuthentication or
   DestinationRule that weakens STRICT/auto-mTLS. Inspect `istioctl proxy-config
   listeners POD -n NAMESPACE -o json` and `clusters` for every inventory entry.
5. Run the existing native wallet, participant, database, mail and BDD checks.
   Capture negotiated TLS 1.3 / mutual-authentication evidence on every link;
   demonstrate rejection of direct plaintext and TLS 1.2 from an unmeshed test
   pod. Retain inventory, mesh revision/digest, policies, proxy configurations,
   handshake results and deletion/redeploy results as the TDC-070 receipt.

No manifest rendering is a substitute for the last two validation steps. Shared
stack enrollment and mesh installation require its owner's existing change
approval. The supplied tool does not infer permission to change shared workloads.
Istio reference:
https://istio.io/latest/docs/tasks/security/tls-configuration/workload-min-tls-version/

Gateway enrollment targets the owning EnvoyProxy CR so its controller preserves
injection after reconciliation. Public ingress stays with Envoy's existing TLS 1.3
listener (`includeInboundPorts: ""` for that gateway only); its backend connections
use mesh mTLS. Public clients must not be forced to present mesh certificates.
Verify the generated Gateway Deployment rollout separately and confirm the
public listener still rejects plaintext/TLS 1.2. This inbound exception is refused
for every ordinary workload. Preserve the same settings in the owner's GitOps
source so later reconciliation does not restore a weaker deployment.
