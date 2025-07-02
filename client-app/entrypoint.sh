#!/bin/sh

# Put a static API key in Vault KV store (this normally done outside app, here for demo)
vault kv put secret/api api_key="supersecretapikey123"

# Read and print the API key from Vault
API_KEY=$(vault kv get -field=api_key secret/api)
echo "API Key from Vault: $API_KEY"

# Keep container running so you can exec or view logs
tail -f /dev/null