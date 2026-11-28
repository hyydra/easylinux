#!/usr/bin/env bash
# Suspend keys for XFCE (per user, no root). Run setup-system.sh too (root) so that the power
# button also suspends instead of powering off.
#
# xfce4-power-manager normally takes the key handling away from logind, but on some machines
# it does not act on the keys: logind logs "Suspend key pressed short." and nothing sleeps
# (seen on the ThinkPad X280 with Fn+4). Telling it to leave the keys to logind fixes that;
# logind reads them from the kernel input device, so it does not depend on X key grabs.
# Do NOT also bind the keys to `systemctl suspend`: both would fire and the machine would
# suspend twice.
set -euo pipefail

echo "==> Suspend keys"
if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "[skip] xfconf-query not found: this module is for XFCE's xfce4-power-manager"
    exit 0
fi

# remove the earlier easylinux version's direct key bindings, if present
for key in XF86Sleep XF86Suspend XF86PowerOff; do
    if [ "$(xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" 2>/dev/null || true)" = "systemctl suspend" ]; then
        xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -r
    fi
done

for prop in logind-handle-suspend-key logind-handle-power-key logind-handle-hibernate-key; do
    xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$prop" -n -t bool -s true
done
# xfce4-power-manager also reacts to the X key itself (its own button action) unless told not to:
# then one press suspends via logind AND pops up xfpm's own "hibernate?" dialog.
for prop in power-button-action sleep-button-action hibernate-button-action; do
    xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$prop" -n -t uint -s 0
done
echo "[✓] xfce4-power-manager now leaves the suspend/power/hibernate keys to logind (its own button actions: nothing)"

# the inhibitor lock is taken at startup
if pgrep -x xfce4-power-manager >/dev/null 2>&1 && [ -z "${ES_TEST:-}" ]; then
    (setsid xfce4-power-manager --restart >/dev/null 2>&1 &)
    echo "[✓] Restarted xfce4-power-manager"
fi
