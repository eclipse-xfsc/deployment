# XFSC Cassandra OpenBao Chart

This chart installs Cassandra with only its administrative bootstrap account.

No application-specific users, databases, keyspaces, buckets or ACL accounts
are created during installation. Those resources are expected to be created
later by the XFSC Resource Provisioner when a concrete workload requests them.

## OpenBao

Default KV-v2 mount:

```text
infrastructure
```

Default logical secret path:

```text
infrastructure/cassandra/<release-name>
```

Stored keys:

```text
cassandra-password
```

## Behavior

1. The pre-install Job authenticates through the namespace Resource Provisioner
   ServiceAccount.
2. It creates the `infrastructure` KV-v2 mount only when it does not exist.
3. It writes the administrative bootstrap credentials.
4. ESO synchronizes them into the root Kubernetes Secret.
5. The Bitnami chart starts the service with that root/admin account.
6. No application user is created.

## Later provisioning

The XFSC operator or Resource Provisioner can later:

- generate workload-specific credentials,
- connect using the administrative account,
- create the requested user/database/keyspace/bucket,
- store the workload credentials below a separate path,
- create an `ExternalSecret` for the consuming workload.

## Important

The root Secret must not be exposed through a general workload
`ResourceProvider`. Keep root credentials restricted to the infrastructure
namespace and the provisioning component.

## ResourceProvider connection

The chart renders a namespaced XFSC `ResourceProvider` by default. It contains
only static connection values under `spec.outputs.env`. It does not expose the
administrative bootstrap credentials and does not create an
`externalSecrets` mapping.

Disable it with:

```yaml
resourceProvider:
  enabled: false
```

Restrict cluster-scope resolution to selected consumer namespaces with:

```yaml
resourceProvider:
  allow:
    namespaces:
      - tenant-a
      - tenant-b
```
