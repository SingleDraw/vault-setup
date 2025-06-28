#!/bin/bash

# Initialize and configure Vault

set -e

# --------------------------------------------------------------
# Setup environment variables and colors :)
# --------------------------------------------------------------

# read .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
fi 

VAULT_ADDR=${VAULT_ADDR:-http://localhost:8200}
VAULT_TOKEN=${VAULT_TOKEN:-myroot}  # Default token if not set

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------
# Start Vault setup
# ------------------------------------------------------------

echo -e "${GREEN}Starting Vault setup...${NC}"

# Start Vault container
echo "Starting Vault container..."
docker-compose up -d vault

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
sleep 10

# Export Vault environment variables
export VAULT_ADDR
export VAULT_TOKEN

# Check Vault status
echo "Checking Vault status..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault status

echo -e "${GREEN}Vault is running!${NC}"
echo -e "${YELLOW}Access the UI at: http://localhost:8200${NC}"
echo -e "${YELLOW}Root token: myroot${NC}"


# --------------------------------------------------------------
# Initialize Vault
# --------------------------------------------------------------

# Enable KV secrets engine
# echo "Enabling KV secrets engine..."
# docker exec vault vault secrets enable -path=ansible kv-v2

# Check if KV secrets engine is already enabled
echo "Checking if KV secrets engine is already enabled..."
if docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault secrets list | grep -q "ansible/"; then
  echo -e "${YELLOW}KV secrets engine is already enabled at ansible/${NC}"
else
  echo "Enabling KV secrets engine..."
  docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault secrets enable -path=ansible kv-v2
fi



# ---------------------------------------------------------------
# Create initial policies and tokens
# ---------------------------------------------------------------

# Create initial policies
echo "Creating Ansible policy..."
docker exec -i -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy write ansible-policy - <<EOF
# Allow read/write to ansible secrets
path "ansible/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ansible/" {
  capabilities = ["list"]
}
EOF
# Create a token for Ansible with limited permissions
echo "Creating Ansible token..."
# or use the -field option to get just the token
ANSIBLE_TOKEN=$(docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault token create \
  -policy=ansible-policy \
  -ttl=24h \
  -renewable=true \
  -field=token)


echo -e "${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}Ansible token: ${ANSIBLE_TOKEN}${NC}"
echo ""
echo "Save this token securely. You can also create new tokens with:"
echo "docker exec -e VAULT_ADDR=\"http://127.0.0.1:8200\" -e VAULT_TOKEN=\"\$VAULT_TOKEN\" vault vault token create -policy=ansible-policy"

# Store some example secrets
echo "Storing example secrets..."
docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv put ansible/database username=dbuser password=secret123
docker exec -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv put ansible/api-keys service1=key123 service2=key456

echo -e "${GREEN}Example secrets stored in ansible/ path${NC}"
