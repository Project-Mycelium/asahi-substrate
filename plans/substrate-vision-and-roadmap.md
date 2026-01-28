# Substrate: Vision & Roadmap

## The Core Philosophy

> "The substrate is not the destination. Formless is the destination. The substrate just gets us there."

> "The system that can build its own substrate can build anything."

Substrate is **not** a Linux distribution. It's a **minimal, purpose-built hosting layer** for Formless Kernel. The architecture is inverted from traditional OS thinking:

```
Traditional:     OS → Desktop → Applications → Your Tool
Substrate:       Hardware → Minimal Boot → Formless IS the OS
```

**Formless IS the operating environment**, not an application running on top of Linux.

---

## Project Name Evolution

The project has evolved through several names reflecting the journey:
- `fungiOS` - Early biological/mycelial metaphor
- `wavyOS` - Aesthetic direction
- `asahi-atomic` - Technical foundation (Asahi + atomic/immutable)
- `asahi-substrate` - Current: emphasizes the "substrate" philosophy
- `Formless Substrate` - Brand name: the substrate that runs Formless

---

## What We ARE Building

### The Stack

```
┌─────────────────────────────────────┐
│         FORMLESS KERNEL             │  ← The actual "OS" / interface
│    (Agentic Operating System)       │
├─────────────────────────────────────┤
│         SUBSTRATE LAYER             │  ← Minimal Linux foundation
│  ┌─────────────────────────────┐   │
│  │ Podman (rootless containers)│   │
│  │ PipeWire + speakersafetyd   │   │
│  │ NetworkManager + iwd        │   │
│  │ SSH + Tailscale             │   │
│  │ Mesa (Asahi GPU)            │   │
│  │ Asahi Kernel (16k pages)    │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│    APPLE SILICON BOOT CHAIN         │
│    m1n1 → U-Boot → systemd-boot     │
└─────────────────────────────────────┘
│           M1/M2/M3/M4 HARDWARE      │
└─────────────────────────────────────┘
```

### Required Components

| Layer | Component | Purpose |
|-------|-----------|---------|
| Boot | m1n1, U-Boot | Apple Silicon boot chain |
| Kernel | Asahi kernel-16k | Apple hardware support |
| GPU | Mesa + Asahi DRM | Graphics acceleration |
| Audio | PipeWire + speakersafetyd | Audio with speaker protection |
| Network | NetworkManager + iwd | WiFi and networking |
| Containers | Podman (rootless) | App isolation, Formless agents |
| Remote | SSH + Tailscale | Secure access |
| Updates | bootc | Atomic OCI-based updates |

### Critical Safety: Speaker Protection

**speakersafetyd is MANDATORY and must NEVER be disabled.**

Apple Silicon speakers can be permanently damaged without this daemon. This is a hard requirement, not optional.

---

## What We Are NOT Building

| NOT This | Why |
|----------|-----|
| GNOME/KDE desktop | Formless IS the desktop |
| GDM/login manager | Boot directly to Formless |
| Package manager GUI | Container-native only |
| Multiple users | Single-purpose: one user (`formless`) |
| General-purpose distro | Purpose-built for Formless |
| Firefox, office apps | Everything runs in containers |

---

## Success Criteria

- [ ] **Boot to Formless in < 15 seconds**
- [ ] **Image size < 1GB** (stretch goal: < 500MB)
- [ ] **Silent boot** - no scrolling text, clean splash
- [ ] **WiFi connects automatically**
- [ ] **Audio works without configuration**
- [ ] **GPU acceleration functional**
- [ ] **Can spawn containers from Formless**
- [ ] **OTA updates via `bootc upgrade`**
- [ ] **SSH + Tailscale accessible**

---

## Roadmap

### Phase 1: Minimal Boot ✅ COMPLETE
- [x] Strip Containerfile to minimal
- [x] Boot on Asahi hardware (M1)
- [x] Network, audio, display working
- [x] SSH + Tailscale accessible
- [x] Document package set

### Phase 2: Formless Integration ✅ COMPLETE
- [x] Formless binary runs on substrate
- [x] Formless detects Podman runtime
- [x] Boot directly to Formless TUI (no login prompt) - IMPLEMENTED
  - Created `formless.target` as default boot target
  - Updated `formless.service` to run dashboard on tty1 with TTY output
  - Created `formless-boot.sh` wrapper (starts daemon then dashboard)
  - Disabled getty@tty1, kept getty@tty2 as emergency fallback
  - Added proper service ordering (first-boot → formless.service)
  - TTY allocation and cursor management configured
- [x] formless.service as default target (via formless.target)
- [x] Substrate Bridge command infrastructure added
  - New `formless substrate` command group
  - Implemented: config, service, network, audio, power, display, update subcommands
  - Full help text and examples for all commands
  - Stubs ready for Phase 4 backend implementation
- [ ] Test agent spawning (requires hardware deployment)
  - Verify `formless spawn <image>` works from TUI
  - Test container lifecycle (create, run, cleanup)
  - Verify Podman integration with daemon running
  - Document any issues with TTY-based agent interaction

### Phase 3: Boot Experience
- [ ] Plymouth splash screen (clean boot)
- [ ] Large console font in initramfs
- [ ] Boot time < 15 seconds
- [ ] Silent kernel messages

### Phase 4: Formless System Integration
- [ ] `formless config` commands for system settings
- [ ] `formless service` wrapper for systemctl
- [ ] `formless network` for WiFi/Tailscale
- [ ] `formless update` for bootc upgrades

### Phase 5: Display Evolution
Three options under consideration:
- **Option A** (Current): TTY/Console mode
- **Option B**: cage (minimal Wayland) → Formless as client
- **Option C**: Formless as compositor (Smithay-based)

### Phase 6: Production Hardening
- [ ] Security audit
- [ ] Recovery mechanism (rollback)
- [ ] OTA update testing
- [ ] Documentation for external users

---

## Formless ↔ Substrate Bridge

This is **Phase 7** of the Formless Kernel roadmap. The bridge enables:

### System Management Commands

```bash
# Console & Display
formless config font <small|medium|large|huge>
formless config boot <quiet|verbose|debug>
formless config splash <theme>

# Services
formless service <name> <start|stop|restart|status|enable|disable>

# Network
formless network wifi connect <ssid>
formless network wifi list
formless network tailscale status
formless network tailscale up

# Updates
formless update              # bootc upgrade wrapper
formless update --check      # check for updates
formless rollback            # boot previous deployment

# Hardware (Apple Silicon)
formless audio status        # speakersafetyd check
formless power <performance|balanced|powersave>
formless display brightness <0-100>
```

### Architecture

```
┌─────────────────────────────────────┐
│         FORMLESS KERNEL             │
│  ┌─────────────────────────────┐   │
│  │     Substrate Bridge        │   │  ← New crate
│  │  - SystemdClient            │   │
│  │  - NetworkClient            │   │
│  │  - BootcClient              │   │
│  │  - HardwareClient           │   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│         SUBSTRATE (Linux)           │
│    systemd, NetworkManager,         │
│    bootc, /sys, /proc               │
└─────────────────────────────────────┘
```

---

## Technical Decisions

### Why Fedora Asahi bootc?

| Consideration | GNOME OS | Fedora Asahi bootc |
|--------------|----------|-------------------|
| Apple Silicon | ❌ Generic ARM64 | ✅ Full support |
| Production ready | ❌ Dev only | ✅ Production |
| Speaker safety | ❌ No | ✅ speakersafetyd |
| GPU drivers | ❌ No Asahi | ✅ Mesa Asahi |
| Build system | BuildStream (complex) | Containerfile (familiar) |
| Community | None for M1 | Active Asahi + Fedora |

### Package Management Strategy

| Layer | Tool | Mutability |
|-------|------|------------|
| System | OSTree | Immutable (baked at build) |
| User tools | Homebrew | Mutable (/home/linuxbrew) |
| Apps | Podman | Ephemeral containers |

### Display Strategy

Current: **TTY/Console mode** - simplest, works now

Future options:
1. **cage** - Minimal Wayland compositor, Formless as client
2. **Smithay** - Formless becomes the compositor itself
3. **Direct DRM** - TUI-only, maximum performance

---

## Current Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Podman not found | Homebrew binary hardcodes PATH | Rebuilt from source with `/usr/bin/podman` |
| Password login fails | systemd-sysusers uses `!*` not `!` | Fixed sed pattern in Containerfile |
| Boot text scrolling | No quiet params | Added to boot entries + Containerfile |
| Font changes mid-boot | vconsole.conf loads late | Need Plymouth or initramfs font |
| Kernel cmdline ignored | bootc needs deployment cycle | Edit boot entries directly for now |

---

## The Moonshot Vision

From the Formless strategic documents:

> "The operating system for AI agents, as foundational as Linux was for servers."

Substrate + Formless together represent a new paradigm:
- **Local-first**: Your hardware, your data, your agents
- **Self-improving**: Agents can improve the system itself
- **Biological architecture**: Endocrine, immune, social systems
- **Privacy paramount**: Therapy/personal stays local
- **User control**: Not cloud-dependent

The full stack vision:
```
User owns hardware
    → Immutable Linux (Substrate)
        → Agentic Orchestration (Formless)
            → Personal AI agents executing safely
```

---

---

## Implementation Details: Phase 2-4

### Phase 2: Formless Integration (Continuing)

**Status:** ~70% complete

**Remaining Tasks:**
1. **Test Agent Spawning** (Current)
   - Create test container to verify `formless spawn` works
   - Verify Podman socket is accessible to formless service
   - Test long-running agents and cleanup
   - Document TTY interaction model for agents

2. **Documentation**
   - Update boot flow documentation
   - Document new formless.target and boot sequence
   - Note changes to getty configuration

**Blockers:** None identified

**Next:** Move to Phase 3 once agent spawning confirmed working

---

### Phase 3: Boot Experience (Planning)

**Goal:** Achieve <15 second boot, clean visual experience

**Tasks:**
1. **Plymouth Integration**
   - Complete research from BOOT_VISUAL_HANDOFF.md
   - Determine if mystery Fedora spinner can be disabled
   - Implement custom splash screen or none
   - Rebuild initramfs if needed

2. **Boot Time Optimization**
   - Profile current boot with `systemd-analyze`
   - Identify slow services and optimize
   - Target: <15 seconds (currently ~11.9s, so good)
   - Parallel start services where possible

3. **Silent Boot**
   - Verify kernel quiet parameters working
   - Remove scrolling text
   - Smooth transition to Formless TUI
   - Hide all boot messages

**Current State:** Boot time is already good (11.93s). Boot visuals need research.

---

### Phase 4: Formless System Integration

**Goal:** Enable system management from Formless CLI

**Architecture:**
```
formless config     → Console/boot/display settings
formless service    → systemctl wrapper
formless network    → NetworkManager/Tailscale
formless audio      → PipeWire/speaker safety
formless power      → CPU governor / battery
formless display    → Brightness / resolution
formless update     → bootc wrapper
```

**Implementation Steps:**

1. **Create Substrate Bridge Crate** (in formless-kernel)
   - New crate: `formless-substrate`
   - Provides clients for: SystemdClient, NetworkClient, BootcClient, HardwareClient
   - Handle privilege escalation (sudo or polkit)
   - Thread-safe IPC to system services

2. **Implement Config Commands**
   ```rust
   // formless config font <size>
   // Edit /etc/vconsole.conf, run setfont

   // formless config boot <quiet|verbose|debug>
   // Edit /boot/loader/entries/*.conf kernel options

   // formless config splash <theme|off>
   // plymouth-set-default-theme + dracut rebuild
   ```

3. **Implement Service Commands** (wraps systemctl)
   ```rust
   formless service list
   formless service status <name>
   formless service start|stop|restart <name>
   formless service enable|disable <name>
   formless service logs <name>
   ```

4. **Implement Network Commands** (nmcli + tailscale)
   ```rust
   formless network status
   formless network wifi list|connect|disconnect
   formless network tailscale status|up|down
   ```

5. **Implement Update Commands** (bootc wrapper)
   ```rust
   formless update [--check]
   formless rollback [--list]
   ```

6. **Implement Audio Commands** (PipeWire + speaker safety)
   ```rust
   formless audio status        # Check speaker protection
   formless audio volume <0-100>
   formless audio mute|unmute
   ```

7. **Implement Power Commands**
   ```rust
   formless power status
   formless power mode <performance|balanced|powersave>
   formless power sleep|shutdown|reboot
   ```

8. **Implement Display Commands** (backlight + DRM)
   ```rust
   formless display brightness <0-100>
   formless display brightness up|down
   ```

**Privilege Model:**
- Start with: `sudo` prompts for privileged operations
- Migrate to: polkit rules for seamless UX
- Rules: Allow formless user specific actions without password
- Sensitive operations: require manual sudo prompt (updates, power)

**Testing Requirements:**
- Each command must work from Formless TUI
- All commands must be idempotent
- Configuration must survive reboot
- Error handling for missing dependencies

---

## Next Actions

### Immediate (This Session)
1. Add Plymouth to Containerfile for clean boot
2. Implement quiet boot in initramfs
3. Test boot sequence

### Short Term (This Week)
1. Boot directly to Formless (no login prompt)
2. Implement basic `formless config` commands
3. Reduce image size

### Medium Term (This Month)
1. Substrate Bridge crate in formless-kernel
2. Full system management via Formless
3. Wayland compositor evaluation

### Long Term (Q2 2026)
1. Phase 7 Substrate Bridge complete
2. Sub-15-second boot
3. First external users
