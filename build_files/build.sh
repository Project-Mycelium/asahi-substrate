#!/bin/bash
set -ouex pipefail

# --- PACKAGES ---
# Install standard packages via dnf5
# (Add your custom tools here later, e.g., 'fish', 'zsh' if not in base)
dnf5 install -y tmux fastfetch

# --- SYSTEM UNITS ---
# Enable Podman socket for containers
systemctl enable podman.socket

# --- ASAHI POST-PROCESSING ---
# Critical: Regenerate initramfs for the 16k kernel so the machine can boot
echo "⚡ Regenerating initramfs for Asahi (16k)..."
dracut --force --add-drivers "nvme-apple" --kver $(rpm -q kernel-16k --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}+16k')

# --- CLEANUP ---
# Ensure no temporary files persist
rm -rf /tmp/*