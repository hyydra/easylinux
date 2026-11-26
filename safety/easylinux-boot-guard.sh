#!/bin/sh
# easylinux boot guard (POSIX sh).
#   start        before the display manager: if the previous boot after an easylinux
#                change was never confirmed healthy, roll the changes back.
#   confirm      after the display manager: once a graphical session (or, on a
#                headless box, a stable multi-user boot) is reached, disarm the guard.
#   confirm-now  same check without waiting; also run at shutdown, so a clean
#                shutdown from a working desktop counts as healthy.
# ES_EXPECT=graphical|headless overrides the auto-detection.
STATE="${ES_STATE_DIR:-/var/lib/easylinux}"
ROLLBACK="${ES_ROLLBACK:-/usr/local/sbin/easylinux-rollback}"
POLL="${ES_POLL:-10}"; SETTLE="${ES_SETTLE:-30}"; TRIES="${ES_TRIES:-36}"; HEADLESS_WAIT="${ES_HEADLESS_WAIT:-90}"

log() { if command -v logger >/dev/null 2>&1; then logger -t easylinux "$*"; else echo "easylinux: $*" >&2; fi; }

graphical_expected() {
    case "${ES_EXPECT:-}" in graphical) return 0 ;; headless) return 1 ;; esac
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        [ "$(systemctl get-default 2>/dev/null)" = graphical.target ]
        return
    fi
    for dm in lightdm gdm gdm3 sddm lxdm slim greetd ly xdm; do
        command -v "$dm" >/dev/null 2>&1 && return 0
    done
    return 1
}

graphical_session() {
    pgrep -x 'Xorg|Xwayland|Xorg.bin|X|sway|Hyprland|kwin_wayland|gnome-shell|weston|labwc|river|wayfire|niri|cage' >/dev/null 2>&1
}

uptime_secs() { cut -d. -f1 /proc/uptime 2>/dev/null || echo 0; }

healthy() {
    rm -f "$STATE/pending" "$STATE/booting"
    log "boot confirmed healthy - easylinux changes kept"
    exit 0
}

case "${1:-start}" in
    start)
        [ -s "$STATE/pending" ] || exit 0
        if [ -e "$STATE/booting" ]; then
            log "previous boot was not confirmed healthy - rolling back easylinux changes"
            "$ROLLBACK" --auto || true
        else
            mkdir -p "$STATE"; : > "$STATE/booting"
        fi
        ;;
    confirm)
        [ -s "$STATE/pending" ] || exit 0
        if graphical_expected; then
            i=0
            while [ "$i" -lt "$TRIES" ]; do
                sleep "$POLL"
                if graphical_session; then
                    sleep "$SETTLE"
                    graphical_session && healthy
                fi
                i=$((i + 1))
            done
            log "no graphical session after changes - will roll back on next boot"
        else
            sleep "$HEADLESS_WAIT"
            healthy
        fi
        ;;
    confirm-now)
        [ -s "$STATE/pending" ] || exit 0
        if graphical_expected; then
            graphical_session && healthy
        else
            [ "$(uptime_secs)" -ge "$HEADLESS_WAIT" ] && healthy
        fi
        ;;
esac
exit 0
