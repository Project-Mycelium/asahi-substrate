# Build Architecture

## Overview

asahi-substrate uses a two-tier build system to produce minimal, modular OS images for Apple Silicon.

```
┌─────────────────────────────────────────────────────────────────┐
│                     SUBSTRATE IMAGES                             │
│  (what you deploy to hardware)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐    ┌─────────────────────┐             │
│  │  asahi-substrate    │    │ asahi-substrate     │             │
│  │  (stable)           │    │ -gnomeos (substrate)│             │
│  │                     │    │                     │             │
│  │  ~2.5GB             │    │  ~1GB (target)      │             │
│  │  fedora-bootc base  │    │  GNOME OS base      │             │
│  └──────────┬──────────┘    └──────────┬──────────┘             │
│             │                          │                         │
│             └──────────┬───────────────┘                         │
│                        │                                         │
│              ┌─────────▼─────────┐                               │
│              │  Asahi Kernel     │                               │
│              │  + Hardware Layer │                               │
│              │  + SSH/Tailscale  │                               │
│              └───────────────────┘                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ BASE IMAGES
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌─────────────────────┐    ┌─────────────────────┐             │
│  │  fedora-bootc:43    │    │ gnomeos-base-aarch64│             │
│  │  (upstream)         │    │ (we build this)     │             │
│  │                     │    │                     │             │
│  │  quay.io/fedora/    │    │ Built from          │             │
│  │  fedora-bootc:43    │    │ gnome-build-meta    │             │
│  └─────────────────────┘    └─────────────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Image Variants

### 1. asahi-substrate (stable)
- **Base**: `quay.io/fedora/fedora-bootc:43`
- **Size**: ~2.5GB
- **Use case**: Daily driver, full compatibility
- **Package management**: DNF available
- **Status**: Production-ready

### 2. asahi-substrate-gnomeos (substrate)
- **Base**: `ghcr.io/<user>/gnomeos-base-aarch64:nightly` (built from source)
- **Size**: ~1GB (target)
- **Use case**: Minimal Formless substrate
- **Package management**: OSTree only, no DNF
- **Status**: Experimental

## Build Workflows

### GitHub Actions Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `build-gnomeos-base.yml` | Build GNOME OS aarch64 from source | Manual, weekly |
| `build-substrate.yml` | Build both substrate variants | Push, manual, weekly |

### Local Build Commands

```bash
# Build stable (fedora-bootc base)
just build-substrate

# Build substrate (GNOME OS base) - requires base image
just build-gnomeos-base-remote  # Trigger GitHub Actions build first
just build-substrate-gnomeos    # Then build locally

# Or trigger everything remotely
gh workflow run build-substrate.yml
```

## GNOME OS Base Build

We build GNOME OS aarch64 from source because:
1. Upstream only publishes x86_64 OCI images
2. We want full control over the base
3. Enables true "substrate" architecture (no distro cruft)

### Build Process

```
gnome-build-meta (upstream)
        │
        ▼ BuildStream
┌───────────────────┐
│ GNOME OS aarch64  │
│ OCI Image         │
└───────────────────┘
        │
        ▼ Published to
ghcr.io/<user>/gnomeos-base-aarch64:nightly
```

### Build Time
- Native ARM64 runner: ~2-4 hours
- Cached rebuild: ~30-60 minutes

## Kernel Graft

Both variants use the same kernel graft approach:

```dockerfile
# Stage 1: Extract kernel from Asahi COPR
FROM quay.io/fedora/fedora:41 as extractor
RUN dnf copr enable -y @asahi/kernel
RUN dnf download --resolve kernel-16k
# ... extract to /payload/lib/modules

# Stage 2: Graft onto base
FROM ${BASE_IMAGE}
RUN rm -rf /usr/lib/modules/*
COPY --from=extractor /payload/lib/modules /usr/lib/modules
```

## Hardware Enablement Layer

Both variants include:
- `mesa-dri-drivers` - GPU acceleration
- `asahi-audio` + `speakersafetyd` - Audio with speaker protection
- `pipewire` + `wireplumber` - Audio routing
- `nvme-apple` - Storage driver (in initramfs)

## Remote Access Layer

Baked into both variants:
- SSH server (key-only authentication)
- Tailscale (auto-join on first boot)
- Authorized keys from `build_files/authorized_keys.d/`

## Philosophy

> "The substrate is not the destination. Formless is the destination. The substrate just gets us there."

The GNOME OS variant represents the true "substrate" vision:
- No package manager (apps via containers)
- No distro userspace (just GNOME + kernel)
- Minimal attack surface
- Fast boot (<15 seconds target)
- Formless becomes the shell

The fedora-bootc variant is the "stable" path:
- Full Fedora compatibility
- DNF for emergencies
- Larger but more familiar
- Good for development/debugging

## Related Docs

- [SUBSTRATE_VISION.md](SUBSTRATE_VISION.md) - Design philosophy
- [RECON.md](RECON.md) - Hardware reconnaissance
- [SERIAL_DEBUG.md](SERIAL_DEBUG.md) - Low-level debugging
