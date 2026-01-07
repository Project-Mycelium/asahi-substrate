#!/bin/bash
# Enable GNOME Night Light and set a warm temperature (4000K)
# This script is intended to run in a user session.

echo "Applying Wavy Color Tint (Night Light)..."

gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 4000

logger "WavyOS: Night Light configured to 4000K."
