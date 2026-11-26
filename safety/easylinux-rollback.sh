#!/bin/sh
# easylinux-rollback: undo easylinux system changes from a snapshot.
# Plain POSIX sh, no dependencies, so it also works from a live USB / rescue shell.
#
#   easylinux-rollback                  roll back the latest snapshot
#   easylinux-rollback --list           list snapshots (newest first)
#   easylinux-rollback --status         show guard state
#   easylinux-rollback --auto           roll back every unconfirmed snapshot (boot guard)
#   easylinux-rollback <snapshot-dir>   roll back a specific snapshot
#   --root /mnt                         operate on an offline system mounted at /mnt
#
# Rescue examples:
#   GRUB recovery root shell :  mount -o remount,rw / ; easylinux-rollback
#   live USB (root on /mnt, /boot mounted at /mnt/boot):
#       sh /mnt/var/backups/easylinux/latest/rollback.sh --root /mnt
set -eu

TAB="$(printf '\t')"
ROOT=""
MODE=latest
SNAP_ARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root)   ROOT="${2%/}"; shift 2 ;;
        --list)   MODE=list; shift ;;
        --status) MODE=status; shift ;;
        --auto)   MODE=auto; shift ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *)        SNAP_ARG="${1%/}"; MODE=one; shift ;;
    esac
done
BACKUP_DIR="${ES_BACKUP_DIR:-$ROOT/var/backups/easylinux}"
STATE_DIR="${ES_STATE_DIR:-$ROOT/var/lib/easylinux}"

if [ "$(id -u)" -ne 0 ] && [ -z "${ES_TEST:-}" ]; then
    echo "[-] Please run as root: sudo $0 $*"
    exit 1
fi

list_snapshots() {
    # real directories only: skips the "latest" symlink
    find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r
}

rebuild_initramfs() {
    if   command -v update-initramfs >/dev/null 2>&1; then update-initramfs -u
    elif command -v dracut           >/dev/null 2>&1; then dracut -f --kver "$(uname -r)"
    elif command -v mkinitcpio       >/dev/null 2>&1; then mkinitcpio -P
    elif command -v mkinitfs         >/dev/null 2>&1; then mkinitfs "$(uname -r)"
    else echo "  [!] no initramfs tool found; regenerate it manually if boot config changed"
    fi
}

rollback_one() {
    snap="$1"
    if [ ! -f "$snap/manifest" ] && [ -n "$ROOT" ] && [ -f "$ROOT$snap/manifest" ]; then snap="$ROOT$snap"; fi
    [ -f "$snap/manifest" ] || { echo "[-] Not a snapshot: $snap"; return 1; }
    echo "==> Rolling back $snap"
    while IFS="$TAB" read -r kind path; do
        case "$kind" in
            F)
                mkdir -p "$(dirname "$ROOT$path")"
                cp -a "$snap/files$path" "$ROOT$path.easylinux-tmp"
                mv -f "$ROOT$path.easylinux-tmp" "$ROOT$path"
                echo "  [restored] $path"
                ;;
            N)
                rm -f "$ROOT$path"
                echo "  [removed]  $path"
                ;;
        esac
    done < "$snap/manifest"

    if [ -f "$snap/notes" ]; then sed 's/^/  [note] /' "$snap/notes"; fi

    needs_initramfs=0
    if ! grep -q "${TAB}/boot/initr" "$snap/manifest" \
       && grep -qE "${TAB}/etc/(modprobe\.d|initramfs-tools|dracut\.conf\.d|mkinitcpio)" "$snap/manifest"; then
        needs_initramfs=1
    fi
    if [ -n "$ROOT" ]; then
        [ "$needs_initramfs" = 0 ] || echo "  [!] boot config was restored but no initramfs copy exists: regenerate it from a chroot"
    elif [ -z "${ES_TEST:-}" ]; then
        [ "$needs_initramfs" = 0 ] || rebuild_initramfs || true
        udevadm control --reload 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
    fi

    touch "$snap/ROLLED_BACK"
    if [ -f "$STATE_DIR/pending" ]; then
        rel="${snap#"$ROOT"}"
        grep -vxF -- "$rel" "$STATE_DIR/pending" > "$STATE_DIR/pending.new" || true
        mv -f "$STATE_DIR/pending.new" "$STATE_DIR/pending"
        [ -s "$STATE_DIR/pending" ] || rm -f "$STATE_DIR/pending" "$STATE_DIR/booting"
    fi
}

done_msg() { echo "=== Rolled back. Reboot to be sure everything is back to normal. ==="; }

case "$MODE" in
    list)   list_snapshots ;;
    status)
        echo "snapshots : $(list_snapshots | wc -l)"
        echo "unconfirmed: $( [ -s "$STATE_DIR/pending" ] && wc -l < "$STATE_DIR/pending" || echo 0 )"
        [ ! -e "$STATE_DIR/booting" ] || echo "guard      : waiting for a healthy boot (booting flag set)"
        ;;
    auto)
        [ -s "$STATE_DIR/pending" ] || exit 0
        awk '{a[NR]=$0} END{for(i=NR;i>0;i--)print a[i]}' "$STATE_DIR/pending" > "$STATE_DIR/pending.rev"
        while read -r s; do rollback_one "$s" || true; done < "$STATE_DIR/pending.rev"
        rm -f "$STATE_DIR/pending.rev" "$STATE_DIR/pending" "$STATE_DIR/booting"
        ;;
    one)    rollback_one "$SNAP_ARG"; done_msg ;;
    latest)
        latest="$(list_snapshots | head -n 1)"
        [ -n "$latest" ] || { echo "[-] No snapshots in $BACKUP_DIR"; exit 1; }
        rollback_one "$latest"; done_msg
        ;;
esac
