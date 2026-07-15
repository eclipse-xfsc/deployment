# XFSC Cassandra K8ssandra Chart

Requires the K8ssandra Operator and cert-manager.

Creates a namespaced OpenBao SecretStore, administrative Cassandra credentials,
a K8ssandraCluster, and a connection-only XFSC ResourceProvider.

Default OpenBao path:

```text
infrastructure/cassandra/<release-name>
```

Only the administrative `cassandra` user is created. Workload-specific roles
and keyspaces are created later by the XFSC provisioner.

Install:

```bash
helm upgrade --install cassandra . --namespace infrastructure
```
