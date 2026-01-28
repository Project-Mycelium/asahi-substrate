# Phase 3: Boot Sequence Testing Checklist

**Date:** 2026-01-28
**Target Hardware:** M1 MacBook at 192.168.8.114
**Status:** Ready to Deploy

---

## Pre-Deployment Checklist

- [ ] Build completed successfully (build script run)
- [ ] Asahi kernel confirmed in image
- [ ] All systemd units validated (formless.service, formless.target, getty@tty2)
- [ ] Containerfile passed bootc lint (non-fatal warnings acceptable)
- [ ] Image pushed to registry (if using ghcr.io)

---

## Deployment Steps

### 1. Prepare Hardware

- [ ] M1 hardware is accessible (192.168.8.114)
- [ ] SSH key auth working (`ssh formless@192.168.8.114`)
- [ ] Current image backed up or noted
- [ ] Plan for emergency recovery (Ctrl+Alt+F2 shell)

### 2. Deploy Image

```bash
# Build on target hardware or push container
podman build -f src/Containerfile.substrate -t asahi-substrate:phase3 .
# OR push to registry first
podman push ghcr.io/ericrowan/asahi-substrate:latest
```

### 3. Apply Image

```bash
# On M1 hardware
sudo bootc switch ghcr.io/ericrowan/asahi-substrate:latest
sudo systemctl reboot
```

---

## Boot Sequence Observation

### Visual Boot Flow (Record what you see)

**Before Reboot:**
- [ ] Note current boot time from last session
- [ ] Check if system is stable

**During Boot:**
- [ ] Time from power-on to Apple logo: ___ seconds
- [ ] Observe logos/splash screens in order:
  1. [ ] Apple logo
  2. [ ] Asahi logo (m1n1)
  3. [ ] Fedora guitar pick
  4. [ ] "Hit any key..." countdown
  5. [ ] Mystery Fedora spinner (INVESTIGATE THIS)
  6. [ ] Console font change
  7. [ ] Formless TUI appears

**Document Any Issues:**
- [ ] Black screen at any point? Duration: ___
- [ ] Kernel panics or error messages?
- [ ] TTY rendering artifacts?
- [ ] Audio issues?

### Expected Behavior

✅ **Should see:**
- Formless TUI appears with no login prompt
- Direct boot to dashboard (11-15 seconds total)
- Cursor hidden
- Large console font (latarcyrheb-sun32)
- No kernel message spam (quiet mode)

❌ **Should NOT see:**
- Getty login prompt
- Desktop environment
- Disk spinning indicator
- Full kernel debug output

---

## Post-Boot Testing

### 1. Verify Boot Metrics

```bash
# SSH to hardware
ssh formless@192.168.8.114

# Check boot time
systemd-analyze

# Expected output around:
# Startup finished in XXXms (kernel) + XXXms (initrd) + XXXXs (userspace)
# Total: ~11-15 seconds
```

- [ ] Boot time recorded: ___ seconds
- [ ] Within acceptable range (< 15s target)

### 2. Verify Service Status

```bash
# Check Formless is running
systemctl status formless.service
systemctl status formless.target

# Expected: active (running)
```

- [ ] formless.service: active (running)
- [ ] formless.target: active (running)
- [ ] No error messages in status

### 3. Test Emergency Fallback

```bash
# While at Formless TUI, press Ctrl+Alt+F2
# Should see getty@tty2 shell prompt
```

- [ ] Ctrl+Alt+F2 gives shell access
- [ ] Can run commands as formless user
- [ ] Ctrl+Alt+F1 returns to Formless TUI

### 4. Run Investigation Commands

```bash
# Execute the investigation script
bash 02-phase3-investigate.sh 192.168.8.114

# Or manually run commands from BOOT_CHAIN_RESEARCH.md
ssh formless@192.168.8.114 "cat /proc/cmdline"
```

**Document Findings:**

**Mystery Fedora Spinner:**
- [ ] Source identified: _______________
- [ ] Is it Plymouth? [ ] systemd splash? [ ] BGRT? [ ] Unknown?
- [ ] Can it be disabled? Yes / No / Maybe

**U-Boot Configuration:**
- [ ] uboot-tools available? Yes / No
- [ ] Can access fw_printenv? Yes / No
- [ ] bootdelay value: ___
- [ ] Can bootdelay be changed? Yes / No / Not applicable

**Kernel Cmdline:**
- [ ] `quiet` parameter applied? Yes / No
- [ ] `systemd.show_status=false` applied? Yes / No
- [ ] All expected parameters present? Yes / No

---

## Agent Spawning Test

### 1. Formless Daemon Status

```bash
ssh formless@192.168.8.114

# Check daemon is running
formless status

# Expected: Daemon running, socket accessible
```

- [ ] Daemon running successfully
- [ ] Socket accessible at `/home/formless/.formless/kernel.sock`
- [ ] No permission errors

### 2. List Agents

```bash
formless list
```

- [ ] Can list agents without error
- [ ] Output shows zero or existing agents
- [ ] No socket connection errors

### 3. Spawn Test Agent

```bash
formless exec -i alpine:latest "echo 'Test successful'"
```

- [ ] Agent spawned successfully
- [ ] Got agent ID
- [ ] Command executed without error
- [ ] No Podman socket issues

---

## Documentation

### Update BOOT_CHAIN_RESEARCH.md

```markdown
## Investigation Results (2026-01-28)

### Mystery Fedora Spinner
- **Source:** [identified source]
- **Solution:** [possible fix]
- **Status:** [fixed/unsupported/investigating]

### U-Boot Configuration
- **bootdelay:** [value]
- **Can be changed:** [yes/no]
- **Action taken:** [if any]

### Boot Time
- Before Phase 3: 11.93s
- After Phase 3: ___s
- **Target:** <15s
- **Status:** ✅ Met / ❌ Not met
```

### Commit Changes

```bash
cd /Users/eric/dev/personal/asahi-substrate

# Update docs with findings
git add plans/BOOT_CHAIN_RESEARCH.md plans/substrate-vision-and-roadmap.md

# Commit
git commit -m "docs: Phase 3 boot investigation results and findings"
```

---

## Success Criteria

### Phase 3 Complete ✅

- [ ] Containerfile builds without errors
- [ ] Boot sequence works end-to-end
- [ ] Formless TUI appears directly (no login)
- [ ] Boot time measured and documented
- [ ] Investigation commands run successfully
- [ ] Mystery Fedora spinner source identified
- [ ] U-Boot configuration assessed
- [ ] Agent spawning verified
- [ ] Findings documented in BOOT_CHAIN_RESEARCH.md
- [ ] All results committed to git

### Phase 3 Issues 🔄

If any blockers encountered:
- [ ] Describe issue
- [ ] Note fallback behavior (Ctrl+Alt+F2 works?)
- [ ] Plan for Phase 3.5 investigation
- [ ] Don't block Phase 4 (system commands) - can iterate

---

## Next Steps (Phase 4)

Once Phase 3 is complete:

1. **System Command Backends** - Implement actual functionality
   - systemctl wrapper for service commands
   - nmcli/iwd for network management
   - bootc for system updates
   - PipeWire for audio control

2. **Privilege Model** - Handle sudo/polkit for restricted operations

3. **Testing** - Verify each command works from Formless TUI

---

## Contact

**Previous Phase Agent:** [Agent Name]
**Hardware Owner:** Eric Rowan (@ericrowan)
**Emergency Contact:** SSH to 192.168.8.114 + Ctrl+Alt+F2 for shell

---

**Remember:** Boot visuals are secondary to functionality. If Formless boots and agents work, Phase 3 is successful even if there are multiple splash screens.
