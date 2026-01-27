#!/bin/bash
# Remote Access Layer Setup
# Called during container build to configure SSH + Tailscale

set -euo pipefail

echo "=== Configuring Remote Access Layer ==="

# Install packages
dnf install -y --setopt=install_weak_deps=False \
    tailscale \
    openssh-server

# Enable services (start early in boot)
systemctl enable tailscaled.service
systemctl enable sshd.service

# SSH Hardening
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Ensure .ssh directory exists in skeleton
mkdir -p /etc/skel/.ssh
chmod 700 /etc/skel/.ssh

echo "=== Remote Access Layer configured ==="
echo "  - tailscaled.service enabled"
echo "  - sshd.service enabled"
echo "  - Password auth disabled"
echo "  - Root login disabled"
