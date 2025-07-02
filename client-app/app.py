import os
import hvac

VAULT_ADDR = os.getenv("VAULT_ADDR", "http://vault:8200")
TOKEN_PATH = os.getenv("VAULT_TOKEN_PATH", "/vault/agent-data/agent-token")

def read_token():
    with open(TOKEN_PATH, "r") as f:
        return f.read().strip()

def main():
    token = read_token()
    client = hvac.Client(url=VAULT_ADDR, token=token)

    secret_path = "secret/data/myapp/apikey"
    secret = client.secrets.kv.v2.read_secret_version(path="myapp/apikey")

    print("API Key from Vault:", secret['data']['data']['api_key'])

if __name__ == "__main__":
    main()
