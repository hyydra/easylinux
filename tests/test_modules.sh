#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sandbox
cd "$TEST_ROOT" || exit 1

echo "-- windows-clipboard module"
export XDG_CONFIG_HOME="$SB/cfg"; mkdir -p "$SB/cfg/xfce4" "$SB/cfg/kitty"
printf 'font_size 12\n' > "$SB/cfg/kitty/kitty.conf"
printf 'TerminalEmulator=xfce4-terminal\nWebBrowser=firefox\n' > "$SB/cfg/xfce4/helpers.rc"
printf '#!/bin/sh\n' > "$SB/bin/kitty"; chmod +x "$SB/bin/kitty"
PATH="$SB/bin:$PATH" bash desktop/windows-clipboard/install.sh >/dev/null 2>&1
PATH="$SB/bin:$PATH" bash desktop/windows-clipboard/install.sh >/dev/null 2>&1
assert_contains "$SB/cfg/kitty/easylinux.conf" "map ctrl+c copy_and_clear_or_interrupt" "Ctrl+C = copy or interrupt"
assert_contains "$SB/cfg/kitty/easylinux.conf" "map ctrl+v paste_from_clipboard" "Ctrl+V = paste"
assert_eq "$(grep -c '^include easylinux.conf$' "$SB/cfg/kitty/kitty.conf")" 1 "include line added once (idempotent)"
assert_contains "$SB/cfg/xfce4/helpers.rc" "TerminalEmulator=kitty" "default terminal switched to kitty"
bash desktop/windows-clipboard/uninstall.sh >/dev/null 2>&1
assert_contains "$SB/cfg/xfce4/helpers.rc" "TerminalEmulator=xfce4-terminal" "uninstall restores the old terminal"
assert_lacks "$SB/cfg/kitty/kitty.conf" "easylinux" "uninstall removes the include"
assert_contains "$SB/cfg/kitty/kitty.conf" "font_size 12" "user's own kitty settings kept"

echo "-- missing kitty without package install: default terminal untouched"
rm -rf "$SB/cfg"; mkdir -p "$SB/cfg/xfce4" "$SB/min"; printf 'TerminalEmulator=xfce4-terminal\n' > "$SB/cfg/xfce4/helpers.rc"
# a PATH that has the basic tools but certainly no kitty, whatever is installed on this machine
for c in bash mkdir install touch grep sed cp dirname cat rm mv; do ln -sf "$(command -v "$c")" "$SB/min/$c"; done
EASYLINUX_NO_PKG=1 PATH="$SB/min" bash desktop/windows-clipboard/install.sh >/dev/null 2>&1
assert_eq "$?" 1 "install reports failure when kitty is missing"
assert_contains "$SB/cfg/xfce4/helpers.rc" "TerminalEmulator=xfce4-terminal" "terminal not switched"
assert_file "$SB/cfg/kitty/easylinux.conf" "config is still written, ready for later"

echo "-- install.sh dispatch"
assert_eq "$(bash install.sh --version)" "$(cat VERSION)" "--version prints VERSION"
bash install.sh --bogus >"$SB/out" 2>&1; assert_eq "$?" 1 "unknown option exits 1"
assert_contains "$SB/out" "Usage:" "usage is printed"
if [ "$(id -u)" -eq 0 ]; then echo "  skip --system dispatch (running as root would execute for real)"; else
    printf '#!/bin/sh\necho "WOULD-RUN $@"\n' > "$SB/bin/sudo"; chmod +x "$SB/bin/sudo"
    echo "ThinkPad X280" > "$SB/dmi"
    EASYLINUX_DMI_FILE="$SB/dmi" PATH="$SB/bin:$PATH" bash install.sh --system > "$SB/out" 2>&1
    assert_contains "$SB/out" "harden-boot.sh" "--system hardens the boot everywhere"
    assert_contains "$SB/out" "fix-system-errors.sh" "--system applies ThinkPad fixes on an X280"
    assert_contains "$SB/out" "setup-touchpad-split.sh" "--system applies the touchpad split on an X280"
    assert_contains "$SB/out" "Thunderbolt firmware" "--system checks the Thunderbolt firmware on an X280"
    echo "ThinkPad T14" > "$SB/dmi"
    EASYLINUX_DMI_FILE="$SB/dmi" PATH="$SB/bin:$PATH" bash install.sh --system > "$SB/out" 2>&1
    assert_contains "$SB/out" "harden-boot.sh" "other laptop: boot hardening still applied"
    assert_lacks "$SB/out" "fix-system-errors.sh" "other laptop: hardware fixes skipped"
fi

echo "-- set-scroll-direction"
S=hardware/thinkpad-x280/set-scroll-direction.sh
bash "$S" bogus >/dev/null 2>&1; assert_eq "$?" 1 "invalid direction rejected"
cp hardware/thinkpad-x280/70-synaptics.conf "$SB/syn.conf"
EASYLINUX_SCROLL_CONFS="$SB/syn.conf" bash "$S" --persist-only traditional >/dev/null 2>&1
assert_contains "$SB/syn.conf" 'Option "VertScrollDelta" "111"' "traditional = positive delta"
assert_contains "$SB/syn.conf" 'Option "HorizScrollDelta" "111"' "traditional also horizontal"
EASYLINUX_SCROLL_CONFS="$SB/syn.conf" bash "$S" --persist-only natural >/dev/null 2>&1
assert_contains "$SB/syn.conf" 'Option "VertScrollDelta" "-111"' "natural = negative delta"
assert_file "$SB/bk" "scroll change was snapshotted first"

echo "-- safety lib survives set -euo pipefail (ls of missing kernel globs must not abort)"
bash -c 'set -euo pipefail; source safety/lib.sh; es_begin pf; es_arm' >/dev/null 2>&1
assert_eq "$?" 0 "es_arm completes under pipefail"

echo "-- touchpad split is computed from the pad's real range"
S=hardware/thinkpad-x280/setup-touchpad-split.sh
mkdir -p "$SB/xorg"
EASYLINUX_NO_PKG=1 EASYLINUX_XORG_DIR="$SB/xorg" EASYLINUX_TOUCHPAD_X_RANGE="1266 5676" bash "$S" >/dev/null 2>&1
assert_contains "$SB/xorg/70-synaptics.conf" 'Option "SoftButtonAreas" "3471 0 0 0 0 0 0 0"' "PS/2 range 1266..5676 -> split 3471"
assert_contains "$SB/xorg/99-synaptics-custom.conf" 'Option "SoftButtonAreas" "3471 ' "second config gets the same split"
EASYLINUX_NO_PKG=1 EASYLINUX_XORG_DIR="$SB/xorg" EASYLINUX_TOUCHPAD_X_RANGE="0 1936" bash "$S" >/dev/null 2>&1
assert_contains "$SB/xorg/70-synaptics.conf" 'Option "SoftButtonAreas" "968 0 0 0 0 0 0 0"' "SMBus range 0..1936 -> split 968"
assert_contains "$SB/xorg/70-synaptics.conf" 'Option "VertScrollDelta" "-111"' "scroll settings kept"

echo "-- kbd-backlight helper"
K=desktop/kbd-backlight/easylinux-kbd-backlight
cat > "$SB/bin/busctl" <<'STUB'
#!/bin/sh
case "$*" in
    *GetMaxBrightness*) echo "i 2" ;;
    *GetBrightness*)    echo "i $(cat "$KBD_STATE")" ;;
    *SetBrightness*)    for last; do :; done; echo "$last" > "$KBD_STATE" ;;
esac
STUB
chmod +x "$SB/bin/busctl"; export KBD_STATE="$SB/kbd"
kbd() { PATH="$SB/bin:$PATH" sh "$K" "$1"; cat "$KBD_STATE"; }
echo 0 > "$KBD_STATE"
assert_eq "$(kbd cycle)" 1 "cycle: off -> dim"
assert_eq "$(kbd cycle)" 2 "cycle: dim -> bright"
assert_eq "$(kbd cycle)" 0 "cycle: bright -> off"
assert_eq "$(kbd up; kbd up)" "1
2" "up steps through the levels"
assert_eq "$(kbd up)" 2 "up stops at the maximum"
assert_eq "$(kbd off)" 0 "off"
assert_eq "$(kbd down)" 0 "down stops at 0"

echo "-- kbd-backlight at boot and wake-up"
mkdir -p "$SB/etcb" "$SB/sbinb"
EASYLINUX_ETC="$SB/etcb" EASYLINUX_SBIN="$SB/sbinb" bash desktop/kbd-backlight/setup-boot.sh >/dev/null 2>&1
assert_file "$SB/sbinb/easylinux-kbd-backlight-max" "helper installed"
assert_contains "$SB/etcb/systemd/system/easylinux-kbd-backlight.service" "ExecStart=$SB/sbinb/easylinux-kbd-backlight-max" "boot service runs the helper"
assert_contains "$SB/etcb/systemd/system/easylinux-kbd-backlight.service" "WantedBy=multi-user.target" "boot service is enabled for normal boots (after systemd-backlight)"
assert_no_file "$SB/etcb/udev/rules.d/90-easylinux-kbd-backlight.rules" "old udev rule is not used on systemd"
assert_contains "$SB/etcb/systemd/system/easylinux-kbd-backlight-resume.service" "WantedBy=suspend.target" "resume service is tied to suspend.target"
assert_contains "$SB/etcb/systemd/system/easylinux-kbd-backlight-resume.service" "sleep 1; $SB/sbinb/easylinux-kbd-backlight-max" "resume service waits, then calls the helper"
assert_no_file "$SB/etcb/systemd/system-sleep/easylinux-kbd-backlight" "no sleep hook on systemd (the resume service replaces it)"
mkdir -p "$SB/led"; echo 2 > "$SB/led/max_brightness"; echo 0 > "$SB/led/brightness"
sed "s|/sys/class/leds/\*kbd_backlight|$SB/led|" "$SB/sbinb/easylinux-kbd-backlight-max" > "$SB/helper-test"
sh "$SB/helper-test"; assert_eq "$(cat "$SB/led/brightness")" 2 "helper sets the LED to max_brightness"

echo "-- suspend keys"
printf '#!/bin/sh\necho "$@" >> %s/xfconf\n' "$SB" > "$SB/bin/xfconf-query"; chmod +x "$SB/bin/xfconf-query"
PATH="$SB/bin:$PATH" bash desktop/suspend-keys/install.sh >/dev/null 2>&1
assert_contains "$SB/xfconf" "/xfce4-power-manager/logind-handle-suspend-key -n -t bool -s true" "xfpm leaves the suspend key to logind"
assert_contains "$SB/xfconf" "/xfce4-power-manager/logind-handle-power-key -n -t bool -s true" "xfpm leaves the power key to logind"
assert_contains "$SB/xfconf" "/xfce4-power-manager/power-button-action -n -t uint -s 0" "xfpm's own power-button action is off (no second handler)"
EASYLINUX_LOGIND_DROPIN="$SB/logind.conf" bash desktop/suspend-keys/setup-system.sh >/dev/null 2>&1
assert_contains "$SB/logind.conf" "HandlePowerKey=suspend" "logind: power button suspends"
assert_contains "$SB/logind.conf" "HandleSuspendKey=suspend" "logind: suspend key suspends"

echo "-- Thunderbolt firmware check"
C=hardware/thinkpad-x280/check-thunderbolt-firmware.sh
mkdir -p "$SB/tbt"; echo "ThinkPad X280" > "$SB/dmi-x280"; echo "ThinkPad T14" > "$SB/dmi-t14"
tbt() { EASYLINUX_DMI_FILE="$SB/$1" EASYLINUX_TBT_SYSFS="$SB/tbt" PATH="$SB/bin:$PATH" bash "$C" ${2:-} > "$SB/out" 2>&1; }
echo "14.0" > "$SB/tbt/nvm_version"; tbt dmi-x280
assert_eq "$?" 0 "an outdated firmware is a warning, not a failure"
assert_contains "$SB/out" "NVM 14.0 is OLDER than 20" "NVM 14.0 is reported as affected"
assert_contains "$SB/out" "easylinux --tbt-update" "the fix command is shown"
printf '#!/bin/sh\necho "$@" >> %s/notified\n' "$SB" > "$SB/bin/notify-send"; chmod +x "$SB/bin/notify-send"
tbt dmi-x280 --notify
assert_contains "$SB/notified" "Thunderbolt firmware is outdated" "--notify shows a desktop notification"
echo "20.0" > "$SB/tbt/nvm_version"; rm -f "$SB/notified"; tbt dmi-x280 --notify
assert_contains "$SB/out" "not affected" "NVM 20.0 is fine"
assert_no_file "$SB/notified" "no notification when the firmware is fixed"
echo "14.0" > "$SB/tbt/nvm_version"; tbt dmi-t14
assert_contains "$SB/out" "Not a ThinkPad X280" "other laptops are skipped"
rm -f "$SB/tbt/nvm_version"; tbt dmi-x280
assert_contains "$SB/out" "Thunderbolt controller not visible" "missing controller is skipped, not an error"

echo "-- Yaru theme with light/dark cycle"
mkdir -p "$SB/themes/Yaru/gtk-3.0" "$SB/themes/Yaru/xfwm4" "$SB/themes/Yaru-hdpi/xfwm4" "$SB/themes/Yaru-dark/xfwm4" "$SB/themes/Yaru-dark-hdpi/xfwm4" \
         "$SB/icons/Yaru" "$SB/icons/Yaru-dark" "$SB/xf" "$SB/home"
cat > "$SB/bin/xfconf-query" <<'STUB'
#!/bin/sh
# tiny xfconf: one file per channel+property
c=""; p=""; v=""; mode=get
while [ $# -gt 0 ]; do case "$1" in -c) c="$2"; shift ;; -p) p="$2"; shift ;; -s) v="$2"; mode=set; shift ;; -r) mode=rm ;; esac; shift; done
f="$XF/$c$(echo "$p" | tr / _)"
case $mode in get) [ -f "$f" ] && cat "$f" || exit 1 ;; set) echo "$v" > "$f" ;; rm) rm -f "$f" ;; esac
STUB
printf '#!/bin/sh\n[ "$1" = set ] && echo "$4" > "$XF/gs_$3"\nexit 0\n' > "$SB/bin/gsettings"
chmod +x "$SB/bin/xfconf-query" "$SB/bin/gsettings"; export XF="$SB/xf"
echo Greybird > "$XF/xsettings_Net_ThemeName"; echo Default-xhdpi > "$XF/xfwm4_general_theme"; echo 144 > "$XF/xsettings_Xft_DPI"
th() { EASYLINUX_THEMES_DIR="$SB/themes" EASYLINUX_ICONS_DIR="$SB/icons" HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/cfgt" PATH="$SB/bin:$PATH" "$@" >/dev/null 2>&1; }
TB="$SB/home/.local/bin/easylinux-theme"
EASYLINUX_NOW=12:00 th bash desktop/theme/install.sh; EASYLINUX_NOW=12:00 th bash desktop/theme/install.sh
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru "noon: light Yaru"
assert_eq "$(cat "$XF/xfwm4_general_theme")" Yaru-hdpi "window frame follows the DPI (144 -> hdpi)"
assert_eq "$(cat "$XF/gs_color-scheme")" default "noon: apps told light"
assert_contains "$SB/cfgt/systemd/user/easylinux-theme.timer" "OnCalendar=*:0/10" "timer checks the schedule every 10 minutes"
assert_contains "$SB/state/easylinux/theme-backup" "Greybird" "original theme saved (not overwritten by the second run)"
EASYLINUX_NOW=21:30 th "$TB" --timer
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru-dark "21:30: timer switches to dark"
assert_eq "$(cat "$XF/xsettings_Net_IconThemeName")" Yaru-dark "dark icons"
assert_eq "$(cat "$XF/xfwm4_general_theme")" Yaru-dark-hdpi "dark window frame at hdpi"
assert_eq "$(cat "$XF/gs_color-scheme")" prefer-dark "apps told dark"
EASYLINUX_NOW=06:59 th "$TB" --timer
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru-dark "06:59: still dark"
EASYLINUX_NOW=07:00 th "$TB" --timer
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru "07:00: light again"
th "$TB" toggle
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru-dark "toggle flips to dark"
EASYLINUX_NOW=12:00 th "$TB" --timer
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru-dark "after a manual choice the timer leaves it alone"
EASYLINUX_NOW=12:00 th "$TB" auto
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Yaru "auto returns to the schedule"
th bash desktop/theme/uninstall.sh
assert_eq "$(cat "$XF/xsettings_Net_ThemeName")" Greybird "uninstall restores the GTK theme"
assert_eq "$(cat "$XF/xfwm4_general_theme")" Default-xhdpi "uninstall restores the window frame"
assert_no_file "$XF/xsettings_Net_IconThemeName" "a value that was unset before is unset again"
assert_no_file "$SB/cfgt/systemd/user/easylinux-theme.timer" "uninstall removes the timer"
rm -rf "$SB/themes/Yaru"; th bash desktop/theme/install.sh; rc=$?
EASYLINUX_THEMES_DIR="$SB/themes" HOME="$SB/home" XDG_STATE_HOME="$SB/state" PATH="$SB/bin:$PATH" bash desktop/theme/install.sh > "$SB/out" 2>&1
assert_eq "$rc" 1 "missing Yaru theme is reported as a failure"
assert_contains "$SB/out" "apt install yaru-theme-gtk" "and says how to install it"
unset XF

echo "-- global keyboard: layout indicator as text"
cat > "$SB/bin/xfconf-query" <<'STUB'
#!/bin/sh
case "$*" in
    *" -l"*) echo /plugins/plugin-18 ;;
    *"-p /plugins/plugin-18") echo xkb ;;
    *" -s "*) echo "$@" >> "$KB" ;;
esac
STUB
chmod +x "$SB/bin/xfconf-query"; export KB="$SB/kb"
PATH="$SB/bin:$PATH" bash desktop/xfce-global-keyboard/set-global-keyboard.sh >/dev/null 2>&1
assert_contains "$KB" "/plugins/plugin-18/group-policy -n -t uint -s 0" "layout is global"
assert_contains "$KB" "/plugins/plugin-18/display-type -n -t uint -s 1" "indicator shows text, not a flag"
assert_contains "$KB" "/plugins/plugin-18/display-name -n -t uint -s 1" "indicator shows the language"
unset KB

echo "-- keyring module"
S=desktop/keyring/setup-keyring.sh
mkdir -p "$SB/pam"; printf '@include common-auth\n@include common-session\n' > "$SB/pam/lightdm"
printf 'auth optional pam_gnome_keyring.so\n' > "$SB/pam/common-auth"; : > "$SB/pam/common-session"
EASYLINUX_NO_PKG=1 EASYLINUX_PAM_DIR="$SB/pam" bash "$S" > "$SB/out" 2>&1
assert_contains "$SB/out" "unlocks with your login" "PAM stack with pam_gnome_keyring is recognised"
: > "$SB/pam/common-auth"
EASYLINUX_NO_PKG=1 EASYLINUX_PAM_DIR="$SB/pam" bash "$S" > "$SB/out" 2>&1
assert_contains "$SB/out" "does not load pam_gnome_keyring" "missing PAM module is reported"

finish
