#!/bin/bash

# Vault Bootstrap Script for Production-like Environment

docker-compose -f docker-compose-prod.yml up -d

until docker exec vault vault status 2>/dev/null | grep -q '^Sealed *true'; do
  sleep 1
done

if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
fi 
VAULT_ADDR=${VAULT_ADDR:-http://localhost:8200}

# --------------------------------------------------------------
# 1 # Initialize Vault in production environment (do it only once)

# check if vault is already initialized
if docker exec vault vault status | grep -q 'Sealed *false'; then
    echo "Vault is already initialized and unsealed."
    exit 0
elif [ ! -f vault-init.json ]; then
    echo "Vault is not initialized. Initializing Vault..."
    docker exec vault vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-init.json
else
    echo "Vault is initialized but sealed. Unsealing Vault..."
fi

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
# Wait until Vault is sealed and ready
# This is necessary because the Vault container might take some time to start up and be ready for commands
until docker exec vault vault status 2>/dev/null | grep -q '^Sealed *true'; do
  sleep 1
done

# 2 # Unseal Vault using the unseal key
VAULT_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' vault-init.json)

# UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' vault-init.json) # Use jq to extract the first unseal key
UNSEAL_KEY=$(awk '/"unseal_keys_b64"/ {getline; gsub(/[",\[\]]/, "", $0); print $1}' vault-init.json) # not ideal, but works for single unseal key

for _ in {1..5}; do
  if docker exec -e VAULT_ADDR="http://127.0.0.1:8200" vault vault operator unseal "$UNSEAL_KEY"; then
    break
  else
    echo "Retrying unseal in 2s..."
    sleep 2
  fi
done

# Check Vault status
echo "Checking Vault status..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault status