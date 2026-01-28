# Phase 3 Execution Guide - Ready to Deploy

**Build Status:** ✅ COMPLETE
**Date:** 2026-01-28
**Image:** ghcr.io/ericrowan/asahi-substrate:latest (6 GB, locally built)

---

## Build Verification

✅ Container built successfully
✅ Asahi kernel confirmed (6.17.12-400.asahi.fc42.aarch64+16k)
✅ Bootc lint passed (non-fatal warnings only)
✅ All Phase 2 changes integrated
  - Direct Formless TUI boot (no login)
  - Systemd target configured for boot default
  - System command framework ready
  - Kernel parameters optimized for quiet boot

---

## Deployment Workflow

### Step 1: Push to Registry (Development Machine)

```bash
# Make sure you're logged in to GHCR
podman login ghcr.io

# Push the built image
podman push ghcr.io/ericrowan/asahi-substrate:latest

# Verify push
podman image inspect ghcr.io/ericrowan/asahi-substrate:latest | grep Id
```

**Expected:** Image pushed to registry, no errors

---

### Step 2: Deploy to Hardware (M1 MacBook - 192.168.8.114)

SSH to the hardware and apply the new image:

```bash
# SSH to hardware
ssh formless@192.168.8.114

# Apply new image with bootc
sudo bootc switch ghcr.io/ericrowan/asahi-substrate:latest

# When prompted to reboot, confirm
# Note: First boot may take longer as system initializes

# Monitor boot from console (observe visuals, timing)
sudo systemctl reboot

# Boot will show:
# 1. Apple logo (firmware)
# 2. Asahi logo (m1n1)
# 3. Fedora guitar pick (U-Boot splash)
# 4. "Hit any key..." countdown (U-Boot menu)
# 5. [MYSTERY] Fedora spinner - WE'RE INVESTIGATING THIS
# 6. Console font change (large HiDPI)
# 7. Formless TUI appears ← OUR GOAL (should see directly, no login)
```

**Expected Boot Flow:**
- Total time: ~11-15 seconds
- Formless TUI appears with no login prompt
- Dashboard ready to use

---

### Step 3: Post-Boot Investigation (Optional - From Dev Machine)

```bash
# Once hardware is booted and stable, run investigation
bash ./scripts/phase3/02-phase3-investigate.sh 192.168.8.114

# This will:
# - Check mystery Fedora spinner source
# - Verify U-Boot configuration accessibility
# - Confirm kernel cmdline parameters applied
# - Collect boot performance metrics
# - Save results to timestamped file

# Results file will be: phase3-results-<timestamp>.txt
```

---

### Step 4: Manual Investigation (If Script Issues)

If the investigation script encounters issues, run individual commands:

```bash
# SSH to hardware first
ssh formless@192.168.8.114

# Task 1: Identify mystery spinner
lsinitrd /boot/initramfs-*.img 2>/dev/null | grep -iE '(fedora|plymouth|splash|bgrt|logo)'
systemctl status plymouth-start 2>&1 || echo 'Plymouth not running'
cat /proc/cmdline | tr ' ' '\n'
journalctl -b | grep -iE '(splash|plymouth|logo)' | head -20

# Task 2: U-Boot configuration
which fw_printenv fw_setenv 2>/dev/null && echo '✅ uboot-tools available' || echo '❌ not found'
sudo fw_printenv 2>/dev/null | head -20 || echo 'Cannot access'
sudo fw_printenv bootdelay 2>/dev/null || echo 'Not found'

# Task 3: Kernel cmdline verification
cat /proc/cmdline
grep -q quiet /proc/cmdline && echo '✅ quiet applied' || echo '❌ not applied'

# Task 4: Formless service status
systemctl get-default  # Should be: formless.target
systemctl status formless.service
systemctl status formless.target

# Task 5: Boot performance
systemd-analyze
systemd-analyze blame | head -20
```

---

## Investigation Focus

### Priority 1: Mystery Fedora Spinner
- **What:** Screen showing horizontal Fedora logo with spinner
- **Observed:** Between U-Boot menu and Formless TUI startup
- **Goal:** Identify source
  - Plymouth (disabled, but packages still present?)
  - systemd splash (built-in splash screen)
  - BGRT (Boot Graphics Resource Table from firmware)
  - dracut spinner
- **Action:** Run investigation script Task 1

### Priority 2: U-Boot Countdown (2 second waste)
- **What:** "Hit any key to stop autoboot: 2..." menu
- **Impact:** ~2 seconds added to boot time
- **Solution:** Reduce/eliminate via fw_setenv if uboot-tools available
- **Action:** Run investigation script Task 2

### Priority 3: Visual Optimization
- Lower priority than boot time (already good at 11.93s)
- May require m1n1 or U-Boot reconfiguration
- Only pursue if spinner source identified and fixable

---

## Success Criteria

✅ **Deployment succeeds** - Hardware boots to Formless TUI
✅ **Direct TUI boot** - No login prompt, dashboard appears immediately
✅ **Boot time documented** - systemd-analyze shows actual time
✅ **Investigation complete** - All Task 1-5 commands executed
✅ **Mystery spinner identified** - Source determined
✅ **U-Boot accessible** - fw_printenv works or documented why not
✅ **Findings committed** - Results updated in BOOT_CHAIN_RESEARCH.md

---

## Files for This Phase

```
scripts/phase3/
├── 01-phase3-build.sh              ✅ COMPLETE - Build container
├── 02-phase3-investigate.sh        ⏳ READY - Run after deployment
├── 03-phase3-test-checklist.md     ⏳ Use to track testing
├── README.md                        ← Quick reference
└── PHASE3_EXECUTION_GUIDE.md      ← You are here
```

---

## Hardware Status

**IP:** 192.168.8.114
**User:** formless
**Auth:** SSH key-based
**Current Image:** Previous Phase 2 build
**Emergency Fallback:** Ctrl+Alt+F2 for getty@tty2 shell

---

## Next Steps (After Phase 3 Complete)

1. Update `plans/BOOT_CHAIN_RESEARCH.md` with investigation results
2. Commit findings to git:
   ```bash
   git add plans/BOOT_CHAIN_RESEARCH.md docs/phase3-results-*.txt
   git commit -m "docs: Phase 3 investigation findings and boot analysis"
   ```
3. If spinner identified and fixable, plan Phase 3.5 optimization
4. Move to Phase 4: System Command Backends
   - Implement `formless substrate` command backends
   - Add privilege escalation (sudo/polkit)
   - Test all commands from TUI

---

## Troubleshooting

### Boot doesn't reach Formless TUI
1. Ctrl+Alt+F2 to access emergency shell
2. Check service: `systemctl status formless.service`
3. Check logs: `journalctl -u formless.service -n 50`
4. Restart: `sudo systemctl restart formless.service`

### Investigation script fails
1. Check hardware connectivity: `ping 192.168.8.114`
2. Check SSH key works: `ssh formless@192.168.8.114 echo test`
3. Run investigation commands manually (see Step 4 above)

### U-Boot tools not available
1. Try install: `sudo dnf install uboot-tools`
2. If fails: may be unavailable in Fedora Asahi
3. Document limitation in BOOT_CHAIN_RESEARCH.md

---

## Questions During Deployment?

1. **Boot stuck?** Use Ctrl+Alt+F2 for shell access
2. **Can't SSH?** Check IP (192.168.8.114) and network connectivity
3. **Formless not starting?** Check journalctl logs for errors
4. **Need to revert?** Previous image still available on hardware

---

**Status:** Ready to deploy! All scripts prepared, hardware ready, investigation framework in place.
