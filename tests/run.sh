#!/usr/bin/env bash
# Run every tests/test_*.sh; non-zero exit if any file fails.
cd "$(dirname "${BASH_SOURCE[0]}")"
failed=0
for t in test_*.sh; do
    echo "== $t"
    bash "$t" || { failed=$((failed + 1)); echo "  !! $t FAILED"; }
done
echo
if [ "$failed" -eq 0 ]; then echo "ALL TEST FILES PASSED"; else echo "$failed TEST FILE(S) FAILED"; exit 1; fi
