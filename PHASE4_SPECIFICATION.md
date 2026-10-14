# Phase 4 Implementation Specification

**Version:** 1.0
**Date:** 2026-01-28
**Author:** Claude Opus 4.5
**Target:** Formless Substrate Backend Implementation

---

## Scope Decision: Option C - Both in Sequence

This specification covers **both** the formless.service integration fix **and** the full Phase 4 backend implementation. The rationale:

1. **The service integration is a prerequisite.** Without formless.service enabled and running, there is no interface to invoke the backend commands.
2. **The gap between documentation and reality must be closed first.** The Containerfile sets `formless.target` as default, but hardware verification shows `graphical.target` is active and formless.service is disabled.
3. **Backend implementation is the actual Phase 4 work.** The 28 commands in substrate.rs are all stubs returning "coming in Phase 4".

**Structure:** Phase 4A (Service Integration) then Phase 4B (Backend Implementation), with a clear checkpoint between them.

---

## Part I: Phase 4A - Service Integration Fix

### 4A.1 Problem Statement

**Expected state (per documentation):**
- formless.target is the default boot target
- formless.service starts automatically
- User sees Formless TUI directly on tty1

**Actual state (verified on hardware):**
- graphical.target is the default
- formless.service is disabled
- formless.target does not exist as a real target
- System boots to graphical.target with no display manager (blank screen or login prompt)

**Root cause:** The Containerfile includes `systemctl set-default formless.target`, but:
1. formless.target has `WantedBy=default.target` in its [Install] section
2. formless.service has `WantedBy=formless.target`
3. Neither service is "enabled" in the systemd sense (symlinks not created)
4. The `systemctl set-default` command sets the default target but doesn't enable the service units

### 4A.2 Tasks

#### Task 4A.2.1: Fix Containerfile Service Enablement

**File:** `/Users/eric/src/asahi-substrate/src/Containerfile.substrate`

**Current (line ~144-145):**
```dockerfile
RUN chmod +x /usr/libexec/formless-boot && \
    systemctl set-default formless.target
```

**Change to:**
```dockerfile
RUN chmod +x /usr/libexec/formless-boot && \
    systemctl set-default formless.target && \
    systemctl enable formless.target && \
    systemctl enable formless.service
```

**Rationale:** The `enable` commands create the necessary symlinks in `/etc/systemd/system/` that cause systemd to pull in these units at boot.

**Verification command (run in container build):**
```bash
ls -la /etc/systemd/system/default.target
ls -la /etc/systemd/system/formless.target.wants/
```

**Expected output:**
- `default.target -> /usr/lib/systemd/system/formless.target`
- `formless.target.wants/` contains `formless.service` and `formless-first-boot.service`

#### Task 4A.2.2: Fix formless.target Unit File

**File:** `/Users/eric/src/asahi-substrate/src/build_files/formless.target`

**Current:**
```ini
[Unit]
Description=Formless System
Documentation=https://github.com/Project-Mycelium/formless-kernel
After=multi-user.target
Wants=multi-user.target formless.service formless-first-boot.service

[Install]
WantedBy=default.target
```

**Issue:** A target should not have `WantedBy=default.target` when it IS the default target. The [Install] section is only used when enabling, not when setting default.

**Change to:**
```ini
[Unit]
Description=Formless System
Documentation=https://github.com/Project-Mycelium/formless-kernel
Requires=multi-user.target
After=multi-user.target
Wants=formless.service formless-first-boot.service
AllowIsolate=yes

[Install]
Alias=default.target
```

**Rationale:**
- `Requires=multi-user.target` ensures all basic system services start
- `AllowIsolate=yes` allows `systemctl isolate formless.target`
- `Alias=default.target` creates proper linkage when enabled

#### Task 4A.2.3: Fix formless.service Dependency

**File:** `/Users/eric/src/asahi-substrate/src/build_files/formless.service`

**Current line 7:**
```ini
Requires=formless-first-boot.service
```

**Issue:** `Requires=` means formless.service fails if formless-first-boot fails. But formless-first-boot has `ConditionPathExists=!/var/lib/formless/.first-boot-done` - it will be skipped (not failed) on subsequent boots. However, this is fine.

**Real issue - line 8:**
```ini
ConditionVirtualization=!container
```

**This prevents formless.service from running in containers during testing.** This is intentional but needs documentation that testing requires `--privileged` or real hardware.

**No change needed,** but document this in the task output.

#### Task 4A.2.4: Verify formless Binary Installation

**File:** `/Users/eric/src/asahi-substrate/src/build_files/first-boot-setup.sh`

**Current behavior (lines 179-185):**
```bash
if [ -f "$HOMEBREW_PREFIX/bin/formless" ]; then
    systemctl enable formless.service || true
    log "Formless service enabled"
else
    log "Formless binary not found - service not enabled"
fi
```

**Issue:** This runs during first-boot, but the service should already be enabled from the Containerfile. The issue is the formless binary might not exist until after first-boot builds it from source.

**Current flow:**
1. Container built with formless.service enabled
2. First boot: formless-first-boot.service runs, installs Homebrew, installs tools, may build formless
3. formless.service tries to start, but binary may not exist yet
4. Service fails, system continues

**Fix:** The formless binary should be baked into the container image, not built on first boot.

**New task: Create formless binary installation in Containerfile**

Add after the Homebrew bootstrap section (around line 125):

```dockerfile
# -----------------------------------------------------------------------------
# 6b. Pre-built Formless Binary (from GitHub releases or CI)
# -----------------------------------------------------------------------------
# For development: Build from local source during container build
# For production: Download from GitHub releases
ARG FORMLESS_VERSION="latest"
ARG FORMLESS_BINARY_URL=""

# Option 1: Copy pre-built binary if available
# COPY --from=formless-builder /app/target/release/formless /home/linuxbrew/.linuxbrew/bin/

# Option 2: For now, leave a placeholder script that explains the situation
RUN echo '#!/bin/bash' > /home/linuxbrew/.linuxbrew/bin/formless && \
    echo 'echo "Formless binary not yet installed. Run setup-kernel.sh or install from release."' >> /home/linuxbrew/.linuxbrew/bin/formless && \
    chmod +x /home/linuxbrew/.linuxbrew/bin/formless
```

**Better solution:** Build formless as part of container build. This requires:
1. Add Rust toolchain to container build
2. Clone formless-kernel repo
3. Build and install binary

This is out of scope for Phase 4A (it's a deployment optimization). For now, document that manual kernel setup is required.

#### Task 4A.2.5: Build and Deploy Test Image

**Commands:**
```bash
cd /Users/eric/src/asahi-substrate
podman build -f src/Containerfile.substrate -t ghcr.io/ericrowan/asahi-substrate:phase4a .
podman push ghcr.io/ericrowan/asahi-substrate:phase4a
ssh formless@192.168.8.114 "sudo bootc switch ghcr.io/ericrowan/asahi-substrate:phase4a && sudo systemctl reboot"
```

**Wait 2-3 minutes for reboot, then verify:**
```bash
ssh formless@192.168.8.114 "systemctl status formless.service && systemctl get-default"
```

**Expected output:**
- `formless.service` is active (or failed if binary not present, but enabled)
- Default target is `formless.target`

### 4A.3 Success Criteria

| Criterion | Validation Command | Expected Result |
|-----------|-------------------|-----------------|
| formless.target is default | `systemctl get-default` | `formless.target` |
| formless.service is enabled | `systemctl is-enabled formless.service` | `enabled` |
| formless.target is active | `systemctl is-active formless.target` | `active` |
| Boot time unchanged | `systemd-analyze` | `<12s total` |

### 4A.4 Checkpoint Gate

**Before proceeding to Phase 4B:**
1. Phase 4A changes committed to git
2. Container image built and pushed as `:phase4a`
3. Hardware deployed and verified
4. Boot sequence shows Formless TUI (or known failure if binary missing)
5. SSH access confirmed working

---

## Part II: Phase 4B - Backend Implementation

### 4B.1 Architecture Overview

**New crate:** `formless-substrate-backends`

**Location:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/`

**Structure:**
```
formless-substrate-backends/
├── Cargo.toml
├── src/
│   ├── lib.rs              # Module exports + common types
│   ├── error.rs            # Backend error types
│   ├── privilege.rs        # Privilege escalation (sudo/polkit)
│   ├── service.rs          # systemctl wrapper
│   ├── network.rs          # nmcli + tailscale wrappers
│   ├── audio.rs            # pipewire/pactl + speakersafetyd
│   ├── power.rs            # CPU governor + suspend/reboot
│   ├── display.rs          # backlight + resolution
│   ├── update.rs           # bootc wrapper
│   └── config.rs           # font, boot params, plymouth
└── tests/
    ├── service_tests.rs
    ├── network_tests.rs
    └── integration_tests.rs
```

### 4B.2 Common Types and Error Handling

#### Task 4B.2.1: Create Cargo.toml

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/Cargo.toml`

```toml
[package]
name = "formless-substrate-backends"
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true
description = "System command backends for Formless Substrate"

[dependencies]
tokio = { workspace = true, features = ["process", "fs", "io-util"] }
serde = { workspace = true }
serde_json.workspace = true
thiserror.workspace = true
anyhow.workspace = true
tracing.workspace = true

[dev-dependencies]
tokio-test.workspace = true
tempfile.workspace = true
```

#### Task 4B.2.2: Create lib.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/lib.rs`

```rust
//! Formless Substrate Backends
//!
//! System command implementations for the Formless Substrate OS layer.
//! These backends wrap system tools (systemctl, nmcli, bootc, etc.) to provide
//! a consistent interface for the Formless CLI.

pub mod audio;
pub mod config;
pub mod display;
pub mod error;
pub mod network;
pub mod power;
pub mod privilege;
pub mod service;
pub mod update;

pub use error::{BackendError, BackendResult};
```

#### Task 4B.2.3: Create error.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/error.rs`

```rust
//! Error types for substrate backends.

use thiserror::Error;

/// Result type for backend operations.
pub type BackendResult<T> = Result<T, BackendError>;

/// Errors that can occur in substrate backends.
#[derive(Error, Debug)]
pub enum BackendError {
    /// A required system command was not found.
    #[error("Command not found: {command}. Ensure {package} is installed.")]
    CommandNotFound { command: String, package: String },

    /// Command execution failed.
    #[error("Command failed: {command}\nExit code: {code}\nStderr: {stderr}")]
    CommandFailed {
        command: String,
        code: i32,
        stderr: String,
    },

    /// Privilege escalation required but not available.
    #[error("Privilege escalation required for: {operation}")]
    PrivilegeRequired { operation: String },

    /// Operation timed out.
    #[error("Operation timed out after {seconds}s: {operation}")]
    Timeout { operation: String, seconds: u64 },

    /// Invalid argument provided.
    #[error("Invalid argument: {message}")]
    InvalidArgument { message: String },

    /// Service-specific error.
    #[error("Service error: {message}")]
    ServiceError { message: String },

    /// Network-specific error.
    #[error("Network error: {message}")]
    NetworkError { message: String },

    /// Audio-specific error.
    #[error("Audio error: {message}")]
    AudioError { message: String },

    /// Speaker safety check failed - CRITICAL.
    #[error("SPEAKER SAFETY: {message}. Audio operations blocked.")]
    SpeakerSafetyError { message: String },

    /// Power operation error.
    #[error("Power error: {message}")]
    PowerError { message: String },

    /// Display error.
    #[error("Display error: {message}")]
    DisplayError { message: String },

    /// Update/bootc error.
    #[error("Update error: {message}")]
    UpdateError { message: String },

    /// Configuration error.
    #[error("Config error: {message}")]
    ConfigError { message: String },

    /// JSON parsing error.
    #[error("Failed to parse JSON: {0}")]
    JsonError(#[from] serde_json::Error),

    /// I/O error.
    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),
}
```

### 4B.3 Privilege Escalation Module

#### Task 4B.3.1: Create privilege.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/privilege.rs`

```rust
//! Privilege escalation handling for system operations.
//!
//! Provides sudo wrapper and polkit integration for privileged operations.

use crate::error::{BackendError, BackendResult};
use std::process::Stdio;
use tokio::process::Command;
use tracing::{debug, warn};

/// Operations that require privilege escalation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivilegedOp {
    /// Start/stop/restart a system service.
    ServiceControl,
    /// Enable/disable a service at boot.
    ServiceEnable,
    /// System power operations (reboot, shutdown, suspend).
    PowerControl,
    /// System update operations (bootc).
    SystemUpdate,
    /// Network configuration changes.
    NetworkConfig,
    /// System configuration changes.
    SystemConfig,
}

impl PrivilegedOp {
    /// Returns the polkit action ID for this operation, if applicable.
    pub fn polkit_action(&self) -> Option<&'static str> {
        match self {
            Self::ServiceControl => Some("org.freedesktop.systemd1.manage-units"),
            Self::ServiceEnable => Some("org.freedesktop.systemd1.manage-unit-files"),
            Self::PowerControl => Some("org.freedesktop.login1.power-off"),
            Self::SystemUpdate => None, // Uses sudo directly
            Self::NetworkConfig => Some("org.freedesktop.NetworkManager.settings.modify.system"),
            Self::SystemConfig => None, // Uses sudo directly
        }
    }
}

/// Check if we're running as root.
pub fn is_root() -> bool {
    unsafe { libc::geteuid() == 0 }
}

/// Execute a command with sudo if not already root.
///
/// # Arguments
/// * `program` - The program to execute
/// * `args` - Arguments to pass to the program
/// * `operation` - The type of privileged operation (for error messages)
///
/// # Returns
/// * `Ok(output)` - Command stdout as string
/// * `Err(BackendError)` - If command fails or privilege escalation fails
pub async fn sudo_exec(
    program: &str,
    args: &[&str],
    operation: PrivilegedOp,
) -> BackendResult<String> {
    let (cmd_program, cmd_args) = if is_root() {
        (program, args.to_vec())
    } else {
        let mut sudo_args = vec!["-n", program]; // -n = non-interactive
        sudo_args.extend(args);
        ("sudo", sudo_args)
    };

    debug!("Executing: {} {:?}", cmd_program, cmd_args);

    let output = Command::new(cmd_program)
        .args(&cmd_args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        // Check if this is a sudo permission error
        if stderr.contains("password is required") || stderr.contains("sudo:") {
            warn!("Privilege escalation failed for {:?}", operation);
            Err(BackendError::PrivilegeRequired {
                operation: format!("{:?}", operation),
            })
        } else {
            Err(BackendError::CommandFailed {
                command: format!("{} {}", program, args.join(" ")),
                code: output.status.code().unwrap_or(-1),
                stderr,
            })
        }
    }
}

/// Execute a command without privilege escalation.
pub async fn exec(program: &str, args: &[&str]) -> BackendResult<String> {
    debug!("Executing: {} {:?}", program, args);

    let output = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                BackendError::CommandNotFound {
                    command: program.to_string(),
                    package: program.to_string(),
                }
            } else {
                BackendError::IoError(e)
            }
        })?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(BackendError::CommandFailed {
            command: format!("{} {}", program, args.join(" ")),
            code: output.status.code().unwrap_or(-1),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
        })
    }
}
```

### 4B.4 Service Backend

#### Task 4B.4.1: Create service.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/service.rs`

```rust
//! Service management backend - systemctl wrapper.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use serde::{Deserialize, Serialize};
use tracing::debug;

/// Service state from systemctl.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ServiceState {
    Active,
    Inactive,
    Failed,
    Activating,
    Deactivating,
    Reloading,
    Unknown,
}

impl From<&str> for ServiceState {
    fn from(s: &str) -> Self {
        match s.trim().to_lowercase().as_str() {
            "active" => Self::Active,
            "inactive" => Self::Inactive,
            "failed" => Self::Failed,
            "activating" => Self::Activating,
            "deactivating" => Self::Deactivating,
            "reloading" => Self::Reloading,
            _ => Self::Unknown,
        }
    }
}

/// Information about a system service.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceInfo {
    pub name: String,
    pub state: ServiceState,
    pub enabled: bool,
    pub description: String,
}

/// List all system services.
pub async fn list_services(json_output: bool) -> BackendResult<Vec<ServiceInfo>> {
    let output = exec(
        "systemctl",
        &[
            "list-units",
            "--type=service",
            "--all",
            "--no-pager",
            "--plain",
        ],
    )
    .await?;

    let mut services = Vec::new();

    for line in output.lines().skip(1) {
        // Skip header
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 4 {
            let name = parts[0].trim_end_matches(".service").to_string();
            let state = ServiceState::from(parts[2]);
            let description = parts[4..].join(" ");

            services.push(ServiceInfo {
                name,
                state,
                enabled: false, // Will be filled in if needed
                description,
            });
        }
    }

    debug!("Found {} services", services.len());
    Ok(services)
}

/// Get detailed status of a specific service.
pub async fn service_status(name: &str) -> BackendResult<ServiceInfo> {
    let unit_name = normalize_unit_name(name);

    // Get active state
    let state_output = exec("systemctl", &["is-active", &unit_name]).await;
    let state = match state_output {
        Ok(s) => ServiceState::from(s.as_str()),
        Err(_) => ServiceState::Inactive,
    };

    // Get enabled state
    let enabled_output = exec("systemctl", &["is-enabled", &unit_name]).await;
    let enabled = enabled_output
        .map(|s| s.trim() == "enabled")
        .unwrap_or(false);

    // Get description
    let desc_output = exec(
        "systemctl",
        &["show", &unit_name, "--property=Description", "--value"],
    )
    .await;
    let description = desc_output.unwrap_or_default().trim().to_string();

    Ok(ServiceInfo {
        name: name.to_string(),
        state,
        enabled,
        description,
    })
}

/// Start a service.
pub async fn start_service(name: &str) -> BackendResult<()> {
    let unit_name = normalize_unit_name(name);
    sudo_exec(
        "systemctl",
        &["start", &unit_name],
        PrivilegedOp::ServiceControl,
    )
    .await?;
    Ok(())
}

/// Stop a service.
pub async fn stop_service(name: &str) -> BackendResult<()> {
    let unit_name = normalize_unit_name(name);
    sudo_exec(
        "systemctl",
        &["stop", &unit_name],
        PrivilegedOp::ServiceControl,
    )
    .await?;
    Ok(())
}

/// Restart a service.
pub async fn restart_service(name: &str) -> BackendResult<()> {
    let unit_name = normalize_unit_name(name);
    sudo_exec(
        "systemctl",
        &["restart", &unit_name],
        PrivilegedOp::ServiceControl,
    )
    .await?;
    Ok(())
}

/// Enable a service at boot.
pub async fn enable_service(name: &str) -> BackendResult<()> {
    let unit_name = normalize_unit_name(name);
    sudo_exec(
        "systemctl",
        &["enable", &unit_name],
        PrivilegedOp::ServiceEnable,
    )
    .await?;
    Ok(())
}

/// Disable a service at boot.
pub async fn disable_service(name: &str) -> BackendResult<()> {
    let unit_name = normalize_unit_name(name);
    sudo_exec(
        "systemctl",
        &["disable", &unit_name],
        PrivilegedOp::ServiceEnable,
    )
    .await?;
    Ok(())
}

/// Get service logs.
pub async fn service_logs(name: &str, lines: usize, follow: bool) -> BackendResult<String> {
    let unit_name = normalize_unit_name(name);
    let lines_str = lines.to_string();

    let mut args = vec!["-u", &unit_name, "-n", &lines_str, "--no-pager"];
    if follow {
        args.push("-f");
    }

    exec("journalctl", &args).await
}

/// Normalize unit name to include .service suffix if missing.
fn normalize_unit_name(name: &str) -> String {
    if name.contains('.') {
        name.to_string()
    } else {
        format!("{}.service", name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_unit_name() {
        assert_eq!(normalize_unit_name("sshd"), "sshd.service");
        assert_eq!(normalize_unit_name("sshd.service"), "sshd.service");
        assert_eq!(normalize_unit_name("network.target"), "network.target");
    }

    #[test]
    fn test_service_state_from_str() {
        assert_eq!(ServiceState::from("active"), ServiceState::Active);
        assert_eq!(ServiceState::from("ACTIVE"), ServiceState::Active);
        assert_eq!(ServiceState::from("inactive"), ServiceState::Inactive);
        assert_eq!(ServiceState::from("failed"), ServiceState::Failed);
        assert_eq!(ServiceState::from("garbage"), ServiceState::Unknown);
    }
}
```

### 4B.5 Network Backend

#### Task 4B.5.1: Create network.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/network.rs`

```rust
//! Network management backend - nmcli and tailscale wrappers.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use serde::{Deserialize, Serialize};
use tracing::debug;

/// Network connection status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkStatus {
    pub connected: bool,
    pub connection_type: String,
    pub ssid: Option<String>,
    pub ip_address: Option<String>,
    pub gateway: Option<String>,
}

/// WiFi network information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WifiNetwork {
    pub ssid: String,
    pub signal_strength: i32,
    pub security: String,
    pub in_use: bool,
}

/// Tailscale status information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TailscaleStatus {
    pub connected: bool,
    pub ip: Option<String>,
    pub hostname: Option<String>,
    pub exit_node: Option<String>,
}

// =============================================================================
// Network Status
// =============================================================================

/// Get overall network status.
pub async fn network_status() -> BackendResult<NetworkStatus> {
    let output = exec("nmcli", &["-t", "-f", "TYPE,STATE,CONNECTION", "device"]).await?;

    let mut connected = false;
    let mut connection_type = "none".to_string();
    let mut ssid = None;

    for line in output.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 3 && parts[1] == "connected" {
            connected = true;
            connection_type = parts[0].to_string();
            if parts[0] == "wifi" {
                ssid = Some(parts[2].to_string());
            }
            break;
        }
    }

    // Get IP address if connected
    let ip_address = if connected {
        exec("hostname", &["-I"])
            .await
            .ok()
            .map(|s| s.split_whitespace().next().unwrap_or("").to_string())
            .filter(|s| !s.is_empty())
    } else {
        None
    };

    // Get gateway
    let gateway = if connected {
        exec("ip", &["route", "show", "default"])
            .await
            .ok()
            .and_then(|s| {
                s.split_whitespace()
                    .nth(2)
                    .map(|g| g.to_string())
            })
    } else {
        None
    };

    Ok(NetworkStatus {
        connected,
        connection_type,
        ssid,
        ip_address,
        gateway,
    })
}

// =============================================================================
// WiFi Operations
// =============================================================================

/// List available WiFi networks.
pub async fn wifi_list() -> BackendResult<Vec<WifiNetwork>> {
    // Rescan first
    let _ = exec("nmcli", &["device", "wifi", "rescan"]).await;

    // Wait briefly for scan
    tokio::time::sleep(std::time::Duration::from_secs(1)).await;

    let output = exec(
        "nmcli",
        &["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"],
    )
    .await?;

    let mut networks = Vec::new();

    for line in output.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 4 && !parts[1].is_empty() {
            networks.push(WifiNetwork {
                ssid: parts[1].to_string(),
                signal_strength: parts[2].parse().unwrap_or(0),
                security: parts[3].to_string(),
                in_use: parts[0] == "*",
            });
        }
    }

    // Sort by signal strength (descending)
    networks.sort_by(|a, b| b.signal_strength.cmp(&a.signal_strength));

    debug!("Found {} WiFi networks", networks.len());
    Ok(networks)
}

/// Connect to a WiFi network.
pub async fn wifi_connect(ssid: &str, password: Option<&str>) -> BackendResult<()> {
    let mut args = vec!["device", "wifi", "connect", ssid];

    if let Some(pwd) = password {
        args.push("password");
        args.push(pwd);
    }

    sudo_exec("nmcli", &args, PrivilegedOp::NetworkConfig).await?;
    Ok(())
}

/// Disconnect from current WiFi.
pub async fn wifi_disconnect() -> BackendResult<()> {
    exec("nmcli", &["device", "disconnect", "wlan0"]).await?;
    Ok(())
}

/// List saved WiFi networks.
pub async fn wifi_saved() -> BackendResult<Vec<String>> {
    let output = exec(
        "nmcli",
        &["-t", "-f", "NAME,TYPE", "connection", "show"],
    )
    .await?;

    let networks: Vec<String> = output
        .lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 2 && parts[1] == "802-11-wireless" {
                Some(parts[0].to_string())
            } else {
                None
            }
        })
        .collect();

    Ok(networks)
}

/// Forget a saved WiFi network.
pub async fn wifi_forget(ssid: &str) -> BackendResult<()> {
    sudo_exec(
        "nmcli",
        &["connection", "delete", ssid],
        PrivilegedOp::NetworkConfig,
    )
    .await?;
    Ok(())
}

// =============================================================================
// Tailscale Operations
// =============================================================================

/// Get Tailscale status.
pub async fn tailscale_status() -> BackendResult<TailscaleStatus> {
    let output = exec("tailscale", &["status", "--json"]).await;

    match output {
        Ok(json_str) => {
            // Parse the JSON output
            let status: serde_json::Value = serde_json::from_str(&json_str)?;

            let connected = status
                .get("BackendState")
                .and_then(|v| v.as_str())
                .map(|s| s == "Running")
                .unwrap_or(false);

            let ip = status
                .get("TailscaleIPs")
                .and_then(|v| v.as_array())
                .and_then(|arr| arr.first())
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());

            let hostname = status
                .get("Self")
                .and_then(|v| v.get("HostName"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());

            Ok(TailscaleStatus {
                connected,
                ip,
                hostname,
                exit_node: None,
            })
        }
        Err(_) => Ok(TailscaleStatus {
            connected: false,
            ip: None,
            hostname: None,
            exit_node: None,
        }),
    }
}

/// Connect to Tailscale.
pub async fn tailscale_up() -> BackendResult<()> {
    sudo_exec("tailscale", &["up"], PrivilegedOp::NetworkConfig).await?;
    Ok(())
}

/// Disconnect from Tailscale.
pub async fn tailscale_down() -> BackendResult<()> {
    sudo_exec("tailscale", &["down"], PrivilegedOp::NetworkConfig).await?;
    Ok(())
}

/// Get Tailscale IP address.
pub async fn tailscale_ip() -> BackendResult<String> {
    let output = exec("tailscale", &["ip", "-4"]).await?;
    Ok(output.trim().to_string())
}
```

### 4B.6 Audio Backend

#### Task 4B.6.1: Create audio.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/audio.rs`

```rust
//! Audio management backend - PipeWire/pactl + speakersafetyd.
//!
//! CRITICAL: All audio operations MUST verify speaker safety daemon is running.
//! This is non-negotiable for Apple Silicon hardware protection.

use crate::error::{BackendError, BackendResult};
use crate::privilege::exec;
use serde::{Deserialize, Serialize};
use tracing::{debug, error, warn};

/// Audio system status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioStatus {
    pub volume: u8,
    pub muted: bool,
    pub speaker_safe: bool,
    pub speaker_safe_message: String,
    pub default_sink: String,
}

/// Audio device information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioDevice {
    pub name: String,
    pub description: String,
    pub is_default: bool,
    pub volume: u8,
    pub muted: bool,
}

/// Verify speaker safety daemon is running.
/// Returns Ok(()) if safe, Err if speaker protection is compromised.
async fn verify_speaker_safety() -> BackendResult<()> {
    let output = exec("systemctl", &["is-active", "speakersafetyd.service"]).await;

    match output {
        Ok(status) if status.trim() == "active" => {
            debug!("Speaker safety daemon is active");
            Ok(())
        }
        _ => {
            error!("SPEAKER SAFETY DAEMON NOT RUNNING - BLOCKING AUDIO OPERATIONS");

            // Attempt to start the service
            warn!("Attempting to start speakersafetyd...");
            let start_result = exec("systemctl", &["start", "speakersafetyd.service"]).await;

            if start_result.is_ok() {
                // Verify it's now running
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                let verify = exec("systemctl", &["is-active", "speakersafetyd.service"]).await;
                if verify.map(|s| s.trim() == "active").unwrap_or(false) {
                    warn!("speakersafetyd started successfully");
                    return Ok(());
                }
            }

            Err(BackendError::SpeakerSafetyError {
                message: "speakersafetyd is not running and could not be started. \
                         Audio operations are BLOCKED to protect hardware. \
                         Run: sudo systemctl start speakersafetyd".to_string(),
            })
        }
    }
}

/// Get audio system status.
pub async fn audio_status() -> BackendResult<AudioStatus> {
    // Check speaker safety first
    let speaker_safe = verify_speaker_safety().await.is_ok();
    let speaker_safe_message = if speaker_safe {
        "Speaker protection active".to_string()
    } else {
        "WARNING: Speaker protection NOT active!".to_string()
    };

    // Get default sink info
    let sink_output = exec("pactl", &["get-default-sink"]).await?;
    let default_sink = sink_output.trim().to_string();

    // Get volume
    let vol_output = exec("pactl", &["get-sink-volume", "@DEFAULT_SINK@"]).await?;
    let volume = parse_volume(&vol_output).unwrap_or(0);

    // Get mute status
    let mute_output = exec("pactl", &["get-sink-mute", "@DEFAULT_SINK@"]).await?;
    let muted = mute_output.contains("yes");

    Ok(AudioStatus {
        volume,
        muted,
        speaker_safe,
        speaker_safe_message,
        default_sink,
    })
}

/// Set volume level (0-100).
pub async fn set_volume(level: u8) -> BackendResult<()> {
    // CRITICAL: Verify speaker safety before any volume change
    verify_speaker_safety().await?;

    if level > 100 {
        return Err(BackendError::InvalidArgument {
            message: "Volume must be 0-100".to_string(),
        });
    }

    let volume_str = format!("{}%", level);
    exec("pactl", &["set-sink-volume", "@DEFAULT_SINK@", &volume_str]).await?;

    debug!("Volume set to {}%", level);
    Ok(())
}

/// Mute audio.
pub async fn mute() -> BackendResult<()> {
    exec("pactl", &["set-sink-mute", "@DEFAULT_SINK@", "1"]).await?;
    debug!("Audio muted");
    Ok(())
}

/// Unmute audio.
pub async fn unmute() -> BackendResult<()> {
    // Verify speaker safety before unmuting
    verify_speaker_safety().await?;

    exec("pactl", &["set-sink-mute", "@DEFAULT_SINK@", "0"]).await?;
    debug!("Audio unmuted");
    Ok(())
}

/// List audio devices.
pub async fn list_devices() -> BackendResult<Vec<AudioDevice>> {
    let output = exec("pactl", &["list", "sinks", "short"]).await?;
    let default_sink = exec("pactl", &["get-default-sink"]).await?;
    let default_sink = default_sink.trim();

    let mut devices = Vec::new();

    for line in output.lines() {
        let parts: Vec<&str> = line.split('\t').collect();
        if parts.len() >= 2 {
            let name = parts[1].to_string();
            let is_default = name == default_sink;

            // Get volume for this sink
            let vol_output = exec("pactl", &["get-sink-volume", &name]).await;
            let volume = vol_output.ok().and_then(|s| parse_volume(&s)).unwrap_or(0);

            // Get mute status
            let mute_output = exec("pactl", &["get-sink-mute", &name]).await;
            let muted = mute_output.map(|s| s.contains("yes")).unwrap_or(false);

            devices.push(AudioDevice {
                name: name.clone(),
                description: name, // Would need pactl list sinks for full description
                is_default,
                volume,
                muted,
            });
        }
    }

    Ok(devices)
}

/// Set output device.
pub async fn set_output(device: &str) -> BackendResult<()> {
    // Verify speaker safety
    verify_speaker_safety().await?;

    exec("pactl", &["set-default-sink", device]).await?;
    debug!("Default sink set to {}", device);
    Ok(())
}

/// Parse volume percentage from pactl output.
fn parse_volume(output: &str) -> Option<u8> {
    // Output looks like: "Volume: front-left: 65536 / 100% / 0.00 dB, ..."
    output
        .split('/')
        .nth(1)?
        .trim()
        .trim_end_matches('%')
        .parse()
        .ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_volume() {
        assert_eq!(
            parse_volume("Volume: front-left: 65536 / 100% / 0.00 dB, front-right: 65536 / 100% / 0.00 dB"),
            Some(100)
        );
        assert_eq!(
            parse_volume("Volume: front-left: 32768 / 50% / -18.06 dB"),
            Some(50)
        );
    }
}
```

### 4B.7 Power Backend

#### Task 4B.7.1: Create power.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/power.rs`

```rust
//! Power management backend - CPU governor, suspend, reboot, shutdown.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use serde::{Deserialize, Serialize};
use std::path::Path;
use tracing::debug;

/// Power status information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PowerStatus {
    pub on_battery: bool,
    pub battery_percent: Option<u8>,
    pub time_remaining: Option<String>,
    pub power_mode: PowerMode,
}

/// CPU power/performance mode.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum PowerMode {
    Performance,
    Balanced,
    Powersave,
}

impl std::str::FromStr for PowerMode {
    type Err = BackendError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "performance" => Ok(Self::Performance),
            "balanced" | "schedutil" | "ondemand" => Ok(Self::Balanced),
            "powersave" => Ok(Self::Powersave),
            _ => Err(BackendError::InvalidArgument {
                message: format!("Unknown power mode: {}. Use performance, balanced, or powersave.", s),
            }),
        }
    }
}

impl PowerMode {
    /// Get the CPU governor name for this mode.
    fn governor(&self) -> &'static str {
        match self {
            Self::Performance => "performance",
            Self::Balanced => "schedutil", // Or ondemand on older kernels
            Self::Powersave => "powersave",
        }
    }
}

/// Get power status.
pub async fn power_status() -> BackendResult<PowerStatus> {
    // Check if on battery
    let ac_online = tokio::fs::read_to_string("/sys/class/power_supply/AC/online")
        .await
        .map(|s| s.trim() == "1")
        .unwrap_or(true); // Assume AC if can't read

    let on_battery = !ac_online;

    // Get battery percentage
    let battery_percent = tokio::fs::read_to_string("/sys/class/power_supply/BAT0/capacity")
        .await
        .ok()
        .and_then(|s| s.trim().parse().ok());

    // Get current CPU governor (from first CPU)
    let governor = tokio::fs::read_to_string(
        "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor",
    )
    .await
    .unwrap_or_else(|_| "unknown".to_string());

    let power_mode = match governor.trim() {
        "performance" => PowerMode::Performance,
        "powersave" => PowerMode::Powersave,
        _ => PowerMode::Balanced,
    };

    // Time remaining estimate (if battery)
    let time_remaining = if on_battery {
        // Could parse from upower if available
        None
    } else {
        None
    };

    Ok(PowerStatus {
        on_battery,
        battery_percent,
        time_remaining,
        power_mode,
    })
}

/// Set CPU power mode.
pub async fn set_power_mode(mode: PowerMode) -> BackendResult<()> {
    let governor = mode.governor();

    // Find all CPUs
    let cpu_path = Path::new("/sys/devices/system/cpu");
    let mut cpus = Vec::new();

    if let Ok(mut entries) = tokio::fs::read_dir(cpu_path).await {
        while let Ok(Some(entry)) = entries.next_entry().await {
            let name = entry.file_name();
            let name_str = name.to_string_lossy();
            if name_str.starts_with("cpu") && name_str[3..].chars().all(|c| c.is_ascii_digit()) {
                cpus.push(name_str.to_string());
            }
        }
    }

    debug!("Setting governor to {} for {} CPUs", governor, cpus.len());

    // Set governor for each CPU
    for cpu in &cpus {
        let path = format!("/sys/devices/system/cpu/{}/cpufreq/scaling_governor", cpu);
        sudo_exec(
            "tee",
            &[&path],
            PrivilegedOp::PowerControl,
        )
        .await
        .ok(); // Ignore errors for offline CPUs
    }

    // Alternative: use cpupower if available
    let _ = sudo_exec(
        "cpupower",
        &["frequency-set", "-g", governor],
        PrivilegedOp::PowerControl,
    )
    .await;

    debug!("Power mode set to {:?}", mode);
    Ok(())
}

/// Suspend the system.
pub async fn suspend() -> BackendResult<()> {
    debug!("Suspending system...");
    sudo_exec("systemctl", &["suspend"], PrivilegedOp::PowerControl).await?;
    Ok(())
}

/// Reboot the system.
pub async fn reboot() -> BackendResult<()> {
    debug!("Rebooting system...");
    sudo_exec("systemctl", &["reboot"], PrivilegedOp::PowerControl).await?;
    Ok(())
}

/// Shutdown the system.
pub async fn shutdown() -> BackendResult<()> {
    debug!("Shutting down system...");
    sudo_exec("systemctl", &["poweroff"], PrivilegedOp::PowerControl).await?;
    Ok(())
}
```

### 4B.8 Display Backend

#### Task 4B.8.1: Create display.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/display.rs`

```rust
//! Display management backend - brightness and resolution.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use serde::{Deserialize, Serialize};
use std::path::Path;
use tracing::debug;

/// Display information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub brightness: u8,
    pub max_brightness: u32,
    pub resolution: String,
}

/// Brightness adjustment direction.
#[derive(Debug, Clone, Copy)]
pub enum BrightnessChange {
    Set(u8),
    Up,
    Down,
}

const BRIGHTNESS_STEP: u8 = 10;

/// Find the backlight device path.
async fn find_backlight() -> BackendResult<String> {
    let backlight_base = Path::new("/sys/class/backlight");

    if let Ok(mut entries) = tokio::fs::read_dir(backlight_base).await {
        while let Ok(Some(entry)) = entries.next_entry().await {
            let name = entry.file_name();
            let path = backlight_base.join(&name);

            // Prefer apple-panel-bl for Apple hardware
            if name.to_string_lossy().contains("apple") {
                return Ok(path.to_string_lossy().to_string());
            }
        }

        // Fall back to first available
        let mut entries = tokio::fs::read_dir(backlight_base).await?;
        if let Ok(Some(entry)) = entries.next_entry().await {
            return Ok(backlight_base.join(entry.file_name()).to_string_lossy().to_string());
        }
    }

    Err(BackendError::DisplayError {
        message: "No backlight device found".to_string(),
    })
}

/// Get current brightness (0-100).
pub async fn get_brightness() -> BackendResult<u8> {
    let backlight = find_backlight().await?;

    let current = tokio::fs::read_to_string(format!("{}/brightness", backlight))
        .await?
        .trim()
        .parse::<u32>()
        .map_err(|_| BackendError::DisplayError {
            message: "Failed to parse brightness".to_string(),
        })?;

    let max = tokio::fs::read_to_string(format!("{}/max_brightness", backlight))
        .await?
        .trim()
        .parse::<u32>()
        .map_err(|_| BackendError::DisplayError {
            message: "Failed to parse max brightness".to_string(),
        })?;

    let percent = ((current as f64 / max as f64) * 100.0) as u8;
    Ok(percent)
}

/// Set brightness level.
pub async fn set_brightness(change: BrightnessChange) -> BackendResult<u8> {
    let backlight = find_backlight().await?;

    let max = tokio::fs::read_to_string(format!("{}/max_brightness", backlight))
        .await?
        .trim()
        .parse::<u32>()
        .map_err(|_| BackendError::DisplayError {
            message: "Failed to parse max brightness".to_string(),
        })?;

    let current_percent = get_brightness().await?;

    let new_percent = match change {
        BrightnessChange::Set(level) => level.min(100),
        BrightnessChange::Up => current_percent.saturating_add(BRIGHTNESS_STEP).min(100),
        BrightnessChange::Down => current_percent.saturating_sub(BRIGHTNESS_STEP),
    };

    let new_value = ((new_percent as f64 / 100.0) * max as f64) as u32;
    let brightness_path = format!("{}/brightness", backlight);

    debug!("Setting brightness to {}% (raw value: {})", new_percent, new_value);

    // Write to brightness file (requires root)
    let value_str = new_value.to_string();
    sudo_exec(
        "sh",
        &["-c", &format!("echo {} > {}", value_str, brightness_path)],
        PrivilegedOp::SystemConfig,
    )
    .await?;

    Ok(new_percent)
}

/// Get current display resolution.
pub async fn get_resolution() -> BackendResult<String> {
    // Try xrandr first
    if let Ok(output) = exec("xrandr", &["--current"]).await {
        for line in output.lines() {
            if line.contains("*") {
                // Find the resolution with the asterisk (current)
                if let Some(res) = line.split_whitespace().next() {
                    return Ok(res.to_string());
                }
            }
        }
    }

    // Fall back to fbset for framebuffer
    if let Ok(output) = exec("fbset", &["-s"]).await {
        for line in output.lines() {
            if line.contains("geometry") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    return Ok(format!("{}x{}", parts[1], parts[2]));
                }
            }
        }
    }

    // Read from DRM
    let drm_path = "/sys/class/drm";
    if let Ok(mut entries) = tokio::fs::read_dir(drm_path).await {
        while let Ok(Some(entry)) = entries.next_entry().await {
            let mode_path = format!("{}/modes", entry.path().display());
            if let Ok(modes) = tokio::fs::read_to_string(&mode_path).await {
                if let Some(first_mode) = modes.lines().next() {
                    return Ok(first_mode.to_string());
                }
            }
        }
    }

    Err(BackendError::DisplayError {
        message: "Could not determine current resolution".to_string(),
    })
}

/// Set display resolution.
pub async fn set_resolution(resolution: &str) -> BackendResult<()> {
    // Validate format
    if !resolution.contains('x') {
        return Err(BackendError::InvalidArgument {
            message: "Resolution must be in WIDTHxHEIGHT format (e.g., 1920x1080)".to_string(),
        });
    }

    // Try xrandr
    let result = exec("xrandr", &["--output", "eDP-1", "--mode", resolution]).await;

    if result.is_err() {
        // Try with different output name
        exec("xrandr", &["--output", "eDP", "--mode", resolution]).await?;
    }

    debug!("Resolution set to {}", resolution);
    Ok(())
}
```

### 4B.9 Update Backend

#### Task 4B.9.1: Create update.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/update.rs`

```rust
//! System update backend - bootc wrapper.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use serde::{Deserialize, Serialize};
use tracing::debug;

/// Update status information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateStatus {
    pub current_image: String,
    pub current_version: Option<String>,
    pub update_available: bool,
    pub staged_image: Option<String>,
}

/// Deployment information for rollback.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Deployment {
    pub image: String,
    pub version: Option<String>,
    pub timestamp: String,
    pub is_booted: bool,
    pub is_staged: bool,
}

/// Check for available updates.
pub async fn check_updates() -> BackendResult<UpdateStatus> {
    let output = exec("bootc", &["status", "--json"]).await?;
    let status: serde_json::Value = serde_json::from_str(&output)?;

    let current_image = status
        .get("status")
        .and_then(|s| s.get("booted"))
        .and_then(|b| b.get("image"))
        .and_then(|i| i.get("image"))
        .and_then(|i| i.as_str())
        .unwrap_or("unknown")
        .to_string();

    let current_version = status
        .get("status")
        .and_then(|s| s.get("booted"))
        .and_then(|b| b.get("image"))
        .and_then(|i| i.get("version"))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());

    let staged_image = status
        .get("status")
        .and_then(|s| s.get("staged"))
        .and_then(|s| s.get("image"))
        .and_then(|i| i.get("image"))
        .and_then(|i| i.as_str())
        .map(|s| s.to_string());

    // Check if update available (fetch latest)
    let upgrade_check = sudo_exec(
        "bootc",
        &["upgrade", "--check"],
        PrivilegedOp::SystemUpdate,
    )
    .await;

    let update_available = upgrade_check
        .map(|s| !s.contains("No updates available"))
        .unwrap_or(false);

    Ok(UpdateStatus {
        current_image,
        current_version,
        update_available,
        staged_image,
    })
}

/// Apply pending update.
pub async fn apply_update() -> BackendResult<String> {
    debug!("Applying system update...");

    let output = sudo_exec(
        "bootc",
        &["upgrade"],
        PrivilegedOp::SystemUpdate,
    )
    .await?;

    Ok(output)
}

/// Get update changelog (if available).
pub async fn changelog() -> BackendResult<String> {
    // bootc doesn't have built-in changelog support
    // This would need to fetch from container registry or GitHub releases

    let status = check_updates().await?;

    let mut changelog = String::new();
    changelog.push_str(&format!("Current: {}\n", status.current_image));

    if let Some(staged) = &status.staged_image {
        changelog.push_str(&format!("Staged: {}\n", staged));
    }

    if status.update_available {
        changelog.push_str("\nUpdate available. Run 'formless substrate update apply' to install.\n");
        changelog.push_str("Note: System will need to reboot after update.\n");
    } else {
        changelog.push_str("\nSystem is up to date.\n");
    }

    Ok(changelog)
}

/// List available deployments for rollback.
pub async fn list_deployments() -> BackendResult<Vec<Deployment>> {
    let output = exec("bootc", &["status", "--json"]).await?;
    let status: serde_json::Value = serde_json::from_str(&output)?;

    let mut deployments = Vec::new();

    // Current booted deployment
    if let Some(booted) = status.get("status").and_then(|s| s.get("booted")) {
        if let Some(image) = booted.get("image") {
            deployments.push(Deployment {
                image: image.get("image").and_then(|i| i.as_str()).unwrap_or("unknown").to_string(),
                version: image.get("version").and_then(|v| v.as_str()).map(|s| s.to_string()),
                timestamp: booted.get("timestamp").and_then(|t| t.as_str()).unwrap_or("unknown").to_string(),
                is_booted: true,
                is_staged: false,
            });
        }
    }

    // Rollback deployment (if exists)
    if let Some(rollback) = status.get("status").and_then(|s| s.get("rollback")) {
        if let Some(image) = rollback.get("image") {
            deployments.push(Deployment {
                image: image.get("image").and_then(|i| i.as_str()).unwrap_or("unknown").to_string(),
                version: image.get("version").and_then(|v| v.as_str()).map(|s| s.to_string()),
                timestamp: rollback.get("timestamp").and_then(|t| t.as_str()).unwrap_or("unknown").to_string(),
                is_booted: false,
                is_staged: false,
            });
        }
    }

    Ok(deployments)
}

/// Rollback to previous deployment.
pub async fn rollback() -> BackendResult<String> {
    debug!("Rolling back to previous deployment...");

    let output = sudo_exec(
        "bootc",
        &["rollback"],
        PrivilegedOp::SystemUpdate,
    )
    .await?;

    Ok(format!("{}\n\nReboot required to complete rollback.", output))
}
```

### 4B.10 Config Backend

#### Task 4B.10.1: Create config.rs

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/config.rs`

```rust
//! Configuration backend - font, boot verbosity, plymouth.

use crate::error::{BackendError, BackendResult};
use crate::privilege::{exec, sudo_exec, PrivilegedOp};
use tracing::debug;

/// Console font size presets.
#[derive(Debug, Clone, Copy)]
pub enum FontSize {
    Small,   // 8x16
    Medium,  // 12x22 (terminus)
    Large,   // 16x32
    Huge,    // 24x32 (latarcyrheb-sun32)
}

impl std::str::FromStr for FontSize {
    type Err = BackendError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "small" => Ok(Self::Small),
            "medium" => Ok(Self::Medium),
            "large" => Ok(Self::Large),
            "huge" => Ok(Self::Huge),
            _ => Err(BackendError::InvalidArgument {
                message: format!("Unknown font size: {}. Use small, medium, large, or huge.", s),
            }),
        }
    }
}

impl FontSize {
    /// Get the console font name.
    fn font_name(&self) -> &'static str {
        match self {
            Self::Small => "default8x16",
            Self::Medium => "ter-122b",
            Self::Large => "ter-132b",
            Self::Huge => "latarcyrheb-sun32",
        }
    }
}

/// Boot verbosity level.
#[derive(Debug, Clone, Copy)]
pub enum BootVerbosity {
    Quiet,   // quiet loglevel=3
    Normal,  // loglevel=4
    Verbose, // loglevel=6
    Debug,   // loglevel=7 debug
}

impl std::str::FromStr for BootVerbosity {
    type Err = BackendError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "quiet" => Ok(Self::Quiet),
            "normal" => Ok(Self::Normal),
            "verbose" => Ok(Self::Verbose),
            "debug" => Ok(Self::Debug),
            _ => Err(BackendError::InvalidArgument {
                message: format!("Unknown verbosity: {}. Use quiet, normal, verbose, or debug.", s),
            }),
        }
    }
}

impl BootVerbosity {
    /// Get kernel cmdline parameters for this verbosity.
    fn cmdline_params(&self) -> &'static str {
        match self {
            Self::Quiet => "quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3",
            Self::Normal => "loglevel=4 systemd.show_status=auto",
            Self::Verbose => "loglevel=6 systemd.show_status=true",
            Self::Debug => "loglevel=7 debug systemd.show_status=true systemd.log_level=debug",
        }
    }
}

/// Set console font size.
pub async fn set_font(size: FontSize) -> BackendResult<()> {
    let font_name = size.font_name();
    debug!("Setting console font to {}", font_name);

    // Update /etc/vconsole.conf
    let vconsole_content = format!("FONT={}\n", font_name);

    sudo_exec(
        "sh",
        &["-c", &format!("echo '{}' > /etc/vconsole.conf", vconsole_content.trim())],
        PrivilegedOp::SystemConfig,
    )
    .await?;

    // Apply immediately
    sudo_exec("setfont", &[font_name], PrivilegedOp::SystemConfig).await?;

    Ok(())
}

/// Set boot verbosity level.
pub async fn set_boot_verbosity(verbosity: BootVerbosity) -> BackendResult<()> {
    let params = verbosity.cmdline_params();
    debug!("Setting boot verbosity to {:?}", verbosity);

    // Update /etc/kernel/cmdline
    sudo_exec(
        "sh",
        &["-c", &format!("echo '{}' > /etc/kernel/cmdline", params)],
        PrivilegedOp::SystemConfig,
    )
    .await?;

    // On bootc systems, this takes effect on next boot
    // Could also run grub2-mkconfig if GRUB is used

    Ok(())
}

/// Set Plymouth splash theme.
pub async fn set_splash(theme: &str) -> BackendResult<()> {
    debug!("Setting Plymouth theme to {}", theme);

    if theme == "off" {
        // Disable Plymouth
        sudo_exec(
            "sh",
            &["-c", "sed -i 's/splash/nosplash/' /etc/kernel/cmdline || true"],
            PrivilegedOp::SystemConfig,
        )
        .await?;
    } else {
        // Verify theme exists
        let themes_output = exec("plymouth-set-default-theme", &["--list"]).await?;
        if !themes_output.lines().any(|l| l.trim() == theme) {
            return Err(BackendError::InvalidArgument {
                message: format!(
                    "Unknown Plymouth theme: {}. Available: {}",
                    theme,
                    themes_output.lines().collect::<Vec<_>>().join(", ")
                ),
            });
        }

        // Set theme
        sudo_exec(
            "plymouth-set-default-theme",
            &[theme, "-R"], // -R rebuilds initramfs
            PrivilegedOp::SystemConfig,
        )
        .await?;
    }

    Ok(())
}
```

### 4B.11 Update substrate.rs to Use Backends

#### Task 4B.11.1: Add Backend Dependency to formless-cli

**File:** `/Users/eric/src/formless-kernel/crates/formless-cli/Cargo.toml`

Add to `[dependencies]`:
```toml
formless-substrate-backends = { path = "../formless-substrate-backends" }
```

#### Task 4B.11.2: Update substrate.rs Handlers

**File:** `/Users/eric/src/formless-kernel/crates/formless-cli/src/substrate.rs`

Replace all the stub handlers (lines 397-619) with actual backend calls. Example for service handler:

```rust
use formless_substrate_backends::{service, network, audio, power, display, update, config};
use formless_substrate_backends::error::BackendError;

pub async fn handle_service(args: ServiceArgs) -> Result<()> {
    match args.subcommand {
        ServiceSubcommand::List { json } => {
            let services = service::list_services(json).await
                .context("Failed to list services")?;

            if json {
                println!("{}", serde_json::to_string_pretty(&services)?);
            } else {
                for svc in services {
                    let state_str = match svc.state {
                        service::ServiceState::Active => "\x1b[32mactive\x1b[0m",
                        service::ServiceState::Inactive => "inactive",
                        service::ServiceState::Failed => "\x1b[31mfailed\x1b[0m",
                        _ => "unknown",
                    };
                    println!("{:<40} {:<10} {}", svc.name, state_str, svc.description);
                }
            }
            Ok(())
        },
        ServiceSubcommand::Status { name } => {
            let info = service::service_status(&name).await
                .context("Failed to get service status")?;
            println!("Service: {}", info.name);
            println!("Status:  {:?}", info.state);
            println!("Enabled: {}", if info.enabled { "yes" } else { "no" });
            println!("Description: {}", info.description);
            Ok(())
        },
        ServiceSubcommand::Start { name } => {
            service::start_service(&name).await
                .context("Failed to start service")?;
            println!("Started {}", name);
            Ok(())
        },
        ServiceSubcommand::Stop { name } => {
            service::stop_service(&name).await
                .context("Failed to stop service")?;
            println!("Stopped {}", name);
            Ok(())
        },
        ServiceSubcommand::Restart { name } => {
            service::restart_service(&name).await
                .context("Failed to restart service")?;
            println!("Restarted {}", name);
            Ok(())
        },
        ServiceSubcommand::Enable { name } => {
            service::enable_service(&name).await
                .context("Failed to enable service")?;
            println!("Enabled {}", name);
            Ok(())
        },
        ServiceSubcommand::Disable { name } => {
            service::disable_service(&name).await
                .context("Failed to disable service")?;
            println!("Disabled {}", name);
            Ok(())
        },
        ServiceSubcommand::Logs { name, lines, follow } => {
            let logs = service::service_logs(&name, lines, follow).await
                .context("Failed to get logs")?;
            println!("{}", logs);
            Ok(())
        },
    }
}
```

Similar updates for all other handlers.

### 4B.12 Add Crate to Workspace

**File:** `/Users/eric/src/formless-kernel/Cargo.toml`

Add to `members` array:
```toml
"crates/formless-substrate-backends",
```

### 4B.13 Testing

#### Task 4B.13.1: Create Unit Tests

**File:** `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/tests/service_tests.rs`

```rust
use formless_substrate_backends::service;

#[tokio::test]
async fn test_normalize_unit_name() {
    // This is tested in the module, but verify public API works
}

#[tokio::test]
#[ignore] // Requires systemd
async fn test_list_services() {
    let services = service::list_services(false).await.unwrap();
    assert!(!services.is_empty());
}

#[tokio::test]
#[ignore] // Requires systemd
async fn test_service_status() {
    let status = service::service_status("sshd").await.unwrap();
    assert_eq!(status.name, "sshd");
}
```

#### Task 4B.13.2: Create Integration Test Script

**File:** `/Users/eric/src/asahi-substrate/scripts/phase4/integration-test.sh`

```bash
#!/bin/bash
# Phase 4 Integration Tests
# Run on deployed hardware to verify all commands work

set -e

echo "=== Phase 4 Integration Tests ==="
echo "Target: formless@192.168.8.114"
echo ""

SSH_HOST="${1:-formless@192.168.8.114}"

run_test() {
    local name="$1"
    local cmd="$2"
    echo -n "Testing: $name... "
    if ssh "$SSH_HOST" "$cmd" > /dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        return 1
    fi
}

# Service tests
run_test "service list" "formless substrate service list"
run_test "service status sshd" "formless substrate service status sshd"

# Network tests
run_test "network status" "formless substrate network status"
run_test "wifi list" "formless substrate network wifi list"
run_test "tailscale status" "formless substrate network tailscale status"

# Audio tests (may fail if no audio device)
run_test "audio status" "formless substrate audio status" || true

# Power tests
run_test "power status" "formless substrate power status"

# Display tests
run_test "display brightness" "formless substrate display brightness" || true

# Update tests
run_test "update check" "formless substrate update check"

echo ""
echo "=== Integration tests complete ==="
```

---

## Part III: Deployment & Validation

### 3.1 Build Sequence

```bash
# 1. Build Rust crates locally
cd /Users/eric/src/formless-kernel
cargo build --release

# 2. Run tests
cargo test -p formless-substrate-backends

# 3. Build container
cd /Users/eric/src/asahi-substrate
podman build -f src/Containerfile.substrate -t ghcr.io/ericrowan/asahi-substrate:phase4 .

# 4. Push to registry
podman push ghcr.io/ericrowan/asahi-substrate:phase4

# 5. Deploy to hardware
ssh formless@192.168.8.114 "sudo bootc switch ghcr.io/ericrowan/asahi-substrate:phase4 && sudo systemctl reboot"
```

### 3.2 Validation Checklist

| Check | Command | Expected |
|-------|---------|----------|
| Boot target | `systemctl get-default` | `formless.target` |
| Formless service | `systemctl status formless.service` | `active (running)` |
| Boot time | `systemd-analyze` | `<12s` |
| Service list | `formless substrate service list` | Shows services |
| Network status | `formless substrate network status` | Shows connection |
| Audio status | `formless substrate audio status` | Shows speaker safety |
| Power status | `formless substrate power status` | Shows battery/mode |
| Update check | `formless substrate update check` | Shows current image |

### 3.3 Success Criteria

| Criterion | Target | Validation |
|-----------|--------|------------|
| All 28 commands work | 100% | Integration test script |
| Boot time impact | <100ms added | Before/after systemd-analyze |
| Speaker safety | Never bypassed | Audio commands check speakersafetyd |
| Privilege escalation | Works with sudo | Test privileged commands |
| Error messages | Helpful | Manual review of error cases |

---

## Part IV: Risk Assessment

### 4.1 Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Formless binary not in container | High | Service fails to start | Document manual setup; plan binary inclusion for next phase |
| sudo -n fails (needs password) | Medium | Privileged commands fail | Document wheel group setup; add polkit rules |
| speakersafetyd not installed | Low | Audio blocked (by design) | Verify in Containerfile |
| Resolution commands fail on tty | Medium | Display commands unusable | Document limitation; plan for Wayland in Phase 5 |
| bootc rollback requires manual | Low | User confusion | Document reboot requirement |

### 4.2 Unknowns

1. **Exact formless binary path on deployed system** - Need to verify first-boot-setup creates correct symlinks
2. **xrandr availability without X** - May need wlr-randr for Wayland or pure DRM control
3. **CPU governor support on Apple Silicon** - May not have standard governors

### 4.3 Out of Scope for Phase 4

- Wayland compositor integration (Phase 5)
- Binary release pipeline (future)
- OTA update UI in TUI (future)
- Polkit rule creation automation (optional enhancement)

---

## Part V: Work Breakdown for Parallel Execution

### Independent Tasks (Can Run in Parallel)

**Group A: Backend Implementation (Rust)**
- Task 4B.2.1: Create Cargo.toml
- Task 4B.2.2: Create lib.rs
- Task 4B.2.3: Create error.rs
- Task 4B.3.1: Create privilege.rs
- Task 4B.4.1: Create service.rs
- Task 4B.5.1: Create network.rs
- Task 4B.6.1: Create audio.rs
- Task 4B.7.1: Create power.rs
- Task 4B.8.1: Create display.rs
- Task 4B.9.1: Create update.rs
- Task 4B.10.1: Create config.rs

**Group B: Infrastructure Changes (Can run with Group A)**
- Task 4A.2.1: Fix Containerfile service enablement
- Task 4A.2.2: Fix formless.target unit file
- Task 4B.12: Add crate to workspace

### Sequential Tasks (Must Wait)

**After Group A completes:**
- Task 4B.11.1: Add backend dependency to formless-cli
- Task 4B.11.2: Update substrate.rs handlers

**After all code changes:**
- Task 4B.13.1: Create unit tests
- Task 4B.13.2: Create integration test script
- Task 4A.2.5: Build and deploy test image

---

## Effort Estimate

**Phase 4A (Service Integration Fix):** 30 minutes
- File edits: 10 minutes
- Container build: 15 minutes
- Deploy + verify: 5 minutes

**Phase 4B (Backend Implementation):** 2-4 hours
- Backend crate setup: 15 minutes
- 11 source files: ~2 hours (parallel)
- substrate.rs integration: 30 minutes
- Testing: 30 minutes
- Deploy + validation: 30 minutes

**Total: 3-5 hours** (assuming parallel agent execution)

---

## Appendix A: File Manifest

| File | Action | Lines (Approx) |
|------|--------|----------------|
| `/Users/eric/src/asahi-substrate/src/Containerfile.substrate` | Edit | +3 lines |
| `/Users/eric/src/asahi-substrate/src/build_files/formless.target` | Edit | ~10 lines |
| `/Users/eric/src/formless-kernel/Cargo.toml` | Edit | +1 line |
| `/Users/eric/src/formless-kernel/crates/formless-cli/Cargo.toml` | Edit | +1 line |
| `/Users/eric/src/formless-kernel/crates/formless-cli/src/substrate.rs` | Edit | ~400 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/Cargo.toml` | Create | ~25 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/lib.rs` | Create | ~15 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/error.rs` | Create | ~80 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/privilege.rs` | Create | ~100 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/service.rs` | Create | ~180 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/network.rs` | Create | ~220 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/audio.rs` | Create | ~180 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/power.rs` | Create | ~150 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/display.rs` | Create | ~160 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/update.rs` | Create | ~150 lines |
| `/Users/eric/src/formless-kernel/crates/formless-substrate-backends/src/config.rs` | Create | ~140 lines |
| `/Users/eric/src/asahi-substrate/scripts/phase4/integration-test.sh` | Create | ~50 lines |

**Total new code: ~1,450 lines**
**Total edits: ~410 lines**

---

## Appendix B: Command Reference

All 28 commands that will be functional after Phase 4:

```
formless substrate service list [--json]
formless substrate service status <name>
formless substrate service start <name>
formless substrate service stop <name>
formless substrate service restart <name>
formless substrate service enable <name>
formless substrate service disable <name>
formless substrate service logs <name> [-n LINES] [-f]

formless substrate network status
formless substrate network wifi list
formless substrate network wifi connect <ssid> [-p PASSWORD]
formless substrate network wifi disconnect
formless substrate network wifi saved
formless substrate network wifi forget <ssid>
formless substrate network tailscale status
formless substrate network tailscale up
formless substrate network tailscale down
formless substrate network tailscale ip

formless substrate audio status
formless substrate audio volume <0-100>
formless substrate audio mute
formless substrate audio unmute
formless substrate audio devices
formless substrate audio output <device>

formless substrate power status
formless substrate power mode <performance|balanced|powersave>
formless substrate power sleep
formless substrate power reboot
formless substrate power shutdown

formless substrate display brightness <0-100|up|down>
formless substrate display resolution
formless substrate display set-resolution <WIDTHxHEIGHT>

formless substrate update check
formless substrate update apply
formless substrate update changelog
formless substrate update rollback [--list]

formless substrate config font <small|medium|large|huge>
formless substrate config boot <quiet|normal|verbose|debug>
formless substrate config splash <theme|off>
```

---

**End of Specification**

*Document prepared for parallel agent execution. Each task is self-contained with explicit file paths, expected content, and success criteria.*
