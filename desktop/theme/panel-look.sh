#!/usr/bin/env bash
# A tidier XFCE panel to go with the Yaru/elementary theme (per user, no root):
#   - bar 36 px with 28 px icons for the menu button and task list, and smaller (18 px) status tray
#     icons, so the tray has room to breathe instead of everything being the same cramped size
#   - bar position locked and no task-list handle: no dotted drag-handle marks at the ends
#   - weather plugin: flat "simplistic" icon set instead of the glossy "liquid" one
#   - battery plugin: an icon next to the percentage instead of the coloured bar
#   - nm-applet in indicator mode + Wi-Fi signal icons from the icon theme (nm-signal-icons.sh)
# The previous values are saved once; panel-look.sh --undo puts them back.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/easylinux"
BACKUP="$STATE/panel-look-backup"
PANEL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/panel"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/nm-applet.desktop"
WEATHER="${EASYLINUX_WEATHER_ICONS:-/usr/share/xfce4/weather/icons}"
SIZE=36; ICON_SIZE=28; TRAY_ICON_SIZE=18
q() { xfconf-query -c xfce4-panel "$@"; }

echo "==> Panel look"
if ! command -v xfconf-query >/dev/null 2>&1; then echo "[skip] not XFCE"; exit 0; fi

plugin_ids() {   # $1 = plugin type -> ids
    local p
    for p in $(q -l 2>/dev/null | sed -n 's|^/plugins/plugin-\([0-9][0-9]*\)$|\1|p'); do
        [ "$(q -p "/plugins/plugin-$p" 2>/dev/null)" = "$1" ] && echo "$p"
    done
    return 0
}
panel_paths() { q -l 2>/dev/null | sed -n 's|^\(/panels/panel-[0-9][0-9]*\)/size$|\1|p'; }
panel_running() { pgrep -x xfce4-panel >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; }

# every xfconf property this script writes: "path<TAB>type<TAB>value"
writes() {
    local panel id
    for panel in $(panel_paths); do
        printf '%s/size\tuint\t%s\n' "$panel" "$SIZE"
        printf '%s/icon-size\tuint\t%s\n' "$panel" "$ICON_SIZE"
        printf '%s/position-locked\tbool\ttrue\n' "$panel"
    done
    for id in $(plugin_ids tasklist); do printf '/plugins/plugin-%s/show-handle\tbool\tfalse\n' "$id"; done
    for id in $(plugin_ids systray); do
        printf '/plugins/plugin-%s/icon-size\tuint\t%s\n' "$id" "$TRAY_ICON_SIZE"
        printf '/plugins/plugin-%s/square-icons\tbool\ttrue\n' "$id"
    done
    if [ -d "$WEATHER/simplistic" ]; then
        for id in $(plugin_ids weather); do printf '/plugins/plugin-%s/theme-dir\tstring\t%s/simplistic\n' "$id" "$WEATHER"; done
    fi
}

if [ "${1:-}" = --undo ]; then
    if [ ! -f "$BACKUP" ]; then echo "[skip] no saved panel settings"; exit 0; fi
    stopped=0; if panel_running; then xfce4-panel -q || true; stopped=1; sleep 1; fi
    while IFS=$'\t' read -r kind path type value; do
        case "$kind" in
            x) if [ "$value" = "<unset>" ]; then q -p "$path" -r 2>/dev/null || true; else q -p "$path" -n -t "$type" -s "$value"; fi ;;
            f) cp -f "$STATE/$path" "$PANEL_DIR/$(basename "$path" .bak)" 2>/dev/null || true ;;
        esac
    done < "$BACKUP"
    rm -f "$AUTOSTART" "$BACKUP"
    bash "$SCRIPT_DIR/nm-signal-icons.sh" --undo
    if [ "$stopped" = 1 ]; then (setsid xfce4-panel >/dev/null 2>&1 &); fi
    echo "[✓] Panel look restored"
    exit 0
fi

# save the originals once
if [ ! -f "$BACKUP" ]; then
    mkdir -p "$STATE"
    : > "$BACKUP"
    while IFS=$'\t' read -r path type value; do
        old="$(q -p "$path" 2>/dev/null || echo "<unset>")"
        printf 'x\t%s\t%s\t%s\n' "$path" "$type" "$old" >> "$BACKUP"
    done < <(writes)
    for rc in "$PANEL_DIR"/battery-*.rc; do
        [ -f "$rc" ] || continue
        cp -f "$rc" "$STATE/$(basename "$rc").bak"
        printf 'f\t%s\t-\t-\n' "$(basename "$rc").bak" >> "$BACKUP"
    done
fi

# the battery plugin rewrites its rc file when the panel quits, so edit it with the panel stopped
stopped=0
if compgen -G "$PANEL_DIR/battery-*.rc" >/dev/null && panel_running; then xfce4-panel -q || true; stopped=1; sleep 1; fi
while IFS=$'\t' read -r path type value; do q -p "$path" -n -t "$type" -s "$value"; done < <(writes)
for rc in "$PANEL_DIR"/battery-*.rc; do
    [ -f "$rc" ] || continue
    sed -i 's/^display_icon=.*/display_icon=true/; s/^display_bar=.*/display_bar=false/' "$rc"
done
if [ "$stopped" = 1 ]; then (setsid xfce4-panel >/dev/null 2>&1 &); fi
echo "[✓] Panel $SIZE px, icons $ICON_SIZE px (tray $TRAY_ICON_SIZE px), locked, battery icon, flat weather icons"

# Wi-Fi: nm-applet in indicator mode, icons from the icon theme
if [ -f /etc/xdg/autostart/nm-applet.desktop ]; then
    mkdir -p "$(dirname "$AUTOSTART")"
    sed 's|^Exec=nm-applet.*|Exec=nm-applet --indicator|' /etc/xdg/autostart/nm-applet.desktop > "$AUTOSTART"
    if pgrep -x nm-applet >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; then
        pkill -x nm-applet || true; (setsid nm-applet --indicator >/dev/null 2>&1 &)
    fi
fi
bash "$SCRIPT_DIR/nm-signal-icons.sh" || true
