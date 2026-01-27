#!/bin/bash
# Add SSH key to substrate authorized_keys.d for baked-in access
# Usage: ./scripts/add-ssh-key.sh [key-file] [name]
#
# Examples:
#   ./scripts/add-ssh-key.sh                              # Add default key with hostname
#   ./scripts/add-ssh-key.sh ~/.ssh/id_rsa.pub work-laptop
#   ./scripts/add-ssh-key.sh - my-key < key.pub           # Read from stdin

set -euo pipefail

KEYS_DIR="src/build_files/authorized_keys.d"

# Ensure directory exists
mkdir -p "$KEYS_DIR"

# Determine key source
if [[ "${1:-}" == "-" ]]; then
    # Read from stdin
    KEY_CONTENT=$(cat)
    KEY_NAME="${2:-stdin}"
elif [[ -n "${1:-}" && -f "$1" ]]; then
    KEY_CONTENT=$(cat "$1")
    KEY_NAME="${2:-$(basename "$1" .pub)}"
else
    # Default: use local ed25519 or rsa key
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        KEY_CONTENT=$(cat ~/.ssh/id_ed25519.pub)
    elif [[ -f ~/.ssh/id_rsa.pub ]]; then
        KEY_CONTENT=$(cat ~/.ssh/id_rsa.pub)
    else
        echo "Error: No SSH key found. Generate one with: ssh-keygen -t ed25519"
        exit 1
    fi
    KEY_NAME="${2:-$(hostname -s)}"
fi

# Validate key format
if ! echo "$KEY_CONTENT" | grep -qE '^ssh-(ed25519|rsa|ecdsa)'; then
    echo "Error: Invalid SSH public key format"
    exit 1
fi

# Write key
KEY_FILE="$KEYS_DIR/${KEY_NAME}.pub"
echo "$KEY_CONTENT" > "$KEY_FILE"
echo "Added key: $KEY_FILE"

# Show all registered keys
echo ""
echo "Registered keys for substrate builds:"
for f in "$KEYS_DIR"/*.pub; do
    [[ -f "$f" ]] && echo "  - $(basename "$f"): $(cut -d' ' -f1-2 "$f" | cut -c1-50)..."
done

echo ""
echo "These keys will be baked into the next substrate build."
echo "To authorize on a running system, copy the key manually:"
echo "  ssh user@host 'cat >> ~/.ssh/authorized_keys' < $KEY_FILE"
