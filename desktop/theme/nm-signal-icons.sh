#!/usr/bin/env bash
# Wi-Fi signal icons in the tray: nm-applet uses the legacy "nm-signal-*" names, which only the
# old blue-bars set in hicolor provides, so the tray looks dated next to a modern icon theme.
# Render the icon theme's own network-wireless-signal-* icons under those names in the user's
# icon directory (per user, no root, nothing in /usr is touched).
#   nm-signal-icons.sh           install
#   nm-signal-icons.sh --undo    remove them
set -euo pipefail

THEME="${EASYLINUX_SIGNAL_THEME:-elementary}"
ICONS="${EASYLINUX_ICONS_DIR:-/usr/share/icons}"
OUT="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
SIZES="16 22 24 32 48"
MAP="00:none 25:weak 50:ok 75:good 100:excellent"
MARK="$OUT/.easylinux-nm-signal"

if [ "${1:-}" = --undo ]; then
    if [ -f "$MARK" ]; then
        for s in $SIZES; do
            for m in $MAP; do rm -f "$OUT/${s}x${s}/apps/nm-signal-${m%%:*}.png"; done
        done
        rm -f "$MARK"
        echo "[✓] Wi-Fi signal icons restored to the defaults"
    else
        echo "[skip] no easylinux Wi-Fi signal icons installed"
    fi
    exit 0
fi

echo "==> Wi-Fi signal icons"
src() {   # path of the theme's icon for a wireless level
    find "$ICONS/$THEME" -name "network-wireless-signal-$1.svg" ! -path '*symbolic*' 2>/dev/null | sort -t/ -k6 -n | tail -1
}
if [ -z "$(src good)" ]; then
    echo "[skip] icon theme '$THEME' has no network-wireless-signal icons"
    exit 0
fi
command -v python3 >/dev/null 2>&1 || { echo "[skip] python3 not found"; exit 0; }

python3 -I - "$OUT" "$SIZES" "$MAP" "$ICONS/$THEME" <<'PY'
import os, subprocess, sys
import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
out, sizes, mapping, theme = sys.argv[1], sys.argv[2].split(), sys.argv[3].split(), sys.argv[4]
def find(level):
    best = None
    for root, _, files in os.walk(theme):
        if 'symbolic' in root: continue
        f = 'network-wireless-signal-%s.svg' % level
        if f in files:
            p = os.path.join(root, f)
            if best is None or len(p) < len(best): best = p
    return best
for m in mapping:
    num, level = m.split(':')
    p = find(level)
    if not p: continue
    for s in sizes:
        d = os.path.join(out, '%sx%s' % (s, s), 'apps'); os.makedirs(d, exist_ok=True)
        GdkPixbuf.Pixbuf.new_from_file_at_size(p, int(s), int(s)).savev(os.path.join(d, 'nm-signal-%s.png' % num), 'png', [], [])
PY
touch "$MARK"
gtk-update-icon-cache -f -t "$OUT" >/dev/null 2>&1 || true
echo "[✓] nm-signal-* icons now come from the $THEME icon theme (undo: $0 --undo)"
