#!/bin/bash
# Phase 3: Boot Chain Investigation Script
# Run on deployed M1 hardware to investigate boot sequence
# Based on: plans/BOOT_CHAIN_RESEARCH.md

HARDWARE_IP="${1:-192.168.8.114}"
HARDWARE_USER="formless"

echo "=========================================="
echo "Phase 3: Boot Chain Investigation"
echo "=========================================="
echo "Target: $HARDWARE_USER@$HARDWARE_IP"
echo ""
echo "This script runs investigation commands from BOOT_CHAIN_RESEARCH.md"
echo "to identify mystery Fedora spinner and U-Boot configuration."
echo ""

# Check if hardware is reachable
echo "Checking hardware connectivity..."
if ! ping -c 1 -t 2 "$HARDWARE_IP" >/dev/null 2>&1; then
    echo "❌ Cannot reach $HARDWARE_IP"
    exit 1
fi
echo "✅ Hardware is reachable"
echo ""

# Create temporary results file
RESULTS="/tmp/phase3-results-$(date +%s).txt"
echo "Recording results to: $RESULTS"
echo ""

# Helper function to run SSH commands and log results
run_investigation() {
    local title="$1"
    local command="$2"

    echo "=== $title ===" | tee -a "$RESULTS"
    echo "Command: $command" | tee -a "$RESULTS"
    ssh "$HARDWARE_USER@$HARDWARE_IP" "$command" 2>&1 | tee -a "$RESULTS"
    echo "" | tee -a "$RESULTS"
}

# ====== Task 1: Identify Mystery Fedora Spinner ======
echo "Task 1: Identify Mystery Fedora Spinner"
echo "========================================="
echo ""

run_investigation \
    "1a. Initramfs Splash Files" \
    "lsinitrd /boot/initramfs-*.img 2>/dev/null | grep -iE '(fedora|plymouth|splash|bgrt|logo)' || echo 'No splash files found'"

run_investigation \
    "1b. Plymouth Status" \
    "systemctl status plymouth-start 2>&1 || echo 'Plymouth not running'"

run_investigation \
    "1c. Applied Kernel Cmdline" \
    "cat /proc/cmdline | tr ' ' '\n'"

run_investigation \
    "1d. Boot Logs for Splash" \
    "journalctl -b 2>&1 | grep -iE '(splash|plymouth|logo|fedora|bgrt)' | head -20 || echo 'No splash messages in logs'"

run_investigation \
    "1e. Fedora Logos Package" \
    "rpm -qa | grep -E '(fedora-logos|fedora-release|fedora-backgrounds)'"

run_investigation \
    "1f. Plymouth Themes" \
    "ls -la /usr/share/plymouth/themes/ 2>/dev/null || echo 'No Plymouth themes directory'"

run_investigation \
    "1g. Systemd Boot Status" \
    "bootctl status 2>&1 || echo 'bootctl not available'"

# ====== Task 2: U-Boot Configuration Access ======
echo ""
echo "Task 2: U-Boot Configuration"
echo "============================="
echo ""

run_investigation \
    "2a. Check uboot-tools" \
    "which fw_printenv fw_setenv 2>/dev/null && echo '✅ uboot-tools available' || echo '❌ uboot-tools not found'"

run_investigation \
    "2b. U-Boot Environment" \
    "sudo fw_printenv 2>/dev/null | head -20 || echo 'Cannot access U-Boot environment'"

run_investigation \
    "2c. U-Boot Boot Delay" \
    "sudo fw_printenv bootdelay 2>/dev/null || echo 'bootdelay not found'"

run_investigation \
    "2d. U-Boot Splash Config" \
    "sudo fw_printenv 2>/dev/null | grep -iE '(splash|boot_logo|bootcmd)' || echo 'No splash config found'"

# ====== Task 3: Kernel Cmdline Verification ======
echo ""
echo "Task 3: Kernel Cmdline Verification"
echo "===================================="
echo ""

run_investigation \
    "3a. Applied Kernel Parameters" \
    "cat /proc/cmdline"

run_investigation \
    "3b. Quiet Parameter Check" \
    "grep -q quiet /proc/cmdline && echo '✅ quiet parameter applied' || echo '❌ quiet parameter NOT applied'"

run_investigation \
    "3c. Systemd Status Setting" \
    "grep -q 'systemd.show_status=false' /proc/cmdline && echo '✅ systemd.show_status=false applied' || echo '❌ not applied'"

# ====== Task 4: Formless Service Status ======
echo ""
echo "Task 4: Formless Service Status"
echo "================================"
echo ""

run_investigation \
    "4a. Systemd Default Target" \
    "systemctl get-default"

run_investigation \
    "4b. Formless Service Status" \
    "systemctl status formless.service 2>&1 | head -15"

run_investigation \
    "4c. Formless Target Status" \
    "systemctl status formless.target 2>&1 | head -15"

run_investigation \
    "4d. Getty TTY2 Status (Fallback)" \
    "systemctl status getty@tty2.service 2>&1 | head -10"

run_investigation \
    "4e. Recent Boot Logs" \
    "journalctl -b -n 50 | grep -iE '(formless|boot|startup|error)' || echo 'No matching messages'"

# ====== Task 5: Performance Metrics ======
echo ""
echo "Task 5: Boot Performance"
echo "======================="
echo ""

run_investigation \
    "5a. Boot Time Analysis" \
    "systemd-analyze 2>&1 | head -10"

run_investigation \
    "5b. Detailed Boot Time" \
    "systemd-analyze blame 2>&1 | head -20"

run_investigation \
    "5c. Critical Chain" \
    "systemd-analyze critical-chain 2>&1 | head -30"

# ====== Summary ======
echo ""
echo "=========================================="
echo "Investigation Complete!"
echo "=========================================="
echo "Results saved to: $RESULTS"
echo ""
echo "Next steps:"
echo "1. Review the results file for key findings"
echo "2. Look for mystery Fedora spinner source"
echo "3. Check if U-Boot tools are available"
echo "4. Verify kernel cmdline parameters applied"
echo "5. Update BOOT_CHAIN_RESEARCH.md with findings"
echo ""
echo "Copy results file to analysis:"
echo "  scp $HARDWARE_USER@$HARDWARE_IP:$RESULTS ./phase3-results.txt"
echo ""
