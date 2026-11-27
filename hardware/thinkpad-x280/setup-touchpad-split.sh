#!/usr/bin/env bash
# Configure ThinkPad X280 touchpad with full-height left/right button split
set -euo pipefail

if [ "$EUID" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XORG_DIR="${EASYLINUX_XORG_DIR:-/etc/X11/xorg.conf.d}"

# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

echo "=== 0. Creating safety snapshot (undo: sudo easylinux-rollback) ==="
es_begin touchpad-split
es_backup "$XORG_DIR/70-synaptics.conf"
es_backup "$XORG_DIR/99-synaptics-custom.conf"
if command -v dpkg >/dev/null 2>&1 && ! dpkg -s xserver-xorg-input-synaptics >/dev/null 2>&1; then
    es_note "easylinux installed the apt package xserver-xorg-input-synaptics; remove it with: apt-get remove xserver-xorg-input-synaptics"
fi
es_arm

echo "=== 1. Installing xserver-xorg-input-synaptics ==="
if [ -n "${EASYLINUX_NO_PKG:-}" ]; then
    echo "[skip] package installation disabled (running inside a package manager); the package depends on it"
else
    apt-get update -y
    apt-get install -y xserver-xorg-input-synaptics
fi

# The synaptics driver splits the pad in the device's own coordinates, which differ per
# driver mode (PS/2 on the X280 with synaptics_intertouch=0: X 1266..5676, SMBus: 0..1936).
# A split outside that range turns the whole pad into a right button, so use the middle of
# the real range. Prints "min max" of the touchpad's X axis, or nothing if it cannot be read.
touchpad_x_range() {
    if [ -n "${EASYLINUX_TOUCHPAD_X_RANGE:-}" ]; then echo "$EASYLINUX_TOUCHPAD_X_RANGE"; return; fi
    command -v python3 >/dev/null 2>&1 || return 0
    python3 -I - <<'PY' 2>/dev/null || true
import fcntl, re, struct, os
blocks = open('/proc/bus/input/devices').read().split('\n\n')
for b in blocks:
    if not re.search(r'Name=.*touch ?pad', b, re.I):
        continue
    m = re.search(r'Handlers=.*\b(event\d+)', b)
    if not m:
        continue
    try:
        fd = os.open('/dev/input/' + m.group(1), os.O_RDONLY)
        buf = bytearray(24)
        fcntl.ioctl(fd, 0x80184540, buf)          # EVIOCGABS(ABS_X)
        _, mn, mx, _, _, _ = struct.unpack('6i', buf)
        print(mn, mx)
        break
    except OSError:
        pass
PY
}

echo "=== 2. Deploying Touchpad Split Configuration ==="
mkdir -p "$XORG_DIR"
cp "$SCRIPT_DIR/70-synaptics.conf" "$XORG_DIR/70-synaptics.conf"
read -r XMIN XMAX <<< "$(touchpad_x_range)"
if [ -n "${XMIN:-}" ] && [ -n "${XMAX:-}" ] && [ "$XMAX" -gt "$XMIN" ]; then
    SPLIT=$(( (XMIN + XMAX) / 2 ))
    sed -i -E "s|(Option \"SoftButtonAreas\" \")[0-9]+ |\1$SPLIT |" "$XORG_DIR/70-synaptics.conf"
    echo "[✓] Touchpad X range $XMIN..$XMAX -> right button starts at X=$SPLIT"
else
    echo "[!] Could not read the touchpad range; using the ThinkPad X280 default (X=3471)"
fi
cp "$XORG_DIR/70-synaptics.conf" "$XORG_DIR/99-synaptics-custom.conf"

echo "[✓] Successfully installed 70-synaptics.conf into $XORG_DIR/"
echo "=== Done! Please log out and back in (or reboot) for changes to take effect. ==="
