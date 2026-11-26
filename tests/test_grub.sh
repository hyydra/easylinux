#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CHECK="$(command -v grub-script-check || command -v grub2-script-check || true)"
if [ -z "$CHECK" ]; then echo "  skip (grub-script-check not installed)"; exit 0; fi
sandbox; unset ES_NO_GRUB
LIB="$TEST_ROOT/safety/lib.sh"; RB="$TEST_ROOT/safety/easylinux-rollback.sh"
mkdir -p "$SB/boot"
# fake grub-mkconfig renders the effective settings into a valid grub script
cat > "$SB/bin/grub-mkconfig" << 'EOF2'
#!/bin/bash
[ "${FAKE_MKCONFIG_FAIL:-}" = 1 ] && exit 1
( set +eu; . "$ES_GRUB_DEFAULT" >/dev/null 2>&1; for f in "$ES_GRUB_DROPIN_DIR"/*.cfg; do [ -f "$f" ] && . "$f"; done
  { echo "set timeout=${GRUB_TIMEOUT:-5}"; echo "set style=${GRUB_TIMEOUT_STYLE:-menu}"; echo "set rf=${GRUB_RECORDFAIL_TIMEOUT:--1}"
    echo 'menuentry "Ubuntu" { echo hi }'; echo 'menuentry "Ubuntu old kernel" { echo hi }'; } > "$2" )
EOF2
chmod +x "$SB/bin/grub-mkconfig"; export PATH="$SB/bin:$PATH"
export ES_GRUB_CFG="$SB/boot/grub.cfg" ES_GRUB_DEFAULT="$SB/default-grub" ES_GRUB_DROPIN_DIR="$SB/dropin"
setup() {   # $1 = yes: drop-in dir exists
    printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT_STYLE=hidden\nGRUB_TIMEOUT=0\n' > "$ES_GRUB_DEFAULT"
    rm -rf "$SB/dropin" "$SB/bk" "$SB/st"; [ "$1" = yes ] && mkdir "$SB/dropin"
    printf 'set timeout=0\nmenuentry "Ubuntu" { echo hi }\nmenuentry "Ubuntu old kernel" { echo hi }\n' > "$ES_GRUB_CFG"
}
run() { bash -c "source $LIB; es_begin $1; es_arm" >"$SB/out" 2>&1; }

echo "-- hidden menu + endless recordfail is hardened (drop-in)"
setup yes; run A
assert_contains "$ES_GRUB_CFG" "set timeout=3" "grub.cfg regenerated with a visible timeout"
assert_contains "$ES_GRUB_CFG" "set style=menu" "menu is no longer hidden"
assert_contains "$ES_GRUB_CFG" "set rf=5" "recordfail no longer waits forever"
sleep 1; bash "$RB" >/dev/null 2>&1
assert_contains "$ES_GRUB_CFG" "set timeout=0" "rollback restores the old grub.cfg"
assert_eq "$(ls "$SB/dropin" | wc -l | tr -d ' ')" 0 "rollback removes the drop-in"

echo "-- no drop-in directory: main file is edited and restored"
setup no; run B
assert_contains "$ES_GRUB_DEFAULT" "GRUB_RECORDFAIL_TIMEOUT=5" "default file hardened"
sleep 1; bash "$RB" >/dev/null 2>&1
assert_contains "$ES_GRUB_DEFAULT" "GRUB_TIMEOUT_STYLE=hidden" "default file restored by rollback"
assert_lacks "$ES_GRUB_DEFAULT" "RECORDFAIL" "added key removed by rollback"

echo "-- failing grub-mkconfig leaves everything untouched"
setup yes; FAKE_MKCONFIG_FAIL=1 run C
assert_contains "$ES_GRUB_CFG" "set timeout=0" "grub.cfg unchanged"
assert_eq "$(ls "$SB/dropin" | wc -l | tr -d ' ')" 0 "drop-in reverted"
assert_eq "$(ls "$SB/boot" | grep -c easylinux)" 0 "no temp file left behind"

echo "-- already safe: no change"
setup yes; printf 'GRUB_TIMEOUT_STYLE=menu\nGRUB_TIMEOUT=5\nGRUB_RECORDFAIL_TIMEOUT=5\n' > "$SB/dropin/10.cfg"; run D
assert_contains "$SB/out" "already safe" "reports GRUB already safe"
assert_contains "$ES_GRUB_CFG" "set timeout=0" "grub.cfg not regenerated"
finish
