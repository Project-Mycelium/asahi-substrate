# Boot Visual Cleanup - Handoff Document

**Date:** 2026-01-28
**Status:** BLOCKED - Multiple boot stages have embedded logos
**Priority:** Understanding the full boot chain before making more changes

---

## The Problem

User sees 5+ screens during boot instead of clean "Apple Logo → Formless":

1. **Apple Logo** - Firmware (unavoidable, expected)
2. **Asahi Logo** - m1n1 stage 1 bootloader
3. **Fedora Guitar Pick** - m1n1 stage 2 or U-Boot splash
4. **U-Boot Text** - "Hit any key to stop autoboot: 2..."
5. **Horizontal Fedora + Spinner** - Unknown source (thought we disabled Plymouth)

---

## What We Tried (Session 2026-01-28)

### Plymouth Removal ❌ Did Not Fix
- Removed `splash rd.plymouth=1 plymouth.ignore-serial-consoles` from kernel cmdline
- Commented out Plymouth theme setup in Containerfile
- Commented out initramfs rebuild with Plymouth
- **Result:** Still seeing Fedora spinner - source unknown

### Transparent Watermark ❌ Made It Worse
- Created 149x43 transparent PNG to replace Fedora logo in Plymouth spinner theme
- **Result:** Added a 4th logo instead of removing one

### Package Removal ✅ Worked (but unrelated to boot visuals)
- Removed Firefox, ibus, emoji fonts, botocore (~759MB saved)
- Package count: 1353 → 1330

---

## Current Boot Time

```
Startup finished in 701ms (kernel) + 3.704s (initrd) + 7.522s (userspace) = 11.93s
```

Boot time is fine. The problem is purely visual.

---

## The Asahi Boot Chain (Research Needed)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Apple iBoot (firmware)                                   │
│    - Shows Apple logo                                       │
│    - Cannot be modified                                     │
├─────────────────────────────────────────────────────────────┤
│ 2. m1n1 Stage 1                                             │
│    - Asahi's bootloader stub                                │
│    - May show Asahi logo                                    │
│    - Installed by asahi-installer                           │
│    - Location: ???                                          │
├─────────────────────────────────────────────────────────────┤
│ 3. m1n1 Stage 2 + U-Boot                                    │
│    - Full bootloader                                        │
│    - Shows Fedora guitar pick splash?                       │
│    - Shows "Hit any key" countdown (2 seconds wasted)       │
│    - Location: /boot/efi/??? or embedded                    │
│    - Config: fw_printenv/fw_setenv (not installed)          │
├─────────────────────────────────────────────────────────────┤
│ 4. systemd-boot                                             │
│    - Boot menu (timeout set to 0) ✅                        │
│    - Location: /boot/loader/loader.conf                     │
├─────────────────────────────────────────────────────────────┤
│ 5. Linux Kernel + initramfs                                 │
│    - Plymouth splash (DISABLED but still showing???)        │
│    - Quiet params set ✅                                    │
├─────────────────────────────────────────────────────────────┤
│ 6. Userspace                                                │
│    - systemd services                                       │
│    - Auto-login → Formless ✅                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Questions to Research

1. **Where is the horizontal Fedora + spinner coming from?**
   - Plymouth is supposedly disabled
   - Could be: systemd's boot splash, BGRT, or leftover in initramfs
   - Check: `lsinitrd | grep -E "(fedora|logo|splash)"`

2. **Can m1n1/U-Boot splash be disabled?**
   - U-Boot env tools not installed (`fw_printenv` missing)
   - May need to install `uboot-tools` package
   - Or rebuild U-Boot from source with silent config

3. **Where does the guitar pick logo come from?**
   - Could be m1n1 stage 2
   - Could be U-Boot splash screen
   - Asahi-specific customization

4. **Is there a Fedora boot splash separate from Plymouth?**
   - Check for `fedora-logos` package
   - Check for systemd boot splash

---

## Files Modified This Session

| File | Change |
|------|--------|
| `src/Containerfile.substrate` | Removed Plymouth from cmdline, commented out theme setup |
| `src/build_files/watermark-transparent.png` | Created (not helping) |

---

## Current Containerfile State (relevant sections)

```dockerfile
# Line 187 - Kernel cmdline (Plymouth params REMOVED)
RUN mkdir -p /etc/kernel && \
    echo 'quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0' > /etc/kernel/cmdline

# Lines 200-208 - Plymouth setup (COMMENTED OUT)
# RUN plymouth-set-default-theme spinner 2>/dev/null || true
# COPY build_files/watermark-transparent.png /usr/share/plymouth/themes/spinner/watermark.png
# RUN KVER=$(ls /usr/lib/modules | head -n 1) && \
#     dracut --force --add plymouth /boot/initramfs-${KVER}.img ${KVER} 2>/dev/null || \
#     echo "Plymouth initramfs rebuild skipped (will be done on first boot)"
```

---

## Commands for Investigation

```bash
# SSH to target
ssh formless@192.168.8.114

# Check what's in initramfs
lsinitrd | grep -E "(plymouth|fedora|logo|splash|bgrt)"

# Check for boot splash packages
rpm -qa | grep -E "(plymouth|logo|splash|boot)"

# Check U-Boot tools
rpm -q uboot-tools

# Check if Plymouth is actually disabled
systemctl status plymouth-start plymouth-quit

# Check kernel cmdline actually applied
cat /proc/cmdline

# Check for systemd boot features
bootctl status

# Look at boot log for splash-related messages
journalctl -b | grep -iE "(plymouth|splash|logo)"
```

---

## What's Working ✅

- Boot time: 11.93s (target was <15s)
- Auto-login as formless user
- Auto-start Formless dashboard
- Large console font
- systemd-boot timeout 0
- No password prompt
- speakersafetyd active (speaker protection)
- Firefox and bloat removed

---

## What's NOT Working ❌

- Boot visuals: 5 different screens/logos
- Plymouth "disabled" but Fedora spinner still appears
- U-Boot countdown wastes 2 seconds
- No way to modify m1n1/U-Boot without deep Asahi knowledge

---

## Recommended Next Steps

1. **Research Asahi boot chain** - Read Asahi Linux docs on m1n1/U-Boot
2. **Install uboot-tools** - Try `fw_printenv` to see U-Boot config
3. **Investigate the mystery spinner** - Where is horizontal Fedora coming from?
4. **Consider acceptance** - U-Boot/m1n1 logos may be unavoidable without rebuilding bootloaders
5. **Focus on other wins** - Substrate Bridge commands (Phase 4) might be better use of time

---

## Task List Status

| # | Task | Status |
|---|------|--------|
| 1 | Create transparent Plymouth watermark | ✅ Done (didn't help) |
| 2 | Update Containerfile with watermark | ✅ Done |
| 3 | Build and push substrate image | ✅ Done |
| 4 | Deploy to M1 hardware | ✅ Done |
| 5 | Audit remaining boot improvements | ✅ Done |
| 6 | Remove Firefox and desktop apps | ✅ Done |
| 7 | Remove qcom-firmware | 📋 Staged |
| 8 | Trim glibc langpacks | 📋 Pending |
| 9 | Disable Plymouth for clean boot | ✅ Done (but not effective) |

---

## Target Machine Info

- **Host:** M1 MacBook
- **IP (LAN):** 192.168.8.114
- **IP (Tailscale):** 100.73.161.5
- **User:** formless (password: formless for console, SSH is key-only)
- **OS:** Formless Substrate (Fedora Asahi 42)
- **Kernel:** 6.17.12-400.asahi.fc42.aarch64+16k

---

## Repository Info

- **Local path:** /Users/eric/dev/personal/asahi-substrate
- **Registry:** ghcr.io/ericrowan/asahi-substrate:latest
- **Related:** /Users/eric/src/formless-kernel (Formless Kernel codebase)

---

*"The boot chain has many masters. We've only silenced one."*
