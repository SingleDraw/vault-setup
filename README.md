# Vault + Consul Development Setup

This setup provides a local development environment with HashiCorp Vault and Consul running in Docker containers.

## ⚠️ Security Notice

**This configuration is for development/testing only!** It uses insecure practices including:
- Single unseal key (threshold=1)
- Storing vault credentials in `vault-init.json` 
- Automated unsealing from stored credentials

**Never use this in production!**

## Services

- **Consul**: Service discovery and Vault storage backend (port 8500)
- **Vault**: Secret management server (port 8200) 
- **Vault UI**: Web interface for Vault (port 8000)

## Quick Start

### 1. Initial Bootstrap
```bash
./prod.bootstrap.sh
```
This script will:
- Start Consul and Vault containers
- Initialize Vault with a single unseal key
- Store initialization data in `vault-init.json` (insecure!)
- Automatically unseal Vault using the stored key

### 2. Setup Ansible Integration (Run Once)
```bash
./prod.setup-ansible.sh
```
This configures Vault for Ansible by:
- Enabling the KV secrets engine
- Creating an Ansible-specific policy
- Generating an authentication token for Ansible
- Storing example secrets for testing

### 3. Test Secret Reading
```bash
./prod.read-ansible-secrets.sh
```
Verifies that secrets can be read from Vault using the Ansible token.

## After Restarts

When Vault containers restart, run the bootstrap script again to unseal:
```bash
./prod.bootstrap.sh
```

The script detects if Vault is already initialized and only performs the unsealing step.

## Data Persistence

Configuration and secrets persist between container restarts via Docker volumes:
- `consul_data`: Consul's data directory
- `vault-data`: Vault's data storage
- `vault-logs`: Vault's log files

## Production Considerations

For production deployments:
- Use multiple unseal keys with higher threshold (e.g., 3 of 5)
- Store unseal keys securely (separate systems/people)
- Use auto-unsealing with cloud KMS or another Vault cluster
- Implement proper authentication methods (LDAP, OIDC, etc.)
- Use TLS encryption for all communications
- Set up proper monitoring and alerting

## Accessing Services

- **Vault API**: http://localhost:8200
- **Vault UI**: http://localhost:8000  
- **Consul UI**: http://localhost:8500

## Troubleshooting

If containers fail to start:
1. Check if ports 8200, 8500, or 8000 are already in use
2. Verify Docker is running and has sufficient resources
3. Check logs: `docker-compose logs <service-name>`

If Vault is sealed after restart:
- Run `./prod.bootstrap.sh` to unseal using stored credentials