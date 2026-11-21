# ThinkPad X280 Hardware & System Fixes

Automated script to address known hardware quirks and system errors on the Lenovo ThinkPad X280 under Ubuntu / Debian-based Linux distributions.

### What it fixes:
1. **Touchpad & TrackPoint Buttons Bug**: Configures `synaptics_intertouch=0` in `/etc/modprobe.d/psmouse.conf` to prevent physical button dropouts caused by SMBus passthrough conflicts.
2. **Sleep / Resume Touchpad Recovery**: Adds a systemd sleep hook (`/etc/systemd/system-sleep/touchpad-reload.sh`) to automatically reload the PS/2 mouse driver after suspend.
3. **Udev Lenovo Charge Rule**: Adds a file existence check (`TEST`) to avoid initramfs boot warnings if `lenovo-charge-fix.sh` is missing.
4. **ALSA `snd-ioctl32` Warning**: Patches obsolete 32-bit ioctl module call in `alsa-base.conf`.
5. **Crash Dumps & Failed Units**: Flushes stale `/var/crash` dumps and resets systemd failed units.
6. **Initramfs Update**: Automatically runs `update-initramfs -u` to apply driver options early at boot.

### Usage:
```bash
sudo ./fix-system-errors.sh
```
