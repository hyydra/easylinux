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
finish
