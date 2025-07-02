# Vault Transit Auto-Unsealing with Consul & Agent Demo

A local environment demonstrating **Vault Transit Auto-Unsealing** with **Consul** as the storage backend. Includes a **Vault Agent** example, **Ansible secret storage**, and an interactive menu for managing it all.

---

## Features

* 🔐 Vault auto-unsealing using Transit & Consul
* ⚙️ Vault Agent mode with containerized client app
* 🧪 Ansible secrets: write & read from Vault KV
* 🧰 Interactive terminal menu via `setup-vault.sh`
* 🧹 One-command teardown for cleanup

---

## Menu Options (`./setup-vault.sh`)

* **Agent Mode: Run Vault + Unsealer + Agent + Consul**
  Simulates a production-like setup with Vault Agent. Uses pre-exported JSON credentials (e.g. `role_id`, `secret_id`) for testing and display purposes.

* **Agent Mode: Run Client App to test Vault Agent**
  Launches a Python container app that authenticates using Vault Agent and fetches secrets.

* **Dev Mode: Run Vault + Unsealer + Consul**
  Starts Vault in development mode with auto-unseal using the root token from `.env`.

* **Dev Mode: Setup Ansible Secrets in Vault**
  Writes mock secrets into Vault KV for Ansible testing.

* **Dev Mode: Read Ansible Secrets from Vault**
  Reads the stored secrets, simulating secure retrieval by a client like Ansible.

* **Destroy All**
  Removes all containers and volumes to reset the environment.

---

## Structure

```text
.
├── bin
│   ├── scripts
│   │   ├── dev.bootstrap.sh
│   │   ├── dev.read-ansible-secrets.sh
│   │   ├── dev.setup-ansible-secrets.sh
│   │   ├── prod.bootstrap.sh
│   │   └── prod.client-app.sh
│   ├── destroy
│   └── ...
├── client-app
│   ├── app.py
│   ├── Dockerfile
│   └── entrypoint.sh
├── vault-config
│   ├── dev/
│   └── prod/
│       ├── agent/
│       │   ├── creds/
│       │   │   ├── role_id
│       │   │   └── secret_id
│       │   └── agent.hcl
│       ├── main/
│       │   ├── vault.hcl
│       │   └── vault.hcl.tpl
│       └── unsealer/
│           └── unsealer.hcl
├── docker-compose-*.yml
├── setup-vault.sh   ← Main menu entrypoint
├── .env             ← Environment variables
└── README.md
```

---

## Notes

* **Production mode** uses an initialized and sealed Vault with external unsealer logic (manual or scripted).
* **Development mode** uses pre-configured root token auto-unsealer for testing purposes.
* The **Vault Agent** in prod allows dynamic secret injection to apps without exposing tokens.

## Requirements

* Docker & Docker Compose
* Bash
* Vault & Consul images pulled automatically