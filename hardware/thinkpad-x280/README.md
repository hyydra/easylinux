# ThinkPad X280 Hardware & System Fixes

Automated scripts and configurations to address known hardware quirks and system errors on the Lenovo ThinkPad X280 under Ubuntu / Debian-based Linux distributions.

### Modules:

#### 1. System & Driver Fixes (`fix-system-errors.sh`)
1. **Touchpad & TrackPoint Buttons Bug**: Configures `synaptics_intertouch=0` in `/etc/modprobe.d/psmouse.conf` to prevent physical button dropouts caused by SMBus passthrough conflicts.
2. **Sleep / Resume Touchpad Recovery**: Adds a systemd sleep hook (`/etc/systemd/system-sleep/touchpad-reload.sh`) to automatically reload the PS/2 mouse driver after suspend.
3. **Udev Lenovo Charge Rule**: Adds a file existence check (`TEST`) to avoid initramfs boot warnings if `lenovo-charge-fix.sh` is missing.
4. **ALSA `snd-ioctl32` Warning**: Patches obsolete 32-bit ioctl module call in `alsa-base.conf`.
5. **Crash Dumps & Failed Units**: Flushes stale `/var/crash` dumps and resets systemd failed units.
6. **Initramfs Update**: Automatically runs `update-initramfs -u` to apply driver options early at boot.

Usage:
```bash
sudo ./fix-system-errors.sh
```

#### 2. Touchpad Full-Height Left/Right Button Split (`setup-touchpad-split.sh`)
Solves the issue where `libinput` only treats the bottom 1 cm as button areas and registers mid/upper right-side clicks as left clicks.
- Installs `xserver-xorg-input-synaptics`.
- Configures a 50/50 vertical division across the full height of the pad: anywhere on the right half clicks as Right Mouse Button.
- Retains natural two-finger scrolling and tap-to-click.

Usage:
```bash
sudo ./setup-touchpad-split.sh
```
