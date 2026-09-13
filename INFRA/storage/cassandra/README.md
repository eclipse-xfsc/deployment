# XFSC Lightweight Cassandra Chart

Ein leichtes internes Cassandra-Cluster ohne Operator, cert-manager oder Admission Webhooks.

## Enthalten

- Docker Official Image `cassandra:5.0.5`
- StatefulSet mit `OrderedReady`
- Headless Service für Gossip und Seed Discovery
- CQL Service für interne Clients
- PVC pro Node
- aktivierte `PasswordAuthenticator`- und `CassandraAuthorizer`-Konfiguration
- OpenBao Init Job
- namespaced ESO `SecretStore`
- `ExternalSecret` für den administrativen Account
- einmaliger Passwort-Bootstrap-Job
- connection-only XFSC `ResourceProvider`
- optionales PodDisruptionBudget

## OpenBao

Standard-Mount:

```text
infrastructure
```

Standard-Pfad bei Release `cassandra`:

```text
cassandra/cassandra
```

Inhalt:

```json
{
  "username": "cassandra",
  "password": "<generiert>"
}
```

Es werden keine Workload-spezifischen Rollen oder Keyspaces angelegt.

## Installation

```bash
helm upgrade --install cassandra \
  . \
  --namespace infrastructure
```

## Drei interne Nodes

Standardmäßig entstehen:

```text
cassandra-0.cassandra-headless.infrastructure.svc.cluster.local
cassandra-1.cassandra-headless.infrastructure.svc.cluster.local
cassandra-2.cassandra-headless.infrastructure.svc.cluster.local
```

Der erste Pod ist der initiale Seed. `OrderedReady` startet weitere Nodes erst,
nachdem der vorherige Node bereit ist.

## Entwicklungsprofil

```yaml
replicaCount: 1

podDisruptionBudget:
  enabled: false

persistence:
  size: 10Gi

resources:
  requests:
    cpu: 250m
    memory: 1Gi
  limits:
    cpu: "1"
    memory: 2Gi

cluster:
  heap:
    max: 1G
    new: 200M
```

## StorageClass

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: longhorn
```

Ein leerer Wert lässt `storageClassName` vollständig weg und verwendet damit
die Default-StorageClass des Clusters.

## Auth-Bootstrap

Nach Aktivierung der Cassandra-Authentifizierung existiert zunächst der
integrierte Superuser:

```text
cassandra / cassandra
```

Der `post-install`-Job wartet auf CQL und ändert das Passwort unmittelbar auf
den von OpenBao erzeugten Wert. Der Job ist bewusst kein `post-upgrade`-Hook.
Eine Passwortrotation muss den bisherigen Wert kennen und sollte über einen
eigenen Provisionierungsablauf erfolgen.

## Auth testen

```bash
kubectl run cassandra-auth-test \
  --rm -it \
  --restart=Never \
  --namespace infrastructure \
  --image=cassandra:5.0.5 \
  --env="CASSANDRA_USERNAME=$(kubectl get secret cassandra-root-auth -n infrastructure -o jsonpath='{.data.username}' | base64 -d)" \
  --env="CASSANDRA_PASSWORD=$(kubectl get secret cassandra-root-auth -n infrastructure -o jsonpath='{.data.password}' | base64 -d)" \
  -- bash -ec '
    cqlsh cassandra 9042 \
      -u "$CASSANDRA_USERNAME" \
      -p "$CASSANDRA_PASSWORD" \
      -e "SELECT cluster_name, data_center, rack FROM system.local;"
  '
```

## ResourceProvider

Der Provider veröffentlicht ausschließlich:

```text
CASSANDRA_HOST
CASSANDRA_PORT
CASSANDRA_DATACENTER
```

Die administrativen Credentials werden nicht an Workloads ausgegeben.

## Betriebshinweise

Das Chart ist absichtlich schlanker als K8ssandra. Es bietet keine automatischen
Repairs, Backups, Multi-Datacenter-Orchestrierung oder Cassandra-aware
Decommission-Workflows.

Vor dem Reduzieren von `replicaCount` muss der betroffene Node mit `nodetool
decommission` sauber entfernt werden. Regelmäßige Repairs und Backups müssen
separat geplant werden.
