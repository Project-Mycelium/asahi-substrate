#!/bin/bash
# Formless Substrate First Boot Setup
# Runs once on first boot to complete system configuration

set -euo pipefail

LOG_TAG="formless-first-boot"
log() { logger -t "$LOG_TAG" "$1"; echo "[first-boot] $1"; }

log "Starting Formless Substrate first boot setup..."

# Ensure state directory exists (may not persist from image in bootc)
mkdir -p /var/lib/formless

# =============================================================================
# 0. SSH KEY RESTORATION (in case /var persisted without keys)
# =============================================================================
log "Ensuring SSH keys are set up..."

FORMLESS_HOME="/home/formless"
SSH_DIR="$FORMLESS_HOME/.ssh"

# Ensure .ssh directory exists with correct permissions
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# If authorized_keys is missing or empty, restore from /etc/skel
if [ ! -s "$SSH_DIR/authorized_keys" ]; then
    if [ -f /etc/skel/.ssh/authorized_keys ]; then
        cp /etc/skel/.ssh/authorized_keys "$SSH_DIR/authorized_keys"
        log "Restored authorized_keys from /etc/skel"
    fi
fi

# Fix ownership
chown -R formless:formless "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys" 2>/dev/null || true

log "SSH setup complete"

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
    rustup-init \
    openssl \
    pkg-config \
    || log "Some tools may have failed to install (non-fatal)"

# =============================================================================
# 2b. RUST TOOLCHAIN
# =============================================================================
log "Installing Rust toolchain..."

CARGO_HOME="/home/$HOMEBREW_USER/.cargo"
if [ ! -f "$CARGO_HOME/bin/rustc" ]; then
    sudo -u "$HOMEBREW_USER" "$HOMEBREW_PREFIX/bin/rustup-init" -y
    log "Rust toolchain installed"
else
    log "Rust toolchain already installed"
fi

# Add cargo to profile if not present
if ! grep -q '\.cargo/env' "/home/$HOMEBREW_USER/.bashrc" 2>/dev/null; then
    cat >> "/home/$HOMEBREW_USER/.bashrc" << 'EOF'

# Rust/Cargo
[ -f ~/.cargo/env ] && source ~/.cargo/env
EOF
    chown "$HOMEBREW_USER:$HOMEBREW_USER" "/home/$HOMEBREW_USER/.bashrc"
    log "Added Cargo to shell profile"
fi

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

    # Set up build environment with OpenSSL paths
    export OPENSSL_DIR="$HOMEBREW_PREFIX/opt/openssl"
    export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/openssl/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export PATH="$CARGO_HOME/bin:$PATH"

    sudo -u "$HOMEBREW_USER" \
        OPENSSL_DIR="$OPENSSL_DIR" \
        PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
        PATH="$CARGO_HOME/bin:$PATH" \
        cargo build --release

    # Install all available binaries
    for bin in formless formless-kernel formless-dashboard; do
        if [ -f "target/release/$bin" ]; then
            cp "target/release/$bin" "$HOMEBREW_PREFIX/bin/"
            chmod +x "$HOMEBREW_PREFIX/bin/$bin"
            log "Installed: $bin"
        fi
    done
    log "Formless built and installed"
else
    log "Formless not available - will need manual installation"
    log "Run: ~/scripts/setup-kernel.sh (after cloning formless-kernel)"
    log "Or:  git clone https://github.com/ericrowan/formless-kernel.git ~/src/formless-kernel"
    log "     ~/scripts/setup-kernel.sh"
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
log "  3. Install Formless kernel:"
log "       git clone https://github.com/ericrowan/formless-kernel.git ~/src/formless-kernel"
log "       ./scripts/setup-kernel.sh"
log "  4. Or if kernel was pre-cloned: sudo systemctl start formless"
log ""
log "Welcome to Formless Substrate."
