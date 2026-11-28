#!/usr/bin/env bash
# A tidier XFCE panel to go with the Yaru/elementary theme (per user, no root):
#   - roomy bar: 48 px high, 32 px icons for the menu button and task list, 22 px status tray icons,
#     and 4x8 px padding on the panel buttons (bigger click targets)
#   - the menu button shows its icon plus the word "Start": a wide target that is easy to hit
#   - bar position locked and no task-list handle: no dotted drag-handle marks at the ends
#   - weather plugin: flat "simplistic" icon set instead of the glossy "liquid" one
#   - battery plugin: an icon next to the percentage instead of the coloured bar
#   - taller start (Whisker) menu that fits the screen, without the dark outline (GTK CSS block)
#   - the user-name menu button ("peti": log out / lock) is removed; the Start menu has those buttons
#   - a minimalist, colourless icon set for the battery and the desktop icons (minimal-icons.sh)
#   - nm-applet in indicator mode + Wi-Fi signal icons from the icon theme (nm-signal-icons.sh)
# The previous values are saved once; panel-look.sh --undo puts them back.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/easylinux"
BACKUP="$STATE/panel-look-backup"
PANEL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/panel"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/nm-applet.desktop"
GTK_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css"
WEATHER="${EASYLINUX_WEATHER_ICONS:-/usr/share/xfce4/weather/icons}"
SIZE=48; ICON_SIZE=32; TRAY_ICON_SIZE=22
q() { xfconf-query -c xfce4-panel "$@"; }

# start menu height: as tall as fits above the bar (screen height - bar - a margin), 400..800 px
screen_h="$(xdpyinfo 2>/dev/null | sed -n 's/.*dimensions: *[0-9]*x\([0-9]*\) pixels.*/\1/p' | head -1 || true)"
MENU_H=$(( ${screen_h:-0} > 0 ? screen_h - SIZE - 40 : 640 ))
[ "$MENU_H" -lt 400 ] && MENU_H=400; [ "$MENU_H" -gt 800 ] && MENU_H=800
CSS_BEGIN="/* easylinux-whisker: start menu without the dark outline */"
CSS_END="/* end easylinux-whisker */"

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
    for id in $(plugin_ids whiskermenu); do
        printf '/plugins/plugin-%s/menu-height\tint\t%s\n' "$id" "$MENU_H"
        printf '/plugins/plugin-%s/menu-width\tint\t480\n' "$id"
        printf '/plugins/plugin-%s/show-button-title\tbool\ttrue\n' "$id"
        printf '/plugins/plugin-%s/button-title\tstring\tStart\n' "$id"
        printf '/plugins/plugin-%s/show-button-icon\tbool\ttrue\n' "$id"
    done
    for id in $(plugin_ids systray); do
        printf '/plugins/plugin-%s/icon-size\tuint\t%s\n' "$id" "$TRAY_ICON_SIZE"
        printf '/plugins/plugin-%s/square-icons\tbool\ttrue\n' "$id"
    done
    if [ -d "$WEATHER/simplistic" ]; then
        for id in $(plugin_ids weather); do printf '/plugins/plugin-%s/theme-dir\tstring\t%s/simplistic\n' "$id" "$WEATHER"; done
    fi
}

# plugin-ids of a panel as a space-separated list, and the reverse
panel_ids() { q -p "$1/plugin-ids" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)$/\1/p' | paste -sd' '; }
set_panel_ids() {
    local panel="$1"; shift
    local args=() id
    for id in "$@"; do args+=(-t int -s "$id"); done
    q -p "$panel/plugin-ids" --force-array "${args[@]}"
}

if [ "${1:-}" = --undo ]; then
    if [ ! -f "$BACKUP" ]; then echo "[skip] no saved panel settings"; exit 0; fi
    stopped=0; if panel_running; then xfce4-panel -q || true; stopped=1; sleep 1; fi
    while IFS=$'\t' read -r kind path type value; do
        case "$kind" in
            x) if [ "$value" = "<unset>" ]; then q -p "$path" -r 2>/dev/null || true; else q -p "$path" -n -t "$type" -s "$value"; fi ;;
            f) cp -f "$STATE/$path" "$PANEL_DIR/$(basename "$path" .bak)" 2>/dev/null || true ;;
            a) # shellcheck disable=SC2086
               set_panel_ids "$path" $value ;;
        esac
    done < "$BACKUP"
    if [ -f "$GTK_CSS" ] && grep -qE "easylinux-(whisker|panel-padding)" "$GTK_CSS"; then
        sed -i '/easylinux-whisker: start menu/,/end easylinux-whisker/d' "$GTK_CSS"
        sed -i '/easylinux-panel-padding/,/end easylinux-panel-padding/d' "$GTK_CSS"
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$GTK_CSS"
    fi
    rm -f "$AUTOSTART" "$BACKUP"
    bash "$SCRIPT_DIR/nm-signal-icons.sh" --undo
    bash "$SCRIPT_DIR/minimal-icons.sh" --undo
    [ -x "$HOME/.local/bin/easylinux-theme" ] && "$HOME/.local/bin/easylinux-theme" refresh || true
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
    for panel in $(panel_paths); do
        printf 'a\t%s\t-\t%s\n' "$panel" "$(panel_ids "$panel")" >> "$BACKUP"
    done
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
# drop the user-name menu button ("actions" plugin) from the panels
actions="$(plugin_ids actions | paste -sd' ')"
if [ -n "$actions" ]; then
    for panel in $(panel_paths); do
        keep=(); for id in $(panel_ids "$panel"); do case " $actions " in *" $id "*) ;; *) keep+=("$id") ;; esac; done
        set_panel_ids "$panel" "${keep[@]}"
    done
fi
if [ "$stopped" = 1 ]; then (setsid xfce4-panel >/dev/null 2>&1 &); fi
echo "[✓] Panel $SIZE px, icons $ICON_SIZE px (tray $TRAY_ICON_SIZE px), locked, battery icon, flat weather icons, start menu ${MENU_H}px, wide Start button"

# start menu without the dark outline: one marked block in the user's GTK CSS (kept idempotent)
mkdir -p "$(dirname "$GTK_CSS")"; touch "$GTK_CSS"
if ! grep -qF "easylinux-whisker" "$GTK_CSS"; then
    cat >> "$GTK_CSS" <<EOF

$CSS_BEGIN
#whiskermenu-window,
#whiskermenu-window decoration,
#whiskermenu-window > box {
    border: none;
    box-shadow: none;
    outline: none;
}
$CSS_END
EOF
fi
if ! grep -qF "easylinux-panel-padding" "$GTK_CSS"; then
    cat >> "$GTK_CSS" <<'EOF'

/* easylinux-panel-padding: roomier panel buttons, bigger click targets */
.xfce4-panel button {
    padding: 4px 8px;
    min-height: 36px;
}
/* end easylinux-panel-padding */
EOF
fi
if [ "$stopped" = 0 ] && panel_running; then (setsid xfce4-panel -r >/dev/null 2>&1 &); fi

# Wi-Fi: nm-applet in indicator mode, icons from the icon theme
if [ -f /etc/xdg/autostart/nm-applet.desktop ]; then
    mkdir -p "$(dirname "$AUTOSTART")"
    sed 's|^Exec=nm-applet.*|Exec=nm-applet --indicator|' /etc/xdg/autostart/nm-applet.desktop > "$AUTOSTART"
    if pgrep -x nm-applet >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; then
        pkill -x nm-applet || true; (setsid nm-applet --indicator >/dev/null 2>&1 &)
    fi
fi
bash "$SCRIPT_DIR/minimal-icons.sh" || true
[ -x "$HOME/.local/bin/easylinux-theme" ] && "$HOME/.local/bin/easylinux-theme" refresh || true
bash "$SCRIPT_DIR/nm-signal-icons.sh" || true
