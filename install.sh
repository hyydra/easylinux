#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROG="${EASYLINUX_PROG:-$0}"

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# Run one step; never abort the whole run because one module is not applicable.
FAILED=0
step() {
    local name="$1"; shift
    echo ""
    echo "### $name"
    if ! "$@"; then
        echo "[!] $name failed"
        FAILED=1
    fi
}

is_thinkpad_x280() {
    grep -qs 'ThinkPad X280' /sys/class/dmi/id/product_version
}

# Per-user settings (no root): safe to run from a login script.
apply_user() {
    if command -v xfce4-panel >/dev/null 2>&1 && command -v xfconf-query >/dev/null 2>&1; then
        step "XFCE panel watchdog" bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
        step "Global keyboard layout" bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
    else
        echo "[skip] XFCE not found: panel watchdog and global keyboard layout"
    fi
    step "Windows-style clipboard" bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
    return "$FAILED"
}

# System settings (root): boot hardening everywhere, hardware fixes only where they apply.
apply_system() {
    step "Boot hardening (GRUB guard, rollback)" as_root bash "$ROOT_DIR/safety/harden-boot.sh"
    if is_thinkpad_x280; then
        step "ThinkPad X280 fixes" as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
        step "ThinkPad X280 touchpad split" as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
    else
        echo "[skip] Not a ThinkPad X280: hardware fixes not applied"
    fi
    return "$FAILED"
}

install_all() {
    bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
    echo ""
    bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
    echo ""
    bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
    echo ""
    as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
    echo ""
    as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
}

show_menu() {
    echo "========================================="
    echo "            easylinux installer          "
    echo "  EXPERIMENTAL and RISKY: changes system "
    echo "  files and GRUB. Read the README first. "
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
            as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        3)
            as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
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
            as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
            ;;
        --touchpad)
            as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
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
        --user)
            apply_user
            ;;
        --system)
            apply_system
            ;;
        --boot)
            as_root bash "$ROOT_DIR/safety/harden-boot.sh"
            ;;
        --scroll)
            shift
            EASYLINUX_PROG="$PROG" bash "$ROOT_DIR/hardware/thinkpad-x280/set-scroll-direction.sh" "$@"
            ;;
        --version)
            cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown"
            ;;
        --rollback)
            shift
            as_root bash "$ROOT_DIR/safety/easylinux-rollback.sh" "$@"
            ;;
        *)
            echo "Usage: ${PROG##*/} [--user | --system | --boot | --version | --panel | --thinkpad | --touchpad | --keyboard | --clipboard | --scroll natural|traditional|toggle | --all | --rollback [--list|snapshot]]"
            exit 1
            ;;
    esac
fi
