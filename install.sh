#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_menu() {
    echo "========================================="
    echo "            easylinux installer          "
    echo "========================================="
    echo "1) Install XFCE Panel Auto-Restart Watchdog"
    echo "2) Apply ThinkPad X280 Hardware Fixes (requires sudo)"
    echo "3) Install Everything"
    echo "4) Exit"
    echo "========================================="
    read -rp "Select an option [1-4]: " choice
    case "$choice" in
        1)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            ;;
        2)
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        3)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            echo ""
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid selection."
            exit 1
            ;;
    esac
}

if [ $# -eq 0 ]; then
    show_menu
else
    case "$1" in
        --panel)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            ;;
        --thinkpad)
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        --all)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        *)
            echo "Usage: $0 [--panel | --thinkpad | --all]"
            exit 1
            ;;
    esac
fi
