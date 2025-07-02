#!/bin/sh

if [ -z "$UNSEALER_TOKEN" ]; then
  if [ -f /vault/config/vault.hcl ]; then
    echo "UNSEALER_TOKEN is not set, but vault.hcl already exists. Using existing configuration."
  else
    echo "Error: UNSEALER_TOKEN is not set and vault.hcl does not exist."
    echo "Please set UNSEALER_TOKEN environment variable or create vault.hcl manually."
    exit 1
  fi
else
  echo "Setting up Vault configuration with template and UNSEALER_TOKEN..."
  # Replace placeholders manually with sed
  sed "s|\${UNSEALER_TOKEN}|$UNSEALER_TOKEN|g" \
    /vault/config/vault.hcl.tpl > /vault/config/vault.hcl
fi

exec "$@"

 