# Backup and rollback of a PCI installation

This procedure covers the two things a PCI installation owns and that an upgrade can
change: the `/data` volume of the ORCE deployment (flow file, installed modules,
uibuilder sources, the PCI installation record) and the PostgreSQL database of PCI.
It is written for the replacement of an existing deployment by the application image
(`docs/operations/deployment.md`, "Deploying the application image"), and it applies
to every upgrade. Shared services (OCM, Keycloak, Envoy) are not touched by a PCI
upgrade and are outside this procedure.

Use the ORCE namespace, deployment and container names of the installation; the
examples use `xfsc-orce-pci-orce`, `xfsc-orce` and the PCI PostgreSQL StatefulSet
`fap-pci-postgres`. Keep every backup outside Git and outside the cluster namespace
it protects, under the owner's retention policy.

## 1. Record the running state

```bash
NS=xfsc-orce-pci-orce; DEPLOY=xfsc-orce; STAMP=$(date -u +%Y%m%dT%H%M%SZ); OUT=backup-$STAMP; mkdir -p "$OUT"
kubectl -n "$NS" get deploy "$DEPLOY" -o json > "$OUT/deployment.json"
kubectl -n "$NS" get pod -l "$(kubectl -n "$NS" get deploy "$DEPLOY" -o go-template='{{range $k,$v := .spec.selector.matchLabels}}{{printf "%s=%s," $k $v}}{{end}}' | sed 's/,$//')" \
  -o jsonpath='{.items[0].status.containerStatuses[0].imageID}' > "$OUT/running-image-digest.txt"
kubectl -n "$NS" get configmap fap-pci-config -o yaml > "$OUT/fap-pci-config.yaml"
helm -n "$NS" list -o json > "$OUT/helm-releases.json"
kubectl -n "$NS" exec deploy/"$DEPLOY" -- cat /data/fap-pci/install/flows.json > "$OUT/pci-ownership.json" 2>/dev/null || true
kubectl -n "$NS" exec deploy/"$DEPLOY" -- cat /data/fap-pci/install/image-release.json > "$OUT/image-release.json" 2>/dev/null || true
```

`running-image-digest.txt` names the image the rollback returns to. The ConfigMap
and the Helm release list identify the configuration; Secrets are not exported by
this procedure (they are not changed by an upgrade; recover them from the owner's
secret management if ever needed).

## 2. Back up `/data`

Stop writes first: scale the ORCE deployment to zero, or announce a maintenance
window and accept that in-flight offers (process memory) are lost either way.

```bash
kubectl -n "$NS" scale deploy "$DEPLOY" --replicas=0
kubectl -n "$NS" rollout status deploy "$DEPLOY" --timeout=5m
```

Take the backup with a short-lived pod that mounts the same PersistentVolumeClaim
read-only (the claim name is in `deployment.json` under the volume mounted at
`/data`):

```bash
CLAIM=$(jq -r '.spec.template.spec.volumes[] | select(.persistentVolumeClaim) | .persistentVolumeClaim.claimName' "$OUT/deployment.json" | head -1)
kubectl -n "$NS" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata: {name: fap-pci-data-backup}
spec:
  restartPolicy: Never
  containers:
    - name: tar
      image: alpine:3.20
      command: [sh, -c, "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data, readOnly: true}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: $CLAIM, readOnly: true}
EOF
kubectl -n "$NS" wait pod/fap-pci-data-backup --for=condition=Ready --timeout=5m
kubectl -n "$NS" exec fap-pci-data-backup -- tar -C /data -czf - --exclude=./.npm . > "$OUT/data.tgz"
sha256sum "$OUT/data.tgz" > "$OUT/data.tgz.sha256"
kubectl -n "$NS" delete pod fap-pci-data-backup
```

If the storage class supports volume snapshots, take a `VolumeSnapshot` of the claim
in addition; the archive remains the portable copy. The archive contains the flow
file with every ORCE flow, including non-PCI flows of the instance.

## 3. Back up the PCI database

```bash
kubectl -n "$NS" exec fap-pci-postgres-0 -- sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --format=custom' > "$OUT/pci.dump"
sha256sum "$OUT/pci.dump" > "$OUT/pci.dump.sha256"
```

The dump uses the credentials already present in the pod; none are typed or stored
here. Verify with `pg_restore --list "$OUT/pci.dump" | head`.

## 4. Upgrade

Proceed with the deployment guide: change the image of the ORCE container to the new
application image by digest and let the deployment roll out; on first start the image
seeds `/data` (see `deployment/image/seed-data.mjs`) and the readiness endpoint
reports the result. Record the new running digest with the same command as in step 1.
Then run the completion tests and the deployed UX tests.

## 5. Rollback

Rollback returns to the recorded image and the recorded `/data`; the database is
restored only if the upgrade changed the schema (the additive schema of G0 does not
require it for a rollback within the same major version).

```bash
kubectl -n "$NS" scale deploy "$DEPLOY" --replicas=0
kubectl -n "$NS" rollout status deploy "$DEPLOY" --timeout=5m
# Restore /data from the archive into the same claim.
kubectl -n "$NS" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata: {name: fap-pci-data-restore}
spec:
  restartPolicy: Never
  containers:
    - name: tar
      image: alpine:3.20
      command: [sh, -c, "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: $CLAIM}
EOF
kubectl -n "$NS" wait pod/fap-pci-data-restore --for=condition=Ready --timeout=5m
sha256sum -c "$OUT/data.tgz.sha256"
kubectl -n "$NS" exec fap-pci-data-restore -- sh -c 'find /data -mindepth 1 -maxdepth 1 ! -name .npm -exec rm -rf {} +'
kubectl -n "$NS" exec -i fap-pci-data-restore -- tar -C /data -xzf - < "$OUT/data.tgz"
kubectl -n "$NS" delete pod fap-pci-data-restore
# Return the deployment to the recorded image.
IMAGE=$(cat "$OUT/running-image-digest.txt" | sed 's/^docker-pullable:\/\///')
kubectl -n "$NS" set image deploy/"$DEPLOY" "$(jq -r '.spec.template.spec.containers[0].name' "$OUT/deployment.json")=$IMAGE"
kubectl -n "$NS" scale deploy "$DEPLOY" --replicas=1
kubectl -n "$NS" rollout status deploy "$DEPLOY" --timeout=10m
```

If the image is managed by Helm or ArgoCD (deployment repository), make the image
change there instead of with `kubectl set image`, so that the next sync does not undo
it. If the database must be restored:

```bash
kubectl -n "$NS" exec -i fap-pci-postgres-0 -- sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' < "$OUT/pci.dump"
```

Check `/healthz`, `/readyz`, the provider UI and one tenant route, then record the
rollback (date, reason, image digest before and after, archive checksums) with the
deployment record.

## What a backup does not contain

Offers, callbacks and journey inputs live in process memory for at most the request
lifetime and are lost at any restart. Secrets stay in Kubernetes. Keycloak, OCM and
the participant service have their own backup procedures and are not changed by a PCI
upgrade. Anything created in the UI between the backup and the rollback is lost; take
the backup immediately before the upgrade.
