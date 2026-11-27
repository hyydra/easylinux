#!/usr/bin/env bash
# Keyboard backlight keys (Fn+Space on a ThinkPad) for XFCE.
# XFCE does not bind XF86KbdBrightnessUp/Down/LightOnOff, so the backlight stays off.
# This installs a small UPower-based helper and binds the keys to it (per user, no root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/easylinux-kbd-backlight"

echo "==> Keyboard backlight keys"
mkdir -p "$BIN_DIR"
install -m 755 "$SCRIPT_DIR/easylinux-kbd-backlight" "$BIN"
echo "[✓] Installed $BIN"

if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "[skip] xfconf-query not found: bind the keys in your desktop to '$BIN up|down|cycle'"
    exit 0
fi
bind() {
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -n -t string -s "$BIN $2"
}
bind XF86KbdBrightnessUp up
bind XF86KbdBrightnessDown down
bind XF86KbdLightOnOff cycle
echo "[✓] Bound XF86KbdBrightnessUp/Down/LightOnOff (Fn+Space cycles off / dim / bright)"
if ! "$BIN" status >/dev/null 2>&1; then
    echo "[!] No UPower keyboard backlight detected on this machine; the keys are bound but do nothing here"
fi
