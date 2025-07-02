#!/bin/bash

# WORKING TRANSIT UNSEALING SCRIPT - DEV MODE [main vault prod mode + unsealer dev mode] - dont forget to enhance with agent container!!

#
#           DONT FORGET TO REMOVE vault-init.json WITH SUBSEQUENT RUNS ! 
#

if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
fi

UNSEALER_TOKEN=${UNSEALER_TOKEN:-unsealer-root-token}  # Default token if not set
VAULT_ADDR=http://127.0.0.1:8200

# Start unsealer first
# docker-compose -f docker-compose-prod.yml up -d consul vault-unsealer
docker-compose -f docker-compose-dev.yml up -d consul vault-unsealer

# # Wait for unsealer to be ready (should be quick in dev mode)
# sleep 10
# or. Wait for unsealer to be UNSEALED (not just running)
echo "Waiting for unsealer to be ready and unsealed..."
until docker exec vault-unsealer env VAULT_ADDR=$VAULT_ADDR vault status 2>/dev/null | grep -q 'Sealed.*false'; do
  echo "Waiting for unsealer to unseal..."
  sleep 3
done
# echo "Unsealer is ready!"
echo "Unsealer is ready and unsealed!" # should be unsealed by now automatically

# Setup transit engine
docker exec vault-unsealer sh -c "
  export VAULT_ADDR=http://127.0.0.1:8200
  export VAULT_TOKEN=$UNSEALER_TOKEN
  # Enable transit secrets engine
  vault secrets enable transit
  # Create the auto-unseal key
  vault write -f transit/keys/autounseal
  echo 'Transit engine setup complete'
"

# 5. Start main vault
docker-compose -f docker-compose-dev.yml up -d vault

# 6. Check status
# sleep 5
# docker exec vault vault status
# Wait for main vault to be ready
echo "Waiting for main vault to be ready..."
until docker exec vault env VAULT_ADDR=$VAULT_ADDR vault status 2>/dev/null | grep -q -E '(Sealed|initialized)'; do
  echo "Waiting for main vault..."
  sleep 2
done


# Check if vault is already initialized
if docker exec vault env VAULT_ADDR=$VAULT_ADDR vault status 2>/dev/null | grep -q 'Initialized *true'; then
    echo "Main vault is already initialized."
    if docker exec vault env VAULT_ADDR=$VAULT_ADDR vault status 2>/dev/null | grep -q 'Sealed *false'; then
        echo "Main vault is already unsealed."
        exit 0
    else
        echo "Main vault is sealed but should auto-unseal..."
        # Wait a bit for auto-unseal to work
        sleep 5
        if docker exec vault env VAULT_ADDR=$VAULT_ADDR vault status 2>/dev/null | grep -q 'Sealed *false'; then
            echo "Auto-unseal successful!"
            exit 0
        else
            echo "Auto-unseal failed. Check configuration."
            exit 1
        fi
    fi
fi

# Initialize vault (this should only happen once)
echo "Initializing main vault..."
if [ ! -f vault-init.json ]; then
    # With auto-unseal, we can use higher threshold for recovery keys
    docker exec vault env VAULT_ADDR=$VAULT_ADDR vault operator init \
        -recovery-shares=5 \
        -recovery-threshold=3 \
        -format=json > vault-init.json
    echo "Vault initialized. Recovery keys saved to vault-init.json"
else
    echo "vault-init.json already exists."
fi

# Wait for auto-unseal to work
echo "Waiting for auto-unseal..."
sleep 5

# Check final status
echo "Checking vault status..."
VAULT_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' vault-init.json)

export VAULT_TOKEN

if docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault status; then
    echo ""
    echo "🎉 Vault setup complete!"
    echo "Main vault: $VAULT_ADDR"
    echo "Unsealer vault: $UNSEALER_ADDR"
    echo "Vault UI: http://localhost:8000"
    echo ""
    echo "Root token: $VAULT_TOKEN"
    echo "Recovery keys are in vault-init.json"
    echo ""
    echo "The main vault should auto-unseal on future restarts."
else
    echo "❌ Something went wrong. Check the logs:"
    echo "docker-compose logs vault"
    echo "docker-compose logs vault-unsealer"
    exit 1
fi