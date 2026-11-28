#!/usr/bin/env bash
# Check the ThinkPad X280 Thunderbolt firmware (read-only by default).
# The X280 charges only over USB-C, negotiated by the Thunderbolt controller. Firmware older than
# NVM 20 is the known 2018 ThinkPad bug: it wears out its flash and USB-C charging starts failing
# (charger not detected, or connects and drops). Lenovo's fix is NVM 20.00 (on LVFS).
# See README.md in this folder, "Known issue: charging stops".
#
#   (no option)  report; warn with the fix steps if the firmware is affected
#   --notify     also show a desktop notification when affected (used at login)
#   --update     flash the Thunderbolt firmware with fwupd (root, charger connected; fwupd's own
#                AC check stays on). Never done automatically.
set -euo pipefail

FIXED_MAJOR=20
TBT="${EASYLINUX_TBT_SYSFS:-/sys/bus/thunderbolt/devices/0-0}"
DMI="${EASYLINUX_DMI_FILE:-/sys/class/dmi/id/product_version}"

if ! grep -qs 'ThinkPad X280' "$DMI"; then
    echo "[skip] Not a ThinkPad X280: Thunderbolt firmware check not applicable"
    exit 0
fi
if [ ! -r "$TBT/nvm_version" ]; then
    echo "[skip] Thunderbolt controller not visible (no $TBT/nvm_version); is the thunderbolt module loaded?"
    exit 0
fi

nvm="$(cat "$TBT/nvm_version")"
major="${nvm%%.*}"
if [ "$major" -ge "$FIXED_MAJOR" ] 2>/dev/null; then
    echo "[✓] Thunderbolt firmware NVM $nvm (>= $FIXED_MAJOR): not affected by the USB-C charging bug"
    exit 0
fi

cat <<EOF
[!] Thunderbolt firmware NVM $nvm is OLDER than $FIXED_MAJOR.
    This firmware wears out its own flash; USB-C charging then stops working (charger not
    detected, or it connects and drops every few seconds). Update it while it still works:
        sudo apt install fwupd
        sudo easylinux --tbt-update          (or: fwupdmgr get-devices; sudo fwupdmgr update <ID>)
    Details and the no-charger workaround: hardware/thinkpad-x280/README.md, "Known issue".
EOF

if [ "${1:-}" = --notify ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical -i battery-caution "ThinkPad Thunderbolt firmware is outdated" \
        "NVM $nvm can stop USB-C charging. Update it with: sudo easylinux --tbt-update" 2>/dev/null || true
fi

if [ "${1:-}" = --update ]; then
    if [ "$EUID" -ne 0 ]; then echo "[-] --update needs root: sudo $0 --update"; exit 1; fi
    if ! command -v fwupdmgr >/dev/null 2>&1; then
        echo "[-] fwupdmgr not found: sudo apt install fwupd"; exit 1
    fi
    id="$(fwupdmgr get-devices --json 2>/dev/null | python3 -I -c '
import json, sys
for d in json.load(sys.stdin).get("Devices", []):
    if "thunderbolt" in d.get("Name", "").lower() and "updatable" in d.get("Flags", []):
        print(d["DeviceId"]); break
' || true)"
    if [ -z "$id" ]; then echo "[-] fwupd does not list an updatable Thunderbolt controller"; exit 1; fi
    fwupdmgr refresh >/dev/null 2>&1 || true
    echo "==> Flashing Thunderbolt controller $id (fwupd requires the charger to be connected)"
    fwupdmgr update "$id" --no-reboot-check
    echo "[i] Now: $(cat "$TBT/nvm_version" 2>/dev/null). Unplug and replug the charger; a short reconnect loop for a few minutes is normal."
fi
exit 0
