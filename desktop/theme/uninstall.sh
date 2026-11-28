#!/usr/bin/env bash
# Put back the look the user had before desktop/theme/install.sh, and stop the light/dark timer.
set -euo pipefail
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/easylinux/theme-backup"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [ -z "${ES_TEST:-}" ]; then systemctl --user disable --now easylinux-theme.timer >/dev/null 2>&1 || true; fi
rm -f "$UNITS/easylinux-theme.timer" "$UNITS/easylinux-theme.service" "$HOME/.local/bin/easylinux-theme"
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/easylinux/theme.conf"

if [ ! -f "$BACKUP" ]; then echo "[skip] No saved theme settings ($BACKUP)"; exit 0; fi
while IFS=$'\t' read -r channel prop value; do
    if [ "$channel" = gsettings ]; then
        command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface "$prop" "${value:-default}" 2>/dev/null || true
    elif [ -n "$value" ]; then
        xfconf-query -c "$channel" -p "$prop" -n -t string -s "$value"
    else
        xfconf-query -c "$channel" -p "$prop" -r 2>/dev/null || true
    fi
done < "$BACKUP"
rm -f "$BACKUP"
echo "[✓] Previous theme, icons and fonts restored; light/dark timer removed"
