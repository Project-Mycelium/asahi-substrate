#!/bin/bash
# Formless Substrate Connection Tool
# Helps establish and troubleshoot connections to the substrate

set -euo pipefail

# Configuration
SUBSTRATE_HOSTS=(
    "100.73.161.5"      # Tailscale
    "192.168.8.114"     # LAN WiFi
    "169.254.1.2"       # Thunderbolt link-local
)
SUBSTRATE_USER="${SUBSTRATE_USER:-eric}"
SSH_OPTS="-o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Formless Substrate Connection Tool ==="
echo ""

# Function to test connectivity
test_host() {
    local host=$1
    local name=$2

    printf "  %-20s " "$name ($host)"

    # Test ping
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        printf "${GREEN}PING✓${NC} "
    else
        printf "${RED}PING✗${NC} "
        echo ""
        return 1
    fi

    # Test SSH
    if ssh $SSH_OPTS "$SUBSTRATE_USER@$host" "exit 0" &>/dev/null; then
        printf "${GREEN}SSH✓${NC}"
        echo ""
        return 0
    else
        printf "${RED}SSH✗${NC}"
        echo ""
        return 1
    fi
}

# Function to get local network info
show_local_info() {
    echo "Local Network Interfaces:"
    echo "-------------------------"
    if command -v ip &>/dev/null; then
        ip -4 addr show | grep "inet " | awk '{print "  " $2 " on " $NF}'
    else
        ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print "  " $2}'
    fi
    echo ""
}

# Function to setup SSH key
setup_ssh_key() {
    echo "SSH Key Setup"
    echo "-------------"

    local pubkey=""
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        pubkey=$(cat ~/.ssh/id_ed25519.pub)
        echo "Found ed25519 key"
    elif [[ -f ~/.ssh/id_rsa.pub ]]; then
        pubkey=$(cat ~/.ssh/id_rsa.pub)
        echo "Found RSA key"
    else
        echo "No SSH key found. Generate one with:"
        echo "  ssh-keygen -t ed25519"
        return 1
    fi

    echo ""
    echo "Run this on the substrate to authorize this machine:"
    echo ""
    echo "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubkey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    echo ""
}

# Function to connect
connect() {
    local host=$1
    echo "Connecting to $SUBSTRATE_USER@$host..."
    ssh $SSH_OPTS "$SUBSTRATE_USER@$host"
}

# Function to run diagnostic on substrate
run_diagnostic() {
    local host=$1
    echo "Running diagnostic on substrate ($host)..."
    ssh $SSH_OPTS "$SUBSTRATE_USER@$host" bash << 'DIAGNOSTIC'
echo "=== Substrate Diagnostic ==="
echo ""
echo "System:"
uname -a
echo ""
echo "OS:"
cat /etc/os-release | head -5
echo ""
echo "Kernel packages:"
rpm -qa 2>/dev/null | grep -i kernel | head -5 || dpkg -l 2>/dev/null | grep -i kernel | head -5
echo ""
echo "Asahi packages:"
rpm -qa 2>/dev/null | grep -i asahi | sort || echo "N/A"
echo ""
echo "Display:"
cat /sys/class/drm/card*/status 2>/dev/null | head -5 || echo "N/A"
echo ""
echo "Network:"
ip -4 addr show | grep "inet " | head -5
echo ""
echo "Services:"
systemctl is-active sshd tailscaled NetworkManager pipewire 2>/dev/null || echo "systemctl not available"
DIAGNOSTIC
}

# Main menu
case "${1:-scan}" in
    scan)
        show_local_info
        echo "Scanning for substrate..."
        echo "-------------------------"
        FOUND=""
        for i in "${!SUBSTRATE_HOSTS[@]}"; do
            host="${SUBSTRATE_HOSTS[$i]}"
            case $i in
                0) name="Tailscale" ;;
                1) name="LAN/WiFi" ;;
                2) name="Thunderbolt" ;;
                *) name="Host $i" ;;
            esac
            if test_host "$host" "$name"; then
                FOUND="$host"
            fi
        done
        echo ""
        if [[ -n "$FOUND" ]]; then
            echo "${GREEN}Substrate reachable at: $FOUND${NC}"
            echo "Connect with: $0 connect $FOUND"
        else
            echo "${RED}No reachable substrate found${NC}"
            echo ""
            echo "Troubleshooting:"
            echo "  1. Check substrate is powered on"
            echo "  2. Verify network connection"
            echo "  3. Run: $0 setup-key"
        fi
        ;;

    connect)
        host="${2:-}"
        if [[ -z "$host" ]]; then
            # Auto-find
            for h in "${SUBSTRATE_HOSTS[@]}"; do
                if ping -c 1 -W 2 "$h" &>/dev/null; then
                    host="$h"
                    break
                fi
            done
        fi
        if [[ -z "$host" ]]; then
            echo "No reachable host found. Specify manually: $0 connect <ip>"
            exit 1
        fi
        connect "$host"
        ;;

    diag|diagnostic)
        host="${2:-}"
        if [[ -z "$host" ]]; then
            for h in "${SUBSTRATE_HOSTS[@]}"; do
                if ssh $SSH_OPTS "$SUBSTRATE_USER@$h" "exit 0" &>/dev/null; then
                    host="$h"
                    break
                fi
            done
        fi
        if [[ -z "$host" ]]; then
            echo "No SSH-accessible host found."
            exit 1
        fi
        run_diagnostic "$host"
        ;;

    setup-key)
        setup_ssh_key
        ;;

    add-host)
        host="${2:-}"
        if [[ -z "$host" ]]; then
            echo "Usage: $0 add-host <ip>"
            exit 1
        fi
        echo "Add this to SUBSTRATE_HOSTS in the script:"
        echo "    \"$host\""
        ;;

    *)
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  scan         Scan for reachable substrate (default)"
        echo "  connect [ip] Connect to substrate via SSH"
        echo "  diag [ip]    Run diagnostic on substrate"
        echo "  setup-key    Show SSH key setup instructions"
        echo "  add-host <ip> Add a new host IP"
        ;;
esac
