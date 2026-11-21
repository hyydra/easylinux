#!/usr/bin/env bash

# Description: Watchdog script to ensure xfce4-panel stays running.
# Automatically relaunches xfce4-panel if it crashes or terminates.

export DISPLAY="${DISPLAY:-:0}"
if [ -z "$XAUTHORITY" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

# Ensure single watchdog instance
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/xfce4-panel-watchdog.lock"
exec 200>"$LOCKFILE"
flock -n 200 || {
    echo "Watchdog is already running." >&2
    exit 0
}

LOG_FILE="${HOME}/.cache/xfce4-panel-watchdog.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "XFCE panel watchdog started (PID $$)."

RESTART_COUNT=0
WINDOW_START=$(date +%s)

while true; do
    # Only monitor while the X display is currently active
    if xset q >/dev/null 2>&1; then
        if ! pgrep -u "$(id -u)" -x "xfce4-panel" >/dev/null 2>&1; then
            CURRENT_TIME=$(date +%s)

            # Reset crash throttle counter every 60 seconds
            if (( CURRENT_TIME - WINDOW_START > 60 )); then
                RESTART_COUNT=0
                WINDOW_START=$CURRENT_TIME
            fi

            RESTART_COUNT=$((RESTART_COUNT + 1))

            if (( RESTART_COUNT > 5 )); then
                log "Warning: xfce4-panel restarted $RESTART_COUNT times within 60s. Throttling for 10s..."
                sleep 10
            fi

            # Export SESSION_MANAGER from running window manager if not present
            if [ -z "$SESSION_MANAGER" ]; then
                WM_PID=$(pgrep -u "$(id -u)" -x xfwm4 | head -n 1)
                if [ -n "$WM_PID" ] && [ -r "/proc/$WM_PID/environ" ]; then
                    SM=$(tr '\0' '\n' < "/proc/$WM_PID/environ" | grep '^SESSION_MANAGER=' | cut -d= -f2-)
                    [ -n "$SM" ] && export SESSION_MANAGER="$SM"
                fi
            fi

            log "xfce4-panel is not running. Restarting..."
            nohup xfce4-panel >> "$LOG_FILE" 2>&1 &
            sleep 2
        fi
    fi

    sleep 2
done
