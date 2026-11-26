#!/usr/bin/env bash
# Windows-style Ctrl+C / Ctrl+V everywhere, including the terminal.
# GUI apps already use Ctrl+C/V on Linux; terminals are the exception
# (Ctrl+Shift+C/V), because Ctrl+C there means "interrupt". kitty can do both:
# copy when text is selected, interrupt otherwise - exactly like Windows Terminal.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
HELPERS="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/helpers.rc"
INCLUDE_LINE="include easylinux.conf"

echo "==> Windows-style clipboard (Ctrl+C / Ctrl+V)"

install_kitty() {
    command -v kitty >/dev/null 2>&1 && return 0
    if [ -n "${EASYLINUX_NO_PKG:-}" ]; then
        echo "[!] kitty is not installed and package installation is disabled here"
        return 1
    fi
    echo "[!] kitty is not installed; installing it with the system package manager (needs sudo)"
    if   command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y kitty
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y kitty
    elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm kitty
    elif command -v zypper  >/dev/null 2>&1; then sudo zypper --non-interactive install kitty
    elif command -v apk     >/dev/null 2>&1; then sudo apk add kitty
    elif command -v xbps-install >/dev/null 2>&1; then sudo xbps-install -y kitty
    else echo "[-] Unknown package manager: install 'kitty' manually and re-run."; return 1
    fi
}

# 1. kitty config (written first so it is ready as soon as kitty exists)
mkdir -p "$KITTY_DIR"
install -m 644 "$SCRIPT_DIR/kitty-easylinux.conf" "$KITTY_DIR/easylinux.conf"
touch "$KITTY_DIR/kitty.conf"
if ! grep -qxF "$INCLUDE_LINE" "$KITTY_DIR/kitty.conf"; then
    printf '\n# easylinux\n%s\n' "$INCLUDE_LINE" >> "$KITTY_DIR/kitty.conf"
fi
echo "[✓] kitty: Ctrl+C = copy-or-interrupt, Ctrl+V = paste ($KITTY_DIR/easylinux.conf)"

# 2. make kitty the default terminal - only if it really is installed
if install_kitty && command -v kitty >/dev/null 2>&1; then
    if command -v xfce4-session >/dev/null 2>&1 || [ -d "$(dirname "$HELPERS")" ]; then
        mkdir -p "$(dirname "$HELPERS")"
        [ -f "$HELPERS" ] && [ ! -f "$HELPERS.easylinux-bak" ] && cp -a "$HELPERS" "$HELPERS.easylinux-bak"
        touch "$HELPERS"
        if grep -q '^TerminalEmulator=' "$HELPERS"; then
            sed -i 's|^TerminalEmulator=.*|TerminalEmulator=kitty|' "$HELPERS"
        else
            echo "TerminalEmulator=kitty" >> "$HELPERS"
        fi
        echo "[✓] XFCE default terminal (Ctrl+Alt+T) = kitty"
    fi
    echo "=== Done! Open a NEW terminal: select text + Ctrl+C copies, no selection + Ctrl+C interrupts, Ctrl+V pastes. ==="
else
    echo "[!] kitty missing: default terminal left unchanged (config is ready; re-run after installing kitty)."
    exit 1
fi
