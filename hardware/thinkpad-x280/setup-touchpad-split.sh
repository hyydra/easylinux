#!/usr/bin/env bash
# Configure ThinkPad X280 touchpad with full-height left/right button split
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Installing xserver-xorg-input-synaptics ==="
apt-get update -y
apt-get install -y xserver-xorg-input-synaptics

echo "=== 2. Deploying Touchpad Split Configuration ==="
mkdir -p /etc/X11/xorg.conf.d
cp "$SCRIPT_DIR/70-synaptics.conf" /etc/X11/xorg.conf.d/70-synaptics.conf
cp "$SCRIPT_DIR/70-synaptics.conf" /etc/X11/xorg.conf.d/99-synaptics-custom.conf

echo "[✓] Successfully installed 70-synaptics.conf into /etc/X11/xorg.conf.d/"
echo "=== Done! Please log out and back in (or reboot) for changes to take effect. ==="
