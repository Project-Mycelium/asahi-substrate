# Formless + Substrate Integration

## Overview

Formless is not an application running on Substrate. **Formless IS the operating system.** The Substrate exists only to provide the minimal hardware abstraction layer needed to run Formless.

This document tracks the integration points between Formless Kernel and the Substrate OS layer.

---

## Phase 7: Substrate Bridge (Formless Roadmap)

This integration is Phase 7 of the Formless Kernel roadmap, enabling Formless to manage and configure the underlying Substrate.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                 FORMLESS KERNEL                      │
│  ┌─────────────────────────────────────────────┐   │
│  │           Substrate Bridge Crate             │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐       │   │
│  │  │ Systemd │ │ Network │ │  Bootc  │       │   │
│  │  │ Client  │ │ Client  │ │ Client  │       │   │
│  │  └─────────┘ └─────────┘ └─────────┘       │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐       │   │
│  │  │Hardware │ │ Display │ │  Audio  │       │   │
│  │  │ Client  │ │ Client  │ │ Client  │       │   │
│  │  └─────────┘ └─────────┘ └─────────┘       │   │
│  └─────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│              SUBSTRATE (Linux Layer)                 │
│   systemd, NetworkManager, bootc, /sys, /proc       │
└─────────────────────────────────────────────────────┘
```

---

## Command Reference

### Boot & Console Customization

#### Font Management
```bash
formless config font <size>
```

| Size | Font | Pixels |
|------|------|--------|
| small | default8x16 | 8x16 |
| medium | sun12x22 | 12x22 |
| large | latarcyrheb-sun32 | 16x32 |
| huge | solar24x32 | 24x32 |

**Implementation:**
```rust
// Edit /etc/vconsole.conf
// Run: setfont <font_path>
```

#### Boot Verbosity
```bash
formless config boot <mode>
```

| Mode | Kernel Options |
|------|---------------|
| quiet | `quiet loglevel=3 systemd.show_status=false` |
| normal | (default) |
| verbose | `systemd.log_level=info` |
| debug | `systemd.log_level=debug rd.debug` |

**Implementation:**
```rust
// Edit /boot/loader/entries/ostree-*.conf
// Modify 'options' line
```

#### Plymouth Splash
```bash
formless config splash <theme>
formless config splash off
```

**Available themes:** spinner, fade-in, text, details

**Implementation:**
```rust
// plymouth-set-default-theme <theme>
// dracut --force --add plymouth <initramfs>
```

---

### System Management

#### Service Control
```bash
formless service <name> <action>
formless service list              # List all services
formless service status <name>     # Service status
formless service start <name>      # Start service
formless service stop <name>       # Stop service
formless service restart <name>    # Restart service
formless service enable <name>     # Enable at boot
formless service disable <name>    # Disable at boot
formless service logs <name>       # View logs (journalctl)
```

**Implementation:** Wrapper around `systemctl` and `journalctl`

#### Network Configuration
```bash
formless network status            # Overall network status
formless network wifi list         # List available networks
formless network wifi connect <ssid> [password]
formless network wifi disconnect
formless network wifi saved        # List saved networks
formless network wifi forget <ssid>

formless network tailscale status  # Tailscale status
formless network tailscale up      # Connect to Tailscale
formless network tailscale down    # Disconnect
formless network tailscale ip      # Show Tailscale IP
```

**Implementation:**
- WiFi: `nmcli` wrapper
- Tailscale: `tailscale` CLI wrapper

#### Update Management
```bash
formless update                    # Check and apply updates
formless update --check            # Check only, don't apply
formless update --changelog        # Show what changed
formless update --apply            # Apply pending update
formless rollback                  # Boot previous deployment
formless rollback --list           # List available deployments
```

**Implementation:** `bootc` wrapper with status parsing

---

### Hardware Integration (Apple Silicon)

#### Audio
```bash
formless audio status              # Speaker protection status
formless audio volume <0-100>      # Set volume
formless audio mute                # Mute
formless audio unmute              # Unmute
formless audio devices             # List audio devices
formless audio output <device>     # Set output device
```

**CRITICAL:** Speaker protection (speakersafetyd) must NEVER be disabled.

**Implementation:** PipeWire/PulseAudio CLI, speakersafetyd status check

#### Power Management
```bash
formless power status              # Battery status, power source
formless power mode <mode>         # Set power mode
formless power sleep               # Sleep system
formless power shutdown            # Shutdown
formless power reboot              # Reboot
```

| Mode | Description |
|------|-------------|
| performance | Maximum performance, higher power |
| balanced | Default, adaptive |
| powersave | Maximum battery life |

**Implementation:**
- CPU governor: `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor`
- Battery: `/sys/class/power_supply/`
- Power profiles daemon if available

#### Display
```bash
formless display brightness <0-100>  # Set brightness
formless display brightness up       # Increase 10%
formless display brightness down     # Decrease 10%
formless display resolution          # Show current resolution
formless display resolution <WxH>    # Set resolution (if supported)
```

**Implementation:**
- Brightness: `/sys/class/backlight/*/brightness`
- Resolution: `drm` or Wayland protocols

---

### Development Environment

#### Container Runtime
```bash
formless container run <image> [cmd]  # Run container
formless container ps                 # List containers
formless container logs <id>          # View logs
formless container kill <id>          # Kill container
formless container images             # List images
formless container pull <image>       # Pull image
```

**Implementation:** Podman CLI wrapper (already in formless-runtime)

#### Homebrew Integration
```bash
formless brew <args>               # Pass-through to brew
formless brew install <pkg>        # Install package
formless brew upgrade              # Upgrade all
formless brew list                 # List installed
```

**Implementation:**
- Ensure correct PATH/environment
- Pass-through to `/home/linuxbrew/.linuxbrew/bin/brew`

---

## Implementation Status

### Completed
- [x] Podman runtime detection (hardcoded path fix)
- [x] Console font configuration (latarcyrheb-sun32)
- [x] Quiet boot parameters
- [x] Plymouth added to Containerfile

### In Progress
- [ ] Boot directly to Formless (no login prompt)
- [ ] formless.service as default target

### Planned
- [ ] Substrate Bridge crate in formless-kernel
- [ ] `formless config` commands
- [ ] `formless service` commands
- [ ] `formless network` commands
- [ ] `formless update` commands
- [ ] `formless audio` commands
- [ ] `formless power` commands
- [ ] `formless display` commands

---

## Technical Notes

### Privilege Escalation

System changes require root. Options:
1. **polkit rules** - Allow formless user specific actions without password
2. **sudo wrapper** - Formless prompts for elevation
3. **setuid helpers** - Small binaries for specific tasks
4. **D-Bus system services** - Preferred for complex operations

Recommendation: Start with sudo, migrate to polkit rules for seamless UX.

### Configuration Persistence

All config changes should be:
1. **Idempotent** - Running twice has same effect as once
2. **Reversible** - Can undo any change
3. **Logged** - Track what changed and when
4. **Validated** - Check before applying

### File Locations

| Config | Path | Persistence |
|--------|------|-------------|
| Console font | /etc/vconsole.conf | Survives reboot |
| Kernel cmdline | /boot/loader/entries/*.conf | Per deployment |
| Network | /etc/NetworkManager/ | Survives reboot |
| Tailscale | /var/lib/tailscale/ | Survives reboot |
| Homebrew | /home/linuxbrew/ | Survives reboot |
| Plymouth | /etc/plymouth/ | Baked in image |

### Boot Entry Management

On bootc/ostree systems:
- `/etc/kernel/cmdline` is used for NEW deployments
- Existing deployments need direct edit of `/boot/loader/entries/ostree-*.conf`
- After `bootc upgrade`, new entry gets cmdline from `/etc/kernel/cmdline`

---

## Future Ideas

### Short Term
- [ ] TUI wizard for initial setup (`formless setup`)
- [ ] Declarative config file (`~/.config/formless/substrate.toml`)
- [ ] Status bar showing battery, network, time

### Medium Term
- [ ] Sync settings across machines via Tailscale
- [ ] Voice control integration (Whisper + Formless)
- [ ] Auto-detect hardware and suggest optimizations

### Long Term
- [ ] Formless as Wayland compositor (Smithay)
- [ ] Direct GPU rendering in Formless TUI
- [ ] Gesture support for trackpad
- [ ] Touch Bar integration (if applicable)

---

## Related Documents

- [Substrate Vision & Roadmap](./substrate-vision-and-roadmap.md)
- [Formless Kernel ROADMAP.md](/Users/eric/src/formless-kernel/ROADMAP.md)
- [Formless Kernel README.md](/Users/eric/src/formless-kernel/README.md)
