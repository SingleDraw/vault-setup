# Production configuration (vault-config/vault.hcl)

service_registration "consul" {
  address = "consul:8500"             # This must be correct (Consul's address)
  service_address = "vault"           # Or an IP like "192.168.48.3" # ✅ ONLY if Consul and Vault are in the same network AND Consul resolves it
  service_tags = "vault,vault-prod" # Tags for the Vault service in Consul
}

storage "consul" {
  address = "consul:8500" # Consul service address in Docker Compose - name of the service
  path    = "vault/"      # Path in Consul where Vault will store its data
}

listener "tcp" {
  address     = "0.0.0.0:8200"  # Listen on all interfaces on port 8200
  tls_disable = 1               # Disable TLS for development purposes
}

# Transit auto-unsealing
seal "transit" {
  address         = "http://vault-unsealer:8200"  # Internal Docker network address (internal port cause it's in the same network)
  token           = "unsealer-root-token"         # Dev mode root token
  key_name        = "autounseal"                  # Key name in transit engine
  mount_path      = "transit/"                    # Transit engine mount path
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"

ui = true

# Disable mlock for development
disable_mlock = false