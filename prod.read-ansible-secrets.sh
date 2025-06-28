#!/bin/bash

# Test Vault Secrets read access

if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

VAULT_ADDR=${VAULT_ADDR:-http://localhost:8200}
VAULT_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' vault-init.json)
export VAULT_ADDR
export VAULT_TOKEN=${1:-$VAULT_TOKEN}  # Use provided token or default

echo "Testing Vault connectivity..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv get ansible/database
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv get ansible/api-keys


echo "Ansible lookup plugin test:"
echo "{{ lookup('hashi_vault', 'secret=ansible/data/database:username') }}"

# --eof file---