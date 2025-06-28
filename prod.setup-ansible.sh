#!/bin/bash

# Vault setup for Ansible integration

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --------------------------------------------------------------
# Bootstrap Vault access for Ansible by:
    # Enabling the KV secrets engine
    # Creating a policy for Ansible
    # Creating a token for Ansible to authenticate
    # Optionally storing secrets
# --------------------------------------------------------------

# Read VAULT_TOKEN from vault-init.json if it exists
if [ -f vault-init.json ]; then
    VAULT_TOKEN=$(sed -n 's/.*"root_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' vault-init.json)
else
    echo "vault-init.json not found. Please run prod.bootstrap.sh first to initialize Vault."
    exit 1
fi

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

# --------------------------------------------------------------
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

echo "${YELLOW}You can now test read access to these secrets with prod.read-ansible-secrets.sh${NC}"

# Note: Make sure to run this script after prod.bootstrap.sh to ensure Vault is initialized and unsealed.
# ---eof file---