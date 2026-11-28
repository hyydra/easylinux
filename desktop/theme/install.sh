#!/usr/bin/env bash
# One consistent, modern look for XFCE: Yaru for GTK widgets and window frames, Papirus icons, Noto Sans,
# with automatic light/dark switching by time of day (default 07:00 light, 19:00 dark).
# The stock Xubuntu setup mixes Greybird (flat grey GTK) with the plain Default xfwm4 frame, so
# dialogs look unpolished. Per user, no root; the previous values are saved once and
# uninstall.sh puts them back. Needs yaru-theme-gtk; papirus-icon-theme and fonts-noto-core are
# used when installed. Only packages from the distribution's official archive; nothing is
# installed from here (and no third-party snaps).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES="${EASYLINUX_THEMES_DIR:-/usr/share/themes}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/easylinux"
BACKUP="$STATE/theme-backup"
BIN="$HOME/.local/bin/easylinux-theme"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

echo "==> Yaru theme with light/dark cycle"
if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "[skip] xfconf-query not found: this module is for XFCE"
    exit 0
fi
if [ ! -d "$THEMES/Yaru/gtk-3.0" ] || [ ! -d "$THEMES/Yaru/xfwm4" ]; then
    echo "[!] The Yaru theme is not installed: sudo apt install yaru-theme-gtk yaru-theme-icon"
    exit 1
fi

get() { xfconf-query -c "$1" -p "$2" 2>/dev/null || true; }

# save what the user had, once, so a re-run never overwrites the original
if [ ! -f "$BACKUP" ]; then
    mkdir -p "$STATE"
    {
        printf 'xsettings\t/Net/ThemeName\t%s\n'     "$(get xsettings /Net/ThemeName)"
        printf 'xsettings\t/Net/IconThemeName\t%s\n' "$(get xsettings /Net/IconThemeName)"
        printf 'xsettings\t/Gtk/FontName\t%s\n'      "$(get xsettings /Gtk/FontName)"
        printf 'xfwm4\t/general/theme\t%s\n'         "$(get xfwm4 /general/theme)"
        printf 'xfwm4\t/general/title_font\t%s\n'    "$(get xfwm4 /general/title_font)"
        if command -v gsettings >/dev/null 2>&1; then
            printf 'gsettings\tcolor-scheme\t%s\n' "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
        fi
    } > "$BACKUP"
fi

ICONS="${EASYLINUX_ICONS_DIR:-/usr/share/icons}"
if [ ! -d "$ICONS/Papirus-Light" ]; then
    echo "[i] Papirus icons not installed (official package): sudo apt install papirus-icon-theme; using Yaru icons until then"
fi
if command -v fc-list >/dev/null 2>&1 && fc-list : family | grep -qx 'Noto Sans'; then
    xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Noto Sans 10"
    xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "Noto Sans Bold 10"
fi

mkdir -p "$(dirname "$BIN")"
install -m 755 "$SCRIPT_DIR/easylinux-theme" "$BIN"

# check the schedule every 10 minutes and at login; the switch itself only happens when it changes
mkdir -p "$UNITS"
cat > "$UNITS/easylinux-theme.service" <<EOF
[Unit]
Description=easylinux: light/dark theme by time of day

[Service]
Type=oneshot
ExecStart=$BIN --timer
EOF
cat > "$UNITS/easylinux-theme.timer" <<EOF
[Unit]
Description=easylinux: light/dark theme by time of day

[Timer]
OnStartupSec=5s
OnCalendar=*:0/10
Persistent=true

[Install]
WantedBy=timers.target
EOF
if [ -z "${ES_TEST:-}" ] && systemctl --user daemon-reload 2>/dev/null; then
    systemctl --user enable --now easylinux-theme.timer >/dev/null 2>&1 || true
    echo "[✓] Light/dark timer enabled (systemd --user)"
else
    echo "[!] systemd --user not available: switch by hand with 'easylinux-theme light|dark|toggle'"
fi

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/easylinux/theme.conf"
if [ -f "$CONF" ]; then "$BIN" --timer; else "$BIN" auto; fi
echo "[✓] Yaru theme on; $("$BIN" status). Change the times in $CONF (undo: desktop/theme/uninstall.sh)"
