> **⚠ RETIREMENT STAMP — 2026-07-30 (Operation Badger).** The **v1 13-daemon Formless swarm**
> that this README's "install the Formless Kernel / full daemon swarm" (below) and "13 specialized
> daemons" sections describe is **RETIRED** — its launchd agents were quarantined 2026-07-17 and its
> binaries removed from PATH 2026-07-30. Those sections are **historical; do NOT rebuild the swarm.**
> asahi-substrate itself (the bootable Apple-Silicon OS image documented below) **STAYS — Eric ruled** —
> but the current Formless it should host is the **hub + v3 kernel** (`~/dev/formless-hub`,
> `~/src/formless-os`), not the v1 daemon swarm.

# Formless Substrate

A minimal, bootable OS image for Apple Silicon Macs. Built on Fedora Asahi Remix with the Asahi Linux kernel.

## What is this?

Formless Substrate is a headless server OS designed for Apple Silicon (M1/M2/M3/M4). It's meant to be accessed via SSH, not used with a GUI. Think of it as your personal cloud computer running on bare metal.

## Quick Start

### Deploy to your Mac

From an existing Fedora Asahi installation:

```bash
# Switch to Substrate
sudo bootc switch ghcr.io/ericrowan/asahi-substrate:latest
sudo reboot
```

### Connect via SSH

```bash
ssh formless@<your-mac-ip>
```

- **User:** `formless`
- **Password:** `formless` (for console access)
- **Sudo:** Passwordless (wheel group)

## What's Included

| Component | Details |
|-----------|---------|
| **Base** | Fedora Asahi Remix 42 |
| **Kernel** | Asahi Linux (6.17.x) with Apple Silicon drivers |
| **GPU** | Mesa with Asahi drivers |
| **Audio** | PipeWire + speakersafetyd |
| **Network** | NetworkManager + iwd (WiFi) |
| **Remote** | SSH + Tailscale |
| **Containers** | Podman |
| **Package Manager** | Homebrew (installed on first boot) |

## What's NOT Included

- No GUI / Desktop Environment
- No display manager
- No Wayland/X11 session

This is intentional. Substrate is a server.

## First Boot

On first boot, the system will:

1. Set up SSH keys
2. Install Homebrew
3. Install essential CLI tools (neovim, ripgrep, fd, bat, eza, fzf, starship)
4. Install Rust toolchain (for building formless-kernel)
5. Create `.formless/` directories (inbox, sessions, projects)

This takes a few minutes. You can watch progress on the console or just wait and SSH in.

## Formless Kernel Integration

After first boot, you can install the Formless Kernel to enable the full daemon swarm:
> **[RETIRED — see stamp at top; do not rebuild the v1 swarm.]**

```bash
# SSH into your substrate
ssh formless@<your-mac-ip>

# Clone the kernel repository
git clone https://github.com/ericrowan/formless-kernel.git ~/src/formless-kernel

# Run the setup script
setup-kernel
```

The setup script will:
1. Install Rust toolchain (if not present)
2. Build the kernel from source
3. Install binaries to Homebrew's bin directory
4. Enable and start the `formless.service`

### Verify Installation

```bash
# Check service status
systemctl status formless

# Check socket exists
ls -la ~/.formless/kernel.sock

# Test CLI
formless status

# View logs
journalctl -u formless -f
```

### Manual Build (if needed)

```bash
cd ~/src/formless-kernel
cargo build --release
cp target/release/formless /home/linuxbrew/.linuxbrew/bin/
sudo systemctl start formless
```

## Updating

```bash
# Check for updates
sudo bootc upgrade --check

# Apply updates
sudo bootc upgrade
sudo reboot
```

## Building Locally

```bash
cd src
podman build -f Containerfile.substrate -t ghcr.io/ericrowan/asahi-substrate:latest .
podman push ghcr.io/ericrowan/asahi-substrate:latest
```

## GitHub Actions

Builds run automatically:
- On push to `main` (when `src/**` changes)
- Weekly (Mondays 6am UTC)
- Manual trigger via Actions tab

## Architecture

```
┌─────────────────────────────────────────────┐
│           Formless Substrate                │
├─────────────────────────────────────────────┤
│  Formless Kernel (optional)                 │
│  - 13 specialized daemons                   │
│  - JSON-RPC via ~/.formless/kernel.sock     │
├─────────────────────────────────────────────┤
│  User Tools (Homebrew + Rust)               │
│  - neovim, ripgrep, fd, bat, cargo, etc.    │
├─────────────────────────────────────────────┤
│  System Services                            │
│  - sshd, tailscaled, speakersafetyd         │
├─────────────────────────────────────────────┤
│  Fedora Asahi Remix base-atomic:42          │
│  - Asahi kernel + Mesa + PipeWire           │
├─────────────────────────────────────────────┤
│  Apple Silicon Hardware                     │
│  - M1/M2/M3/M4 MacBook/Mac Mini/etc.        │
└─────────────────────────────────────────────┘
```

## Configuration Files

| File | Purpose |
|------|---------|
| `src/Containerfile.substrate` | Main image build |
| `src/build_files/formless-user.conf` | User creation (sysusers) |
| `src/build_files/formless-home.conf` | Home directory (tmpfiles) |
| `src/build_files/first-boot-setup.sh` | First boot automation |
| `src/build_files/setup-kernel.sh` | Kernel installation script |
| `src/build_files/formless.service` | Kernel systemd service |
| `src/build_files/authorized_keys.d/` | SSH public keys |

## Troubleshooting

### Can't SSH in?
- Check if the machine booted: `ping <ip>`
- Try console login: `formless` / `formless`
- Check SSH keys: `cat /home/formless/.ssh/authorized_keys`

### Kernel panic on boot?
- Ensure you're using `base-atomic:42` (not fedora-bootc)
- The Asahi kernel MUST come from the Fedora Asahi Remix base

### Need to rollback?
```bash
sudo bootc rollback
sudo reboot
```

## License

MIT

## Credits

- [Asahi Linux](https://asahilinux.org/) - Apple Silicon Linux support
- [Fedora Asahi Remix](https://fedora-asahi-remix.org/) - Fedora + Asahi integration
- [bootc](https://github.com/containers/bootc) - Bootable container runtime
