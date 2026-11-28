#!/usr/bin/env bash
# XFCE is the base desktop everything else in easyset is built on. On a machine without it, install it
# from the distribution's own archive (apt: official, signed packages), then the look and settings
# modules apply on top. Already installed packages are left alone.
set -euo pipefail

if [ "$EUID" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then echo "[-] Please run as root: sudo $0"; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

# core desktop, the panel plugins the theme module configures, a login screen, a polkit agent for the
# graphical admin prompt, and the keyring. Official archive packages only.
PKGS="xfce4 xfce4-terminal thunar thunar-volman xfce4-screenshooter xfce4-notes-plugin xfce4-battery-plugin xfce4-weather-plugin xfce4-genmon-plugin xfce4-power-manager lightdm lightdm-gtk-greeter policykit-1-gnome gnome-keyring libpam-gnome-keyring network-manager-gnome blueman fonts-noto-core yaru-theme-gtk elementary-icon-theme"

echo "=== XFCE base desktop ==="
if ! command -v apt-get >/dev/null 2>&1; then
    echo "[!] Not an apt system: install XFCE with your package manager (packages: xfce4, a login manager such as lightdm,"
    echo "    xfce4-terminal, thunar, a polkit agent, gnome-keyring), then run 'easyset --user'."
    exit 0
fi
missing=""
for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
if [ -z "$missing" ]; then echo "[✓] XFCE and its helpers are already installed"; exit 0; fi

es_begin xfce-base
es_note "easyset installed XFCE packages; remove with: apt-get remove$missing"
es_arm
echo "Installing:$missing"
if [ -n "${EASYLINUX_NO_PKG:-}" ]; then echo "[skip] package installation disabled here; install these packages: $missing"; exit 0; fi
# only packages that exist in the archive of this release (names differ between releases)
avail=""; for p in $missing; do apt-cache show "$p" >/dev/null 2>&1 && avail="$avail $p" || echo "[i] $p is not in this release's archive, skipped"; done
[ -n "$avail" ] && DEBIAN_FRONTEND=noninteractive apt-get install -y $avail
echo "[✓] XFCE installed; log out and choose the 'Xfce Session' at the login screen"
