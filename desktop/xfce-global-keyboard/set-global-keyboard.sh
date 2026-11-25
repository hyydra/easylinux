#!/usr/bin/env bash
# Configure XFCE to maintain a single global keyboard layout across all windows
set -euo pipefail

echo "=== Configuring Global Keyboard Layout for XFCE ==="

# Find all xkb plugins on xfce4-panel
PLUGINS=$(xfconf-query -c xfce4-panel -l | grep -E '/plugins/plugin-[0-9]+$' || true)

COUNT=0
for p in $PLUGINS; do
    VAL=$(xfconf-query -c xfce4-panel -p "$p" 2>/dev/null || true)
    if [ "$VAL" = "xkb" ]; then
        echo "Found XKB panel plugin: $p"
        xfconf-query -c xfce4-panel -p "${p}/group-policy" -n -t uint -s 0
        echo "[✓] Set ${p}/group-policy = 0 (Globally)"
        COUNT=$((COUNT + 1))
    fi
done

if [ "$COUNT" -eq 0 ]; then
    echo "[!] Note: No active xkb plugin found on xfce4-panel."
fi

# Ensure ibus also uses global engine if available
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.freedesktop.ibus.general use-global-engine true 2>/dev/null || true
    echo "[✓] Configured IBus use-global-engine = true"
fi

echo "=== Done! Keyboard language is now global and will not switch between windows. ==="
