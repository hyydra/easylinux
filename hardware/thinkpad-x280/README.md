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

## Known issue: charging stops / charger not detected (Thunderbolt firmware)

Charging stops now and then or entirely, with any charger and cable. The power-button LED blinks on plug-in; the OS does not see the charger, or sees it for 1-2 s and loses it again.

**Cause:** The X280 charges **only over USB-C**, and the power negotiation (USB-PD) runs through the Thunderbolt 3 controller. Its old firmware (**NVM 14.00** and earlier) is the known 2018 ThinkPad Thunderbolt bug (X280, T480, T480s, X1 Carbon 6, ...): it wears out its own flash and USB-C, including charging, starts failing. Lenovo's fix is **NVM 20.00**.

**Diagnose:**
```bash
cat /sys/bus/thunderbolt/devices/0-0/nvm_version   # 14.0 or lower = affected
cat /sys/class/power_supply/AC/online              # 0 although the charger is plugged in
ls /sys/class/typec/                               # no port*-partner = nothing negotiated
```

**Automatic check:** `easyset --tbt-check` (also part of `--system`, and at login with a desktop notification) warns when the firmware is older than NVM 20. It never flashes by itself; `sudo easyset --tbt-update` flashes it with fwupd, with fwupd's AC check left on.

**Fix (tested on this X280, 2026-11-28):** flash the Thunderbolt firmware from LVFS with `fwupd`. Only that device; the BIOS (1.59) and EC (1.15) were already current.
```bash
sudo apt install fwupd
fwupdmgr get-devices                      # note the "Thunderbolt host controller" Device ID
sudo fwupdmgr update <Device ID>          # 14.00 -> 20.00
```
`fwupd` refuses to flash without AC power ("Device requires AC power to be connected") and `--force` does not override that. If the charger is not detected at all, set `IgnorePower=true` under `[fwupd]` in `/etc/fwupd/fwupd.conf`, run `sudo systemctl restart fwupd`, flash, then **remove the setting again**. The Thunderbolt update is small (258 kB) and is written to the inactive flash bank, but flashing on battery is at your own risk; have at least ~30% charge.

**After flashing:** unplug and replug the charger. For a few minutes it may still connect and drop every ~4 s ("Not charging" for a second); then it settled and charged at ~39 W. If it does not settle: shut down completely, unplug for 30 s, plug in while off, or do an EC reset (pinhole on the bottom, 10 s, without charger).

**Not the cause (checked):** the Linux UCSI driver (`ucsi_acpi`). Unloading and reloading it and replugging made no difference, so do not blacklist it. The battery itself was healthy (84% of design capacity, 166 cycles).
