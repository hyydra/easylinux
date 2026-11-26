#!/usr/bin/env bash
# Configure ThinkPad X280 touchpad with full-height left/right button split
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

echo "=== 0. Creating safety snapshot (undo: sudo easylinux-rollback) ==="
es_begin touchpad-split
es_backup /etc/X11/xorg.conf.d/70-synaptics.conf
es_backup /etc/X11/xorg.conf.d/99-synaptics-custom.conf
if command -v dpkg >/dev/null 2>&1 && ! dpkg -s xserver-xorg-input-synaptics >/dev/null 2>&1; then
    es_note "easylinux installed the apt package xserver-xorg-input-synaptics; remove it with: apt-get remove xserver-xorg-input-synaptics"
fi
es_arm

echo "=== 1. Installing xserver-xorg-input-synaptics ==="
apt-get update -y
apt-get install -y xserver-xorg-input-synaptics

echo "=== 2. Deploying Touchpad Split Configuration ==="
mkdir -p /etc/X11/xorg.conf.d
cp "$SCRIPT_DIR/70-synaptics.conf" /etc/X11/xorg.conf.d/70-synaptics.conf
cp "$SCRIPT_DIR/70-synaptics.conf" /etc/X11/xorg.conf.d/99-synaptics-custom.conf

echo "[✓] Successfully installed 70-synaptics.conf into /etc/X11/xorg.conf.d/"
echo "=== Done! Please log out and back in (or reboot) for changes to take effect. ==="
