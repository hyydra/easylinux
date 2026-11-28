#!/usr/bin/env bash
# logind: the power button and the suspend key put the machine to sleep (default: power off).
# Needs the per-user install.sh in this folder for XFCE (so xfce4-power-manager lets logind
# handle the keys). Install this BEFORE using the power button once the per-user part is
# active: until then logind's default (power off) applies.
set -euo pipefail

if [ "$EUID" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${EASYLINUX_LOGIND_DROPIN:-/etc/systemd/logind.conf.d/50-easylinux-suspend-keys.conf}"

# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

echo "=== logind suspend keys ==="
es_begin suspend-keys
es_backup "$CONF"
es_arm

mkdir -p "$(dirname "$CONF")"
cat > "$CONF" <<'EOF'
# easylinux: power button and suspend key suspend the machine
[Login]
HandlePowerKey=suspend
HandleSuspendKey=suspend
EOF
echo "[✓] Wrote $CONF"
if [ -z "${ES_TEST:-}" ] && [ -d /run/systemd/system ]; then
    systemctl kill -s HUP systemd-logind 2>/dev/null || true
    echo "[✓] logind reloaded"
fi
echo "=== Done ==="
