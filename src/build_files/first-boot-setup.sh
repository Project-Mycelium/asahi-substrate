#!/bin/bash
# Formless Substrate First Boot Setup
# Runs once on first boot to complete system configuration

set -euo pipefail

LOG_TAG="formless-first-boot"
log() { logger -t "$LOG_TAG" "$1"; echo "[first-boot] $1"; }

log "Starting Formless Substrate first boot setup..."

# =============================================================================
# 1. HOMEBREW INSTALLATION
# =============================================================================
log "Installing Homebrew..."

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
HOMEBREW_USER="formless"

# Install Homebrew non-interactively
if [ ! -f "$HOMEBREW_PREFIX/bin/brew" ]; then
    # Download and run installer
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew-install.sh

    # Run as formless user
    sudo -u "$HOMEBREW_USER" NONINTERACTIVE=1 bash /tmp/brew-install.sh

    rm -f /tmp/brew-install.sh
    log "Homebrew installed successfully"
else
    log "Homebrew already installed"
fi

# Add Homebrew to formless user's profile
PROFILE_FILE="/home/$HOMEBREW_USER/.bashrc"
if ! grep -q 'linuxbrew' "$PROFILE_FILE" 2>/dev/null; then
    cat >> "$PROFILE_FILE" << 'EOF'

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
EOF
    chown "$HOMEBREW_USER:$HOMEBREW_USER" "$PROFILE_FILE"
    log "Added Homebrew to shell profile"
fi

# =============================================================================
# 2. ESSENTIAL TOOLS
# =============================================================================
log "Installing essential tools via Homebrew..."

sudo -u "$HOMEBREW_USER" "$HOMEBREW_PREFIX/bin/brew" install \
    gh \
    neovim \
    ripgrep \
    fd \
    bat \
    eza \
    fzf \
    starship \
    || log "Some tools may have failed to install (non-fatal)"

# =============================================================================
# 3. FORMLESS INSTALLATION
# =============================================================================
log "Checking for Formless..."

# Option A: Install from Homebrew tap (if available)
# Option B: Build from source
# Option C: Use container

if [ -n "${FORMLESS_TAP:-}" ]; then
    log "Installing Formless from tap: $FORMLESS_TAP"
    sudo -u "$HOMEBREW_USER" "$HOMEBREW_PREFIX/bin/brew" tap "$FORMLESS_TAP"
    sudo -u "$HOMEBREW_USER" "$HOMEBREW_PREFIX/bin/brew" install formless
elif [ -d "/home/$HOMEBREW_USER/src/formless-kernel" ]; then
    log "Found Formless source - building..."
    cd "/home/$HOMEBREW_USER/src/formless-kernel"
    sudo -u "$HOMEBREW_USER" cargo build --release
    cp target/release/formless "$HOMEBREW_PREFIX/bin/"
    log "Formless built and installed"
else
    log "Formless not available - will need manual installation"
    log "Options:"
    log "  1. brew tap <formless-tap> && brew install formless"
    log "  2. Clone and build: git clone <repo> && cargo build --release"
    log "  3. Use container: podman run formless"
fi

# =============================================================================
# 4. TAILSCALE SETUP (if auth key provided)
# =============================================================================
if [ -f /etc/default/tailscale-autostart ] && [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    log "Tailscale auth key found - network will auto-join"
else
    log "No Tailscale auth key - run 'sudo tailscale up' manually"
fi

# =============================================================================
# 5. FINAL CONFIGURATION
# =============================================================================

# Create Formless directories
sudo -u "$HOMEBREW_USER" mkdir -p "/home/$HOMEBREW_USER/.formless"/{inbox,sessions,projects}
log "Created Formless directories"

# Enable Formless service (but don't start - may not have binary yet)
if [ -f "$HOMEBREW_PREFIX/bin/formless" ]; then
    systemctl enable formless.service || true
    log "Formless service enabled"
else
    log "Formless binary not found - service not enabled"
fi

# =============================================================================
# COMPLETE
# =============================================================================
log "First boot setup complete!"
log ""
log "Next steps:"
log "  1. SSH in: ssh formless@<ip>"
log "  2. Join Tailscale: sudo tailscale up"
log "  3. Install Formless: brew install formless (or build from source)"
log "  4. Start Formless: systemctl --user start formless"
log ""
log "Welcome to Formless Substrate."
