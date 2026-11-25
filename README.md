# easylinux

A curated collection of automated fixers, watchdogs, and desktop utilities for Linux.

## Modules

### 1. Desktop Tweaks (`desktop/`)

#### XFCE Panel Watchdog (`desktop/xfce-panel-watchdog`)
- Automatically monitors and recovers `xfce4-panel` if it crashes or terminates.
- Re-attaches to the active user X11 session and session manager.
- Runs as a `systemd --user` service with crash-loop throttling.

#### XFCE Global Keyboard Layout (`desktop/xfce-global-keyboard`)
- Prevents language/layout resets between different application windows.
- Enforces a single global layout policy across the entire desktop.

### 2. Hardware Tweaks (`hardware/`)

#### ThinkPad X280 System & Driver Fixes (`hardware/thinkpad-x280`)
- Fixes TrackPoint / clickpad conflicts (`synaptics_intertouch=0`).
- Touchpad resume reload hook after suspend.
- Fixes for udev power rules, obsolete ALSA ioctls, and crash dump cleanup.

#### ThinkPad X280 Touchpad Full-Height Split (`hardware/thinkpad-x280`)
- Fixes `libinput` issue where mid/top clicks on the right side register as left clicks.
- Configures `synaptics` driver for a 50/50 vertical division across the full height of the pad ($X_{\text{half}} = 968$).
- Retains natural two-finger scrolling and tap-to-click.

## Quick Start

```bash
git clone https://github.com/hyydra/easylinux.git
cd easylinux
chmod +x install.sh
./install.sh
```

You can run individual modules directly via command-line flags:
```bash
# Install only the panel watchdog
./install.sh --panel

# Enforce global keyboard layout (no per-window switching)
./install.sh --keyboard

# Apply ThinkPad hardware & driver fixes
./install.sh --thinkpad

# Apply ThinkPad full-height touchpad split
./install.sh --touchpad

# Apply everything
./install.sh --all
```
