# Agent Handoff - Formless Substrate

## Session Summary

Implemented the **Formless Kernel Integration Plan** - the Substrate can now host the Formless Kernel (Rust daemon swarm).

## What Was Done

### Files Created
- `scripts/setup-kernel.sh` - One-command kernel installation script
- `src/build_files/setup-kernel.sh` - Copy for container image
- `docs/kernel-integration-report.md` - Full architecture documentation

### Files Modified
- `src/build_files/first-boot-setup.sh` - Added Rust toolchain installation
- `src/Containerfile.substrate` - Added setup-kernel deployment
- `README.md` - Added kernel integration section

### Commit
```
e14eac5 feat: add formless-kernel integration scripts and documentation
```

## Current State

**Substrate (this repo)**: Complete and ready
- Bootable OS image on Apple Silicon (M1)
- SSH access as `formless` user
- Homebrew + Rust toolchain installed on first boot
- `formless.service` configured and ready
- `setup-kernel` script baked into image

**Kernel Integration**: Ready but untested on hardware
- Scripts written and committed
- Needs actual M1 deployment to verify

## Next Steps

1. **Push to remote** (if desired):
   ```bash
   git push origin main
   ```

2. **Rebuild and deploy image**:
   ```bash
   cd src
   podman build -f Containerfile.substrate -t ghcr.io/ericrowan/asahi-substrate:latest .
   podman push ghcr.io/ericrowan/asahi-substrate:latest
   ```

3. **On the M1 Substrate**:
   ```bash
   sudo bootc upgrade
   sudo reboot
   # After reboot:
   setup-kernel
   ```

4. **Verify**:
   ```bash
   systemctl status formless
   formless status
   ls -la ~/.formless/kernel.sock
   ```

## Key Architecture

```
Formless Kernel (Rust)  ←── JSON-RPC via ~/.formless/kernel.sock
        ↓
Formless Substrate (Linux) ←── systemd: formless.service
        ↓
Apple Silicon Hardware
```

## Important Files

| File | Purpose |
|------|---------|
| `src/Containerfile.substrate` | Main image build |
| `src/build_files/first-boot-setup.sh` | First boot automation (installs Homebrew + Rust) |
| `src/build_files/setup-kernel.sh` | Kernel installation (clone, build, install, enable) |
| `src/build_files/formless.service` | systemd unit for kernel daemon |

## External Dependencies

- **formless-kernel repo**: `github.com/ericrowan/formless-kernel`
  - Rust monorepo with 34+ crates
  - 649 tests
  - Builds to `formless`, `formless-kernel`, `formless-dashboard` binaries

## Known Issue: "No such file or directory" on Service Start

The `formless.service` shows this error because the binary doesn't exist yet. This is expected!

**Quick fix (current image):**
```bash
ssh formless@<m1-ip>
git clone https://github.com/ericrowan/formless-kernel.git ~/src/formless-kernel
cd ~/src/formless-kernel
cargo build --release
cp target/release/formless /home/linuxbrew/.linuxbrew/bin/
sudo systemctl start formless
```

**Or with new image (after git push + GitHub Actions build):**
```bash
sudo bootc upgrade && sudo reboot
# After reboot:
setup-kernel  # One command does everything
```

## Potential Issues to Watch

1. **OpenSSL paths**: The build scripts set `OPENSSL_DIR` for Homebrew's OpenSSL. If builds fail, check these paths.

2. **ARM64 Rust**: Should work natively, but first build may need to download many crates.

3. **Socket permissions**: The kernel creates `~/.formless/kernel.sock`. If it doesn't appear, check service logs.

## Useful Commands

```bash
# Check service
journalctl -u formless -f

# Rebuild kernel
cd ~/src/formless-kernel && cargo build --release

# Reinstall binary
cp target/release/formless /home/linuxbrew/.linuxbrew/bin/

# Restart service
sudo systemctl restart formless
```

## Session 2: Kernel Deployed on M1

**What was done:**
1. SSH'd into M1 substrate (100.73.161.5 via Tailscale)
2. Fixed Homebrew permissions
3. Installed Rust toolchain via rustup
4. Built formless-kernel in a Fedora container (podman) to get correct glibc/gcc
5. Installed binaries to `/home/linuxbrew/.linuxbrew/bin/`
6. Started the kernel (it runs but has a runtime detection issue - can't find podman)

**Key finding:**
The bootc image is read-only - can't layer packages via rpm-ostree due to version conflicts. Solution: Added gcc/glibc-devel to Containerfile.substrate for future builds.

**Current kernel status:**
- Binary installed and runs
- Needs fix in formless-kernel to detect podman correctly
- The kernel creates directories and starts but exits quickly

**Commands that worked:**
```bash
# Build in container (on M1)
podman run --rm -v ~/src/formless-kernel:/build:Z -w /build fedora:42 bash -c \
  'dnf install -y gcc gcc-c++ make rust cargo openssl-devel protobuf-compiler protobuf-devel alsa-lib-devel libstdc++-devel && cargo build --release'

# Install binaries
cp ~/src/formless-kernel/target/release/formless /home/linuxbrew/.linuxbrew/bin/

# Start kernel
FORMLESS_HOME=/home/formless/.formless formless start
```

---
*Handoff updated: 2026-01-27*
