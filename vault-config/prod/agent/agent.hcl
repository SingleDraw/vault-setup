exit_after_auth = false
pid_file = "/vault/agent-data/vault-agent.pid"

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/vault/config/creds/role_id"
      # Approach # 1: Use permanent secret_id file
      secret_id_file_path = "/vault/config/creds/secret_id"
      remove_secret_id_file_after_reading = false # Keep the secret_id file for case of container restart

      # Approach # 2: Use secret_id response wrapping
      # secret_id_response_wrapping_path = "auth/approle/role/vault-agent-role/secret-id"
      # secret_id_response_wrapping_token_file = "/vault/config/creds/wrapping_token"

      # Let the agent pull a fresh secret_id
      # secret_id_ttl = "10m"
      # secret_id_num_uses = 0

      # secret_id_file_path = "/vault/config/creds/secret_id"
    }
  }

  sink "file" {
    config = {
      path = "/vault/agent-data/agent-token"
      # mode = 0640 # User read/write, group read only - Vault Agent and Client App must share the same group (not only name but GID)
    }
  }

  # sink "unix" {
  #   config = {
  #     path = "/vault/agent-data/agent-token"
  #   }
  # }

}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "0.0.0.0:8100"
  tls_disable = true
}

