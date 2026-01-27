#!/bin/bash
set -e
FONT_DIR="/usr/share/fonts/wavy"
mkdir -p "$FONT_DIR"

# Download Geist Sans
echo "Fetching Geist Sans..."
curl -L -o /tmp/geist.zip https://github.com/vercel/geist-font/releases/download/1.3.0/Geist-1.3.0.zip
unzip -o -j /tmp/geist.zip "Geist-1.3.0/statics-otf/*.otf" -d "$FONT_DIR"

# Download Geist Mono
echo "Fetching Geist Mono..."
curl -L -o /tmp/geist-mono.zip https://github.com/vercel/geist-font/releases/download/1.3.0/GeistMono-1.3.0.zip
unzip -o -j /tmp/geist-mono.zip "GeistMono-1.3.0/statics-otf/*.otf" -d "$FONT_DIR"

# Cleanup & Cache
rm -f /tmp/geist.zip /tmp/geist-mono.zip
fc-cache -fv
