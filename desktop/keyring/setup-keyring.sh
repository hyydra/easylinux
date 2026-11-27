#!/usr/bin/env bash
# Password keyring (GNOME Keyring + Seahorse): browsers, Wi-Fi, git and mail clients can store
# their passwords, and the keyring unlocks together with the login.
# Debian/Ubuntu based systems; elsewhere it only reports what is missing.
set -euo pipefail

if [ "$EUID" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAM_DIR="${EASYLINUX_PAM_DIR:-/etc/pam.d}"
PKGS="gnome-keyring libpam-gnome-keyring seahorse libsecret-tools"

# shellcheck source=../../safety/lib.sh
source "$SCRIPT_DIR/../../safety/lib.sh"

echo "=== Keyring ==="
es_begin keyring
es_backup "$PAM_DIR/lightdm"
es_backup "$PAM_DIR/gdm-password"
es_backup "$PAM_DIR/sddm"
es_arm

if [ -n "${EASYLINUX_NO_PKG:-}" ]; then
    echo "[skip] package installation disabled (the package depends on: $PKGS)"
elif command -v apt-get >/dev/null 2>&1; then
    missing=""
    for p in $PKGS; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
    if [ -n "$missing" ]; then
        es_note "easylinux installed keyring packages; remove with: apt-get remove$missing"
        apt-get install -y $missing
    else
        echo "[✓] Keyring packages already installed"
    fi
else
    echo "[!] Not an apt system: install gnome-keyring, its PAM module and seahorse with your package manager"
fi

# The login keyring only unlocks automatically if the display manager's PAM stack loads the module.
pam_loads_keyring() {   # the file itself, or the common-auth/common-session it includes
    local f="$PAM_DIR/$1"
    grep -qs 'pam_gnome_keyring' "$f" && return 0
    grep -qs '^@include common-' "$f" && grep -qs 'pam_gnome_keyring' "$PAM_DIR/common-auth" "$PAM_DIR/common-session"
}
found=0; hooked=0
for f in lightdm gdm-password sddm login; do
    [ -f "$PAM_DIR/$f" ] || continue
    found=1
    if pam_loads_keyring "$f"; then hooked=1; fi
done
if [ "$found" -eq 1 ] && [ "$hooked" -eq 0 ]; then
    echo "[!] The login PAM stack does not load pam_gnome_keyring: the keyring will ask for its password after login."
    echo "    On Debian/Ubuntu: sudo apt install --reinstall libpam-gnome-keyring && sudo pam-auth-update"
elif [ "$hooked" -eq 1 ]; then
    echo "[✓] The keyring unlocks with your login"
fi
echo "[i] The 'login' keyring needs the same password as your user account; if it asks anyway, change it in Seahorse (Passwords and Keys)."
echo "=== Done ==="
