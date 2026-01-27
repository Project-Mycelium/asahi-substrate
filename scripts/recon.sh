#!/bin/bash
# Formless Substrate Reconnaissance Script
# Run this on the Asahi machine and share the output

set -euo pipefail

OUTPUT="/tmp/substrate-recon-$(date +%Y%m%d-%H%M%S).txt"

{
echo "========================================"
echo "FORMLESS SUBSTRATE RECONNAISSANCE"
echo "========================================"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "=== 1. SYSTEM INFO ==="
uname -a
echo ""
cat /etc/os-release
echo ""

echo "=== 2. HARDWARE ==="
cat /sys/firmware/devicetree/base/compatible 2>/dev/null | tr '\0' '\n' || echo "N/A"
echo ""
cat /proc/cpuinfo | head -20
echo ""

echo "=== 3. KERNEL ==="
echo "Running: $(uname -r)"
echo ""
echo "Installed kernels:"
rpm -qa 2>/dev/null | grep -i kernel | sort || dpkg -l 2>/dev/null | grep -i linux-image || echo "N/A"
echo ""

echo "=== 4. ASAHI PACKAGES ==="
rpm -qa 2>/dev/null | grep -Ei "asahi|mesa|speakersafe" | sort || echo "N/A"
echo ""

echo "=== 5. LOADED MODULES ==="
lsmod | grep -Ei "apple|asahi|drm|nvme|hid|spi|brcm" || echo "None matching"
echo ""

echo "=== 6. DISPLAY / DRM ==="
echo "DRM cards:"
ls -la /sys/class/drm/ 2>/dev/null | head -10
echo ""
echo "Card status:"
for f in /sys/class/drm/card*/status; do
    echo "$f: $(cat $f 2>/dev/null || echo 'N/A')"
done
echo ""
echo "DRM drivers:"
for f in /sys/class/drm/card*/device/driver; do
    echo "$f -> $(readlink -f $f 2>/dev/null || echo 'N/A')"
done
echo ""
echo "Session type: ${XDG_SESSION_TYPE:-not set}"
echo ""

echo "=== 7. BOOT / CMDLINE ==="
cat /proc/cmdline
echo ""
ls -la /boot/ 2>/dev/null | head -15
echo ""

echo "=== 8. DMESG (DRM/Display related) ==="
dmesg 2>/dev/null | grep -Ei "drm|display|simpledrm|apple|dcp|screen|fb" | tail -50 || journalctl -k | grep -Ei "drm|display" | tail -50 || echo "N/A"
echo ""

echo "=== 9. JOURNAL ERRORS ==="
journalctl -b -p err --no-pager 2>/dev/null | tail -30 || echo "N/A"
echo ""

echo "=== 10. NETWORK ==="
ip -4 addr show | grep "inet "
echo ""
echo "Tailscale status:"
tailscale status 2>/dev/null | head -10 || echo "Tailscale not running"
echo ""

echo "=== 11. AUDIO ==="
echo "PipeWire:"
systemctl --user status pipewire 2>/dev/null | head -5 || systemctl status pipewire 2>/dev/null | head -5 || echo "N/A"
echo ""
echo "speakersafetyd:"
systemctl status speakersafetyd 2>/dev/null | head -5 || echo "N/A"
echo ""
echo "Sound cards:"
cat /proc/asound/cards 2>/dev/null || echo "N/A"
echo ""

echo "=== 12. SERVICES ==="
echo "Key services status:"
for svc in gdm gnome-shell sshd tailscaled NetworkManager pipewire speakersafetyd; do
    status=$(systemctl is-active $svc 2>/dev/null || echo "unknown")
    printf "  %-20s %s\n" "$svc" "$status"
done
echo ""

echo "=== 13. DISK / BOOT ==="
df -h / /boot 2>/dev/null || df -h
echo ""
echo "Boot entries:"
ls -la /boot/loader/entries/ 2>/dev/null || ls -la /boot/efi/loader/entries/ 2>/dev/null || echo "N/A"
echo ""

echo "=== 14. SSH CONFIG ==="
echo "SSH keys:"
ls -la ~/.ssh/ 2>/dev/null || echo "No .ssh directory"
echo ""
echo "SSHD status:"
systemctl status sshd 2>/dev/null | head -8 || echo "N/A"
echo ""

echo "========================================"
echo "END OF RECONNAISSANCE"
echo "========================================"

} 2>&1 | tee "$OUTPUT"

echo ""
echo "=== OUTPUT SAVED TO: $OUTPUT ==="
echo ""
echo "To share: cat $OUTPUT | nc termbin.com 9999"
echo "Or copy the file to USB/shared location"
