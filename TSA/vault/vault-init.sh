#! /bin/sh

set -e

export VAULT_ADDR=http://vault:8200

# give some time for Vault to start and be ready
sleep 3

vault login root

# enable vault transit engine
vault secrets enable transit

# create key1 with type ecdsa-p256
vault write -f transit/keys/key1 type=ecdsa-p256

# create key2 with type ed25519
vault write -f transit/keys/key2 type=ed25519

# create key3 with type rsa-4096
vault write -f transit/keys/key3 type=rsa-4096
