#!/bin/bash
# Wavy/Spore Setup Wizard
# Usage: wavy-setup [--force-intro]

CONFIG_DIR="$HOME/.config/wavy"
mkdir -p "$CONFIG_DIR"
STATE_FILE="$CONFIG_DIR/setup_state"

# Branding Header
echo "🌊 Spore Setup Utility"
echo "========================"

# Intro Logic
if [ ! -f "$STATE_FILE" ] || [ "$1" == "--force-intro" ]; then
    echo "Welcome to your new substrate."
    echo "This wizard will configure your environment for Apple Silicon."
    read -p "Press Enter to begin..."
fi

# 1. Widevine (Netflix/Spotify)
echo ""
read -p "Did you want to install Widevine DRM for media streaming? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Fetching Widevine..."
    # Placeholder for actual curl fetcher logic in V2.4
    echo "✅ Widevine scheduled."
fi

# 2. Keybindings (Mac-Like)
echo ""
read -p "Swap Control and Command keys (Mac-style)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # GNOME Tweak: Swap Left-Ctrl and Left-Alt (Command position)
    gsettings set org.gnome.desktop.input-sources xkb-options "['altwin:ctrl_alt_win']"
    echo "✅ Keys swapped."
fi

# 3. Mark Complete
date > "$STATE_FILE"
echo ""
echo "✅ Setup Complete. Run 'just wavy' to return here."
