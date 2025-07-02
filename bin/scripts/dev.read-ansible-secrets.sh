#!/bin/bash

# Test Vault with Ansible

# read .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
fi

VAULT_ADDR=${VAULT_ADDR:-http://localhost:8200}

VAULT_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' vault-init.json)

export VAULT_ADDR
export VAULT_TOKEN

echo "Using VAULT_ADDR: $VAULT_ADDR"
echo "Testing Vault connectivity..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv get ansible/database

echo ""
echo "Ansible lookup plugin test:"
echo "{{ lookup('hashi_vault', 'secret=ansible/data/database:username') }}"
