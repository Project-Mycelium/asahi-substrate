# Hardware Deployment Handoff

**Date:** 2026-01-27
**Sprint:** Hardware Deployment (FAILED - needs debugging)
**Image:** ghcr.io/ericrowan/asahi-substrate:latest
**Target:** M1 MacBook Pro at 192.168.8.114 (LAN) / 100.73.161.5 (Tailscale)

---

## Summary

Two deployment attempts failed with kernel panics. Root cause identified and partially fixed, but compatibility issue remains.

---

## What Happened

### Attempt 1: Original Image (Kernel Graft Approach)
- **Image version:** 43.20260108.0
- **Problem:** Image was built with `fedora-bootc:43` base and attempted to graft Asahi kernel
- **Root cause:** Kernel graft failed silently. Image had `ostree.linux: 6.18.3-200.fc43.aarch64` (standard Fedora kernel) instead of Asahi kernel
- **Result:** Kernel panic - standard kernel lacks Apple Silicon drivers

### Attempt 2: New Image (Asahi Remix Base)
- **Image version:** 41.20260127.0
- **Approach:** Rebuilt using `quay.io/fedora-asahi-remix-atomic-desktops/base-atomic:41` as base
- **Kernel confirmed:** `6.17.12-400.asahi.fc41.aarch64+16k` (correct Asahi kernel)
- **Result:** Still kernel panic

### Likely Cause of Attempt 2 Failure
- Target machine runs **Fedora 42** Silverblue
- New image uses **Fedora 41** Asahi Remix base
- Possible incompatibility between fc41 kernel/userspace and fc42 system configuration
- The m1n1/bootloader may expect fc42-era components

---

## Current State

### Target Machine (M1)
- **Current OS:** Fedora 42 Silverblue (booted from recovery)
- **Working kernel:** `6.17.12-400.asahi.fc42.aarch64+16k`
- **SSH access:** `ssh erowan@192.168.8.114` (passwordless sudo configured)
- **Staged image:** asahi-substrate:latest (41.20260127.0) - DO NOT REBOOT INTO THIS

### Built Image
- **Registry:** ghcr.io/ericrowan/asahi-substrate:latest
- **Digest:** sha256:69eaf62168d7c4fa9ce0df0814950176d3e033f503c89d0efe84852ccaca0fbc
- **Base:** quay.io/fedora-asahi-remix-atomic-desktops/base-atomic:41
- **Kernel:** 6.17.12-400.asahi.fc41.aarch64+16k (Asahi, but fc41)

### Containerfile
- Updated to v5 at `src/Containerfile.substrate`
- Single-stage build using Asahi Remix base
- No more kernel grafting

---

## Next Steps (Priority Order)

### Option A: Use Fedora 42 Base (Recommended)
Check if Fedora 42 base-atomic exists:
```bash
ssh erowan@192.168.8.114 'skopeo inspect docker://quay.io/fedora-asahi-remix-atomic-desktops/base-atomic:42'
```

If it exists, update `src/Containerfile.substrate`:
```dockerfile
ARG BASE_IMAGE="quay.io/fedora-asahi-remix-atomic-desktops/base-atomic:42"
```

Then rebuild and redeploy.

### Option B: Debug the Kernel Panic
If no fc42 base available:
1. Connect USB-C debug cable to capture panic output
2. Check serial console: `screen /dev/ttyACM0 115200`
3. Compare kernel configs between fc41 and fc42 Asahi kernels
4. May need to use fc42 kernel with fc41 userspace

### Option C: Match Target's Exact Base
The target runs Silverblue. Check what OCI image it uses:
```bash
ssh erowan@192.168.8.114 'rpm-ostree status'
```
Consider using that exact base image.

---

## Key Files

| File | Description |
|------|-------------|
| `src/Containerfile.substrate` | Main build file (v5, single-stage) |
| `src/build_files/` | Supporting files (services, configs) |
| `.swarm/HANDOFF-*.md` | Previous handoffs |

---

## SSH Setup Notes

- User: `erowan` (not `formless`)
- Passwordless sudo: configured
- To prevent sleep during deployment:
```bash
ssh erowan@192.168.8.114 'systemctl --user start deployment-inhibit'
```

---

## Registry Info

- **Fedora Asahi Remix base-atomic images:** `quay.io/fedora-asahi-remix-atomic-desktops/base-atomic`
- **Tags available (as of today):** 41.x only (no 42 confirmed)
- Check for updates: https://github.com/fedora-asahi-remix-atomic-desktops/images

---

## Lessons Learned

1. **Don't fight OSTree** - Kernel grafting doesn't work reliably with bootc. The ostree metadata determines the kernel, not just the files.

2. **Version match matters** - fc41 kernel on fc42 system causes issues. Need to match Fedora versions.

3. **Use the right base** - Fedora Asahi Remix base-atomic images already have everything needed. No grafting required.

4. **Serial debug is valuable** - For kernel panics, USB-C serial output would help identify exact failure point.

---

## Commands Reference

```bash
# SSH to target
ssh erowan@192.168.8.114

# Check bootc status
sudo bootc status

# Rollback to previous deployment
sudo bootc rollback && sudo reboot

# Check available Asahi base images
skopeo inspect docker://quay.io/fedora-asahi-remix-atomic-desktops/base-atomic:42

# Build image locally
cd /Users/eric/dev/personal/asahi-substrate/src
podman build -f Containerfile.substrate -t ghcr.io/ericrowan/asahi-substrate:latest .

# Push to GHCR
podman push ghcr.io/ericrowan/asahi-substrate:latest
```

---

## Status Checklist

- [x] Image built with correct Asahi kernel
- [x] Image pushed to GHCR
- [x] Image pulled to target
- [x] bootc switch staged
- [ ] **Successful boot** - BLOCKED (kernel panic)
- [ ] SSH accessible post-reboot
- [ ] Hardware validation passed
