#!/bin/bash
# Asahi Substrate Diagnostic Script
# Run this on the Asahi Linux machine and copy results back
# Usage: sudo ./asahi-diag.sh

set -euo pipefail

OUTPUT_DIR="/tmp/asahi-diag-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Asahi Substrate Diagnostic ===" | tee "$OUTPUT_DIR/00-header.txt"
echo "Date: $(date)" | tee -a "$OUTPUT_DIR/00-header.txt"
echo "Output: $OUTPUT_DIR" | tee -a "$OUTPUT_DIR/00-header.txt"
echo ""

# System Info
echo "[1/12] System info..."
{
    echo "=== uname ==="
    uname -a
    echo ""
    echo "=== os-release ==="
    cat /etc/os-release
    echo ""
    echo "=== CPU ==="
    cat /proc/cpuinfo | head -30
    echo ""
    echo "=== Memory ==="
    free -h
    echo ""
    echo "=== Device Tree Compatible ==="
    cat /sys/firmware/devicetree/base/compatible 2>/dev/null || echo "N/A"
} > "$OUTPUT_DIR/01-system.txt" 2>&1

# Boot Info
echo "[2/12] Boot info..."
{
    echo "=== Kernel cmdline ==="
    cat /proc/cmdline
    echo ""
    echo "=== /boot contents ==="
    ls -la /boot/
    echo ""
    echo "=== EFI boot entries ==="
    efibootmgr -v 2>/dev/null || echo "efibootmgr not available"
    echo ""
    echo "=== Bootloader entries ==="
    ls -la /boot/loader/entries/ 2>/dev/null || echo "No loader entries"
    cat /boot/loader/entries/*.conf 2>/dev/null || echo ""
} > "$OUTPUT_DIR/02-boot.txt" 2>&1

# Kernel & Modules
echo "[3/12] Kernel modules..."
{
    echo "=== Loaded modules ==="
    lsmod
    echo ""
    echo "=== Apple-related modules ==="
    lsmod | grep -i apple || echo "No apple modules"
    echo ""
    echo "=== DRM modules ==="
    lsmod | grep -i drm || echo "No drm modules"
    echo ""
    echo "=== Kernel packages ==="
    rpm -qa | grep -i kernel || echo ""
} > "$OUTPUT_DIR/03-kernel.txt" 2>&1

# Display / DRM
echo "[4/12] Display info..."
{
    echo "=== DRM cards ==="
    ls -la /sys/class/drm/
    echo ""
    echo "=== DRM status ==="
    for card in /sys/class/drm/card*/; do
        echo "--- $card ---"
        cat "$card/status" 2>/dev/null || echo "N/A"
        cat "$card/modes" 2>/dev/null || echo "N/A"
    done
    echo ""
    echo "=== DRM driver ==="
    for card in /sys/class/drm/card*/device/driver; do
        echo "$card:"
        ls -la "$card" 2>/dev/null || echo "N/A"
    done
    echo ""
    echo "=== Session type ==="
    loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type 2>/dev/null || echo "N/A"
    echo ""
    echo "=== Wayland/X11 ==="
    echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-unset}"
    echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-unset}"
    echo "DISPLAY: ${DISPLAY:-unset}"
} > "$OUTPUT_DIR/04-display.txt" 2>&1

# DRM/GPU Logs
echo "[5/12] DRM logs..."
{
    echo "=== dmesg DRM ==="
    dmesg | grep -i "drm\|display\|gpu\|screen\|simpledrm\|apple" | head -200
} > "$OUTPUT_DIR/05-dmesg-drm.txt" 2>&1

# Journal Errors
echo "[6/12] Journal errors..."
{
    echo "=== Boot errors ==="
    journalctl -b -p err --no-pager | head -200
    echo ""
    echo "=== Display-related journal ==="
    journalctl -b | grep -i "drm\|display\|gpu\|screen\|gdm\|gnome-shell" | head -200
} > "$OUTPUT_DIR/06-journal.txt" 2>&1

# Audio
echo "[7/12] Audio info..."
{
    echo "=== PipeWire status ==="
    systemctl --user status pipewire 2>/dev/null || systemctl status pipewire 2>/dev/null || echo "N/A"
    echo ""
    echo "=== WirePlumber status ==="
    systemctl --user status wireplumber 2>/dev/null || echo "N/A"
    echo ""
    echo "=== speakersafetyd status ==="
    systemctl status speakersafetyd 2>/dev/null || echo "N/A"
    echo ""
    echo "=== Audio devices ==="
    cat /proc/asound/cards 2>/dev/null || echo "N/A"
    echo ""
    echo "=== PipeWire config ==="
    ls -la /etc/pipewire/pipewire.conf.d/ 2>/dev/null || echo "No custom config"
    cat /etc/pipewire/pipewire.conf.d/*.conf 2>/dev/null || echo ""
} > "$OUTPUT_DIR/07-audio.txt" 2>&1

# Network
echo "[8/12] Network info..."
{
    echo "=== Interfaces ==="
    ip addr show
    echo ""
    echo "=== WiFi ==="
    nmcli dev wifi list 2>/dev/null || echo "N/A"
    echo ""
    echo "=== Firmware ==="
    ls -la /lib/firmware/brcm/ 2>/dev/null | head -20 || echo "N/A"
} > "$OUTPUT_DIR/08-network.txt" 2>&1

# Power
echo "[9/12] Power info..."
{
    echo "=== Battery ==="
    upower -i /org/freedesktop/UPower/devices/battery_macsmc_battery 2>/dev/null || \
    cat /sys/class/power_supply/*/uevent 2>/dev/null || echo "N/A"
    echo ""
    echo "=== Power profile ==="
    powerprofilesctl get 2>/dev/null || echo "N/A"
} > "$OUTPUT_DIR/09-power.txt" 2>&1

# Asahi Packages
echo "[10/12] Asahi packages..."
{
    echo "=== Asahi-related RPMs ==="
    rpm -qa | grep -i "asahi\|m1n1\|mesa\|speakersafe" | sort
    echo ""
    echo "=== Kernel version ==="
    rpm -qa | grep kernel | sort
} > "$OUTPUT_DIR/10-packages.txt" 2>&1

# Services
echo "[11/12] Services..."
{
    echo "=== Failed services ==="
    systemctl --failed
    echo ""
    echo "=== Key services ==="
    for svc in gdm gnome-shell NetworkManager bluetooth pipewire speakersafetyd; do
        echo "--- $svc ---"
        systemctl status "$svc" 2>/dev/null | head -10 || echo "N/A"
    done
} > "$OUTPUT_DIR/11-services.txt" 2>&1

# Full dmesg (for deep analysis)
echo "[12/12] Full dmesg..."
{
    dmesg
} > "$OUTPUT_DIR/12-dmesg-full.txt" 2>&1

# Create tarball
echo ""
echo "Creating archive..."
TARBALL="/tmp/asahi-diag-$(hostname)-$(date +%Y%m%d).tar.gz"
tar -czf "$TARBALL" -C /tmp "$(basename $OUTPUT_DIR)"

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
echo "Results: $OUTPUT_DIR/"
echo "Archive: $TARBALL"
echo ""
echo "To transfer to your Mac:"
echo "  scp $TARBALL youruser@yourmac:~/Desktop/"
echo ""
echo "Or view locally:"
echo "  cat $OUTPUT_DIR/04-display.txt   # Display issues"
echo "  cat $OUTPUT_DIR/05-dmesg-drm.txt # DRM logs"
echo "  cat $OUTPUT_DIR/06-journal.txt   # Boot errors"
