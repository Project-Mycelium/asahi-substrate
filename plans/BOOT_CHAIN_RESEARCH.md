# Asahi Apple Silicon Boot Chain Research

**Date:** 2026-01-28
**Status:** In Progress
**Goal:** Understand and optimize boot visuals (5+ screens → clean Formless)

---

## Boot Chain Layers (Understanding)

### 1. Apple iBoot (Firmware) ✅
- **What:** Apple's proprietary boot ROM
- **Visible:** Apple logo
- **Control:** None (firmware level)
- **Status:** Unavoidable and expected

### 2. m1n1 Stage 1 (Stub Bootloader) ❓
- **What:** Asahi's minimal bootloader stub
- **Visible:** Asahi logo (large, colorful)
- **Control:** Possibly configurable in U-Boot or m1n1 config
- **Questions:**
  - Can this logo be disabled?
  - Is it hardcoded or in configuration?
  - Where is it stored (firmware, /boot/efi, or embedded)?

### 3. m1n1 Stage 2 + U-Boot (Full Bootloader) ❓
- **What:** Full Asahi bootloader with U-Boot integration
- **Visible:**
  - Fedora guitar pick splash screen
  - "Hit any key to stop autoboot: 2..." countdown
- **Control:** U-Boot env variables via `fw_printenv`/`fw_setenv`
- **Questions:**
  - Can we disable the guitar pick splash?
  - Can we hide the countdown?
  - Do we need to rebuild U-Boot?
  - Is uboot-tools available in Fedora?

### 4. systemd-boot (EFI Boot Manager) ✅
- **What:** Minimal UEFI boot manager
- **Control:** Via `/boot/loader/loader.conf`
- **Status:** Already configured (timeout=0, no menu)
- **Configuration:** ✅ Done
  ```
  timeout 0
  default ostree-*
  editor no
  ```

### 5. Linux Kernel + initramfs 🔄
- **What:** Kernel startup with optional Plymouth splash
- **Visible:**
  - Plymouth spinner (disabled but still showing?)
  - Kernel messages (quiet params help)
  - systemd startup
- **Questions:**
  - Where is the "horizontal Fedora + spinner" coming from?
  - Is it Plymouth, systemd splash, or BGRT?
  - Was Plymouth disabled correctly?

### 6. systemd Userspace ✅
- **What:** System services startup
- **Visible:** Service logs (quiet mode helps)
- **Control:** kernel cmdline, systemd settings
- **Status:** Configured for quiet boot

### 7. Formless TUI 🎯
- **What:** Our custom interface
- **Visible:** Formless dashboard on tty1
- **Control:** formless.service
- **Status:** Now set as default boot target

---

## Current Boot Output (Observed)

Five distinct screens visible during boot:

1. **Apple Logo** ← Firmware (unavoidable)
2. **Asahi Logo** ← m1n1 stage 1 (possibly optional)
3. **Fedora Guitar Pick** ← U-Boot splash (possibly optional)
4. **"Hit any key..." countdown** ← U-Boot autoboot menu (wastes 2 seconds)
5. **Horizontal Fedora + spinner** ← Unknown source (research needed)

Then:
- Large console font appears (✅ working)
- Formless TUI starts (✅ working)

---

## Boot Performance (Good)

```
Startup finished in 701ms (kernel) + 3.704s (initrd) + 7.522s (userspace) = 11.93s
```

**Target:** <15 seconds ✅ Already achieved

---

## Investigation Tasks

### Task 1: Identify Mystery Fedora Spinner

**Command to run on deployed hardware:**
```bash
# Check initramfs contents for splash-related files
lsinitrd /boot/initramfs-*.img | grep -iE "(fedora|plymouth|splash|bgrt|logo)"

# Check running Plymouth status
systemctl status plymouth-start plymouth-quit

# Check kernel cmdline actually applied
cat /proc/cmdline

# Search logs for splash-related messages
journalctl -b | grep -iE "(splash|plymouth|logo|fedora|bgrt)"

# Check for Fedora logos package
rpm -qa | grep -E "(fedora-logos|fedora-release)"

# Check systemd-boot configuration
bootctl status

# Check if any splash themes are installed
ls -la /usr/share/plymouth/themes/
```

**Hypothesis:**
- Plymouth was "disabled" but packages still installed
- OR systemd has built-in boot splash
- OR BGRT (Boot Graphics Resource Table) is showing Fedora logo
- OR dracut is including splash even though we commented it out

### Task 2: U-Boot Configuration Access

**Command to run on deployed hardware:**
```bash
# Check if uboot-tools is installed
which fw_printenv fw_setenv
rpm -q uboot-tools

# If available, dump U-Boot environment
fw_printenv

# Look for U-Boot splash config
fw_printenv splash_screen
fw_printenv boot_logo
fw_printenv bootcmd

# Check U-Boot bootdelay
fw_printenv bootdelay
```

**If uboot-tools not available:**
- May need to install: `dnf install uboot-tools`
- Or rebuild U-Boot from source with silent config
- Or accept that U-Boot countdown is unavoidable

### Task 3: m1n1 Logo Control

**Research needed:**
- Asahi Linux documentation on m1n1 configuration
- Check if logo is in m1n1 binary or configurable
- Check U-Boot docs for logo configuration
- Look for any Asahi Linux wiki entries on custom boot

**Potential locations:**
- `/boot/efi/` - Fedora Asahi boot partition
- m1n1 source: https://github.com/AsahiLinux/m1n1
- Asahi docs: https://asahilinux.org/

### Task 4: Kernel Cmdline Verification

**What we set:**
```
quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0
```

**Verification:**
```bash
cat /proc/cmdline
# Should show the quiet params we set

# Check actual applied kernel cmdline
grep -i quiet /proc/cmdline
```

---

## Possible Solutions (Priority Order)

### Priority 1: Identify Mystery Spinner
Run investigation commands on hardware to determine source.

**If Plymouth:** Already disabled, issue is with remaining packages or dracut
- Solution: Fully remove Plymouth packages from Containerfile
- Or: Ensure dracut doesn't include it

**If systemd splash:** Can disable via kernel param
- Solution: Add `systemd.show_splash=false` to kernel cmdline

**If BGRT:** Built into UEFI firmware
- Solution: May be unavoidable

### Priority 2: U-Boot Countdown (2 second waste)
If uboot-tools available:
```bash
# Try to reduce bootdelay to 0
sudo fw_setenv bootdelay 0

# Or disable boot menu entirely
sudo fw_setenv boot_delay 0
```

If uboot-tools not available:
- May need to rebuild U-Boot
- Or accept as unavoidable hardware limitation

### Priority 3: m1n1 Logo
- Research Asahi docs for configuration
- May be unavoidable without rebuilding m1n1
- Lower priority since we already have 2-3 logos before this

### Priority 4: Accept Current State
- Boot time is already good (11.93s vs 15s target)
- Only issue is visual (multiple logos)
- May be acceptable given hardware boot chain complexity

---

## Files to Update (Post-Investigation)

1. **Containerfile.substrate** - Add/remove Plymouth packages based on findings
2. **kernel cmdline** - Add splash=off or similar if systemd splash found
3. **/boot/loader/entries/*.conf** - May need U-Boot env tweaks if accessible
4. **Documentation** - Update substrate-vision-and-roadmap.md with findings

---

## Testing Procedure

1. Build updated Containerfile
2. Push to ghcr.io/ericrowan/asahi-substrate:latest
3. Deploy to M1 hardware (192.168.8.114)
4. Boot and observe
5. Run investigation commands from hardware
6. Document findings
7. Iterate based on results

---

## Related Resources

- **Asahi Linux Boot Docs:** https://asahilinux.org/documentation/
- **m1n1 Source:** https://github.com/AsahiLinux/m1n1
- **U-Boot Docs:** https://u-boot.readthedocs.io/
- **Fedora Asahi Remix:** https://github.com/fedora-asahi-remix/
- **Plymouth Docs:** https://www.freedesktop.org/wiki/Software/Plymouth/

---

## Summary

**What we know:**
- Boot time is good (11.93s)
- First 4 logos are from firmware/bootloaders (mostly unavoidable)
- Mystery 5th Fedora spinner needs investigation
- Formless now boots directly to TUI (no login prompt)

**What we need to investigate:**
1. Source of mystery Fedora spinner
2. U-Boot countdown control
3. m1n1 logo customization feasibility

**Best outcome:** Clean "Apple → Formless" experience
**Acceptable outcome:** Current 11.93s boot with multiple logos (performance is more important than visuals)
**Next step:** Run investigation commands on deployed hardware and document findings
