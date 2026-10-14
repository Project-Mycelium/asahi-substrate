#!/bin/bash
# Formless Kernel Integration Script
# Run this on the M1 substrate to install and configure the kernel
#
# Usage: ./setup-kernel.sh [--build-only] [--verify-only]

set -euo pipefail

# Configuration
FORMLESS_USER="formless"
FORMLESS_HOME="/home/$FORMLESS_USER"
HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
KERNEL_REPO="https://github.com/Project-Mycelium/formless-kernel.git"
KERNEL_DIR="$FORMLESS_HOME/src/formless-kernel"
FORMLESS_DIR="$FORMLESS_HOME/.formless"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[kernel]${NC} $1"; }
success() { echo -e "${GREEN}[  ok  ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ warn ]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; }

# Check if running as formless user
check_user() {
    if [ "$(whoami)" != "$FORMLESS_USER" ]; then
        error "This script must be run as '$FORMLESS_USER' user"
        error "Run: sudo -u $FORMLESS_USER $0"
        exit 1
    fi
}

# Step 1: Clone repository
clone_kernel() {
    log "Step 1: Cloning Formless Kernel..."

    if [ -d "$KERNEL_DIR/.git" ]; then
        log "Repository exists, pulling latest..."
        cd "$KERNEL_DIR"
        git pull
        success "Repository updated"
    else
        mkdir -p "$FORMLESS_HOME/src"
        git clone "$KERNEL_REPO" "$KERNEL_DIR"
        success "Repository cloned to $KERNEL_DIR"
    fi
}

# Step 2: Install Rust toolchain
install_rust() {
    log "Step 2: Installing Rust toolchain..."

    if command -v rustc &> /dev/null; then
        RUST_VERSION=$(rustc --version)
        success "Rust already installed: $RUST_VERSION"
        return 0
    fi

    # Check if rustup-init is available via Homebrew
    if [ -f "$HOMEBREW_PREFIX/bin/rustup-init" ]; then
        "$HOMEBREW_PREFIX/bin/rustup-init" -y
    else
        # Install via Homebrew first
        log "Installing rustup via Homebrew..."
        "$HOMEBREW_PREFIX/bin/brew" install rustup-init
        "$HOMEBREW_PREFIX/bin/rustup-init" -y
    fi

    # Source cargo environment
    source "$HOME/.cargo/env"

    RUST_VERSION=$(rustc --version)
    success "Rust installed: $RUST_VERSION"
}

# Step 3: Install build dependencies
install_deps() {
    log "Installing build dependencies..."

    # Check for pkg-config and openssl
    if ! command -v pkg-config &> /dev/null; then
        log "Installing pkg-config via Homebrew..."
        "$HOMEBREW_PREFIX/bin/brew" install pkg-config
    fi

    # Install openssl if not present (needed for some Rust crates)
    if ! "$HOMEBREW_PREFIX/bin/brew" list openssl &> /dev/null; then
        log "Installing openssl via Homebrew..."
        "$HOMEBREW_PREFIX/bin/brew" install openssl
    fi

    success "Build dependencies ready"
}

# Step 4: Build kernel
build_kernel() {
    log "Step 3: Building Formless Kernel..."

    cd "$KERNEL_DIR"

    # Ensure cargo is in PATH
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    # Set OpenSSL paths for Homebrew on Linux
    export OPENSSL_DIR="$HOMEBREW_PREFIX/opt/openssl"
    export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/openssl/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    log "Running cargo build --release (this may take a while)..."
    cargo build --release

    success "Kernel built successfully"

    # List built binaries
    log "Built binaries:"
    ls -la target/release/formless* 2>/dev/null | grep -v '\.d$' | while read line; do
        echo "  $line"
    done
}

# Step 5: Run tests
run_tests() {
    log "Running tests..."

    cd "$KERNEL_DIR"

    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    export OPENSSL_DIR="$HOMEBREW_PREFIX/opt/openssl"
    export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/openssl/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    if cargo test; then
        success "All tests passed"
    else
        warn "Some tests failed - check output above"
        return 1
    fi
}

# Step 6: Install binaries
install_binaries() {
    log "Step 4: Installing binaries..."

    cd "$KERNEL_DIR"

    # List of binaries to install
    BINARIES=("formless" "formless-kernel" "formless-dashboard")

    for bin in "${BINARIES[@]}"; do
        if [ -f "target/release/$bin" ]; then
            cp "target/release/$bin" "$HOMEBREW_PREFIX/bin/"
            chmod +x "$HOMEBREW_PREFIX/bin/$bin"
            success "Installed: $bin"
        else
            warn "Binary not found: $bin (may not be built by default)"
        fi
    done
}

# Step 7: Setup directories
setup_directories() {
    log "Setting up Formless directories..."

    mkdir -p "$FORMLESS_DIR"/{inbox,sessions,projects}

    success "Directories created at $FORMLESS_DIR"
}

# Step 8: Enable and start service
enable_service() {
    log "Step 5-6: Configuring systemd service..."

    # Check if binary exists
    if [ ! -f "$HOMEBREW_PREFIX/bin/formless" ]; then
        error "formless binary not found at $HOMEBREW_PREFIX/bin/formless"
        return 1
    fi

    # Reload systemd
    sudo systemctl daemon-reload

    # Enable service
    sudo systemctl enable formless.service
    success "Service enabled"

    # Start service
    sudo systemctl start formless.service
    success "Service started"

    # Check status
    sleep 2
    if systemctl is-active --quiet formless.service; then
        success "Service is running"
    else
        warn "Service may have failed to start"
        systemctl status formless.service --no-pager || true
    fi
}

# Step 9: Verify installation
verify() {
    log "Step 7: Verifying installation..."

    local errors=0

    # Check binary
    if [ -f "$HOMEBREW_PREFIX/bin/formless" ]; then
        success "Binary exists: $HOMEBREW_PREFIX/bin/formless"
    else
        error "Binary missing: $HOMEBREW_PREFIX/bin/formless"
        ((errors++))
    fi

    # Check socket (may take a moment to appear)
    sleep 1
    if [ -S "$FORMLESS_DIR/kernel.sock" ]; then
        success "Socket exists: $FORMLESS_DIR/kernel.sock"
    else
        warn "Socket not found: $FORMLESS_DIR/kernel.sock"
        warn "  (This is expected if the daemon hasn't started yet)"
    fi

    # Check service status
    if systemctl is-active --quiet formless.service; then
        success "Service is active"
    else
        warn "Service is not active"
    fi

    # Try to get status via CLI
    if command -v formless &> /dev/null; then
        log "Testing formless CLI..."
        if formless status 2>/dev/null; then
            success "CLI status command works"
        else
            warn "CLI status command failed (daemon may not be fully initialized)"
        fi
    fi

    # Check logs
    log "Recent service logs:"
    journalctl -u formless.service -n 10 --no-pager 2>/dev/null || true

    if [ $errors -eq 0 ]; then
        echo ""
        success "=== Kernel integration complete ==="
        echo ""
        log "Useful commands:"
        echo "  formless status          - Check kernel status"
        echo "  systemctl status formless - Check service status"
        echo "  journalctl -u formless -f - Follow service logs"
        echo "  ls -la $FORMLESS_DIR/    - View Formless home"
    else
        echo ""
        error "Integration completed with $errors error(s)"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "======================================"
    echo "  Formless Kernel Integration Script"
    echo "======================================"
    echo ""

    case "${1:-full}" in
        --build-only)
            check_user
            clone_kernel
            install_rust
            install_deps
            build_kernel
            ;;
        --verify-only)
            verify
            ;;
        --test)
            check_user
            run_tests
            ;;
        full|*)
            check_user
            clone_kernel
            install_rust
            install_deps
            build_kernel
            install_binaries
            setup_directories
            enable_service
            verify
            ;;
    esac
}

main "$@"
