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
4. Create user directories

This takes a few minutes. You can watch progress on the console or just wait and SSH in.

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
│  User Tools (Homebrew)                      │
│  - neovim, ripgrep, fd, bat, etc.           │
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
