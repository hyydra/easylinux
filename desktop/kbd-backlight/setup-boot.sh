#!/usr/bin/env bash
# Keyboard backlight at full brightness after power-on and after every wake-up.
# The firmware leaves it off at boot and does not restore it after suspend/hibernate.
#   - udev rule: runs when the LED device appears (boot)
#   - systemd sleep hook: runs after resume
# Both call one helper that sets every *kbd_backlight LED to its max_brightness.
set -euo pipefail

if [ "$EUID" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC="${EASYLINUX_ETC:-/etc}"
SBIN="${EASYLINUX_SBIN:-/usr/local/sbin}"
HELPER="$SBIN/easylinux-kbd-backlight-max"
RULE="$ETC/udev/rules.d/90-easylinux-kbd-backlight.rules"
HOOK="$ETC/systemd/system-sleep/easylinux-kbd-backlight"

# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

echo "=== Keyboard backlight at boot and wake-up ==="
if ! ls /sys/class/leds/*kbd_backlight >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; then
    echo "[skip] No keyboard backlight LED (*kbd_backlight) on this machine"
    exit 0
fi

es_begin kbd-backlight-boot
es_backup "$HELPER"
es_backup "$RULE"
es_backup "$HOOK"
es_arm

mkdir -p "$SBIN" "$(dirname "$RULE")" "$(dirname "$HOOK")"
cat > "$HELPER" <<'EOF'
#!/bin/sh
# easylinux: set the keyboard backlight to maximum
for led in /sys/class/leds/*kbd_backlight; do
    [ -w "$led/brightness" ] && cat "$led/max_brightness" > "$led/brightness"
done
exit 0
EOF
chmod 755 "$HELPER"

cat > "$RULE" <<EOF
# easylinux: keyboard backlight to maximum when the LED appears (boot)
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight", RUN+="$HELPER"
EOF

cat > "$HOOK" <<EOF
#!/bin/sh
# easylinux: keyboard backlight to maximum after suspend/hibernate
[ "\$1" = post ] && $HELPER
exit 0
EOF
chmod 755 "$HOOK"

echo "[✓] Installed $HELPER, $RULE, $HOOK"
if [ -z "${ES_TEST:-}" ]; then
    udevadm control --reload 2>/dev/null || true
    "$HELPER"
    echo "[✓] Backlight set to maximum now"
fi
echo "=== Done ==="
