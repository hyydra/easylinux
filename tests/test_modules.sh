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
assert_contains "$SB/xfconf" "/commands/custom/XF86Suspend -n -t string -s systemctl suspend" "XF86Suspend bound to systemctl suspend"
assert_contains "$SB/xfconf" "/commands/custom/XF86Sleep -n -t string -s systemctl suspend" "Fn+4 (XF86Sleep) bound"

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
