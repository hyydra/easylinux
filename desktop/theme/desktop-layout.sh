#!/usr/bin/env bash
# Desktop layout for XFCE (per user, no root):
#   - desktop icons in columns at the far right edge of the screen (gravity "top right, by columns")
#   - no "Arrange Icons: are you sure?" confirmation, ever
#   - a single workspace, and the same desktop (background, icons) on every workspace
# The previous values are saved once; desktop-layout.sh --undo puts them back.
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/easylinux"
BACKUP="$STATE/desktop-layout-backup"

echo "==> Desktop layout"
if ! command -v xfconf-query >/dev/null 2>&1; then echo "[skip] not XFCE"; exit 0; fi

# channel<TAB>property<TAB>type<TAB>value
settings() {
    printf 'xfce4-desktop\t/desktop-icons/gravity\tint\t2\n'
    printf 'xfce4-desktop\t/desktop-icons/confirm-sorting\tbool\tfalse\n'
    printf 'xfce4-desktop\t/backdrop/single-workspace-mode\tbool\ttrue\n'
    printf 'xfce4-desktop\t/backdrop/single-workspace-number\tint\t0\n'
    printf 'xfwm4\t/general/workspace_count\tint\t1\n'
}

# xfdesktop's own "arrange" re-lays the existing icons for the new gravity; it may leave a small
# notice window behind, which is closed again (only windows that belong to xfdesktop itself).
arrange_icons() {
    pgrep -x xfdesktop >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ] || return 0
    sleep 1; xfdesktop --arrange >/dev/null 2>&1 || true; sleep 2
    command -v wmctrl >/dev/null 2>&1 || return 0
    local pid id
    for pid in $(pgrep -x xfdesktop); do
        for id in $(wmctrl -lp | awk -v p="$pid" '$3==p && $1 !~ /^$/ && $0 !~ /Desktop$/ {print $1}'); do wmctrl -ic "$id" || true; done
    done
}

if [ "${1:-}" = --undo ]; then
    if [ ! -f "$BACKUP" ]; then echo "[skip] no saved desktop layout"; exit 0; fi
    while IFS=$'\t' read -r channel prop type value; do
        if [ "$value" = "<unset>" ]; then xfconf-query -c "$channel" -p "$prop" -r 2>/dev/null || true
        else xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value"; fi
    done < "$BACKUP"
    rm -f "$BACKUP"
    arrange_icons
    echo "[✓] Desktop layout restored"
    exit 0
fi

if [ ! -f "$BACKUP" ]; then
    mkdir -p "$STATE"; : > "$BACKUP"
    while IFS=$'\t' read -r channel prop type value; do
        printf '%s\t%s\t%s\t%s\n' "$channel" "$prop" "$type" "$(xfconf-query -c "$channel" -p "$prop" 2>/dev/null || echo '<unset>')" >> "$BACKUP"
    done < <(settings)
fi
while IFS=$'\t' read -r channel prop type value; do xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value"; done < <(settings)
arrange_icons
echo "[✓] Icons at the far right, no arrange prompt, one workspace (undo: $0 --undo)"
