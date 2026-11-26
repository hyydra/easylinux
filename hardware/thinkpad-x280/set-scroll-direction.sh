#!/usr/bin/env bash
# Set the touchpad scroll direction.
#   natural      content follows your fingers (like a phone / macOS)
#   traditional  wheel-style: fingers down = page scrolls down
#   toggle       flip the current direction
# Applies immediately in the running session (xinput/synclient, no root) and, if the
# system synaptics config from setup-touchpad-split.sh is installed, also persists it
# for the next login (needs sudo; the file is snapshotted first, undo: easylinux --rollback).
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
CONFS=(/etc/X11/xorg.conf.d/70-synaptics.conf /etc/X11/xorg.conf.d/99-synaptics-custom.conf)

current_direction() {
    local conf
    for conf in "${CONFS[@]}"; do
        if [ -f "$conf" ]; then
            grep -q 'Option "VertScrollDelta" "-' "$conf" && echo natural || echo traditional
            return
        fi
    done
    local id
    for id in $(touchpad_ids); do
        if [ "$(xinput list-props "$id" 2>/dev/null | awk -F: '/Natural Scrolling Enabled \(/{gsub(/[ \t]/,"",$2); print $2; exit}')" = 1 ]; then
            echo natural; return
        fi
    done
    echo traditional
}

touchpad_ids() {
    xinput list 2>/dev/null | grep 'slave  pointer' | grep -iE 'touchpad|synaptics' | grep -viE 'trackpoint|virtual' \
        | sed -n 's/.*id=\([0-9]*\).*/\1/p'
}

persist() {   # runs as root
    local want="$1" conf sign="-"
    [ "$want" = natural ] || sign=""
    # shellcheck source=../../safety/lib.sh
    source "$(dirname "$SELF")/../../safety/lib.sh"
    es_begin scroll-direction
    for conf in "${CONFS[@]}"; do
        [ -f "$conf" ] || continue
        es_backup "$conf"
        sed -i -E "s|(Option \"(Vert\|Horiz)ScrollDelta\" \")-?([0-9]+)\"|\1${sign}\3\"|" "$conf"
    done
    echo "[✓] Persisted '$want' in the X config (takes effect at the next login)."
}

if [ "${1:-}" = --persist-only ]; then persist "$2"; exit 0; fi

want="${1:-}"
if [ "$want" = toggle ]; then
    [ "$(current_direction)" = natural ] && want=traditional || want=natural
fi
case "$want" in natural|traditional) ;; *) echo "Usage: ${EASYLINUX_PROG:-$0} natural|traditional|toggle"; exit 1 ;; esac

# 1. live
val=0; [ "$want" = natural ] && val=1
applied=0
if [ -n "${DISPLAY:-}" ] && command -v xinput >/dev/null 2>&1; then
    for id in $(touchpad_ids); do
        if xinput list-props "$id" | grep -q 'libinput Natural Scrolling Enabled ('; then
            xinput set-prop "$id" "libinput Natural Scrolling Enabled" "$val"
            applied=1
        fi
    done
fi
if command -v synclient >/dev/null 2>&1 && synclient -l >/dev/null 2>&1; then
    d=111; [ "$want" = natural ] && d=-111
    synclient VertScrollDelta="$d" HorizScrollDelta="$d" && applied=1
fi
[ "$applied" = 1 ] && echo "[✓] Scroll direction is now '$want' in this session." \
                   || echo "[!] No running touchpad found to change live."

# 2. persist for the next login (synaptics config installed by setup-touchpad-split.sh)
for conf in "${CONFS[@]}"; do
    if [ -f "$conf" ]; then
        if grep -q 'Option "VertScrollDelta" "-' "$conf"; then in_conf=natural; else in_conf=traditional; fi
        if [ "$in_conf" = "$want" ]; then
            echo "[✓] The X config already says '$want': nothing to persist."
        elif [ "$(id -u)" -eq 0 ]; then persist "$want"; else sudo bash "$SELF" --persist-only "$want"; fi
        break
    fi
done
