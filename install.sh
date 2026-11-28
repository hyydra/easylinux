#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROG="${EASYLINUX_PROG:-$0}"

# Run a command as root. In a graphical session with the package installed this shows the polkit
# administrator prompt (like Windows UAC) instead of asking for sudo in a terminal; the polkit
# action only allows this command to run the root-owned scripts of its own install directory.
POLKIT_POLICY="${EASYLINUX_POLKIT_POLICY:-/usr/share/polkit-1/actions/org.easyset.policy}"
as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; return; fi
    if [ -z "${EASYLINUX_NO_POLKIT:-}" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] \
       && command -v pkexec >/dev/null 2>&1 && [ -f "$POLKIT_POLICY" ] \
       && [ "$1" = bash ] && [ "$(stat -c %U "$ROOT_DIR")" = root ] && [ ! -w "$ROOT_DIR" ]; then
        local script="${2#"$ROOT_DIR"/}" exe
        exe="$(grep -o '[^>]*/bin/easyset<' "$POLKIT_POLICY" | head -1)"; exe="${exe%<}"
        if [ "$script" != "$2" ] && [ -x "$exe" ]; then
            pkexec "$exe" --as-root "$script" "${@:3}"
            return
        fi
    fi
    sudo "$@"
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
    grep -qs 'ThinkPad X280' "${EASYLINUX_DMI_FILE:-/sys/class/dmi/id/product_version}"
}

# Per-user settings (no root): safe to run from a login script.
apply_user() {
    if command -v xfce4-panel >/dev/null 2>&1 && command -v xfconf-query >/dev/null 2>&1; then
        step "XFCE panel watchdog" bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
        step "Global keyboard layout" bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
        step "Keyboard layout indicator" bash "$ROOT_DIR/desktop/xfce-global-keyboard/layout-indicator.sh"
    else
        echo "[skip] XFCE not found: panel watchdog and global keyboard layout"
    fi
    step "Windows-style clipboard" bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
    if command -v xfconf-query >/dev/null 2>&1; then
        step "Yaru theme" bash "$ROOT_DIR/desktop/theme/install.sh"
        step "Panel look" bash "$ROOT_DIR/desktop/theme/panel-look.sh"
        step "Desktop layout" bash "$ROOT_DIR/desktop/theme/desktop-layout.sh"
    fi
    if is_thinkpad_x280; then
        step "ThinkPad X280 Thunderbolt firmware check" bash "$ROOT_DIR/hardware/thinkpad-x280/check-thunderbolt-firmware.sh" --notify
    fi
    if command -v xfconf-query >/dev/null 2>&1; then
        step "Keyboard backlight keys" bash "$ROOT_DIR/desktop/kbd-backlight/install.sh"
        step "Suspend keys" bash "$ROOT_DIR/desktop/suspend-keys/install.sh"
    fi
    return "$FAILED"
}

# System settings (root): boot hardening everywhere, hardware fixes only where they apply.
apply_system() {
    step "Boot hardening (GRUB guard, rollback)" as_root bash "$ROOT_DIR/safety/harden-boot.sh"
    step "Suspend keys (logind)" as_root bash "$ROOT_DIR/desktop/suspend-keys/setup-system.sh"
    step "Password keyring" as_root bash "$ROOT_DIR/desktop/keyring/setup-keyring.sh"
    step "Keyboard backlight at boot and wake-up" as_root bash "$ROOT_DIR/desktop/kbd-backlight/setup-boot.sh"
    if is_thinkpad_x280; then
        step "ThinkPad X280 fixes" as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
        step "ThinkPad X280 touchpad split" as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
        step "ThinkPad X280 Thunderbolt firmware check" bash "$ROOT_DIR/hardware/thinkpad-x280/check-thunderbolt-firmware.sh"
    else
        echo "[skip] Not a ThinkPad X280: hardware fixes not applied"
    fi
    return "$FAILED"
}

install_all() {
    bash "$ROOT_DIR/desktop/xfce-panel-watchdog/install.sh"
    echo ""
    bash "$ROOT_DIR/desktop/xfce-global-keyboard/set-global-keyboard.sh"
    bash "$ROOT_DIR/desktop/xfce-global-keyboard/layout-indicator.sh"
    echo ""
    bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
    echo ""
    bash "$ROOT_DIR/desktop/kbd-backlight/install.sh"
    echo ""
    bash "$ROOT_DIR/desktop/theme/install.sh"
    bash "$ROOT_DIR/desktop/theme/panel-look.sh"
    bash "$ROOT_DIR/desktop/theme/desktop-layout.sh"
    echo ""
    bash "$ROOT_DIR/desktop/suspend-keys/install.sh"
    echo ""
    as_root bash "$ROOT_DIR/desktop/suspend-keys/setup-system.sh"
    echo ""
    as_root bash "$ROOT_DIR/desktop/keyring/setup-keyring.sh"
    echo ""
    as_root bash "$ROOT_DIR/desktop/kbd-backlight/setup-boot.sh"
    echo ""
    as_root bash "$ROOT_DIR/hardware/thinkpad-x280/fix-system-errors.sh"
    echo ""
    as_root bash "$ROOT_DIR/hardware/thinkpad-x280/setup-touchpad-split.sh"
    echo ""
    bash "$ROOT_DIR/hardware/thinkpad-x280/check-thunderbolt-firmware.sh"
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
    echo "6) Keyboard backlight keys (Fn+Space)"
    echo "7) Password keyring (GNOME Keyring, requires sudo)"
    echo "8) Install Everything"
    echo "9) Exit"
    echo "========================================="
    read -rp "Select an option [1-9]: " choice
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
            bash "$ROOT_DIR/desktop/kbd-backlight/install.sh"
            ;;
        7)
            as_root bash "$ROOT_DIR/desktop/keyring/setup-keyring.sh"
            ;;
        8)
            install_all
            ;;
        9)
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
            bash "$ROOT_DIR/desktop/xfce-global-keyboard/layout-indicator.sh"
            ;;
        --clipboard)
            bash "$ROOT_DIR/desktop/windows-clipboard/install.sh"
            ;;
        --theme)
            bash "$ROOT_DIR/desktop/theme/install.sh"
            bash "$ROOT_DIR/desktop/theme/panel-look.sh"
            bash "$ROOT_DIR/desktop/theme/desktop-layout.sh"
            ;;
        --tbt-check)
            bash "$ROOT_DIR/hardware/thinkpad-x280/check-thunderbolt-firmware.sh"
            ;;
        --tbt-update)
            as_root bash "$ROOT_DIR/hardware/thinkpad-x280/check-thunderbolt-firmware.sh" --update
            ;;
        --kbd-backlight)
            bash "$ROOT_DIR/desktop/kbd-backlight/install.sh"
            ;;
        --suspend-keys)
            bash "$ROOT_DIR/desktop/suspend-keys/install.sh"
            as_root bash "$ROOT_DIR/desktop/suspend-keys/setup-system.sh"
            ;;
        --kbd-backlight-boot)
            as_root bash "$ROOT_DIR/desktop/kbd-backlight/setup-boot.sh"
            ;;
        --keyring)
            as_root bash "$ROOT_DIR/desktop/keyring/setup-keyring.sh"
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
        --as-root)   # called through pkexec only: run one shipped script as root
            shift
            rel="${1:-}"; shift || true
            if [ "$(id -u)" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then echo "[-] --as-root is for pkexec (root) only"; exit 1; fi
            if [ -z "$rel" ] || [ "${rel#/}" != "$rel" ] || [ "${rel#*..}" != "$rel" ] || [ "${rel%.sh}" = "$rel" ] || [ ! -f "$ROOT_DIR/$rel" ]; then
                echo "[-] Refusing to run '$rel': only shipped *.sh scripts of $ROOT_DIR are allowed"; exit 1
            fi
            exec bash "$ROOT_DIR/$rel" "$@"
            ;;
        --doctor)
            bash "$ROOT_DIR/hardware/generic/doctor.sh"
            ;;
        --version)
            cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown"
            ;;
        --rollback)
            shift
            as_root bash "$ROOT_DIR/safety/easylinux-rollback.sh" "$@"
            ;;
        *)
            echo "Usage: ${PROG##*/} [--user | --system | --boot | --version | --panel | --thinkpad | --touchpad | --keyboard | --clipboard | --kbd-backlight | --kbd-backlight-boot | --suspend-keys | --keyring | --theme | --tbt-check | --doctor | --tbt-update | --scroll natural|traditional|toggle | --all | --rollback [--list|snapshot]]"
            exit 1
            ;;
    esac
fi
