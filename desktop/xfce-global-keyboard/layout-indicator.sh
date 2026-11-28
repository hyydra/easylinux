#!/usr/bin/env bash
# Replace the xkb panel plugin with a Generic Monitor (genmon) that shows the layout in capitals
# ("HU") in the normal panel font. The xkb plugin hard-codes a bold monospace font and lowercase
# codes. Clicking switches to the next layout, like before. Per user, no root.
#   layout-indicator.sh          install
#   layout-indicator.sh --undo   put the xkb plugin back
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/easylinux-layout"
FONT="${EASYLINUX_LAYOUT_FONT:-Noto Sans 10}"
q() { xfconf-query -c xfce4-panel "$@"; }

echo "==> Keyboard layout indicator"
if ! command -v xfconf-query >/dev/null 2>&1; then echo "[skip] not XFCE"; exit 0; fi

panel_ids() { q -p "$1/plugin-ids" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)$/\1/p'; }
set_ids() {   # $1 = panel path, rest = ids
    local panel="$1"; shift
    local args=() id
    for id in "$@"; do args+=(-t int -s "$id"); done
    q -p "$panel/plugin-ids" --force-array "${args[@]}"
}
find_panel_with() {   # plugin type -> "panel-path id"
    local panel id
    for panel in $(q -p /panels 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)$/\/panels\/panel-\1/p'); do
        for id in $(panel_ids "$panel"); do
            [ "$(q -p "/plugins/plugin-$id" 2>/dev/null)" = "$1" ] && { echo "$panel $id"; return 0; }
        done
    done
    return 1
}
swap() {   # replace plugin id $2 by $3 in panel $1, same position
    local panel="$1" old="$2" new="$3" ids=() id
    for id in $(panel_ids "$panel"); do [ "$id" = "$old" ] && ids+=("$new") || ids+=("$id"); done
    set_ids "$panel" "${ids[@]}"
}
restart_panel() { [ -n "${ES_TEST:-}" ] || (setsid xfce4-panel -r >/dev/null 2>&1 &); }

if [ "${1:-}" = --undo ]; then
    if read -r panel gid < <(find_panel_with genmon) && [ -n "$(q -p "/plugins/plugin-$gid/easylinux-replaced" 2>/dev/null)" ]; then
        xid="$(q -p "/plugins/plugin-$gid/easylinux-replaced")"
        swap "$panel" "$gid" "$xid"
        q -p "/plugins/plugin-$gid" -r -R
        restart_panel
        echo "[✓] xkb plugin restored"
    else
        echo "[skip] no easylinux layout indicator found"
    fi
    exit 0
fi

if ! dpkg -s xfce4-genmon-plugin >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; then
    echo "[!] xfce4-genmon-plugin is not installed: sudo apt install xfce4-genmon-plugin"
    exit 1
fi
mkdir -p "$(dirname "$BIN")"
install -m 755 "$SCRIPT_DIR/easylinux-layout" "$BIN"

if read -r panel gid < <(find_panel_with genmon) && [ -n "$(q -p "/plugins/plugin-$gid/easylinux-replaced" 2>/dev/null)" ]; then
    echo "[✓] Layout indicator already installed (plugin-$gid)"
    exit 0
fi
if ! read -r panel xid < <(find_panel_with xkb); then
    echo "[skip] no xkb layout plugin on the panel"
    exit 0
fi

gid=$(( $(q -l | sed -n 's|^/plugins/plugin-\([0-9][0-9]*\).*|\1|p' | sort -n | tail -1) + 1 ))
P="/plugins/plugin-$gid"
q -p "$P" -n -t string -s genmon
q -p "$P/command" -n -t string -s "$BIN genmon-$gid"
q -p "$P/use-label" -n -t bool -s false
q -p "$P/update-period" -n -t int -s 30000      # clicks redraw at once; this only catches outside changes
q -p "$P/font" -n -t string -s "$FONT"
q -p "$P/enable-single-row" -n -t bool -s true
q -p "$P/easylinux-replaced" -n -t int -s "$xid"
swap "$panel" "$xid" "$gid"
restart_panel
echo "[✓] Layout indicator: genmon plugin-$gid replaces xkb plugin-$xid (undo: $0 --undo)"
