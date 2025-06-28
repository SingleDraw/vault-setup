# Development configuration (vault-config/vault.hcl)

# Filesystem storage for development
# This configuration is suitable for local development and testing.
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"  # Listen on all interfaces on port 8200
  tls_disable = 1               # Disable TLS for development purposes
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"
ui = true

# Disable mlock for development
disable_mlock = true