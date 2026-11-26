#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sandbox
G="$TEST_ROOT/safety/easylinux-boot-guard.sh"
SH="$(command -v dash || command -v sh)"
export ES_POLL=0 ES_SETTLE=0 ES_TRIES=2 ES_HEADLESS_WAIT=0
printf '#!/bin/sh\necho called >> %s/calls\nrm -f %s/st/pending %s/st/booting\n' "$SB" "$SB" "$SB" > "$SB/rb"; chmod +x "$SB/rb"; export ES_ROLLBACK="$SB/rb"
mkdir -p "$SB/desk" "$SB/nodesk"
printf '#!/bin/sh\nexit 0\n' > "$SB/desk/pgrep"; printf '#!/bin/sh\nexit 1\n' > "$SB/nodesk/pgrep"; chmod +x "$SB/desk/pgrep" "$SB/nodesk/pgrep"
arm() { mkdir -p "$SB/st"; echo snap > "$SB/st/pending"; rm -f "$SB/st/booting"; }
pending() { [ -e "$SB/st/pending" ] && echo kept || echo cleared; }

arm; "$SH" "$G" start
assert_file "$SB/st/booting" "first boot after a change sets the booting flag"
assert_eq "$(ls "$SB/calls" 2>/dev/null | wc -l | tr -d ' ')" 0 "first boot does not roll back"
PATH="$SB/desk:$PATH" ES_EXPECT=graphical "$SH" "$G" confirm
assert_eq "$(pending)" cleared "desktop reached -> guard disarmed"

arm; "$SH" "$G" start
PATH="$SB/nodesk:$PATH" ES_EXPECT=graphical "$SH" "$G" confirm
assert_eq "$(pending)" kept "no desktop -> stays armed"
"$SH" "$G" start
assert_eq "$(cat "$SB/calls" 2>/dev/null | wc -l | tr -d ' ')" 1 "next boot rolls back after an unconfirmed boot"
assert_eq "$(pending)" cleared "pending cleared after the automatic rollback"

arm; "$SH" "$G" start; ES_EXPECT=headless "$SH" "$G" confirm
assert_eq "$(pending)" cleared "headless boot is confirmed after the wait"

arm; "$SH" "$G" start; PATH="$SB/desk:$PATH" ES_EXPECT=graphical "$SH" "$G" confirm-now
assert_eq "$(pending)" cleared "clean shutdown from a working desktop counts as healthy"
arm; "$SH" "$G" start; PATH="$SB/nodesk:$PATH" ES_EXPECT=graphical "$SH" "$G" confirm-now
assert_eq "$(pending)" kept "shutdown without a desktop does not confirm"

rm -rf "$SB/st"; "$SH" "$G" start; assert_no_file "$SB/st/booting" "nothing pending -> guard does nothing"
finish
