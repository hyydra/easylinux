#!/usr/bin/env bash
# Boot hardening that is useful on every machine: GRUB never waits forever / always
# shows a menu, plus the rollback tool and boot guard. Changes are snapshotted.
set -euo pipefail
if [ "$EUID" -ne 0 ]; then echo "[-] Please run as root: sudo $0"; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
es_begin boot-hardening
es_arm
