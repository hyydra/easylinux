#!/usr/bin/env bash
set -euo pipefail

echo "==> Uninstalling XFCE Panel Watchdog..."

# Stop and disable systemd service
if systemctl --user is-active --quiet xfce4-panel-watchdog.service 2>/dev/null; then
    systemctl --user stop xfce4-panel-watchdog.service || true
fi
systemctl --user disable xfce4-panel-watchdog.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/xfce4-panel-watchdog.service"
systemctl --user daemon-reload || true
echo "[✓] Removed systemd user service"

# Remove script and autostart
rm -f "$HOME/.local/bin/xfce4-panel-watchdog.sh"
rm -f "$HOME/.config/autostart/xfce4-panel-watchdog.desktop"
echo "[✓] Removed binary and autostart files"

echo "==> XFCE Panel Watchdog uninstalled."
