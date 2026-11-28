#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$TEST_ROOT" || exit 1
SHELLCHECK_SH="$(command -v dash || command -v sh)"
while IFS= read -r f; do
    shebang="$(head -n1 "$f")"
    case "$shebang" in
        '#!/bin/sh'*|'#!/sbin/openrc-run'*) checker="$SHELLCHECK_SH" ;;
        *) checker=bash ;;
    esac
    if "$checker" -n "$f" 2>/dev/null; then ok "syntax $f"; else bad "syntax $f"; fi
    case "$f" in tests/lib.sh|safety/lib.sh) ;; *)
        if [ -x "$f" ]; then ok "executable $f"; else bad "executable $f"; fi ;;
    esac
done < <(git ls-files '*.sh' packaging/easyset packaging/easyset-user-setup packaging/debian/postinst safety/easylinux-guard.openrc)
finish
