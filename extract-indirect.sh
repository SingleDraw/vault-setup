#!/bin/bash

# Indirect Reference for array assignment
# This script extracts unseal keys from a JSON file (vault-init.json) and stores them
# in an array called unseal_keys. It uses a function to parse the JSON content and
# extract the unseal keys, which are expected to be in base64 format.

extract_unseal_keys() {
  local json="$1"
  local result_var="$2"
  local keys=()

  local raw_keys
  raw_keys=$(sed -n '/"unseal_keys_b64"[[:space:]]*:[[:space:]]*\[/,/\]/p' <<< "$json")

  local skip_first=1
  while read -r line; do
    ((skip_first)) && { skip_first=0; continue; }
    [[ $line =~ \"([^\"]+)\" ]] && keys+=("${BASH_REMATCH[1]}")
  done <<< "$raw_keys"

  # Assign array via indirect reference
  eval "$result_var=()" # need to eval cause we don't know the name of the array variable in advance
  for key in "${keys[@]}"; do
    eval "$result_var+=(\"\$key\")" # same here, we need to eval to assign to the array, key must be escaped, cause it will be evaluated as a variable
  done
}


# Check if vault-init.json exists
if [[ ! -f vault-init.json ]]; then
  echo "vault-init.json not found. Please ensure it exists in the current directory."
  exit 1
fi

# Read the JSON file and extract unseal keys
json_content=$(cat vault-init.json)
if [[ -z $json_content ]]; then
  echo "vault-init.json is empty or not readable."
  exit 1
fi

extract_unseal_keys "$json_content" unseal_keys

# Now use the array
for key in "${unseal_keys[@]}"; do
  echo "Key: $key"
done