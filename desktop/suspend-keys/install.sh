#!/usr/bin/env bash
# Suspend keys for XFCE.
# xfce4-power-manager holds the logind key handling, but on some machines it does not act on
# the key (logind logs "Suspend key pressed short." and nothing sleeps). Binding the keys
# directly to `systemctl suspend` makes them work. Per user, no root.
#   Fn+4 (ThinkPad)        XF86Sleep / XF86Suspend
#   power button           XF86PowerOff (only if the firmware delivers a short press)
set -euo pipefail

echo "==> Suspend keys"
if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "[skip] xfconf-query not found: bind XF86Sleep/XF86Suspend to 'systemctl suspend' in your desktop"
    exit 0
fi
for key in XF86Sleep XF86Suspend XF86PowerOff; do
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -n -t string -s "systemctl suspend"
done
echo "[✓] Bound XF86Sleep, XF86Suspend (Fn+4) and XF86PowerOff to 'systemctl suspend'"
