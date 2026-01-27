# Formless Substrate: Vision Document

**Date:** 2026-01-26
**Status:** Design Phase
**Philosophy:** The system that can build its own substrate can build anything.

---

## The Vision

Not a Linux distro with Formless running on it.
**Formless IS the operating environment.**

```
┌─────────────────────────────────────────────────────┐
│                    FORMLESS                          │
│         (The interface. The shell. The OS.)         │
├─────────────────────────────────────────────────────┤
│  Container Runtime │ Audio │ Network │ GPU Driver   │
├─────────────────────────────────────────────────────┤
│              Minimal systemd + udev                  │
├─────────────────────────────────────────────────────┤
│         Asahi Kernel (Apple Silicon drivers)         │
├─────────────────────────────────────────────────────┤
│              m1n1 → U-Boot → systemd-boot            │
├─────────────────────────────────────────────────────┤
│              Apple Silicon Hardware                  │
└─────────────────────────────────────────────────────┘
```

---

## What We're NOT Building

| NOT This | Why |
|----------|-----|
| GNOME desktop | We don't need a desktop. Formless is the desktop. |
| Bluefin userspace | Tools for humans at terminals. Formless IS the terminal. |
| Package manager UX | No dnf, no flatpak GUI. Container-native only. |
| Login manager (GDM) | Boot directly to Formless. |
| Multiple users | Single-purpose substrate. One user: formless. |
| General-purpose OS | Purpose-built for one thing: running Formless. |

---

## What We ARE Building

### Layer 0: Boot Chain (Inherited)
- **m1n1**: Apple Silicon stage 1 bootloader (already installed)
- **U-Boot**: Stage 2 bootloader (already installed)
- **systemd-boot**: Bootloader menu (optional, can be silent)

### Layer 1: Kernel
- **Asahi kernel-16k**: Custom kernel with Apple Silicon drivers
- **Required modules**:
  - `nvme-apple` - Storage
  - `apple-spi-hid` - Keyboard/trackpad
  - `brcmfmac` - WiFi
  - `dwc3` + `typec` - USB/Thunderbolt
  - `apple-dcp` or `simpledrm` - Display
  - `asahi` (mesa) - GPU acceleration

### Layer 2: Init System
- **systemd** (minimal)
  - `systemd-networkd` or `NetworkManager` (one, not both)
  - `udev` for device management
  - No `gdm`, no `gnome-session`

### Layer 3: Hardware Services
- **PipeWire** - Audio routing
- **speakersafetyd** - CRITICAL: Speaker protection
- **asahi-audio** - DSP configuration
- **Mesa (asahi)** - GPU acceleration

### Layer 4: Formless Runtime
- **Formless binary** - The shell/interface
- **Container runtime** (optional) - For spawning apps
  - Podman (rootless) or
  - containerd + nerdctl
- **Wayland compositor** OR direct DRM access
  - Option A: Minimal wlroots compositor, Formless as Wayland client
  - Option B: Formless IS the compositor (Smithay-based)
  - Option C: Direct DRM/KMS for TUI-only mode

---

## Package Manifest (Minimal)

### Required (Cannot Boot Without)
```
kernel-16k
dracut
systemd
```

### Required (Cannot Function Without)
```
# Hardware
mesa-dri-drivers          # GPU
asahi-fwupdate           # Firmware management
asahi-scripts            # System integration
speakersafetyd           # Speaker protection (CRITICAL)

# Audio
pipewire
wireplumber
asahi-audio
alsa-ucm-asahi

# Network
NetworkManager           # Or systemd-networkd
iwd                      # WiFi daemon
linux-firmware           # brcmfmac firmware
```

### Formless Layer
```
formless                 # Our binary
# Plus one of:
podman                   # For container spawning
# OR
cage                     # Minimal Wayland compositor
# OR
nothing                  # If Formless does direct DRM
```

### Explicitly EXCLUDED
```
gnome-*                  # All GNOME packages
gdm                      # Login manager
flatpak                  # App delivery (use containers)
plymouth                 # Boot splash (boot fast, not pretty)
firefox, chrome, etc     # Apps run in containers
bluefin-*                # Bluefin userspace
zsh, fish                # Shells (Formless is the shell)
```

---

## Display Strategy Decision

### Option A: Wayland Client
```
systemd → cage (minimal compositor) → Formless (Wayland app)
```
- **Pros**: Standard Wayland, can run other Wayland apps
- **Cons**: Extra layer, cage maintenance

### Option B: Formless as Compositor (Smithay)
```
systemd → Formless (with embedded Smithay compositor)
```
- **Pros**: Tightest integration, Formless controls everything
- **Cons**: More complex Formless, need to handle all input/display

### Option C: Direct DRM (TUI Mode)
```
systemd → Formless (direct /dev/dri access)
```
- **Pros**: Simplest, fastest boot, no Wayland complexity
- **Cons**: No graphical apps, TUI only

**Recommendation:** Start with Option A (cage), evolve to Option B.

---

## Boot Sequence (Target)

```
Power On
    ↓
m1n1 (1-2 seconds)
    ↓
U-Boot (1-2 seconds)
    ↓
Kernel + initramfs (3-5 seconds)
    ↓
systemd (2-3 seconds)
    ├── networkd/NetworkManager
    ├── pipewire
    ├── speakersafetyd
    └── formless.service (Type=simple, TTYPath=/dev/tty1)
    ↓
Formless Running (< 15 seconds from power on)
```

---

## Containerfile Sketch (v3 Substrate)

```dockerfile
# Stage 1: Kernel Extraction (same as before)
FROM quay.io/fedora/fedora:41 as extractor
RUN dnf install -y 'dnf5-command(copr)' cpio findutils
RUN dnf copr enable -y @asahi/kernel
WORKDIR /payload
RUN dnf download --resolve kernel-16k
RUN for rpm in *.rpm; do rpm2cpio "$rpm" | cpio -idm; done
RUN KVER=$(find lib/modules -maxdepth 1 -mindepth 1 -type d -printf "%f") && \
    cp boot/vmlinuz-* lib/modules/$KVER/vmlinuz

# Stage 2: Minimal Substrate
FROM quay.io/fedora/fedora-bootc:43

# 2a. Strip the base (remove desktop packages if present)
RUN dnf remove -y \
    gnome-* gdm plymouth* \
    firefox* chromium* \
    || true

# 2b. Hardware Enablement (Asahi)
RUN dnf install -y 'dnf5-command(copr)' && \
    dnf copr enable -y @asahi/mesa && \
    dnf install -y --setopt=install_weak_deps=False \
        mesa-dri-drivers \
        asahi-fwupdate \
        asahi-audio \
        alsa-ucm-asahi \
        asahi-scripts \
        speakersafetyd \
        dracut-asahi && \
    dnf clean all

# 2c. Kernel Graft
RUN rm -rf /usr/lib/modules/*
COPY --from=extractor /payload/lib/modules /usr/lib/modules

# 2d. Minimal Services
RUN dnf install -y --setopt=install_weak_deps=False \
        NetworkManager \
        iwd \
        pipewire \
        wireplumber && \
    dnf clean all

# 2e. Display (minimal Wayland)
RUN dnf install -y --setopt=install_weak_deps=False \
        cage && \
    dnf clean all

# 2f. Formless (placeholder - would come from our build)
# COPY --from=formless-builder /formless /usr/bin/formless
# For now, just install a terminal as placeholder
RUN dnf install -y --setopt=install_weak_deps=False \
        foot && \
    dnf clean all

# 2g. Configure auto-login to Formless
RUN mkdir -p /etc/systemd/system/getty@tty1.service.d
COPY <<EOF /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/cage /usr/bin/foot
StandardInput=tty
StandardOutput=tty
EOF

# 2h. Initramfs
RUN echo 'add_drivers+=" nvme-apple "' > /etc/dracut.conf.d/asahi.conf && \
    echo 'hostonly="no"' >> /etc/dracut.conf.d/asahi.conf
RUN KVER=$(ls /usr/lib/modules | head -n 1) && \
    depmod -a $KVER && \
    dracut --force --kver $KVER

# 2i. Lint
RUN bootc container lint
```

---

## Development Phases

### Phase 1: Minimal Boot (Current Focus)
- [ ] Strip current Containerfile to minimal
- [ ] Verify it boots on Asahi hardware
- [ ] Confirm: network, audio, display work
- [ ] Document exact package set

### Phase 2: Formless Integration
- [ ] Build Formless for aarch64
- [ ] Create formless.service
- [ ] Boot directly to Formless TUI
- [ ] Test basic operations

### Phase 3: Container Runtime
- [ ] Add Podman (rootless)
- [ ] Formless can spawn containerized apps
- [ ] Test app lifecycle

### Phase 4: Compositor Evolution
- [ ] Evaluate Smithay integration
- [ ] Prototype Formless-as-compositor
- [ ] GPU acceleration in Formless

### Phase 5: Production Hardening
- [ ] Security audit
- [ ] OTA updates via bootc
- [ ] Recovery mechanism
- [ ] First external user

---

## Open Questions

1. **Wayland vs Direct DRM**: Do we need Wayland at all for v1?
2. **Container Runtime**: Podman vs containerd vs none?
3. **Network Management**: NetworkManager vs systemd-networkd?
4. **Audio Complexity**: Can we simplify PipeWire config?
5. **Build Infrastructure**: ARM64 GitHub runners or self-hosted?

---

## Success Criteria

- [ ] Boot to Formless in < 15 seconds
- [ ] Total image size < 1GB (ideally < 500MB)
- [ ] WiFi connects automatically
- [ ] Audio plays without configuration
- [ ] Can spawn a container from Formless
- [ ] OTA update works via `bootc upgrade`

---

*"The substrate is not the destination. Formless is the destination. The substrate just gets us there."*
