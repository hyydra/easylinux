#!/usr/bin/env bash
# easyset --doctor: read-only hardware and system report for any Linux machine.
# Changes nothing. It shows what was detected and which easyset parts apply, so a new
# machine can be checked before anything is installed.
set -u

DMI="${EASYLINUX_DMI_DIR:-/sys/class/dmi/id}"
dmi() { cat "$DMI/$1" 2>/dev/null | head -1; }
ok()   { printf '  [✓] %s\n' "$*"; }
note() { printf '  [i] %s\n' "$*"; }
warn() { printf '  [!] %s\n' "$*"; }

vendor="$(dmi sys_vendor)"; product="$(dmi product_name)"; version="$(dmi product_version)"
echo "== Machine"
echo "  ${vendor:-unknown vendor} ${product:-} ${version:-}   (BIOS $(dmi bios_version), $(dmi bios_date))"
echo "  $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown distro}"), kernel $(uname -r), $(uname -m)"
cpu="$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ //')"; echo "  CPU: ${cpu:-unknown}"
case "$vendor $product $version" in *ThinkPad*X280*) profile="ThinkPad X280 (touchpad, Thunderbolt, charging fixes apply)";;
    *Apple*|*Mac*) profile="Apple (generic parts apply; touchpad/backlight depend on the driver, see below)";;
    *) profile="none: only the generic parts apply";; esac
echo "  Hardware profile: $profile"

echo "== Session and tools"
ok "init: $(ps -p 1 -o comm= 2>/dev/null)   desktop: ${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-none detected}}   session: ${XDG_SESSION_TYPE:-unknown}"
for t in apt-get dnf pacman zypper; do command -v $t >/dev/null 2>&1 && ok "package manager: $t" && break; done
command -v xfconf-query >/dev/null 2>&1 && ok "XFCE settings tool found (theme, panel, desktop modules apply)" || note "no XFCE: theme, panel and desktop modules are skipped"
command -v pkexec >/dev/null 2>&1 && ok "graphical admin prompt available (polkit)" || note "no pkexec: sudo is used"
command -v fwupdmgr >/dev/null 2>&1 && ok "fwupd installed (firmware updates)" || note "fwupd not installed: 'sudo apt install fwupd' enables firmware checks"
[ -d /sys/firmware/efi ] && ok "boot: UEFI" || ok "boot: legacy BIOS"

echo "== Input"
if [ -r /proc/bus/input/devices ]; then
    tp="$(awk 'BEGIN{RS="";FS="\n"} /[Tt]ouch ?[Pp]ad/{for(i=1;i<=NF;i++) if($i ~ /^N: Name=/) print substr($i,10)}' /proc/bus/input/devices | head -2 | tr -d '"' | tr '\n' ';')"
    [ -n "$tp" ] && ok "touchpad: ${tp%;}" || note "no touchpad found"
    grep -qi "trackpoint" /proc/bus/input/devices && ok "TrackPoint present"
fi
if command -v xinput >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    xinput list --name-only 2>/dev/null | grep -qi synaptics && note "driver: synaptics (X11) — easyset's soft-button split applies"
fi
led="$(ls -d /sys/class/leds/*kbd_backlight 2>/dev/null | head -1)"
[ -n "$led" ] && ok "keyboard backlight: $(basename "$led") (max $(cat "$led/max_brightness" 2>/dev/null))" || note "no keyboard backlight LED"

echo "== Power"
bat="$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)"
if [ -n "$bat" ]; then
    ok "battery $(basename "$bat"): $(cat "$bat/capacity" 2>/dev/null)% $(cat "$bat/status" 2>/dev/null); design/now energy $(cat "$bat/energy_full_design" 2>/dev/null) / $(cat "$bat/energy_full" 2>/dev/null)"
    [ -e "$bat/charge_control_end_threshold" ] && ok "charge limit supported: $(cat "$bat/charge_control_end_threshold")%" || note "no charge-limit control"
else note "no battery (desktop?)"; fi
ac="$(cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null | head -1)"; echo "  AC adapter online: ${ac:-n/a}"
echo "  sleep states: $(cat /sys/power/state 2>/dev/null)   mem_sleep: $(cat /sys/power/mem_sleep 2>/dev/null)"
for b in /sys/bus/thunderbolt/devices/0-0/nvm_version; do [ -r "$b" ] && ok "Thunderbolt NVM $(cat "$b")"; done

echo "== Graphics and network"
command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -iE "vga|3d|display" | sed 's/^/  GPU: /' | cut -c1-110
command -v rfkill >/dev/null 2>&1 && rfkill list 2>/dev/null | awk '/^[0-9]/{n=$0} /Soft blocked: yes|Hard blocked: yes/{print "  [!] radio blocked: " n}' | head -3

echo "== Safety net"
[ -x /usr/local/sbin/easylinux-rollback ] && ok "rollback tool installed ($(ls /var/backups/easylinux 2>/dev/null | grep -vc latest) snapshots)" || note "rollback tool not installed yet (it is set up by the first system change)"
command -v grub-mkconfig >/dev/null 2>&1 && ok "GRUB found (boot hardening applies)" || note "no GRUB: boot hardening is skipped (systemd-boot/other: keep a live USB at hand)"
echo
echo "Next: 'easyset --user' (per-user look, no root), 'sudo easyset --system' (system fixes, snapshot first)."
