# Documentation

## Current Architecture (v6)

Formless Substrate uses **Fedora Asahi Remix** as its base. This provides:
- Pre-built Asahi kernel with Apple Silicon drivers
- Mesa GPU drivers
- Audio stack with speaker protection
- WiFi support via brcmfmac

**Previous approaches that failed:**
- Kernel grafting from RPMs (OSTree metadata issues)
- fedora-bootc:43 base (wrong kernel, no Apple Silicon support)
- GNOME OS base (x86_64 only, no ARM64)

## Key Files

- [BUILD_ARCHITECTURE.md](BUILD_ARCHITECTURE.md) - Technical build details
- [SUBSTRATE_VISION.md](SUBSTRATE_VISION.md) - Project goals and philosophy
- [REMOTE_ACCESS.md](REMOTE_ACCESS.md) - SSH and Tailscale setup
- [SERIAL_DEBUG.md](SERIAL_DEBUG.md) - Debug via USB-C serial

## Deployment Checklist

1. ✅ Build image with Asahi kernel
2. ✅ Push to GHCR
3. ✅ Deploy via `bootc switch`
4. ✅ SSH access working
5. ✅ First-boot automation (Homebrew, tools)
6. ⬜ Tailscale auto-join (needs auth key)
7. ⬜ Formless service integration
