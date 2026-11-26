#!/usr/bin/env bash
# Tiny test helpers (no dependencies). Every test runs in a sandbox: system paths are
# redirected with the ES_* variables, so nothing outside a temp dir is ever touched.
T_PASS=0; T_FAIL=0
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok()  { T_PASS=$((T_PASS + 1)); echo "  ok   $*"; }
bad() { T_FAIL=$((T_FAIL + 1)); echo "  FAIL $*"; }

assert_eq()       { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected '$2', got '$1')"; fi; }
assert_file()     { if [ -e "$1" ]; then ok "$2"; else bad "$2 (missing $1)"; fi; }
assert_no_file()  { if [ ! -e "$1" ]; then ok "$2"; else bad "$2 (still exists: $1)"; fi; }
assert_contains() { if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3 ('$2' not in $1)"; fi; }
assert_lacks()    { if ! grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3 ('$2' found in $1)"; fi; }

sandbox() {
    SB="$(mktemp -d)"
    trap 'rm -rf "$SB"' EXIT
    export ES_TEST=1 ES_NO_GRUB=1 ES_BACKUP_DIR="$SB/bk" ES_STATE_DIR="$SB/st"
    mkdir -p "$SB/etc" "$SB/bin"
}

finish() {
    echo "  -> $T_PASS passed, $T_FAIL failed"
    [ "$T_FAIL" -eq 0 ]
}
