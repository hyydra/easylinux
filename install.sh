#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_all() {
    bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
    echo ""
    bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
    echo ""
    bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
    echo ""
    sudo bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
    echo ""
    sudo bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
}

show_menu() {
    echo "========================================="
    echo "            easylinux installer          "
    echo "========================================="
    echo "1) Install XFCE Panel Auto-Restart Watchdog"
    echo "2) Apply ThinkPad X280 Hardware & Driver Fixes (requires sudo)"
    echo "3) Configure ThinkPad X280 Touchpad Left/Right Split (requires sudo)"
    echo "4) Set XFCE Global Keyboard Layout (No per-window language switching)"
    echo "5) Windows-style Ctrl+C / Ctrl+V everywhere (kitty terminal)"
    echo "6) Install Everything"
    echo "7) Exit"
    echo "========================================="
    read -rp "Select an option [1-7]: " choice
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
            bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
            ;;
        6)
            install_all
            ;;
        7)
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
        --clipboard)
            bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
            ;;
        --all)
            install_all
            ;;
        --rollback)
            shift
            sudo bash "$ROOT_DIR/safety/easylinux-rollback.sh" "$@"
            ;;
        *)
            echo "Usage: $0 [--panel | --thinkpad | --touchpad | --keyboard | --clipboard | --all | --rollback [--list|snapshot]]"
            exit 1
            ;;
    esac
fi
