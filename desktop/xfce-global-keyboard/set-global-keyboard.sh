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
        # show the layout as text ("hu", "en") instead of a flag, sized like the other panel text
        xfconf-query -c xfce4-panel -p "${p}/display-type" -n -t uint -s 1
        xfconf-query -c xfce4-panel -p "${p}/display-name" -n -t uint -s 1
        xfconf-query -c xfce4-panel -p "${p}/display-scale" -n -t uint -s 55
        echo "[✓] Layout indicator shows the language as text instead of a flag"
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
    # With a single plain keyboard engine IBus adds nothing but a second, redundant "EN" tray icon,
    # and its menu pops up in the top-left corner of the screen (not by the icon), where it goes
    # unnoticed and grabs the keyboard, so e.g. Print Screen stops working. Hide only the icon when
    # IBus has no real input method (more than one engine, or a non-xkb one, keeps it visible).
    engines="$(gsettings get org.freedesktop.ibus.general preload-engines 2>/dev/null || true)"
    if printf '%s' "$engines" | grep -qE "^(@as \[\]|\['xkb:[^']*'\])$"; then
        gsettings set org.freedesktop.ibus.panel show-icon-on-systray false 2>/dev/null || true
        echo "[✓] Hid the redundant IBus tray icon (its menu opens in the screen corner)"
    fi
fi

echo "=== Done! Keyboard language is now global and will not switch between windows. ==="
