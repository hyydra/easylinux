#!/usr/bin/env bash
# Undo the Windows-style clipboard module (kitty itself stays installed).
set -euo pipefail
KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
HELPERS="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/helpers.rc"

if [ -f "$KITTY_DIR/kitty.conf" ]; then
    sed -i -e '/^# easylinux$/d' -e '/^include easylinux\.conf$/d' "$KITTY_DIR/kitty.conf"
fi
rm -f "$KITTY_DIR/easylinux.conf"
if [ -f "$HELPERS.easylinux-bak" ]; then
    mv -f "$HELPERS.easylinux-bak" "$HELPERS"
elif [ -f "$HELPERS" ]; then
    sed -i '/^TerminalEmulator=kitty$/d' "$HELPERS"
fi
echo "[✓] Windows-style clipboard removed; default terminal restored."
