# easyset linux (easylinux)

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
5. Verified sources only: packages come from the distribution's official, signed archive (or Lenovo's firmware via LVFS); no third-party snaps, PPAs or downloads.

## Modules

### 1. Desktop Tweaks (`desktop/`)

#### XFCE Panel Watchdog (`desktop/xfce-panel-watchdog`)
- Automatically monitors and recovers `xfce4-panel` if it crashes or terminates.
- Re-attaches to the active user X11 session and session manager.
- Runs as a `systemd --user` service with crash-loop throttling.

#### XFCE Global Keyboard Layout (`desktop/xfce-global-keyboard`)
- Prevents language/layout resets between different application windows.
- Enforces a single global layout policy across the entire desktop.
- The panel's layout indicator shows the language in capitals in the normal panel font (`HU`, `US`) instead of a flag: the stock xkb plugin hard-codes a bold monospace font and lowercase codes, so it is replaced by a Generic Monitor (genmon) plugin running `easylinux-layout`. Clicking it switches to the next layout. Undo: `desktop/xfce-global-keyboard/layout-indicator.sh --undo`.
- Hides IBus's redundant "EN" tray icon when IBus has no real input method (only plain keyboard engines): its menu opens in the top-left corner of the screen instead of by the icon, where it goes unnoticed and grabs the keyboard, so Print Screen and other shortcuts stop working until you click elsewhere. IBus itself keeps running; bring the icon back with `gsettings set org.freedesktop.ibus.panel show-icon-on-systray true`.
- IBus (the input-method framework for Chinese, Japanese, Korean, Indic input and the emoji picker) is not needed for typing Hungarian or other Latin layouts, which the XKB layouts handle. If you do not need it, `sudo apt remove ibus` is safe (it only drops the `ibus-table*` input tables); the module works with or without it.

#### Windows-style Clipboard (`desktop/windows-clipboard`)
- `Ctrl+C` / `Ctrl+V` copy and paste everywhere, including the terminal; never Shift+Ctrl.
- Uses the `kitty` terminal: selection + `Ctrl+C` copies, no selection + `Ctrl+C` still interrupts (also over ssh), like Windows Terminal.

#### Yaru Theme (`desktop/theme`)
- One consistent look instead of Xubuntu's mix of Greybird (flat grey GTK) and the plain Default window frame, which made dialogs look unpolished: Yaru for GTK and window frames (sized by screen DPI), elementary icons (official `elementary-icon-theme` package; Yaru icons if it is not installed), Noto Sans as the UI font: `easylinux --theme` (per user, no root; part of `--user`).
- **Light/dark cycle:** light from 07:00, dark from 19:00 (a `systemd --user` timer checks every 10 minutes and at login). Also sets the freedesktop colour-scheme hint, so GTK4, Chrome and Electron apps follow. Change the times in `~/.config/easylinux/theme.conf`.
- Why elementary and not Papirus: with Papirus, Ubuntu's `snapd-desktop-integration` keeps offering to install it as a snap for snap apps, and that snap comes from an unverified third-party publisher. elementary (like Yaru) is already provided to snaps by Canonical's `gtk-common-themes`, so nothing prompts.
- `easylinux-theme light|dark|toggle` picks one by hand and keeps it; `easylinux-theme auto` goes back to the schedule.
- **Panel look** (`desktop/theme/panel-look.sh`, part of `--theme`): roomy 48 px bar with 32 px menu and task icons, 22 px status-tray icons and padded buttons (bigger click targets), a wide `Start` menu button (icon plus the word, easy to hit), a taller start menu without the dark outline, no dotted drag-handle marks (position locked), flat "simplistic" weather icons, a battery icon next to the percentage instead of the bar, and modern Wi-Fi signal icons from the icon theme (`nm-applet --indicator` plus `nm-signal-icons.sh`). `desktop/theme/panel-look.sh --undo` restores the previous values.
- **Minimalist, colourless icon set** (`desktop/theme/minimal-icons.sh`, generated, part of `panel-look.sh`): flat grey battery icons (level bar, a bolt while charging; for xfce4-battery-plugin, upower and GTK status icons) and the desktop icons the theme provides (home, folder, file system, removable drive, trash). It is a small user icon theme `easylinux` that inherits elementary and adds only these icons. The panel's user-name menu button (log out / lock) is removed, since the Start menu has those buttons.
- **Desktop layout** (`desktop/theme/desktop-layout.sh`, part of `--theme`): desktop icons in columns at the far right edge, no "Arrange Icons: are you sure?" prompt, a single workspace and the same desktop on every workspace. `desktop-layout.sh --undo` restores the previous values.
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

## Free icon set

The outline icons are also available on their own as **easyset linux** (CC0, public domain): `make icons` builds `dist/easyset-icons-<version>.tar.gz`, which every release ships. See [iconset/README.md](iconset/README.md).

## Administrator prompt instead of sudo

In a graphical session the installed package asks for the administrator password in a normal window (polkit, the Linux counterpart of Windows UAC) instead of `sudo` in a terminal. It is as safe as sudo: the password is still required, the dialog names the action ("easylinux wants to change system settings"), and the password is remembered for a few minutes, so a multi-step run asks once.
- The polkit action `org.easylinux.apply` is bound to the installed, root-owned `easylinux` command, which (through `--as-root`) runs nothing but the `*.sh` scripts shipped in its own install directory; path tricks (`..`, absolute paths) are refused.
- From a git checkout, or without a graphical session, `sudo` is used as before (set `EASYLINUX_NO_POLKIT=1` to force it).
- Needs a polkit authentication agent in the session; XFCE/Xubuntu already runs one (`policykit-1-gnome`, `mate-polkit` or `lxpolkit`), and the package recommends one.

## Install as a package

```bash
make deb                                   # builds dist/easylinux_<version>_all.deb
sudo apt install ./dist/easylinux_0.3.0_all.deb
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
