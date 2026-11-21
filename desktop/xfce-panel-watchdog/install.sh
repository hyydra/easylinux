#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing XFCE Panel Watchdog..."

# Ensure target directories exist
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/autostart"

# Copy watchdog script
install -m 755 "$SCRIPT_DIR/xfce4-panel-watchdog.sh" "$HOME/.local/bin/xfce4-panel-watchdog.sh"
echo "[✓] Copied script to ~/.local/bin/xfce4-panel-watchdog.sh"

# Install systemd service
cp "$SCRIPT_DIR/xfce4-panel-watchdog.service" "$HOME/.config/systemd/user/xfce4-panel-watchdog.service"
systemctl --user daemon-reload
systemctl --user enable --now xfce4-panel-watchdog.service
echo "[✓] Enabled and started systemd user service: xfce4-panel-watchdog.service"

# Create XDG autostart desktop entry as fallback
cat << 'EOF' > "$HOME/.config/autostart/xfce4-panel-watchdog.desktop"
[Desktop Entry]
Type=Application
Name=XFCE Panel Watchdog
Comment=Automatically restarts xfce4-panel if it crashes
Exec=%h/.local/bin/xfce4-panel-watchdog.sh
Terminal=false
StartupNotify=false
OnlyShowIn=XFCE;
EOF
echo "[✓] Configured XDG desktop autostart entry"

echo "==> Installation complete! Watchdog is now active."
