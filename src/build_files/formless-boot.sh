#!/bin/bash
# Formless Substrate Boot Script
# Starts daemon and dashboard for direct boot experience

set -e

# Setup environment
export PATH="/home/linuxbrew/.linuxbrew/bin:/usr/bin:/bin:/usr/local/bin"
export FORMLESS_HOME="/home/formless/.formless"
export TERM="xterm-256color"

# Ensure formless directory exists
mkdir -p "$FORMLESS_HOME"

# Hide cursor
setterm --cursor off 2>/dev/null || true

# Start the kernel daemon in background (if not already running)
if ! formless status 2>/dev/null | grep -q "Daemon running"; then
    formless start &
    # Give daemon time to start and create socket
    sleep 2
fi

# Launch interactive dashboard
exec formless dashboard
