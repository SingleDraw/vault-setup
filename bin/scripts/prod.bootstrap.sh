#!/bin/bash

if [ -f unsealer-init.json ] || [ -f vault-init.json ]; then
    echo "unsealer-init.json or/and vault-init.json already exists."
    echo "Do you want to reinitialize the unsealer? (y/n)"
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Exiting without changes."
        exit 0
    fi
    echo "Removing existing unsealer-init.json, vault-init.json, and vault-config/prod/vault.hcl files..."
    rm -f unsealer-init.json
    rm -f vault-init.json
    rm -f vault-config/prod/vault.hcl
    docker-compose -f docker-compose-prod.yml down -v
fi

# ---
# Config:
KEY_SHARES=1        # This determines how many pieces the root key is split into.
KEY_THRESHOLD=1     # This is the minimum number of key shares needed to unseal the Vault.
                    # * threshold must be greater than one for multiple shares

# Validation:
if [ "$KEY_SHARES" -gt 1 ] && [ "$KEY_THRESHOLD" -eq 1 ]; then
    echo "Invalid configuration:"
    echo "KEY_SHARES must be greater than KEY_THRESHOLD when KEY_SHARES > 1."
    echo "Adjusting KEY_THRESHOLD to 2."
    KEY_THRESHOLD=2
fi

VAULT_ADDR=http://127.0.0.1:8200

# ----- CHECK IT -----
# This script is designed to bootstrap a Vault setup with a transit auto-unsealer in production mode.

# REMOVE vault-init.json and unsealer-init.json with subsequent runs to reinitialize the vault.
# USE PROPER extract json function to extract unseal keys from vault-init.json and unsealer-init.json
# Move vault-init.json and unsealer-init.json logic to ansible playbook and secure keys with in ansible vault
# Add notification about need to manually unseal unsealer vault if it is sealed (slack? email? etc.)

# 1. Stop and restart
# docker-compose down
docker-compose -f docker-compose-prod.yml up -d consul vault-unsealer
# docker-compose -f docker-compose-prod.yml up -d vault-unsealer

# 2. Wait for unsealer to be ready
until docker exec vault-unsealer vault status 2>/dev/null | grep -q 'Initialized'; do
  echo "Waiting for unsealer..."
  sleep 2
done


# 3. Initialize the unsealer (production mode)
if ! docker exec vault-unsealer vault status 2>/dev/null | grep -q 'Initialized *true'; then
    echo "Unsealer is not initialized. Initializing unsealer..."
    if [ -f unsealer-init.json ]; then
        echo "Cannot initialize unsealer, unsealer-init.json already exists. Please remove it first."
        exit 1
    fi
    docker exec vault-unsealer vault operator init \
        -key-shares="$KEY_SHARES" \
        -key-threshold="$KEY_THRESHOLD" \
        -format=json > unsealer-init.json

    echo "Unsealer initialized. Keys saved to unsealer-init.json"
    echo "Unsealing unsealer vault..."
    # UNSEALER_KEY1=$(jq -r '.unseal_keys_b64[0]' unsealer-init.json)
    # UNSEALER_KEY2=$(jq -r '.unseal_keys_b64[1]' unsealer-init.json)
    # docker exec vault-unsealer vault operator unseal "$UNSEALER_KEY1"
    # docker exec vault-unsealer vault operator unseal "$UNSEALER_KEY2"
    UNSEAL_KEY=$(awk '/"unseal_keys_b64"/ {getline; gsub(/[",\[\]]/, "", $0); print $1}' unsealer-init.json) # not ideal, but works for single unseal key
    docker exec vault-unsealer vault operator unseal "$UNSEAL_KEY"
    # UNSEALER_TOKEN=$(jq -r '.root_token' unsealer-init.json)
    UNSEALER_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' unsealer-init.json)
    echo "Unsealer unsealed with token: $UNSEALER_TOKEN"
else
    echo "Unsealer is already initialized."
    # UNSEALER_TOKEN=$(jq -r '.root_token' unsealer-init.json)
    UNSEALER_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' unsealer-init.json)
    echo "Unsealer unsealed with token: $UNSEALER_TOKEN"
fi


# 5. Setup transit engine
if ! docker exec vault-unsealer vault secrets list | grep -q 'transit/'; then
    echo "Setting up transit engine on unsealer..."
    docker exec vault-unsealer sh -c "
    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN=$UNSEALER_TOKEN
    vault secrets enable transit
    vault write -f transit/keys/autounseal
    "
else
  echo "Transit engine already set up on unsealer."
fi

until docker exec vault-unsealer vault status 2>/dev/null | grep -q 'Sealed *false'; do
  echo "Waiting for unsealer to be unsealed..." # unsealer must be unsealed by now automatically by this script using manual method with keys
  sleep 2
done


# 6. Update your vault.hcl to use the production token
# We need to change the token in vault.hcl to use the unsealer token
export UNSEALER_TOKEN

# -----------------------------------------------------
# 7. Start main vault
docker-compose -f docker-compose-prod.yml up -d vault

# -----------------------------------------------------
# Wait for main vault to be ready
# This will wait until the main vault is initialized and unsealed
# We need to wait for the main vault to be ready before we can initialize it
# -----------------------------------------------------
echo "Waiting for main vault to be ready..."
until docker exec vault vault status 2>/dev/null | grep -q -E '(Sealed|Initialized)'; do
  echo "Waiting for main vault..."
  sleep 2
done


# Check if vault is already initialized
if docker exec vault vault status 2>/dev/null | grep -q 'Initialized *true'; then
    echo "Main vault is already initialized."
    if docker exec vault vault status 2>/dev/null | grep -q 'Sealed *false'; then
        echo "Main vault is already unsealed."
        exit 0
    else
        echo "Main vault is sealed but should auto-unseal..."
        # Wait a bit for auto-unseal to work
        sleep 5
        if docker exec vault vault status 2>/dev/null | grep -q 'Sealed *false'; then
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
    docker exec vault vault operator init \
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

# -----------------------------------------------------
# Ensure Engine is enabled
# -----------------------------------------------------
docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" \
    vault vault secrets enable -path=secret -version=2 kv


# -----------------------------------------------------
# Create Vault Policy for App
# -----------------------------------------------------

APP_NAME=myapp
APP_POLICY_NAME=vault-agent-policy

# Create policy attached to the token for writing secrets ??? sercret/data/$APP_NAME/* ????
docker exec -it vault sh -c "
export VAULT_ADDR=$VAULT_ADDR
export VAULT_TOKEN=$VAULT_TOKEN
vault policy write $APP_POLICY_NAME - <<EOF
path \"secret/data/$APP_NAME/*\" {
  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
}   
EOF
"


# -----------------------------------------------------
# Set Vault Agent
# -----------------------------------------------------

ROLE_NAME=vault-agent-role
SECRET_ID_TTL=0     # 0 for unlimited ttl or 10m : How long the secret ID is valid
TOKEN_TTL=2m       # How long the token is valid
TOKEN_MAX_TTL=3m   # Maximum time the token can be renewed
SECRET_NUM_USES=0   # 0 for unlimited uses or 1 : How many times the secret ID can be used

# Setup Vault Approle for Vault Agent and extract role_id and secret_id
echo "Setting up Vault Approle for Vault Agent..."
docker exec -it vault sh -c "
vault login $VAULT_TOKEN &&
vault auth enable approle &&
vault write auth/approle/role/$ROLE_NAME \
    secret_id_num_uses=$SECRET_NUM_USES \
    token_policies=$APP_POLICY_NAME \
    secret_id_ttl=$SECRET_ID_TTL \
    token_ttl=$TOKEN_TTL \
    token_max_ttl=$TOKEN_MAX_TTL &&
vault write -force auth/approle/role/$ROLE_NAME/secret-id > /tmp/secret_id.txt &&
vault read auth/approle/role/$ROLE_NAME/role-id > /tmp/role_id.txt &&
cat /tmp/role_id.txt &&
cat /tmp/secret_id.txt
"
# vault write -force auth/approle/role/$ROLE_NAME/secret-id > /tmp/secret_id.txt &&
# cat /tmp/secret_id.txt

# for wrapping secret_id
# secret_id_response_wrapping=true \
# secret_id_response_wrapping_path="auth/approle/role/$ROLE_NAME/secret-id" \

# if git bash or windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Convert line endings to Unix format
    CREDS_DIR="//tmp"
else
    # Use Unix-style path
    CREDS_DIR="/tmp"
fi

VAULT_ROLE_ID=$(
  docker exec vault cat "$CREDS_DIR/role_id.txt" | \
  awk '/^role_id/ { print $2 }'
)

VAULT_SECRET_ID=$(
  docker exec vault cat "$CREDS_DIR/secret_id.txt" | \
  grep -E '^secret_id[[:space:]]' | \
  awk '{print $2}'
)



export VAULT_ROLE_ID
# export VAULT_SECRET_ID

# or create files directly in the mounted directory
mkdir -p vault-config/prod/agent/creds
echo "$VAULT_ROLE_ID" > vault-config/prod/agent/creds/role_id
echo "$VAULT_SECRET_ID" > vault-config/prod/agent/creds/secret_id

# Start Vault Agent with the Approle configuration
docker-compose -f docker-compose-prod.yml up -d vault-agent


# -----------------------------------------------------
# Store API key in Vault
# -----------------------------------------------------
export VAULT_ADDR
export VAULT_TOKEN
docker exec -it vault sh -c "\
    vault kv put secret/$APP_NAME/apikey api_key=\"super-secret-api-key\""
# -----------------------------------------------------


# NOW RUN APP AND READ API KEY FROM VAULT !!!!