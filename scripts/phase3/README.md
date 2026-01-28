# Phase 3 Deployment Kit

**Status:** Ready for Phase 3 Boot Testing and Optimization
**Date:** 2026-01-28

---

## What's Inside

This directory contains everything needed to deploy Phase 2 to M1 hardware and run Phase 3 testing.

### Scripts

1. **`01-phase3-build.sh`** - Build Containerfile with validation
   ```bash
   ./01-phase3-build.sh [tag]  # Default tag: latest
   ```
   - Builds the Containerfile.substrate
   - Validates Asahi kernel is present
   - Shows bootc lint results
   - Ready to push to registry

2. **`02-phase3-investigate.sh`** - Boot chain investigation
   ```bash
   ./02-phase3-investigate.sh [hardware-ip]  # Default: 192.168.8.114
   ```
   - Runs all investigation commands from BOOT_CHAIN_RESEARCH.md
   - SSH to hardware and collects data
   - Identifies mystery Fedora spinner
   - Checks U-Boot configuration
   - Verifies kernel cmdline parameters
   - Saves results to timestamped file

3. **`03-phase3-test-checklist.md`** - Complete testing checklist
   - Pre-deployment validation
   - Boot sequence observation guide
   - Post-boot service verification
   - Agent spawning tests
   - Documentation template
   - Success criteria

---

## Quick Start (Phase 3)

### Step 1: Build Container (Local Development Machine)

```bash
cd /Users/eric/dev/personal/asahi-substrate

# Build the container
bash ./scratchpad/01-phase3-build.sh latest

# Expected output:
# ✅ Build successful!
# Image: ghcr.io/ericrowan/asahi-substrate:latest
```

**What this does:**
- Validates Containerfile.substrate syntax
- Ensures Phase 2 changes are correct
- Confirms Asahi kernel is in image
- Shows any bootc lint warnings (non-fatal)

### Step 2: Deploy to Hardware (Optional - if using registry)

```bash
# Push to registry
podman push ghcr.io/ericrowan/asahi-substrate:latest

# On M1 hardware (192.168.8.114):
ssh formless@192.168.8.114
sudo bootc switch ghcr.io/ericrowan/asahi-substrate:latest
sudo systemctl reboot
```

### Step 3: Test Boot Sequence

Observe the boot sequence on hardware and document:
- Visual flow (logos, splash screens)
- Boot time (should be ~11-15 seconds)
- Formless TUI appears directly (no login)
- Fallback shell works (Ctrl+Alt+F2)

### Step 4: Run Investigation

```bash
# From development machine, run investigation script
bash ./scratchpad/02-phase3-investigate.sh 192.168.8.114

# Expected output:
# - Mystery Fedora spinner source identified
# - U-Boot configuration accessible (or not)
# - Kernel cmdline parameters verified
# - Boot performance metrics collected
```

### Step 5: Document Findings

Open `03-phase3-test-checklist.md` and fill in:
- [ ] Boot visuals observed
- [ ] Service status verified
- [ ] Investigation results recorded
- [ ] Next steps identified

Update `plans/BOOT_CHAIN_RESEARCH.md` with actual findings and commit.

---

## Hardware Details

**Target:** Apple M1 MacBook
**IP:** 192.168.8.114
**User:** formless
**Auth:** SSH key-based (no password)
**Emergency:** Ctrl+Alt+F2 → getty@tty2 shell

---

## Phase 2 Review (Before Deploying)

Phase 2 completed:
- ✅ Direct Formless TUI boot (no login prompt)
- ✅ Systemd target configured for boot default
- ✅ Substrate command framework (7 categories)
- ✅ Boot chain research documented

**Key files changed:**
- `src/Containerfile.substrate` - Boot config + kernel params
- `src/build_files/formless.{service,target,boot.sh}`
- `crates/formless-cli/src/substrate.rs` - CLI commands

**Commits:**
- Substrate: `2a7c05b`
- Kernel: `4f95cd8`

---

## Phase 3 Goals

1. ✅ Validate build process (done - build script)
2. ⏳ Deploy to hardware
3. ⏳ Verify boot sequence end-to-end
4. ⏳ Run investigation commands
5. ⏳ Document findings
6. ⏳ Test agent spawning

---

## Expected Boot Flow

```
Power on
  ↓
Apple logo (firmware - unavoidable)
  ↓
Asahi logo (m1n1 stage 1)
  ↓
Fedora guitar pick (U-Boot splash)
  ↓
"Hit any key..." countdown (U-Boot menu - 2 seconds)
  ↓
[MYSTERY] Fedora spinner - INVESTIGATE
  ↓
Console font changes (large HiDPI font)
  ↓
Formless TUI appears ✅ (no login prompt)
  ↓
Formless dashboard ready
```

**Current Boot Time:** 11.93 seconds
**Target:** <15 seconds ✅ Already achieved!
**Focus:** Boot visuals + mystery spinner identification

---

## Investigation Focus

### Priority 1: Mystery Fedora Spinner
- 5 distinct screens visible during boot
- First 4 are from firmware/bootloaders (mostly unavoidable)
- 5th spinner source needs identification
- Run Task 1 from investigation script to determine source
- **May be:** Plymouth (already disabled), systemd splash, or BGRT

### Priority 2: U-Boot Countdown
- "Hit any key..." menu wastes ~2 seconds
- Controllable via `fw_setenv` if uboot-tools available
- May be unavoidable without rebuilding U-Boot
- Run Task 2 from investigation script

### Priority 3: Visual Optimization
- Lower priority than boot time (already good)
- Focus on clean Formless appearance
- May require m1n1 or U-Boot reconfiguration

---

## Key Commands (On Hardware)

```bash
# Check boot time
systemd-analyze
systemd-analyze blame     # Show slowest services
systemd-analyze critical-chain  # Show boot chain

# Check Formless
systemctl status formless.service
systemctl status formless.target

# Check default target
systemctl get-default  # Should be: formless.target

# Emergency shell
# Press: Ctrl+Alt+F2
# Auto-login as: formless

# Return to TUI
# Press: Ctrl+Alt+F1
```

---

## Troubleshooting

### Boot hangs or infinite loop
- Ctrl+Alt+F2 → shell
- Check `journalctl -b` for errors
- Restart services: `sudo systemctl restart formless.service`

### Formless TUI doesn't appear
- Check service: `systemctl status formless.service`
- Check logs: `journalctl -u formless.service -n 50`
- Daemon may have crashed - check socket

### Agent spawning fails
- Check kernel: `formless status`
- Check socket: `ls -la ~/.formless/`
- Podman may not be running - check: `podman system info`

### U-Boot countdown still visible
- uboot-tools may not be installed
- Run: `rpm -q uboot-tools`
- If not available: `sudo dnf install uboot-tools`

---

## Files Generated During Testing

After running `02-phase3-investigate.sh`:

```
phase3-results-<timestamp>.txt  # Investigation results
```

Keep these for documentation. Copy to main project:
```bash
cp /tmp/phase3-results-*.txt ~/dev/personal/asahi-substrate/docs/
```

---

## Next Phase (Phase 4)

Once Phase 3 complete:

1. **System Command Implementation**
   - Implement backends for `formless substrate` commands
   - Add systemctl, nmcli, bootc, PipeWire integration

2. **Privilege Model**
   - Sudo prompts for privileged operations
   - Polkit rules for common operations

3. **Testing from TUI**
   - Each command must work from Formless dashboard
   - Test persistence across reboots

---

## Quick Reference

| Task | Command | Expected Output |
|------|---------|-----------------|
| Build | `./01-phase3-build.sh` | `Successfully tagged...` |
| Investigate | `./02-phase3-investigate.sh` | Results file with findings |
| Check Boot | `systemd-analyze` | Total time < 15s |
| Check Formless | `systemctl status formless.service` | `active (running)` |
| List Agents | `formless list` | Show running agents |
| Spawn Test | `formless exec -i alpine echo test` | Agent ID + output |

---

## Status

- ✅ Phase 2 Complete (direct TUI boot + command framework)
- ✅ Build Validated (container builds successfully)
- ⏳ Phase 3 Ready (deploy to hardware and test)
- 📋 Phase 4 Planned (system command backends)

---

**Questions?** Read the full documentation:
- `handoffs/PHASE_2_COMPLETION.md` - What was completed
- `plans/BOOT_CHAIN_RESEARCH.md` - Investigation guide
- `plans/substrate-vision-and-roadmap.md` - Architecture + roadmap
