# GNOME OS Research for Formless Substrate

**Date:** 2026-01-27
**Purpose:** Evaluate GNOME OS as a potential base for Formless Substrate on Apple Silicon

## Executive Summary

GNOME OS is the GNOME project's official reference operating system, built using BuildStream and deployed via OSTree. While it has aarch64 build support, it is fundamentally a **testing/development distribution** not designed for production use, and **lacks Apple Silicon-specific hardware support**. For Formless Substrate, **Fedora Asahi Remix with bootc remains the superior choice**.

## What is GNOME OS?

GNOME OS is an experimental Linux distribution that ships the latest in-development GNOME desktop, core applications, and stack. Key characteristics:

- **Purpose:** Reference platform for GNOME developers and testers
- **Build System:** BuildStream (not bootc/Containerfile)
- **Update Mechanism:** OSTree (similar to Fedora Silverblue)
- **Package Management:** None - immutable base, Flatpak for apps
- **Target Audience:** GNOME developers, testers, journalists reviewing GNOME

### Versions Available
- **User version:** Standard GNOME experience
- **Developer version:** Includes git, toolbx, podman, debug symbols

### Architecture Support
GNOME OS builds are produced for:
- x86_64 (primary)
- aarch64 (supported since 2018, builds available)

The CI of gnome-build-meta (GNOME's build system) builds for aarch64 in addition to x86_64.

## GNOME OS vs Fedora bootc: Technical Comparison

| Feature | GNOME OS | Fedora Asahi bootc |
|---------|----------|-------------------|
| **Base Purpose** | GNOME testing/development | Production OS |
| **Build System** | BuildStream | Containerfile/bootc |
| **Update Mechanism** | OSTree | OSTree via OCI containers |
| **Apple Silicon Support** | None (generic ARM64 only) | Full (kernel, GPU, audio, etc.) |
| **Kernel** | Generic mainline | Asahi-patched (Apple Silicon drivers) |
| **GPU Support** | Generic Mesa | Asahi Mesa (Apple GPU) |
| **Audio Support** | Generic PipeWire | speakersafetyd (Apple speakers) |
| **Customization** | Requires BuildStream knowledge | Standard Containerfile |
| **Production Ready** | No (explicitly not recommended) | Yes |
| **Stability** | Nightly/bleeding edge | Release-based |

## Why GNOME OS is NOT Suitable for Formless Substrate

### 1. No Apple Silicon Hardware Support
GNOME OS builds generic aarch64 images. It lacks:
- Asahi kernel patches (essential for M1/M2/M3 hardware)
- Apple GPU drivers (Mesa Asahi)
- Speaker protection daemon (speakersafetyd - **critical for hardware safety**)
- Apple-specific firmware loading
- NVMe/storage controller support

Without the Asahi kernel and drivers, GNOME OS **will not boot** on Apple Silicon Macs.

### 2. Not Production Ready
GNOME explicitly states: "GNOME OS is bleeding edge, in-development software, and not recommended for daily usage if you're not a developer."

### 3. Different Build Paradigm
GNOME OS uses BuildStream, a complex build system requiring specialized knowledge. Our current approach uses Containerfiles, which:
- Are widely understood
- Integrate with existing CI/CD (GHCR, Quay.io)
- Allow incremental customization
- Work with bootc tooling

### 4. No Existing Apple Silicon Work
There is no ongoing effort to support Apple Silicon in GNOME OS. The Pinebook Pro (generic ARM64) was the only ARM hardware target, and even that required custom kernel branches.

## Fedora Asahi bootc: Why It Remains the Right Choice

### Current Architecture (Working)
```
Fedora Asahi Remix base-atomic:42
    |
    +-- Asahi kernel (6.17.12-400.asahi.fc42.aarch64+16k)
    +-- Mesa GPU drivers (Asahi)
    +-- Audio stack (PipeWire + speakersafetyd)
    +-- Network (NetworkManager + iwd)
    +-- Container runtime (Podman)
    |
    +-- [Our customizations via Containerfile]
        +-- SSH hardening
        +-- Tailscale
        +-- Homebrew bootstrap
        +-- Formless service
```

### bootc Benefits
The bootc approach elevates OCI/docker containers to be natively supported as a transport mechanism for bootable operating systems. Benefits include:
- **Familiar Tooling:** Standard Containerfile/Dockerfile syntax
- **Registry Distribution:** Push/pull from GHCR, Quay.io
- **Layered Customization:** Each RUN statement is a layer
- **Security Scanning:** Use standard container scanning tools
- **Atomic Updates:** OSTree-backed rollback capability

## Alternative Considerations

### Could We Port GNOME OS to Apple Silicon?
Theoretically possible but impractical:
1. Would need to integrate Asahi kernel into BuildStream
2. Would need to add all Apple-specific Mesa/audio/firmware patches
3. Would lose Fedora's RPM ecosystem and bootc tooling
4. No community support or existing work
5. Estimated effort: 6+ months of dedicated work

### What About Vanilla GNOME on Fedora Asahi?
This is already possible and is the recommended approach:
```bash
# On existing Fedora Asahi
sudo dnf group install gnome-desktop
```

Our substrate could include GNOME if desired, but our current design philosophy is "headless substrate" where:
- Base OS is minimal (no DE)
- Applications run in containers
- Remote access via SSH/Tailscale
- Optional GUI via X11/Wayland forwarding or VNC

## Recommendations

### Keep Current Architecture
The Fedora Asahi bootc approach is correct for Formless Substrate:
1. **Proven Apple Silicon support** (Asahi Linux team maintains this)
2. **Production-ready base** (Fedora quality)
3. **Modern bootc tooling** (OCI-native updates)
4. **Active community** (Asahi + Fedora combined)

### If GNOME Desktop is Desired
Add GNOME packages to the Containerfile rather than switching base:
```dockerfile
RUN dnf group install -y gnome-desktop-environment
RUN systemctl enable gdm.service
```

### Future Watch
Monitor these developments:
- Fedora's bootc evolution (unifying CoreOS/Silverblue/Kinoite)
- Asahi Linux moving to stable kernel releases
- composefs becoming the heart of both OSTree and containers

## Sources

- [GNOME OS Nightly](https://os.gnome.org/)
- [gnome-build-meta on GitHub](https://github.com/GNOME/gnome-build-meta)
- [Fedora Asahi Remix](https://asahilinux.org/fedora/)
- [bootc documentation](https://bootc-dev.github.io/bootc/)
- [rpm-ostree container documentation](https://coreos.github.io/rpm-ostree/container/)
- [Fedora OstreeNativeContainerStable](https://fedoraproject.org/wiki/Changes/OstreeNativeContainerStable)
- [OSTree Wikipedia](https://en.wikipedia.org/wiki/OSTree)
