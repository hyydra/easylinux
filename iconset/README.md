# easylinux Minimal icons

A free, minimalist icon theme: one stroke style (grey outline, rounded caps, 24 px grid), no
colour, about 440 SVG icons: apps (terminal, files, browser, mail, editor, settings, ...),
places, devices, tray (Bluetooth, Wi-Fi levels, volume levels, notifications, updates), dialogs
and a battery set with charging bolts, including the symbolic names GTK and upower use.

**License: CC0 (public domain).** Use, change and redistribute freely.

## Install

```bash
tar xzf easylinux-minimal-icons-*.tar.gz -C ~/.local/share/icons/     # or /usr/share/icons (root)
gtk-update-icon-cache -f -t ~/.local/share/icons/easylinux-minimal
```
Then choose **easylinux Minimal** in your desktop's appearance settings (XFCE: Settings ->
Appearance -> Icons; GNOME: Tweaks). It inherits Adwaita, so any icon it does not draw comes from there.

## Build it yourself

```bash
python3 desktop/theme/make-icons.py OUTPUT_DIR     # writes OUTPUT_DIR/scalable/*.svg
make icons                                          # builds dist/easylinux-minimal-icons-<version>.tar.gz
```
Every icon is defined as a few SVG shapes in `desktop/theme/make-icons.py`; add or change one there.
