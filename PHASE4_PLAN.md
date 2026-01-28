# Phase 4 Implementation Plan: System Command Backends

**Status:** Ready for Implementation
**Date:** January 28, 2026
**Target:** Implement complete backend logic for the Substrate Bridge command infrastructure

---

## Executive Summary

Phase 4 focuses on implementing the backend logic for the Substrate Bridge command infrastructure. The command framework (`formless substrate`) already exists with complete CLI parsing and help text from Phase 2. Phase 4 involves:

1. **System Command Backends** - Implement actual systemctl/nmcli/bootc wrappers
2. **Health Monitoring Framework** - systemd-integrated health checks and recovery
3. **Privilege Escalation Model** - sudo prompts and polkit rules
4. **Cgroup Resource Management** - Process isolation and limits
5. **Testing & Validation** - Integration and performance tests

---

## Current State (Post-Phase 3)

**Completed:**
- Direct Formless TUI boot (no login prompt)
- formless.target as default boot target
- formless.service running on tty1
- Command framework with CLI parsing (substrate.rs - 620 lines)
- 7 command categories with full help text
- Boot chain research completed
- Hardware deployment infrastructure ready

**Status:**
- Boot time: 11.93s (exceeds <15s target)
- SSH: Operational
- Plymouth/BGRT: Identified as boot visual sources
- All command stubs return "coming in Phase 4" messages

---

## Backend Crates Structure

```
formless-kernel/crates/
├── formless-cli/src/substrate.rs          ← Router (already exists)
├── formless-substrate-backends/           ← NEW (parent crate)
│   ├── src/lib.rs                         ← Exports all backends
│   ├── src/service.rs                     ← systemctl wrapper
│   ├── src/network.rs                     ← nmcli/iwd wrapper
│   ├── src/audio.rs                       ← PipeWire/pactl wrapper
│   ├── src/power.rs                       ← CPU governor/suspend
│   ├── src/display.rs                     ← Backlight/resolution
│   ├── src/update.rs                      ← bootc wrapper
│   ├── src/config.rs                      ← /etc config management
│   ├── src/health.rs                      ← Health monitoring
│   ├── src/privilege.rs                   ← Sudo/polkit integration
│   ├── src/cgroup.rs                      ← Resource limits
│   └── Cargo.toml
└── formless-cli/src/
    └── substrate.rs                        ← Update to use backends
```

---

## Backend Command Categories

### 1. Service Management
- `list` - List all system services
- `status <name>` - Check service status
- `start <name>` - Start service (with privilege check)
- `stop <name>` - Stop service (with privilege check)
- `restart <name>` - Restart service
- `enable <name>` - Enable at boot
- `disable <name>` - Disable at boot
- `logs <name>` - View service logs (with -n and -f options)

**Implementation:** Use `systemctl show --json` for JSON parsing, `journalctl --json` for structured logging, cache service list with 10-second TTL.

### 2. Network Management
**WiFi commands:**
- `status` - Show network status
- `wifi list` - List available networks (call nmcli)
- `wifi connect <ssid>` - Connect with password prompt
- `wifi disconnect` - Disconnect
- `wifi saved` - List saved networks
- `wifi forget <ssid>` - Remove saved network

**Tailscale commands:**
- `tailscale status` - Show Tailscale status
- `tailscale up` - Connect to Tailscale
- `tailscale down` - Disconnect
- `tailscale ip` - Show assigned IP

**Implementation:** Use `nmcli` for WiFi (NetworkManager CLI), use `tailscale` CLI for Tailscale operations, parse JSON output.

### 3. Audio Management
- `status` - Speaker protection status + volume
- `volume <0-100>` - Set volume level
- `mute` - Mute audio
- `unmute` - Unmute audio
- `devices` - List audio devices
- `output <device>` - Set output device

**CRITICAL: Speaker Protection** - Verify speakersafetyd is running before any audio operations.

### 4. Power Management
- `status` - Battery/AC status, current mode
- `mode <performance|balanced|powersave>` - Set CPU governor
- `sleep` - Suspend system
- `reboot` - Reboot (with privilege escalation)
- `shutdown` - Shutdown (with privilege escalation)

### 5. Display Management
- `brightness <0-100|up|down>` - Control backlight
- `resolution` - Get current resolution
- `set-resolution <WIDTHxHEIGHT>` - Change resolution

### 6. System Updates
- `check` - Check for available updates
- `apply` - Apply pending update (requires reboot)
- `changelog` - Show update changelog
- `rollback` - Revert to previous deployment

**Implementation:** Use `bootc status --json` for update checking, call `sudo bootc upgrade` for applying updates.

### 7. Configuration
- `font <small|medium|large|huge>` - Change console font size
- `boot <quiet|normal|verbose|debug>` - Set boot verbosity
- `splash <theme|off>` - Configure Plymouth splash

---

## Privilege Escalation Model

### Privilege Methods

1. **Sudo** - For most system operations
   - Prompt user for password
   - Use stdin password input (`sudo -S`)
   - Timeout: 30 seconds

2. **Polkit** - For desktop/system operations
   - Register rules in `/usr/share/polkit-1/rules.d/`
   - Call `pkexec` for privileged operations
   - Allow formless user certain capabilities without prompt

3. **Direct** - No escalation needed
   - Operations already permitted for current user

### Polkit Rules Configuration

Create rules file: `/usr/share/polkit-1/rules.d/formless-substrate.rules`

```
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" ||
        action.id == "org.freedesktop.systemd1.manage-unit-files" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.reboot") {
        if (subject.user == "formless") {
            return polkit.Result.AUTH_ADMIN_KEEP;
        }
    }
});
```

---

## Health Monitoring Framework

Health checks for critical services:

```rust
pub trait HealthCheck: Send + Sync {
    async fn check(&self) -> Result<HealthStatus>;
    fn metric_name(&self) -> &str;
    fn recovery_command(&self) -> Option<&str>;
}

pub struct HealthStatus {
    pub service: String,
    pub status: ServiceState,
    pub health: HealthLevel,
    pub last_checked: SystemTime,
    pub message: String,
}

pub enum ServiceState {
    Running,
    Stopped,
    Failed,
    Restarting,
    Unknown,
}

pub enum HealthLevel {
    Healthy,
    Degraded,
    Critical,
}
```

**Services to monitor:**
- NetworkManager (network connectivity)
- Tailscaled (VPN status)
- PipeWire (audio system)
- speakersafetyd (speaker protection)
- systemd-resolved (DNS)
- firewalld (firewall status)

---

## Cgroup Resource Management

Implement resource limits for services:

```rust
pub struct CgroupManager {
    cgroup_v2_path: PathBuf,
}

impl CgroupManager {
    pub async fn set_memory_limit(&self, service: &str, limit_mb: u64) -> Result<()>;
    pub async fn set_cpu_quota(&self, service: &str, quota_percent: u8) -> Result<()>;
    pub async fn get_resource_usage(&self, service: &str) -> Result<ResourceUsage>;
}

pub struct ResourceUsage {
    pub memory_used_mb: u64,
    pub cpu_percent: f32,
    pub pid_count: usize,
}
```

**Use cases:**
- Limit formless.target processes to prevent resource exhaustion
- Monitor memory usage during command execution
- Track CPU usage for performance optimization

---

## Testing Strategy

### Unit Tests
Location: `formless-substrate-backends/tests/`

```rust
// Service backend tests
#[tokio::test]
async fn test_list_services() {
    let backend = ServiceBackend::new();
    let services = backend.list_services().await.unwrap();
    assert!(!services.is_empty());
}

// Audio safety tests (CRITICAL)
#[tokio::test]
async fn test_speaker_safety_check() {
    let backend = AudioBackend::new();
    let status = backend.status().await.unwrap();
    assert_eq!(status.speaker_safe, true);
}

// Privilege tests
#[tokio::test]
async fn test_privilege_check() {
    let handler = PrivilegeHandler::new();
    let can_escalate = handler.check_capability("reboot").await.unwrap();
    assert!(can_escalate);
}
```

### Integration Tests
Location: `scripts/phase4/integration-tests.sh`

Test all commands end-to-end:
- Service commands (list, status, start, stop)
- Network commands (WiFi, Tailscale)
- Audio commands with speaker protection
- Power commands (sleep, reboot)
- Display commands
- Update commands
- Privilege escalation prompts

### Performance Tests
Measure boot time impact:
- Before: systemd-analyze with backend stubs
- After: systemd-analyze with real backends
- Target: <100ms additional overhead
- Backends are lazy-loaded on first command, not at boot

---

## Implementation Timeline

| Phase | Work | Estimated Duration |
|-------|------|-------------------|
| 4a | Backend infrastructure + traits | 2-3 days |
| 4b | Service backend implementation | 2 days |
| 4c | Network backend | 1.5 days |
| 4d | Audio + Power + Display | 2 days |
| 4e | Update backend | 1 day |
| 4f | Privilege escalation model | 1.5 days |
| 4g | Testing + integration | 2 days |
| 4h | Hardware deployment + validation | 2 days |
| **Total** | | **14-15 days** |

---

## Deployment Strategy

### Phase 4a: Container Build & Registry
1. Build formless-substrate-backends crate
2. Update formless-cli to import backends
3. Build container with new binaries
4. Push to ghcr.io/ericrowan/asahi-substrate:phase4

### Phase 4b: Hardware Deployment
1. SSH to M1 hardware (192.168.8.114)
2. Run: `sudo bootc switch ghcr.io/ericrowan/asahi-substrate:phase4`
3. Observe boot sequence
4. Test commands from TUI

### Phase 4c: Integration Testing
1. Run service commands from TUI
2. Verify privilege escalation works
3. Test network commands (WiFi, Tailscale)
4. Verify audio status reports correctly
5. Test power/reboot commands

---

## Success Criteria

| Criterion | Target | Validation |
|-----------|--------|-----------|
| All commands functional | 100% | All 28 commands work from TUI |
| Privilege escalation | Seamless | sudo prompts work, no errors |
| Boot time impact | <100ms added | systemd-analyze before/after |
| Health checks | Passing | systemctl is-active for all services |
| Audio safety | Never violated | Speaker protection never bypassed |
| Error handling | Graceful | All failures produce helpful messages |
| Documentation | Complete | All commands have --help and examples |

---

## Critical Implementation Details

### Speaker Safety (Audio Backend)
The speaker protection system (speakersafetyd) must NEVER be disabled:

```rust
pub struct SpeakerSafetyMonitor;

impl SpeakerSafetyMonitor {
    pub async fn verify_running(&self) -> Result<()> {
        // Check: systemctl is-active speakersafetyd
        // If not running: attempt restart
        // If restart fails: ERROR - refuse audio operations
        // This is NON-NEGOTIABLE for hardware safety
    }
}
```

### Boot Chain Integration
- Backends are lazy-loaded (not at boot time)
- formless.service starts cleanly without backend initialization
- Commands trigger backend loading on first use
- Boot time impact should be <100ms

### Error Handling
All backends must:
- Return meaningful error messages
- Suggest remediation steps
- Log errors to journalctl
- Never cause system crashes
- Timeout long-running operations (default: 30s)

---

## Dependencies & Integration Points

**External tools required:**
- systemd/systemctl (already in base)
- NetworkManager + nmcli (already in base)
- Tailscale CLI (already in base)
- PipeWire + pactl (already in base)
- bootc (already in base)
- sudo (already in base)
- polkit (needs to be added to Containerfile)

**Formless crates to update:**
- formless-cli (substrate.rs + main.rs)
- NEW: formless-substrate-backends

**System files to create:**
- /usr/share/polkit-1/rules.d/formless-substrate.rules
- /etc/systemd/user.conf (privilege config)

---

## Next Steps After Phase 4

**Phase 5:** Display Evolution
- Explore cage (minimal Wayland compositor)
- Formless as Wayland client
- Or: Formless as Smithay-based compositor

**Phase 6:** Production Hardening
- Security audit
- Recovery mechanisms
- OTA update testing

**Phase 7:** External User Documentation
- Installation guide
- Command reference
- Troubleshooting guide

---

## Conclusion

Phase 4 provides a complete roadmap for implementing production-ready system command backends while maintaining the safety-first philosophy (especially for audio) and integrating cleanly with systemd/bootc infrastructure.

The modular architecture ensures:
- Each backend can be developed independently
- Easy testing of individual subsystems
- Clear privilege boundaries
- Graceful error handling
- Minimal boot time impact

All Phase 3 investigation findings have been incorporated into this plan, particularly the boot chain analysis showing disk I/O as the primary bottleneck and the confirmation that Plymouth BGRT is handling the boot splash rendering.

**Ready to proceed with Phase 4 implementation!**
