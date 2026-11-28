#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v dpkg-deb >/dev/null || { echo "  skip (dpkg-deb not installed)"; exit 0; }
sandbox
cd "$TEST_ROOT" || exit 1
VERSION="$(cat VERSION)"; DEB="dist/easyset_${VERSION}_all.deb"
make deb >/dev/null 2>&1
assert_file "$DEB" "make deb builds the package"
dpkg-deb -I "$DEB" > "$SB/info"
assert_contains "$SB/info" "Package: easyset" "package name"
assert_contains "$SB/info" "Version: $VERSION" "package version matches VERSION"
assert_contains "$SB/info" "WARNING: experimental and risky" "risk warning is in the description"
assert_contains "$SB/info" "Recommends: kitty" "kitty is a recommended package"
mkdir -p "$SB/root"; dpkg-deb -x "$DEB" "$SB/root"; dpkg-deb -e "$DEB" "$SB/ctl"
assert_contains "$SB/ctl/conffiles" "/etc/easyset/easyset.conf" "config file is a conffile"
assert_file "$SB/root/usr/bin/easyset" "easylinux command shipped"
assert_file "$SB/root/etc/xdg/autostart/easyset-user.desktop" "per-user autostart shipped"
assert_eq "$(find "$SB/root" -type d ! -perm 755 | wc -l | tr -d ' ')" 0 "all directories are 0755"
assert_eq "$("$SB/root/usr/bin/easyset" --version)" "$VERSION" "installed command runs from the extracted package"
SH="$(command -v dash || command -v sh)"; "$SH" -n "$SB/ctl/postinst"; assert_eq "$?" 0 "postinst syntax"

echo "-- per-user first-login setup runs once per version"
printf '#!/bin/sh\necho "$@" >> %s/calls\n' "$SB" > "$SB/fake"; chmod +x "$SB/fake"
export EASYLINUX_DELAY=0 EASYLINUX_BIN="$SB/fake" XDG_STATE_HOME="$SB/state" HOME="$SB/home"
"$SB/root/usr/bin/easyset-user-setup"; "$SB/root/usr/bin/easyset-user-setup"
assert_eq "$(wc -l < "$SB/calls" | tr -d ' ')" 1 "second login does not re-apply"
assert_contains "$SB/calls" "--user" "runs the --user settings"
printf '#!/bin/sh\nexit 1\n' > "$SB/fail"; chmod +x "$SB/fail"; rm -rf "$SB/state"
EASYLINUX_BIN="$SB/fail" "$SB/root/usr/bin/easyset-user-setup"
assert_no_file "$SB/state/easylinux/applied" "a failed run is retried at the next login"
finish
