#!/usr/bin/env bash
# easylinux safety net: distro / init / bootloader independent protection for
# scripts that change system files.
#
#   source safety/lib.sh
#   es_begin "name"; es_backup /etc/foo.conf; es_backup_initramfs; ...; es_arm
#
# Layers (each one is skipped, with a notice, when the system cannot do it):
#   1. file snapshot + easylinux-rollback           (any Linux, no dependencies)
#   2. filesystem snapshot (snapper; timeshift opt-in)
#   3. GRUB never waits forever / always shows a menu (so you can't get stuck)
#   4. boot guard: auto-rollback if the next boot never reaches a desktop
#
# Test knobs: ES_TEST=1 skips system side effects; ES_BACKUP_DIR, ES_STATE_DIR,
# ES_GRUB_DEFAULT, ES_GRUB_DROPIN_DIR, ES_GRUB_CFG redirect paths.

ES_BACKUP_DIR="${ES_BACKUP_DIR:-/var/backups/easylinux}"
ES_STATE_DIR="${ES_STATE_DIR:-/var/lib/easylinux}"
ES_SAFETY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ES_KEEP="${ES_KEEP:-10}"
ES_GRUB_DEFAULT="${ES_GRUB_DEFAULT:-/etc/default/grub}"
ES_GRUB_DROPIN_DIR="${ES_GRUB_DROPIN_DIR:-/etc/default/grub.d}"
ES_SNAP=""

es_say()  { echo "[safety] $*"; }
es_warn() { echo "[safety][!] $*" >&2; }

# ---------------------------------------------------------------- detection
es_detect() {
    ES_DISTRO="$( ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-${NAME:-unknown}}" ) || echo unknown )"

    if [ -d /run/systemd/system ]; then ES_INIT=systemd
    elif command -v openrc-run >/dev/null 2>&1 || [ -x /sbin/openrc-run ]; then ES_INIT=openrc
    else ES_INIT=other; fi

    ES_INITRAMFS_TOOL=none
    local t
    for t in update-initramfs dracut mkinitcpio mkinitfs; do
        if command -v "$t" >/dev/null 2>&1; then ES_INITRAMFS_TOOL="$t"; break; fi
    done

    ES_GRUB_MKCONFIG="$(command -v grub-mkconfig || command -v grub2-mkconfig || true)"
    ES_GRUB_CHECK="$(command -v grub-script-check || command -v grub2-script-check || true)"
    ES_GRUB_CFG="${ES_GRUB_CFG:-}"
    if [ -z "$ES_GRUB_CFG" ]; then
        if   [ -f /boot/grub/grub.cfg ];  then ES_GRUB_CFG=/boot/grub/grub.cfg
        elif [ -f /boot/grub2/grub.cfg ]; then ES_GRUB_CFG=/boot/grub2/grub.cfg
        fi
    fi

    ES_BOOTLOADER=unknown
    if [ -n "$ES_GRUB_CFG" ] && [ -n "$ES_GRUB_MKCONFIG" ]; then ES_BOOTLOADER=grub
    elif [ -d /boot/loader ] || [ -d /efi/loader ] || [ -d /boot/efi/loader ]; then ES_BOOTLOADER=systemd-boot
    elif [ -d /boot/syslinux ] || [ -f /boot/extlinux/extlinux.conf ]; then ES_BOOTLOADER=syslinux
    elif [ -f /boot/limine.conf ] || [ -f /boot/limine/limine.conf ]; then ES_BOOTLOADER=limine
    fi

    ES_KERNELS="$(ls /boot/vmlinuz-* /boot/vmlinux-* /boot/Image-* 2>/dev/null | wc -l)"
    [ "$ES_KERNELS" -gt 0 ] || ES_KERNELS="$(ls /boot/vmlinuz* /boot/vmlinux* 2>/dev/null | grep -v '\.old$' | wc -l)"

    ES_FS_SNAP=none
    if   command -v snapper  >/dev/null 2>&1 && snapper list-configs 2>/dev/null | grep -qw root; then ES_FS_SNAP=snapper
    elif command -v timeshift >/dev/null 2>&1; then ES_FS_SNAP=timeshift
    fi
}

es_status() {
    es_detect
    es_say "System      : $ES_DISTRO"
    es_say "Init        : $ES_INIT   Bootloader: $ES_BOOTLOADER   Initramfs tool: $ES_INITRAMFS_TOOL"
    es_say "Kernels     : $ES_KERNELS installed   FS snapshots: $ES_FS_SNAP"
    if [ -e /etc/NIXOS ] || [ -e /run/ostree-booted ]; then
        es_warn "Immutable/declarative system (NixOS/ostree): edits under /etc may be overwritten; rollback is best-effort."
    fi
    if [ "$ES_KERNELS" -lt 2 ]; then
        es_warn "Only $ES_KERNELS kernel installed. Install a second one (e.g. the LTS kernel): it is your real escape hatch if a boot breaks."
    fi
    case "$ES_INIT" in
        systemd|openrc) : ;;
        *) es_warn "Init '$ES_INIT': no automatic boot guard. Manual rollback only (easylinux-rollback)." ;;
    esac
    if [ "$ES_BOOTLOADER" != grub ]; then
        es_warn "Bootloader '$ES_BOOTLOADER': GRUB protections skipped. Make sure its menu has a timeout and an older kernel entry."
    fi
}

# ----------------------------------------------------------------- snapshots
es_begin() {
    ES_SNAP="$ES_BACKUP_DIR/$(date +%Y%m%d-%H%M%S)-$1"
    mkdir -p "$ES_SNAP/files" "$ES_STATE_DIR"
    : > "$ES_SNAP/manifest"
    # self-contained copy so a live USB can use it:  sh <snapshot>/rollback.sh --root /mnt
    cp "$ES_SAFETY_DIR/easylinux-rollback.sh" "$ES_SNAP/rollback.sh"
    chmod 755 "$ES_SNAP/rollback.sh"
    es_say "Snapshot: $ES_SNAP"
    es_prune
}

# keep the newest $ES_KEEP snapshots (never one that is still unconfirmed)
es_prune() {
    local d n=0
    find "$ES_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | while read -r d; do
        n=$((n + 1))
        [ "$n" -gt "$ES_KEEP" ] || continue
        grep -qxF -- "$d" "$ES_STATE_DIR/pending" 2>/dev/null && continue
        rm -rf -- "$d"
    done
}

# Save a file's current state. A file that does not exist yet is recorded so
# rollback removes it again.
es_backup() {
    local path="$1"
    if cut -f2 "$ES_SNAP/manifest" | grep -qxF -- "$path"; then
        return 0
    fi
    if [ -e "$path" ]; then
        mkdir -p "$ES_SNAP/files$(dirname "$path")"
        cp -a "$path" "$ES_SNAP/files$path"
        printf 'F\t%s\n' "$path" >> "$ES_SNAP/manifest"
    else
        printf 'N\t%s\n' "$path" >> "$ES_SNAP/manifest"
    fi
}

# Put one file back immediately (used when a step fails before arming completes).
es_revert() {
    local path="$1"
    if [ -e "$ES_SNAP/files$path" ]; then cp -a "$ES_SNAP/files$path" "$path"; else rm -f "$path"; fi
}

es_note() { printf '%s\n' "$1" >> "$ES_SNAP/notes"; }

# Back up the initramfs images of the running kernel (and unversioned ones such
# as Arch's initramfs-linux.img), tool- and distro-independent.
es_backup_initramfs() {
    local kv f need=0 avail
    local -a files=()
    kv="$(uname -r)"
    for f in /boot/initr*; do
        [ -f "$f" ] && [ ! -L "$f" ] || continue
        case "$f" in
            *"$kv"*) files+=("$f") ;;
            *) case "$(basename "$f")" in *[0-9].[0-9]*) ;; *) files+=("$f") ;; esac ;;
        esac
    done
    [ "${#files[@]}" -gt 0 ] || { es_warn "No initramfs image found in /boot; rollback will regenerate it."; return 0; }
    for f in "${files[@]}"; do need=$((need + $(du -k "$f" | cut -f1))); done
    avail="$(df -Pk "$ES_BACKUP_DIR" | awk 'NR==2{print $4}')"
    if [ "$((need * 2))" -gt "${avail:-0}" ]; then
        es_warn "Not enough free space to save the initramfs; rollback will regenerate it."
        return 0
    fi
    for f in "${files[@]}"; do es_backup "$f"; done
    es_say "Saved initramfs: ${files[*]}"
}

es_rebuild_initramfs() {
    es_detect
    case "$ES_INITRAMFS_TOOL" in
        update-initramfs) update-initramfs -u ;;
        dracut)           dracut -f --kver "$(uname -r)" ;;
        mkinitcpio)       mkinitcpio -P ;;
        mkinitfs)         mkinitfs "$(uname -r)" ;;
        *) es_warn "No known initramfs tool found; skipping initramfs rebuild." ;;
    esac
}

# Optional filesystem-level snapshot. snapper (btrfs) is fast and automatic;
# timeshift can take minutes in rsync mode, so it is opt-in: ES_FS_SNAPSHOT=1.
es_fs_snapshot() {
    [ -n "${ES_TEST:-}" ] && return 0
    case "$ES_FS_SNAP" in
        snapper)   snapper -c root create -d "easylinux: $1" >/dev/null 2>&1 && es_say "snapper snapshot created" ;;
        timeshift) [ "${ES_FS_SNAPSHOT:-0}" = 1 ] && timeshift --create --comments "easylinux: $1" >/dev/null 2>&1 && es_say "timeshift snapshot created" ;;
    esac
    return 0
}

# -------------------------------------------------------------------- GRUB
# Ubuntu/Debian GRUB, after one failed boot, shows the menu and waits FOREVER
# (GRUB_RECORDFAIL_TIMEOUT=-1), and a hidden menu (TIMEOUT=0) hides the older
# kernels. Make sure the menu is visible, times out, and never waits forever.
es_grub_effective() {   # prints "STYLE TIMEOUT RECORDFAIL" as GRUB would see them
    (
        set +eu
        GRUB_TIMEOUT_STYLE=""; GRUB_TIMEOUT=""; GRUB_RECORDFAIL_TIMEOUT=""
        # shellcheck disable=SC1090
        . "$ES_GRUB_DEFAULT" >/dev/null 2>&1
        for f in "$ES_GRUB_DROPIN_DIR"/*.cfg; do [ -f "$f" ] && . "$f" >/dev/null 2>&1; done
        echo "${GRUB_TIMEOUT_STYLE:-menu} ${GRUB_TIMEOUT:-5} ${GRUB_RECORDFAIL_TIMEOUT:--1}"
    )
}

es_grub_set_key() {     # edit /etc/default/grub in place
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ES_GRUB_DEFAULT"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$ES_GRUB_DEFAULT"
    else
        printf '%s=%s\n' "$key" "$val" >> "$ES_GRUB_DEFAULT"
    fi
}

es_grub_safety() {
    [ "$ES_BOOTLOADER" = grub ] || return 0
    local style timeout rf want_style want_timeout want_rf
    read -r style timeout rf <<< "$(es_grub_effective)"
    want_style="$style"; want_timeout="$timeout"; want_rf="$rf"
    case "$style" in menu|countdown) ;; *) want_style=menu ;; esac
    case "$timeout" in ''|*[!0-9]*|0) want_timeout="${ES_GRUB_TIMEOUT:-3}" ;; esac
    case "$rf" in ''|*[!0-9]*|0) want_rf="${ES_GRUB_RECORDFAIL_TIMEOUT:-5}" ;; esac
    if [ "$want_style" = "$style" ] && [ "$want_timeout" = "$timeout" ] && [ "$want_rf" = "$rf" ]; then
        es_say "GRUB already safe (menu=$style timeout=${timeout}s recordfail=${rf}s)."
        return 0
    fi
    if [ -z "$ES_GRUB_CHECK" ]; then
        es_warn "grub-script-check not found: cannot validate a new grub.cfg, so GRUB settings are left untouched."
        return 0
    fi

    local dropin="$ES_GRUB_DROPIN_DIR/99-easylinux-safety.cfg" touched=""
    es_backup "$ES_GRUB_CFG"
    if [ -d "$ES_GRUB_DROPIN_DIR" ]; then
        es_backup "$dropin"; touched="$dropin"
        printf '# easylinux: never get stuck at the GRUB menu\nGRUB_TIMEOUT_STYLE=%s\nGRUB_TIMEOUT=%s\nGRUB_RECORDFAIL_TIMEOUT=%s\n' \
            "$want_style" "$want_timeout" "$want_rf" > "$dropin"
    else
        es_backup "$ES_GRUB_DEFAULT"; touched="$ES_GRUB_DEFAULT"
        es_grub_set_key GRUB_TIMEOUT_STYLE "$want_style"
        es_grub_set_key GRUB_TIMEOUT "$want_timeout"
        es_grub_set_key GRUB_RECORDFAIL_TIMEOUT "$want_rf"
    fi

    # Generate to a temp file, validate, and only then swap it in.
    local tmp old_n new_n
    tmp="$(mktemp "$ES_GRUB_CFG.easylinux-new.XXXXXX")"
    if "$ES_GRUB_MKCONFIG" -o "$tmp" >/dev/null 2>&1 \
       && "$ES_GRUB_CHECK" "$tmp" >/dev/null 2>&1; then
        old_n="$(grep -cE '^[[:space:]]*menuentry ' "$ES_GRUB_CFG" 2>/dev/null || echo 0)"
        new_n="$(grep -cE '^[[:space:]]*menuentry ' "$tmp" || echo 0)"
        if [ "$new_n" -ge 1 ] && [ "$((new_n * 2))" -ge "$old_n" ]; then
            chmod --reference="$ES_GRUB_CFG" "$tmp" 2>/dev/null || true
            mv -f "$tmp" "$ES_GRUB_CFG"
            es_say "GRUB hardened: menu=$want_style timeout=${want_timeout}s recordfail=${want_rf}s ($new_n entries)."
            return 0
        fi
    fi
    rm -f "$tmp"
    es_revert "$touched"
    es_warn "Could not generate a valid grub.cfg; GRUB settings left exactly as they were."
}

# -------------------------------------------------------------- boot guard
es_install_guard() {
    [ -n "${ES_TEST:-}" ] && return 0
    mkdir -p /usr/local/sbin
    cp "$ES_SAFETY_DIR/easylinux-rollback.sh"   /usr/local/sbin/easylinux-rollback
    cp "$ES_SAFETY_DIR/easylinux-boot-guard.sh" /usr/local/sbin/easylinux-boot-guard
    chmod 755 /usr/local/sbin/easylinux-rollback /usr/local/sbin/easylinux-boot-guard
    case "$ES_INIT" in
        systemd)
            cp "$ES_SAFETY_DIR/easylinux-boot-guard.service"   /etc/systemd/system/
            cp "$ES_SAFETY_DIR/easylinux-boot-confirm.service" /etc/systemd/system/
            systemctl daemon-reload
            systemctl enable easylinux-boot-guard.service easylinux-boot-confirm.service >/dev/null 2>&1
            ;;
        openrc)
            cp "$ES_SAFETY_DIR/easylinux-guard.openrc" /etc/init.d/easylinux-guard
            chmod 755 /etc/init.d/easylinux-guard
            rc-update add easylinux-guard default >/dev/null 2>&1 || true
            ;;
        *) es_warn "No supported init for the automatic boot guard; use 'sudo easylinux-rollback' manually." ;;
    esac
}

# Mark the snapshot unconfirmed: if the next boot is not healthy the guard rolls
# it back. Call this BEFORE making the real changes.
es_arm() {
    es_status
    es_fs_snapshot "$(basename "$ES_SNAP")"
    es_grub_safety
    ln -sfn "$(basename "$ES_SNAP")" "$ES_BACKUP_DIR/latest"
    echo "$ES_SNAP" >> "$ES_STATE_DIR/pending"
    rm -f "$ES_STATE_DIR/booting"
    es_install_guard
    es_say "Armed. Undo anytime with: sudo easylinux-rollback"
}
