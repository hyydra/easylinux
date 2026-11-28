#!/usr/bin/env python3
"""Generate the easylinux minimalist icon set: one stroke style (grey outline, rounded caps), no colour.

usage: make-icons.py OUTPUT_DIR

Everything is drawn on a 24x24 grid with a 1.6 px stroke, so the whole set matches the battery
icons. The icons go into OUTPUT_DIR/scalable/ (the theme has a single scalable directory).
Apps with their own brand icon (Chrome, Claude, ...) are not touched: they ship their own artwork.
"""
import os
import sys

INK = "#4b5563"


def svg(body, ink=INK):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
            '<g fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g>\n'
            '</svg>\n' % (ink, body))


FOLDER = '<path d="M3 7a2 2 0 0 1 2-2h4.2l2 2.2H19a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
DOC = '<path d="M7 3.5h6.5L18 8v11.5a1.5 1.5 0 0 1-1.5 1.5H7a1.5 1.5 0 0 1-1.5-1.5V5A1.5 1.5 0 0 1 7 3.5z"/><path d="M13.5 3.5V8H18"/>'
GRID = ('<rect x="4.5" y="4.5" width="6" height="6" rx="1.5"/><rect x="13.5" y="4.5" width="6" height="6" rx="1.5"/>'
        '<rect x="4.5" y="13.5" width="6" height="6" rx="1.5"/><rect x="13.5" y="13.5" width="6" height="6" rx="1.5"/>')
SPEAKER = '<path d="M4 9.5h3.5l4.5-4v13l-4.5-4H4z"/>'


def wifi(level):
    """Three arcs above a dot; 'level' arcs are solid, the rest faint."""
    parts = ['<circle cx="12" cy="18.6" r=".9" fill="%s"/>' % INK]
    for i, r in enumerate((4.6, 8.2, 11.8)):
        d = r * 0.7071
        op = "" if i < level else ' opacity=".28"'
        parts.append('<path d="M%.2f %.2f A%s %s 0 0 1 %.2f %.2f"%s/>' % (12 - d, 18.6 - d, r, r, 12 + d, 18.6 - d, op))
    return "".join(parts)


def volume(level):
    parts = [SPEAKER]
    if level == 0:
        parts.append('<path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>')
    else:
        parts.append('<path d="M15.2 9.2a4 4 0 0 1 0 5.6"/>')
        if level >= 2:
            parts.append('<path d="M18 6.4a8 8 0 0 1 0 11.2"/>')
    return "".join(parts)


def folder_with(inner):
    return FOLDER + inner


GLYPHS = {
    "terminal": ('<rect x="3" y="4.5" width="18" height="15" rx="2.5"/><path d="M7.5 10l3 2.5-3 2.5M12.5 15h4"/>',
                 "utilities-terminal org.xfce.terminal xfce4-terminal org.gnome.Ptyxis org.gnome.Terminal gnome-terminal xterm utilities-terminal-symbolic kitty"),
    "files": (FOLDER, "system-file-manager org.xfce.thunar Thunar thunar folder inode-directory folder-open folder-visiting folder-new folder-drag-accept org.gnome.Nautilus"),
    "home": ('<path d="M4 11.2l8-6.7 8 6.7M6.2 9.8v9.7h11.6V9.8M10 19.5v-5h4v5"/>', "user-home folder-home"),
    "trash": ('<path d="M5 7h14M9.5 7V5h5v2M7 7l.8 12.5h8.4L17 7M10.5 11v5M13.5 11v5"/>', "user-trash edittrash"),
    "trash-full": ('<path d="M5 7h14M9.5 7V5h5v2M7 7l.8 12.5h8.4L17 7M10.5 11v5M13.5 11v5M8.5 4l2-1.6M15.5 4l-2-1.6"/>', "user-trash-full"),
    "drive": ('<rect x="3.5" y="7.5" width="17" height="9.5" rx="2.5"/><path d="M3.5 13h17"/><circle cx="17" cy="15.1" r=".7" fill="%s"/>' % INK,
              "drive-harddisk drive-harddisk-system drive-harddisk-solidstate computer"),
    "usb": ('<rect x="3.5" y="8.5" width="17" height="7" rx="2"/><path d="M7 12h4"/><circle cx="17" cy="12" r=".7" fill="%s"/>' % INK,
            "drive-removable-media drive-removable-media-usb drive-multidisk drive-optical media-removable media-flash"),
    "browser": ('<circle cx="12" cy="12" r="8.5"/><ellipse cx="12" cy="12" rx="3.8" ry="8.5"/><path d="M3.5 12h17"/>',
                "web-browser internet-web-browser internet xfce4-web-browser applications-internet"),
    "mail": ('<rect x="3" y="5.5" width="18" height="13" rx="2"/><path d="M3.5 7.2l8.5 6.3 8.5-6.3"/>',
             "internet-mail mail-client xfce4-mail-reader mail-message-new emblem-mail"),
    "editor": (DOC + '<path d="M9 12.5h6M9 15.5h6"/>',
               "accessories-text-editor org.xfce.mousepad text-x-generic text-x-script x-office-document applications-office accessories-document-viewer"),
    "calculator": ('<rect x="5.5" y="3" width="13" height="18" rx="2"/><path d="M8.5 6.5h7v3h-7z"/><circle cx="9" cy="13.5" r=".6" fill="%s"/><circle cx="12" cy="13.5" r=".6" fill="%s"/><circle cx="15" cy="13.5" r=".6" fill="%s"/><circle cx="9" cy="17" r=".6" fill="%s"/><circle cx="12" cy="17" r=".6" fill="%s"/><circle cx="15" cy="17" r=".6" fill="%s"/>' % ((INK,) * 6),
                   "accessories-calculator"),
    "monitor": ('<rect x="3" y="4.5" width="18" height="15" rx="2.5"/><path d="M5.5 13h3l2-4.5 3 8 2-3.5h3"/>',
                "utilities-system-monitor org.xfce.taskmanager xfce4-taskmanager"),
    "settings": ('<path d="M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="17" r="2"/>',
                 "preferences-system preferences-desktop preferences-other xfce4-settings-manager applications-system preferences-desktop-theme preferences-desktop-display preferences-desktop-keyboard preferences-desktop-font preferences-system-network preferences-desktop-peripherals"),
    "search": ('<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5"/>', "system-search edit-find xfce4-appfinder org.xfce.appfinder"),
    "screenshot": ('<path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16"/><circle cx="12" cy="12" r="2.6"/>',
                   "accessories-screenshot-tool org.xfce.screenshooter xfce4-screenshooter applets-screenshooter"),
    "code": ('<path d="M8 8l-4 4 4 4M16 8l4 4-4 4M13.5 6.5l-3 11"/>', "applications-development"),
    "image": ('<rect x="3.5" y="5" width="17" height="14" rx="2"/><circle cx="8.5" cy="10" r="1.6"/><path d="M4 17.5l5.5-4.8 3.5 3 3-2.5 4 3.8"/>',
              "applications-graphics image-x-generic multimedia-photo-viewer multimedia-photo-manager"),
    "play": ('<circle cx="12" cy="12" r="8.5"/><path d="M10 8.6L15.8 12 10 15.4z"/>',
             "applications-multimedia multimedia-audio-player multimedia-video-player media-playback-start video-x-generic audio-x-generic"),
    "chip": ('<rect x="7" y="7" width="10" height="10" rx="2"/><path d="M10 3.5v3.5M14 3.5v3.5M10 17v3.5M14 17v3.5M3.5 10H7M3.5 14H7M17 10h3.5M17 14h3.5"/>',
             "applications-utilities system utilities-archive"),
    "toolbox": ('<rect x="3.5" y="8" width="17" height="11" rx="2"/><path d="M9 8V6a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 6v2M3.5 13h17"/>',
                "applications-accessories applications-other"),
    "grid": (GRID, "applications-all xfce4-whiskermenu org.xfce.panel.applicationsmenu easylinux-start"),
    "bluetooth": ('<path d="M7 7.5l10 9-5 4.5V3l5 4.5-10 9"/>', "bluetooth blueman blueman-tray bluetooth-active bluetooth-disabled blueman-active"),
    "wired": ('<rect x="5" y="4.5" width="14" height="9" rx="2"/><path d="M9 8h.01M12 8h.01M15 8h.01M12 13.5v3.5M6 17h12M8 17v3M16 17v3"/>', "network-wired nm-device-wired network-idle network-wired-symbolic"),
    "bell": ('<path d="M6.5 16.5v-5a5.5 5.5 0 0 1 11 0v5l1.5 1.5H5zM10 20.5a2 2 0 0 0 4 0"/>', "notification-new notification-message-email preferences-system-notifications"),
    "update": ('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5v8M8.5 12.5l3.5 3.5 3.5-3.5"/>',
               "software-update-available software-update-urgent system-software-update update-notifier livepatch system-software-install"),
    "note": ('<path d="M5 4.5h14v10l-5 5H5z"/><path d="M14 19.5v-5h5M8.5 9h7M8.5 12.5h4"/>', "xfce4-notes-plugin org.xfce.notes xfce4-notes accessories-notes"),
    "clock": ('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', "preferences-system-time appointment-soon org.xfce.panel.clock x-office-calendar"),
    "lock": ('<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>', "system-lock-screen changes-prevent"),
    "logout": ('<path d="M10 4.5H6A1.5 1.5 0 0 0 4.5 6v12A1.5 1.5 0 0 0 6 19.5h4M14.5 8l4 4-4 4M18.5 12H9.5"/>', "system-log-out"),
    "power": ('<path d="M12 4v8M7 7.2a7.5 7.5 0 1 0 10 0"/>', "system-shutdown system-reboot system-suspend"),
    "desktop": ('<rect x="3" y="4.5" width="18" height="12" rx="2"/><path d="M9 20h6M12 16.5V20"/>', "user-desktop video-display org.xfce.panel.showdesktop show-desktop"),
    "download": (folder_with('<path d="M12 10.5v5M9.8 13.6l2.2 2.2 2.2-2.2"/>'), "folder-download"),
    "documents": (folder_with('<path d="M8.5 12.5h7M8.5 15h5"/>'), "folder-documents"),
    "pictures": (folder_with('<circle cx="9.5" cy="12.5" r="1"/><path d="M7 16.2l3-2.5 2 1.6 2.5-2 2.5 2.4"/>'), "folder-pictures"),
    "music": (folder_with('<path d="M10.5 16.2V11l5-1v5.2"/><circle cx="9.3" cy="16.2" r="1.2"/><circle cx="14.3" cy="15.2" r="1.2"/>'), "folder-music"),
    "videos": (folder_with('<path d="M10 11.2L14.6 13.5 10 15.8z"/>'), "folder-videos"),
    "camera": ('<path d="M4 8.5h3l1.5-2h7l1.5 2h3v10H4z"/><circle cx="12" cy="13" r="3"/>', "camera-photo camera-video"),
    "printer": ('<path d="M7 9V4.5h10V9M7 17H5a1.5 1.5 0 0 1-1.5-1.5v-5A1.5 1.5 0 0 1 5 9h14a1.5 1.5 0 0 1 1.5 1.5v5A1.5 1.5 0 0 1 19 17h-2M7 14h10v6H7z"/>', "printer document-print"),
    "keyboard": ('<rect x="3" y="6.5" width="18" height="11" rx="2"/><path d="M6.5 10h.01M9.5 10h.01M12.5 10h.01M15.5 10h.01M18 10h.01M7 14h10"/>', "input-keyboard preferences-desktop-keyboard-shortcuts"),
    "mouse": ('<rect x="7" y="3.5" width="10" height="17" rx="5"/><path d="M12 3.5v6"/>', "input-mouse"),
    "info": ('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8h.01"/>', "dialog-information help-about"),
    "warning": ('<path d="M12 4.5l8.5 15h-17z"/><path d="M12 10v4.5M12 17h.01"/>', "dialog-warning"),
    "error": ('<circle cx="12" cy="12" r="8.5"/><path d="M9 9l6 6M15 9l-6 6"/>', "dialog-error"),
    "question": ('<circle cx="12" cy="12" r="8.5"/><path d="M9.7 9.6a2.4 2.4 0 1 1 3.4 2.2c-.7.4-1.1.8-1.1 1.6M12 16.6h.01"/>', "dialog-question help-browser help-contents"),
    "check": ('<circle cx="12" cy="12" r="8.5"/><path d="M8.2 12.3l2.6 2.6 5-5.4"/>', "dialog-ok emblem-default"),
    "user": ('<circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5"/>', "system-users user-available avatar-default"),
    "chat": ('<path d="M4 6.5A2 2 0 0 1 6 4.5h12a2 2 0 0 1 2 2V15a2 2 0 0 1-2 2h-6l-4.5 3.5V17H6a2 2 0 0 1-2-2z"/>', "internet-chat internet-group-chat"),
    "archive": ('<rect x="3.5" y="5" width="17" height="4" rx="1"/><path d="M5 9v9.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V9M10 13h4"/>', "package-x-generic application-x-archive application-x-compressed-tar"),
    "pdf": (DOC + '<path d="M8.5 15.5c1.5 0 3-1.5 3.5-3.5.4 2 2 3.5 3.5 3.5"/>', "application-pdf"),
    "font": ('<path d="M6 19l6-14 6 14M8.3 14h7.4"/>', "font-x-generic preferences-desktop-font"),
    "exe": ('<rect x="3.5" y="5" width="17" height="14" rx="2"/><path d="M3.5 9h17M6.5 7h.01M9 7h.01"/>', "application-x-executable unknown"),
}


def battery(percent, charging, symbolic=False, missing=False):
    ink = "#2e3436" if symbolic else INK
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">',
             '<rect x="1.5" y="6.5" width="18" height="11" rx="2.5" fill="none" stroke="%s" stroke-width="1.5"/>' % ink,
             '<rect x="20.5" y="10" width="2" height="4" rx="1" fill="%s"/>' % ink]
    if missing:
        parts.append('<path d="M7 9.5l7 5M14 9.5l-7 5" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % ink)
    elif percent > 0:
        parts.append('<rect x="3.5" y="8.5" width="%.2f" height="7" rx="1" fill="%s"/>' % (max(1.2, 14.0 * percent / 100.0), ink))
    if charging and not missing:
        bolt = "11.6,6.6 7,12.7 10.3,12.7 9.4,17.4 14.2,11.1 10.9,11.1"
        if symbolic:
            parts.append('<polygon points="%s" fill="none" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/>' % bolt)
        else:
            parts.append('<polygon points="%s" fill="#ffffff" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (bolt, INK))
    parts.append('</svg>')
    return "\n".join(parts) + "\n"


def main(out):
    d = os.path.join(out, "scalable")
    os.makedirs(d, exist_ok=True)
    written = set()

    def put(name, text):
        with open(os.path.join(d, name + ".svg"), "w") as f:
            f.write(text)
        written.add(name)

    for body, names in GLYPHS.values():
        for n in names.split():
            put(n, svg(body))
            put(n + "-symbolic", svg(body, "#2e3436"))
    # status icons with levels
    for lvl, name in enumerate(("none", "weak", "ok", "good", "excellent")):
        for suffix in ("", "-symbolic"):
            ink = INK if not suffix else "#2e3436"
            put("network-wireless-signal-%s%s" % (name, suffix), svg(wifi(min(lvl, 3)), ink))
    put("network-wireless", svg(wifi(3))); put("network-wireless-symbolic", svg(wifi(3), "#2e3436"))
    put("network-wireless-disconnected", svg(wifi(0))); put("network-wireless-offline-symbolic", svg(wifi(0), "#2e3436"))
    for name, lvl in (("muted", 0), ("low", 1), ("medium", 2), ("high", 3)):
        for suffix in ("", "-symbolic"):
            put("audio-volume-%s%s" % (name, suffix), svg(volume(min(lvl, 3)), INK if not suffix else "#2e3436"))
    # batteries
    for n, p in {"empty": 0, "caution": 15, "low": 35, "good": 70, "full": 100}.items():
        put("battery-%s" % n, battery(p, False)); put("battery-%s-charging" % n, battery(p, True))
    for n, p in {"critical": 10, "low": 30, "ok": 70, "full": 100}.items():
        put("xfce4-battery-%s" % n, battery(p, False)); put("xfce4-battery-%s-charging" % n, battery(p, True))
    put("battery-full-charged", battery(100, True)); put("battery-missing", battery(0, False, missing=True))
    for lvl in range(0, 101, 10):
        put("battery-level-%d-symbolic" % lvl, battery(lvl, False, True))
        put("battery-level-%d-charging-symbolic" % lvl, battery(lvl, True, True))
    put("battery-level-100-charged-symbolic", battery(100, True, True))
    put("battery-missing-symbolic", battery(0, False, True, missing=True))
    print(len(written))


if __name__ == "__main__":
    main(sys.argv[1])
