# Asahi-Substrate Handoff

**Date:** 2026-01-27T16:50:00Z
**Git SHA:** af52c3e
**Session Duration:** ~3 hours

## Completed

- [x] GHCR auth fixed (repository workflow permissions set to read/write)
- [x] Image pushed to ghcr.io/ericrowan/asahi-substrate:latest
- [x] Image validation: PASS (kernel, initramfs, packages verified)
- [x] Git state: clean

## Image Details

- **Registry:** ghcr.io/ericrowan/asahi-substrate:latest
- **Kernel:** 6.17.12-400.asahi.fc41.aarch64+16k
- **Base:** fedora-bootc:43
- **Size:** 2.59 GB

## Validation Results

```
=== Kernel ===
6.17.12-400.asahi.fc41.aarch64+16k

=== Initramfs ===
nvme-apple.ko.xz FOUND

=== Packages ===
mesa-dri-drivers-25.2.7-3.fc43.aarch64
pipewire-1.4.9-1.fc43.aarch64
asahi-audio-3.4-3.fc43.noarch
asahi-fwupdate-20250713-5.fc43.noarch
asahi-scripts-20250713-5.fc43.noarch
dracut-asahi-20250713-5.fc43.noarch
alsa-ucm-asahi-8-2.fc43.noarch
asahi-bless-0.4.2-2.fc43.aarch64

=== Services ===
sshd.service
tailscale-autostart.service
formless-first-boot.service
formless.service
```

## Architecture Summary

**3-Stage Containerfile v4:**
1. Stage 1: Kernel extraction from Asahi COPR
2. Stage 2: Package extraction via rpm2cpio
3. Stage 3: Assembly onto base image

**Package Management:**
- System: OSTree layers (immutable)
- User: Homebrew (/home/linuxbrew/.linuxbrew)
- Apps: Podman containers

## Ready for Hardware Deployment

Target: M1 MacBook at 100.73.161.5 (Tailscale) / 192.168.8.114 (LAN)

```bash
# On target machine:
sudo bootc switch ghcr.io/ericrowan/asahi-substrate:latest
sudo reboot
```

## Next Session Actions

1. Deploy to hardware via bootc switch
2. Validate boot (SSH accessible, display works, audio works)
3. Test first-boot Homebrew installation
4. Begin Formless binary integration
5. Build GNOME OS base variant (trigger build-gnomeos-base.yml)

## Blockers

- None for fedora-bootc variant
- GNOME OS base not yet built (workflow ready, not triggered)

## Notes

- `formless` user created via useradd in Containerfile but may not persist in container runtime (created properly on real boot)
- First-boot service installs Homebrew + essential tools (gh, neovim, ripgrep, etc.)
- Speaker protection daemon (speakersafetyd) enabled - CRITICAL for Apple Silicon
- SSH hardened (key-only auth, root login disabled)

## Key Files

| File | Purpose |
|------|---------|
| `src/Containerfile.substrate` | v4 3-stage build |
| `src/build_files/first-boot-setup.sh` | Homebrew bootstrap |
| `src/build_files/formless.service` | Formless systemd unit |
| `.github/workflows/build-substrate.yml` | CI/CD pipeline |

## Session Commits

1. `feat: v4 Containerfile with 3-stage build and Homebrew bootstrap`
2. `fix: create /var/lib/formless dir and set explicit UID for formless user`
3. `fix: use /var/home for Homebrew dir in bootc images`
4. `fix: use COPY for systemd services instead of heredocs`
5. `chore: clean up debug code after successful build verification`
