# easylinux

A curated collection of automated fixers, watchdogs, and desktop utilities for Linux.

## Modules

### 1. XFCE Panel Watchdog (`desktop/xfce-panel-watchdog`)
- Automatically monitors and recovers `xfce4-panel` if it crashes or terminates.
- Re-attaches to the active user X11 session and session manager.
- Runs as a `systemd --user` service with crash-loop throttling.

### 2. ThinkPad X280 System Fixes (`hardware/thinkpad-x280`)
- Fixes TrackPoint / clickpad conflicts (`synaptics_intertouch=0`).
- Touchpad resume reload hook after suspend.
- Fixes for udev power rules, obsolete ALSA ioctls, and crash dump cleanup.

## Quick Start

```bash
git clone https://github.com/hyydra/easylinux.git
cd easylinux
chmod +x install.sh
./install.sh
```

You can run individual modules directly:
```bash
# Install only the panel watchdog
./install.sh --panel

# Apply ThinkPad hardware fixes
./install.sh --thinkpad
```
