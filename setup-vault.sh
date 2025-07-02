#!/bin/bash

# """
# development.sh
# Builds the Docker images for local development and testing.
# Run & test the images using the provided menu.
# """

# read environment variables from .env file
set -a
# shellcheck disable=SC1091
source .env
set +a

# Menu options
options=(
    "Prod: Run Bootstrap Vault - Unsealer - Agent with Consul"
    "Prod: Run Client App to test Vault Agent" 
    "Dev: Run Bootstrap Vault - Unsealer - Consul"
    "Dev: Setup Ansible Secrets in Vault"
    "Dev: Read Ansible Secrets from Vault"
    "Destroy: Remove all containers and volumes"
    "Exit"
)

# Selected option index
selected=0

# Function to display the menu
draw_menu() {
    clear
    echo "HashiCorp Vault Setup"
    echo "Transit Auto-Unsealing Pattern with Vault Agent and Consul"
    echo "------------------------------------------------------------"
    echo "Select an option:"
    echo "------------------------------------------------------------"
    for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
            echo -e "> \e[1;32m${options[i]}\e[0m"
        else
            echo "  ${options[i]}"
        fi
    done
    echo "------------------------------------------------------------"
    echo " - Use ↑ ↓ arrows to navigate, Enter to select.             "
    echo "------------------------------------------------------------"
    echo "Current selection: ${options[selected]}"
}

# Capture arrow keys and enter
while true; do
    draw_menu

    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.001 key
        case $key in
            "[A") ((selected--));;  # Up
            "[B") ((selected++));;  # Down
        esac
    elif [[ $key == "" ]]; then
        case $selected in
            0)
                echo "Bootstrapping Vault with Unsealer and Consul..."
                (
                    ./bin/scripts/prod.bootstrap.sh
                )
                ;;
            1)
                echo "Running Client App to test Vault Agent..."
                (
                    ./bin/scripts/prod.client-app.sh
                )
                ;;
            2)
                echo "Bootstrapping Vault with Unsealer and Consul in development mode..."
                (
                    ./bin/scripts/dev.bootstrap.sh
                )
                ;;
            3)
                echo "Setting up Ansible Secrets in Vault..."
                (
                    ./bin/scripts/dev.setup-ansible-secrets.sh
                )
                ;;
            4)
                echo "Reading Ansible Secrets from Vault..."
                (
                    ./bin/scripts/dev.read-ansible-secrets.sh
                )
                ;;
            5)
                echo "Destroying all containers and volumes..."
                (                    
                    ./bin/destroy
                )
                ;;
            6)
                echo "Exiting..."
                exit 0
                ;;
        esac
        read -rp "Press any key to return to menu..." -n1
    fi

    # Wrap around
    ((selected < 0)) && selected=$((${#options[@]} - 1))
    ((selected >= ${#options[@]})) && selected=0
done

