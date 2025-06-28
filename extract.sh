#!/bin/bash

extract_unseal_keys() {
  # ------------------------------------------------------
  # Function to extract unseal keys from the JSON file
  # ------------------------------------------------------
  local json="$1"
  local keys=()

  # Extract lines between "unseal_keys_b64": [ and ]
  local raw_keys=$(sed -n '/"unseal_keys_b64"[[:space:]]*:[[:space:]]*\[/,/\]/p' <<< "$json")

  # Extract all quoted strings (assumes no embedded quotes or escaped quotes)
  local skip_first=1
  while read -r line; do
    # Skip the first line which is the "unseal_keys_b64": [
    ((skip_first)) && { skip_first=0; continue; }
    [[ $line =~ \"([^\"]+)\" ]] && keys+=("${BASH_REMATCH[1]}")
  done <<< "$raw_keys"

  # Output or use the keys array
  printf '%s\n' "${keys[@]}"
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------

# Check if vault-init.json exists
if [[ -f vault-init.json ]]; then
  echo "vault-init.json found. Extracting unseal keys..."
  # Read the JSON file and extract unseal keys
  unseal_keys=$(extract_unseal_keys "$(cat vault-init.json)")
  if [[ -n $unseal_keys ]]; then
    echo "Unseal keys extracted:
    "
    echo "$unseal_keys"
  else
    echo "No unseal keys found in vault-init.json."
  fi
else
  echo "vault-init.json not found. Please ensure it exists in the current directory."
  exit 1
fi