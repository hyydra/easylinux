# easylinux

A curated collection of automated fixers, watchdogs, and desktop utilities for Linux.

> ## ⚠️ Experimental and risky
> easylinux is experimental software. It changes system files (`/etc`, initramfs, the GRUB configuration), installs packages and runs as root. A mistake can leave a machine unable to boot or without a working desktop. It was written and tested on one machine (ThinkPad X280, Ubuntu, XFCE, GRUB, systemd); other distros, init systems and bootloaders are untested. The safety net (snapshots, GRUB guard, boot guard, `easylinux --rollback`) lowers the risk but **does not remove it**; it cannot help if the kernel or bootloader itself fails to start. Read the scripts before running them, keep a live USB at hand, back up your data, and do not use it on a machine you cannot afford to repair. No warranty.

## The idea

Take a fresh Linux install and make it behave the way you expect, in one command, on any machine: Windows-style `Ctrl+C` / `Ctrl+V` everywhere (never Shift+Ctrl), one global keyboard layout, a desktop panel that restarts itself, working hardware (touchpad, TrackPoint, sleep/resume). Every change is **safe to try**: system files are snapshotted first, GRUB is hardened so you never get stuck at the boot menu, and a boot guard rolls everything back by itself if the machine stops reaching the desktop. Scripts are idempotent, detect the system they run on (distro, init, bootloader), and say clearly what they did and what they skipped.

**Principles**
1. Never leave the machine unbootable: snapshot, rollback, GRUB guard, boot guard.
2. Detect, don't assume: no hard-wired distro, init or desktop where it can be avoided.
3. Idempotent and reversible: run twice, same result; every module can be undone.
4. Honest output: what was changed, what was skipped, what was not tested.

## Modules

### 1. Desktop Tweaks (`desktop/`)

#### XFCE Panel Watchdog (`desktop/xfce-panel-watchdog`)
- Automatically monitors and recovers `xfce4-panel` if it crashes or terminates.
- Re-attaches to the active user X11 session and session manager.
- Runs as a `systemd --user` service with crash-loop throttling.

#### XFCE Global Keyboard Layout (`desktop/xfce-global-keyboard`)
- Prevents language/layout resets between different application windows.
- Enforces a single global layout policy across the entire desktop.

#### Windows-style Clipboard (`desktop/windows-clipboard`)
- `Ctrl+C` / `Ctrl+V` copy and paste everywhere, including the terminal; never Shift+Ctrl.
- Uses the `kitty` terminal: selection + `Ctrl+C` copies, no selection + `Ctrl+C` still interrupts (also over ssh), like Windows Terminal.

#### Yaru Theme (`desktop/theme`)
- One consistent look instead of Xubuntu's mix of Greybird (flat grey GTK) and the plain Default window frame, which made dialogs look unpolished: Yaru for GTK, window frames (sized by screen DPI) and icons, Noto Sans as the UI font: `easylinux --theme` (per user, no root; part of `--user`).
- **Light/dark cycle:** light from 07:00, dark from 19:00 (a `systemd --user` timer checks every 10 minutes and at login). Also sets the freedesktop colour-scheme hint, so GTK4, Chrome and Electron apps follow. Change the times in `~/.config/easylinux/theme.conf`.
- `easylinux-theme light|dark|toggle` picks one by hand and keeps it; `easylinux-theme auto` goes back to the schedule.
- The previous values are saved once; `desktop/theme/uninstall.sh` restores them and removes the timer.

#### Keyboard Backlight Keys (`desktop/kbd-backlight`)
- XFCE does not bind `XF86KbdBrightnessUp/Down/LightOnOff`, so the backlight (Fn+Space on a ThinkPad) never turned on. Binds them to a small UPower helper (no root): `easylinux --kbd-backlight`.
- Full brightness after power-on and after every wake-up (the firmware leaves it off): `sudo easylinux --kbd-backlight-boot` (systemd services for boot and resume, as `systemd-backlight` restores the saved "off" state early at boot; also part of `--system`; skipped on machines without a keyboard backlight).
- Fn+Space cycles off / dim / bright; `easylinux-kbd-backlight up|down|cycle|on|off|status` works from a terminal too.

#### Suspend Keys (`desktop/suspend-keys`)
- On some machines xfce4-power-manager takes the suspend/power keys away from logind but does not act on them: logind logs `Suspend key pressed short.` and nothing sleeps (seen on the X280 with Fn+4). `easylinux --suspend-keys` tells it to leave those keys to logind and to do nothing itself (otherwise one press suspends via logind and also pops up xfpm's own "hibernate?" dialog; per user) and sets `HandlePowerKey=suspend` / `HandleSuspendKey=suspend` in a logind drop-in (root; the default for the power button is power off). Part of `--user` / `--system`.
- Do not bind the keys to `systemctl suspend` as well: both would fire and the machine suspends twice.
- The short power-button press does reach logind on the X280 (`Power key pressed short.`), even though the kernel's `ff_pwr_btn` counter stays 0. Until `HandlePowerKey=suspend` is set, logind's default (power off) applies, so run the root part (`sudo easylinux --suspend-keys`) before pressing the button.

#### Password Keyring (`desktop/keyring`)
- Installs GNOME Keyring, its PAM module, Seahorse and `secret-tool` so browsers, Wi-Fi, git and mail clients can store passwords and the keyring unlocks with the login: `sudo easylinux --keyring` (also part of `--system`).
- Checks that the display manager's PAM stack loads `pam_gnome_keyring` and tells you if not. The `login` keyring needs the same password as the user account.

### 2. Hardware Tweaks (`hardware/`)

#### ThinkPad X280 System & Driver Fixes (`hardware/thinkpad-x280`)
- Fixes TrackPoint / clickpad conflicts (`synaptics_intertouch=0`).
- Touchpad resume reload hook after suspend.
- Fixes for udev power rules, obsolete ALSA ioctls, and crash dump cleanup.
- **Charging stops / charger not detected:** old Thunderbolt firmware (NVM 14.00). Fix: flash NVM 20.00 with `fwupd`. `easylinux --tbt-check` warns about it (also at login); `sudo easylinux --tbt-update` flashes it on request, never automatically. See [hardware/thinkpad-x280/README.md](hardware/thinkpad-x280/README.md#known-issue-charging-stops--charger-not-detected-thunderbolt-firmware).

#### ThinkPad X280 Touchpad Full-Height Split (`hardware/thinkpad-x280`)
- Fixes `libinput` issue where mid/top clicks on the right side register as left clicks.
- Configures `synaptics` driver for a 50/50 vertical division across the full height of the pad (the split is computed from the pad's real coordinate range, e.g. X=3471 on the X280 PS/2 pad).
- Retains natural two-finger scrolling and tap-to-click.
- Flip the scroll direction any time: `easylinux --scroll natural|traditional|toggle` (applies immediately, persists for the next login via the X config; undo with `easylinux --rollback`).

### 3. Safety Net (`safety/`)
Distro-, init- and bootloader-independent. Every script that changes system files first runs `es_arm`, which detects the system (distro, init, bootloader, initramfs tool, kernels) and enables four layers. A layer that does not fit the system is skipped with a notice, never silently.

| Layer | What it does | Needs |
|---|---|---|
| 1. File snapshot | Copies every file it is about to change (plus the initramfs images) to `/var/backups/easylinux/<snapshot>/` and records files that did not exist | nothing (POSIX sh) |
| 2. FS snapshot | Creates a `snapper` snapshot; `ES_FS_SNAPSHOT=1` also does a `timeshift` one | snapper / timeshift |
| 3. GRUB guard | Makes sure the menu is visible, times out and **never waits forever** after a failed boot (Ubuntu's default `GRUB_RECORDFAIL_TIMEOUT=-1` leaves you stuck at GRUB; a hidden menu hides the older kernels). The new `grub.cfg` is generated to a temp file, validated with `grub-script-check`, and only then swapped in | GRUB (Debian/Ubuntu/Fedora/Arch/SUSE) |
| 4. Boot guard | If the next boot never reaches a desktop (or, on a headless box, a stable boot), the following boot rolls everything back before the display manager starts. A clean shutdown from a working desktop counts as healthy | systemd (OpenRC: best-effort, untested) |

**Undo**
- Normal system: `sudo easylinux-rollback` (or `./install.sh --rollback`). `--list`, `--status`, or a specific snapshot dir are also accepted.
- GRUB menu: *Advanced options* -> an older kernel (its initramfs is never touched by easylinux) or *recovery mode* -> root shell, then `mount -o remount,rw / && easylinux-rollback`.
- Stuck at `grub rescue>`: `ls` to find the root partition, then `set root=(hd0,gpt2)`, `set prefix=(hd0,gpt2)/boot/grub`, `insmod normal`, `normal`. Once booted run `sudo update-grub` (or `easylinux-rollback`).
- Nothing boots: start a live USB, mount the root partition on `/mnt` (and `/boot`, `/boot/efi` if separate), then
  `sh /mnt/var/backups/easylinux/latest/rollback.sh --root /mnt`. Each snapshot carries its own copy of the rollback script.

**Limits (be honest)**
- If the kernel or the bootloader itself cannot start, no userspace guard can run. That is what layers 1-3, the older kernel and the live-USB path are for. Keep at least two kernels installed (`easylinux` warns if there is only one).
- Not rolled back: packages installed with the package manager (the snapshot prints a note with the removal command) and the user-level modules (the panel watchdog has `uninstall.sh`).
- NixOS / ostree systems regenerate `/etc`, so rollback is best-effort there.
- Tested here: Ubuntu + systemd + GRUB (file logic, GRUB hardening, guard logic, `--root`). Not tested on real Fedora/Arch/OpenRC/systemd-boot systems.

## Development

```bash
make test        # runs tests/run.sh: rollback, GRUB hardening, boot guard, modules, .deb build
```
The tests run fully sandboxed (temp dirs, stubbed `sudo`, fake `grub-mkconfig`); they never touch the real `/etc`, GRUB or packages. They also run on every push (GitHub Actions) and gate every release. What they cannot cover: real boots, real GRUB, real hardware, non-Ubuntu distros.

## Install as a package

```bash
make deb                                   # builds dist/easylinux_<version>_all.deb
sudo apt install ./dist/easylinux_0.2.0_all.deb
```
Installing the package applies the settings, with the safety net armed first:
- **At install time (root):** GRUB hardening + rollback tool + boot guard on every machine, and the ThinkPad X280 fixes only on an X280 (`easylinux --system`).
- **At each user's next login (once per version):** global keyboard layout, panel watchdog, Windows-style Ctrl+C/V (`easylinux --user`).
- `kitty` and `xserver-xorg-input-synaptics` are pulled in as recommended packages (the package manager does it; scripts never call `apt` from inside dpkg).
- Opt out in `/etc/easylinux/easylinux.conf` (`AUTO_SYSTEM=0`, `AUTO_USER=0`), then run `sudo easylinux --system` / `easylinux --user` yourself.
- Undo: `sudo easylinux --rollback`.

Other distros: `sudo make install` (generic, `PREFIX=/usr/local` works too) or `make tarball`. Pushing a tag `vX.Y.Z` (matching `VERSION`) makes the GitHub workflow publish the `.deb` and tarball as a release.

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

# Windows-style Ctrl+C / Ctrl+V everywhere (installs and defaults to kitty)
./install.sh --clipboard

# Apply ThinkPad hardware & driver fixes
./install.sh --thinkpad

# Apply ThinkPad full-height touchpad split
./install.sh --touchpad

# Apply everything
./install.sh --all

# What the package does automatically
./install.sh --user      # per-user settings (no root)
./install.sh --system    # boot hardening everywhere + hardware fixes where they apply

# Undo the last system change (snapshot restore)
./install.sh --rollback
```
