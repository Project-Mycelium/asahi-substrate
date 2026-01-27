# Phase 1: Reconnaissance Report

**Date:** 2026-01-26
**Status:** Remote Reconnaissance (compiled from project history + upstream research)
**Source:** asahi-substrate project archives, Bluefin agent conversations, GitHub issues

---

## 1. Hardware Profile

### Target Machine
- **Model:** MacBook Pro M1 Pro (14-inch, 2021)
- **SoC:** Apple M1 Pro
- **RAM:** 16GB unified memory
- **Storage:** 512GB NVMe (Apple ANS2)
- **Display:** 14.2" Liquid Retina XDR (3024x1964, ProMotion 120Hz)
- **Audio:** 6-speaker system with force-cancelling woofers

### Apple Silicon Specifics
| Component | Linux Driver | Status |
|-----------|--------------|--------|
| CPU | Upstream kernel | Working |
| GPU (AGX G13) | asahi mesa | Working (reverse-engineered) |
| NVMe (ANS2) | nvme-apple | Working |
| USB/Thunderbolt | dwc3 + typec | Working |
| WiFi (BCM4387) | brcmfmac + firmware | Working |
| Bluetooth | btbcm | Working |
| Keyboard/Trackpad | apple-spi-hid | Working |
| Audio | asahi-audio + speakersafetyd | Working (DSP required) |
| Display (DCP) | apple-dcp | Working (SimpleDRM fallback) |
| Neural Engine | None | Not supported |
| Secure Enclave | None | Not supported |
| Touch Bar | None | N/A (not on this model) |

---

## 2. Current Software Stack

### Build Architecture (asahi-substrate)
```
┌─────────────────────────────────────────────────┐
│ STAGE 1: EXTRACTOR (Fedora 41)                  │
│ - Downloads kernel-16k from @asahi/kernel COPR  │
│ - Extracts via rpm2cpio                         │
│ - Prepares vmlinuz in OSTree-standard location  │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ STAGE 2: ASSEMBLY (fedora-bootc:43)             │
│ - Mesa drivers from @asahi/mesa COPR            │
│ - asahi-fwupdate, asahi-bless, asahi-audio      │
│ - Kernel graft from Stage 1                     │
│ - Bluefin userspace graft                       │
│ - Audio hardening (quantum fix)                 │
│ - Power rules, fonts, setup wizard              │
│ - dracut initramfs with nvme-apple              │
│ - bootc container lint validation               │
└─────────────────────────────────────────────────┘
```

### Key Packages Installed
```
# Hardware Enablement
mesa-dri-drivers          # GPU acceleration
asahi-fwupdate            # Firmware update tool
asahi-bless               # Boot partition selector
asahi-audio               # Audio DSP configs
alsa-ucm-asahi            # ALSA UCM profiles
asahi-scripts             # System integration scripts
m1n1                      # Stage 1 bootloader
dracut-asahi              # Initramfs hooks
speakersafetyd            # CRITICAL: Speaker protection daemon
muvm                      # MicroVM for 16K page app compat

# Kernel
kernel-16k                # Asahi kernel with 16K pages
```

### Boot Chain
```
Apple iBoot → m1n1 → U-Boot → GRUB → Linux kernel → systemd → GNOME
```

---

## 3. Known Issues Catalog

### From Project History

| ID | Issue | Severity | Status | Notes |
|----|-------|----------|--------|-------|
| ASAHI-001 | Black screen / display init | Critical | Unknown | Mentioned in exploration doc |
| ASAHI-002 | Audio "tinny" / crackling | High | MITIGATED | Quantum fix applied (1024/2048) |
| ASAHI-003 | Audio 100% volume blast | High | FIXED | Removed 99-asahi.conf |
| ASAHI-004 | Night Light broken | Medium | WORKAROUND | Color Tint extension as fallback |
| ASAHI-005 | GNOME Software nag | Low | FIXED | Removed gnome-software-rpm-ostree |
| ASAHI-006 | 16K page app compat | Medium | MITIGATED | muvm installed |

### Audio Fixes Applied
```conf
# /etc/pipewire/pipewire.conf.d/99-wavy-quantum.conf
# Prevents crackling under load
context.properties = {
    default.clock.min-quantum = 1024
    default.clock.max-quantum = 2048
}
```

```
# Removed: /etc/pipewire/pipewire.conf.d/99-asahi.conf
# This caused 100% volume blast on boot
```

---

## 4. Upstream Status (Bluefin ARM64)

### From GitHub Issue #755 (Screenshot)
- **Jorge Castro's Plan:**
  - Nvidia: No (not applicable to ARM)
  - ML territory: Bluefin DX only
  - GTS: No
  - stable: Yes - this should be the default for ARM users
  - latest: Yes - must provide same version as Fedora
  - Turn off nvidia-closed in October

- **Current State:** ARM64 builds are in planning/early availability
- **Recommendation from thread:** Use `lux-os/hci.in` for aarch64 or wait for official Bluefin ARM builds

### Asahi Linux Upstream
- **Kernel:** Patches maintained at github.com/AsahiLinux/linux
- **Mesa:** Custom Gallium driver for AGX (asahi)
- **Fedora Remix:** Official distribution at asahilinux.org/fedora

---

## 5. Build System Status

### Current Containerfile Approach
- **Strategy:** "Kernel Graft" (DNF-less)
- **Base:** `quay.io/fedora/fedora-bootc:43`
- **Kernel Source:** `@asahi/kernel` COPR (kernel-16k)
- **Validation:** `bootc container lint` must pass

### Build Commands
```bash
just build    # Builds linux/arm64 locally via Podman
just verify   # Checks initramfs for nvme-apple driver
just push     # Pushes to GHCR
```

### Verification Checks
```bash
# Must find nvme-apple in initramfs
podman run --rm asahi-substrate:latest lsinitrd | grep nvme-apple

# Must have these packages
podman run --rm asahi-substrate:latest rpm -q kernel-16k asahi-fwupdate asahi-audio
```

---

## 6. Live System Data (Captured 2026-01-27)

SSH access established via Tailscale (100.73.161.5) and LAN (192.168.8.114).

### 6.1 Hardware Enumeration

```
Kernel: Linux asahi-atomic 6.17.12-400.asahi.fc42.aarch64+16k
OS: Fedora 42.20251228.0 (Silverblue)
Boot: BOOT_IMAGE=(hd0,gpt8)/boot/ostree/default-.../vmlinuz-6.17.12-400.asahi.fc42.aarch64+16k
      root=UUID=8300ef97-4760-4fee-b4ee-97157be529c7 rootflags=subvol=/ rw selinux=0
```

### 6.2 Display Status

| Item | Value |
|------|-------|
| DRM Driver | `apple_dcp` (native, NOT SimpleDRM) |
| GPU Driver | `asahi` (1.2MB module) |
| Internal Display | **connected** via eDP-1 |
| Resolution | 3024x1890 (native) |
| HDMI | Available (card2-HDMI-A-1) |
| Session | Wayland (GNOME) |

**Black screen issue: NOT CURRENTLY PRESENT**
Display is connected and working. Issue may be intermittent or resolved by recent kernel update.

### 6.3 Loaded Apple Modules

```
apple_dcp             344064  (Display Controller)
appledrm               49152  (DRM layer)
asahi                1196032  (GPU)
nvme_apple             65536  (Storage)
spi_hid_apple          65536  (Keyboard/Trackpad)
apple_isp             131072  (Camera ISP)
snd_soc_apple_mca      49152  (Audio)
```

### 6.4 Boot Errors (journalctl -b -p err)

| Error | Severity | Notes |
|-------|----------|-------|
| systemd-remount-fs failed | Low | OSTree/btrfs quirk, non-blocking |
| spi-hid-apple timeout (-110) | Low | Keyboard init delay, recovers |
| brcmf_dongle_roam (-52) | Low | WiFi P2P, doesn't affect normal WiFi |
| bluetooth wake params | Low | Cosmetic |

### 6.5 Installed Packages

```
kernel-16k-6.17.12-400.asahi.fc42
mesa-dri-drivers-25.2.7-0.100.fc42
asahi-audio-3.4-1.fc42
asahi-fwupdate-20250130-5.fc42
speakersafetyd (via asahi-platform-metapackage-audio)
```

### 6.6 Open Questions (Still Need Investigation)

1. **Black screen trigger**: When does it occur? Cold boot? Wake from sleep? Random?
2. **External display**: Does HDMI work?
3. **Sleep/wake**: Does suspend work correctly?
4. **Battery**: Runtime observations?

---

## 7. Recommendations

### Immediate (Enable Remote Work)
1. **Enable SSH on Asahi machine**
   ```bash
   # On the Asahi machine
   sudo systemctl enable --now sshd
   # Get IP
   ip addr show
   ```

2. **Or create a diagnostic script** that can be run locally and results copied back:
   ```bash
   # Create: /tmp/asahi-diag.sh
   #!/bin/bash
   exec > /tmp/asahi-diag-$(date +%Y%m%d).txt 2>&1
   uname -a
   cat /etc/os-release
   cat /proc/cmdline
   dmesg | grep -i "drm\|display\|gpu\|apple"
   journalctl -b -p err
   lsmod | head -50
   cat /sys/class/drm/*/status
   rpm -qa | grep -i asahi
   ```

### Short-term (Black Screen Investigation)
1. Check if SimpleDRM vs apple-dcp is being used
2. Review kernel parameters for display options
3. Check if issue is cold-boot specific or persistent

### Medium-term (Minimal Substrate)
1. Document exact packages needed vs inherited
2. Identify services that can be disabled
3. Design Formless-as-shell architecture

---

## 8. Resources

### Asahi Linux
- Kernel: https://github.com/AsahiLinux/linux
- m1n1: https://github.com/AsahiLinux/m1n1
- Docs: https://github.com/AsahiLinux/docs/wiki

### Universal Blue / Bluefin
- Image Template: https://github.com/ublue-os/image-template
- Bluefin: https://github.com/ublue-os/bluefin
- ARM Discussion: Issue #755

### This Project
- Repo: asahi-substrate
- Build: Containerfile + Justfile
- Strategy: Kernel graft + bootc

---

**Next Phase:** BLACK_SCREEN.md (requires machine access or diagnostic data)
