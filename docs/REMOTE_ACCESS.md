# Remote Access Layer for Formless Substrate

**Purpose:** Ensure the substrate is always remotely accessible, even if display fails.

---

## Why This Matters

The substrate may:
- Boot to a black screen (display issues)
- Have Formless crash
- Need debugging without physical access
- Need OTA updates pushed remotely

**Solution:** Tailscale + SSH as foundational services, started before Formless.

---

## Architecture

```
Boot
  ↓
systemd
  ├── tailscaled.service (Priority: Early)
  ├── sshd.service (Priority: Early)
  ├── NetworkManager.service
  └── formless.service (Depends on above)
```

SSH and Tailscale start **before** Formless, so even if Formless fails to start, you can SSH in.

---

## Components

### 1. Tailscale
- **Package:** `tailscale`
- **Service:** `tailscaled.service`
- **Config:** `/etc/default/tailscaled` or systemd drop-in
- **Auth:** Pre-authenticated via auth key or `tailscale up` on first boot

### 2. OpenSSH Server
- **Package:** `openssh-server`
- **Service:** `sshd.service`
- **Config:** `/etc/ssh/sshd_config`
- **Auth:** SSH keys only (no passwords)

---

## Containerfile Addition

```dockerfile
# Remote Access Layer
RUN dnf install -y --setopt=install_weak_deps=False \
        tailscale \
        openssh-server && \
    dnf clean all

# Enable services
RUN systemctl enable tailscaled.service && \
    systemctl enable sshd.service

# SSH hardening - keys only, no passwords
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create authorized_keys location
RUN mkdir -p /etc/skel/.ssh && \
    chmod 700 /etc/skel/.ssh
```

---

## First Boot Setup

### Option A: Pre-baked Auth Key (Recommended for Substrate)

Generate a reusable auth key in Tailscale admin console:
- Settings → Keys → Generate auth key
- Enable: Reusable, Ephemeral (optional), Pre-approved

Add to substrate:

```dockerfile
# Tailscale auto-join (use environment variable or secret)
COPY <<EOF /etc/systemd/system/tailscale-autostart.service
[Unit]
Description=Tailscale Auto-Join
After=tailscaled.service
Wants=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/bin/tailscale up --authkey=tskey-auth-XXXXX --hostname=formless-substrate
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

RUN systemctl enable tailscale-autostart.service
```

### Option B: Manual First Boot

On first boot, run:
```bash
sudo tailscale up
# Opens browser or provides URL to authenticate
```

---

## SSH Key Injection

### At Build Time (for known keys)

```dockerfile
# Inject your SSH public key
COPY <<EOF /etc/skel/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... eric@macbook
EOF
RUN chmod 600 /etc/skel/.ssh/authorized_keys
```

### At Runtime (via cloud-init style)

Create a first-boot service that pulls keys from:
- A config file on USB
- A URL
- Tailscale's SSH key distribution

---

## Network Priority

Ensure Tailscale can connect even if WiFi isn't configured:

```
[Boot Sequence]
1. NetworkManager starts
2. Ethernet (if connected) gets DHCP
3. tailscaled starts, connects via any available network
4. WiFi can be configured later via SSH
```

For initial setup without ethernet:
- Use USB-C ethernet adapter, or
- Pre-configure WiFi in image

---

## Pre-configured WiFi (Optional)

```dockerfile
# Pre-configure WiFi network
COPY <<EOF /etc/NetworkManager/system-connections/home-wifi.nmconnection
[connection]
id=HomeWiFi
type=wifi

[wifi]
ssid=YourNetworkName

[wifi-security]
key-mgmt=wpa-psk
psk=YourPassword

[ipv4]
method=auto

[ipv6]
method=auto
EOF
RUN chmod 600 /etc/NetworkManager/system-connections/home-wifi.nmconnection
```

---

## Firewall Considerations

The substrate should allow:
- Inbound SSH (port 22) - Tailscale handles this via MagicDNS
- Tailscale traffic (UDP 41641)
- DHCP client (UDP 68)

Minimal firewalld rules:
```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=41641/udp
```

Or disable firewalld entirely for the minimal substrate (Tailscale provides its own ACLs).

---

## Recovery Scenarios

### Scenario: Display broken, can't see anything
1. Wait 60 seconds for boot
2. `ssh formless-substrate` (via Tailscale MagicDNS)
3. Debug from remote shell

### Scenario: Formless crashed
1. SSH in
2. `journalctl -u formless.service` to see logs
3. Fix and restart: `systemctl restart formless.service`

### Scenario: Network not configured
1. Connect USB-C ethernet adapter
2. Wait for DHCP
3. SSH via local IP or Tailscale

### Scenario: Tailscale not authenticated
1. Connect via local network SSH (if on same LAN)
2. `sudo tailscale up` to authenticate
3. Future connections via Tailscale

---

## Testing Checklist

- [ ] SSH works via Tailscale IP
- [ ] SSH works via MagicDNS hostname
- [ ] Can SSH before Formless starts
- [ ] Can SSH even if Formless fails
- [ ] Keys-only auth (password rejected)
- [ ] Tailscale auto-connects on boot
- [ ] Survives reboot

---

## Security Notes

1. **No root SSH:** Disable root login in sshd_config
2. **Keys only:** Password auth disabled
3. **Tailscale ACLs:** Use Tailscale admin to restrict who can access
4. **Fail2ban:** Optional, but Tailscale makes this less necessary
5. **No public exposure:** The substrate is only accessible via Tailscale, not public internet

---

## Integration with Formless

Formless should be aware of network status:
```rust
// Check Tailscale status
fn is_tailscale_connected() -> bool {
    Command::new("tailscale")
        .args(["status", "--json"])
        .output()
        .ok()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

// Get Tailscale IP
fn get_tailscale_ip() -> Option<String> {
    // Parse tailscale status --json
}
```

Display in Formless status bar:
```
[Tailscale: ●] [SSH: ●] [WiFi: formless-5g]
```
