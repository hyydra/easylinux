#!/usr/bin/env bash
# A minimalist, colourless (grey) icon set, generated here: battery icons (flat outline, level bar, a bolt while
# charging) and the desktop icons the theme provides (home, folder, file system, removable drive,
# trash). It is installed as a small user icon theme "easylinux" that inherits the main icon theme
# (elementary) and only adds these icons, so nothing else changes. Per user, no root.
#   minimal-icons.sh           generate and install
#   minimal-icons.sh --undo    remove it again
# Names covered: battery-{empty,caution,low,good,full}[-charging], battery-full-charged,
# xfce4-battery-{critical,low,ok,full}[-charging] (xfce4-battery-plugin), battery-missing and battery-level-{0..100}[-charging|-charged]-symbolic
# (upower, xfce4-power-manager and GTK status icons).
set -euo pipefail

BASE="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
DIR="$BASE/easylinux"
PARENT="${EASYLINUX_ICON_PARENT:-elementary}"

if [ "${1:-}" = --undo ]; then
    rm -rf "$DIR"
    echo "[✓] Minimalist icons removed"
    exit 0
fi

echo "==> Minimalist icons"
command -v python3 >/dev/null 2>&1 || { echo "[skip] python3 not found"; exit 0; }
rm -rf "$DIR"; mkdir -p "$DIR/status/scalable" "$DIR/status/symbolic" "$DIR/places/scalable" "$DIR/devices/scalable"

python3 -I - "$DIR" <<'PY'
import os, sys
out = sys.argv[1]
INK = "#4b5563"
def colour(p):
    return INK   # no colour: the level is shown by how much of the bar is filled
BOLT = "11.6,6.6 7,12.7 10.3,12.7 9.4,17.4 14.2,11.1 10.9,11.1"

def svg(percent, charging, symbolic=False, missing=False):
    ink = "#2e3436" if symbolic else INK
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">',
             '<rect x="1.5" y="6.5" width="18" height="11" rx="2.5" fill="none" stroke="%s" stroke-width="1.5"/>' % ink,
             '<rect x="20.5" y="10" width="2" height="4" rx="1" fill="%s"/>' % ink]
    if missing:
        parts.append('<path d="M7 9.5l7 5M14 9.5l-7 5" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % ink)
    elif percent > 0:
        w = max(1.2, 14.0 * percent / 100.0)
        parts.append('<rect x="3.5" y="8.5" width="%.2f" height="7" rx="1" fill="%s"/>' % (w, ink if symbolic else colour(percent)))
    if charging and not missing:
        if symbolic:
            parts.append('<polygon points="%s" fill="none" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/>' % BOLT)
            parts.append('<polygon points="%s" fill="%s" opacity=".0"/>' % (BOLT, ink))
        else:
            parts.append('<polygon points="%s" fill="#ffffff" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (BOLT, INK))
    parts.append('</svg>')
    return "\n".join(parts) + "\n"

def write(sub, name, text):
    with open(os.path.join(out, "status", sub, name + ".svg"), "w") as f:
        f.write(text)

named = {"empty": 0, "caution": 15, "low": 35, "good": 70, "full": 100}
for n, p in named.items():
    write("scalable", "battery-%s" % n, svg(p, False))
    write("scalable", "battery-%s-charging" % n, svg(p, True))
# the names the xfce4-battery-plugin panel plugin asks for
for n, pc in {"critical": 10, "low": 30, "ok": 70, "full": 100}.items():
    write("scalable", "xfce4-battery-%s" % n, svg(pc, False))
    write("scalable", "xfce4-battery-%s-charging" % n, svg(pc, True))
write("scalable", "battery-full-charged", svg(100, True))
write("scalable", "battery-missing", svg(0, False, missing=True))
for lvl in range(0, 101, 10):
    write("symbolic", "battery-level-%d-symbolic" % lvl, svg(lvl, False, True))
    write("symbolic", "battery-level-%d-charging-symbolic" % lvl, svg(lvl, True, True))
write("symbolic", "battery-level-100-charged-symbolic", svg(100, True, True))
write("symbolic", "battery-missing-symbolic", svg(0, False, True, missing=True))

PY

# the outline icon set (apps, places, devices, tray, battery names): one scalable directory
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$DIR/scalable"
python3 -I "$SELF_DIR/make-icons.py" "$DIR" >/dev/null

cat > "$DIR/index.theme" <<EOF
[Icon Theme]
Name=easylinux
Comment=Minimalist battery icons on top of $PARENT
Inherits=$PARENT,hicolor
Directories=scalable,status/scalable,status/symbolic

[status/scalable]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Status

[status/symbolic]
Size=16
MinSize=8
MaxSize=512
Type=Scalable
Context=Status

[scalable]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications
EOF
gtk-update-icon-cache -f -t "$DIR" >/dev/null 2>&1 || true
echo "[✓] $(find "$DIR" -name '*.svg' | wc -l) minimalist icons in the 'easylinux' icon theme (inherits $PARENT)"
