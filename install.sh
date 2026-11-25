#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_menu() {
    echo "========================================="
    echo "            easylinux installer          "
    echo "========================================="
    echo "1) Install XFCE Panel Auto-Restart Watchdog"
    echo "2) Apply ThinkPad X280 Hardware & Driver Fixes (requires sudo)"
    echo "3) Configure ThinkPad X280 Touchpad Left/Right Split (requires sudo)"
    echo "4) Set XFCE Global Keyboard Layout (No per-window language switching)"
    echo "5) Install Everything"
    echo "6) Exit"
    echo "========================================="
    read -rp "Select an option [1-6]: " choice
    case "$choice" in
        1)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            ;;
        2)
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        3)
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
            ;;
        4)
            bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
            ;;
        5)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            echo ""
            bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
            echo ""
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            echo ""
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
            ;;
        6)
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
        --touchpad)
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
            ;;
        --keyboard)
            bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
            ;;
        --all)
            bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
            echo ""
            bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
            echo ""
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            echo ""
            sudo bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
            ;;
        *)
            echo "Usage: $0 [--panel | --thinkpad | --touchpad | --keyboard | --all]"
            exit 1
            ;;
    esac
fi
