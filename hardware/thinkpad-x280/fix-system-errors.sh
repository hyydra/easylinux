#!/usr/bin/env bash
# Script to fix touchpad buttons bug and system errors on Lenovo ThinkPad X280
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root: sudo $0"
    exit 1
fi

echo "=== 1. Fixing Touchpad & TrackPoint SMBus/PS2 Driver Bug ==="
cat << 'EOF' > /etc/modprobe.d/psmouse.conf
# Fix physical TrackPoint buttons & Synaptics clickpad SMBus passthrough conflicts on ThinkPad X280
options psmouse synaptics_intertouch=0
EOF
echo "[✓] Configured /etc/modprobe.d/psmouse.conf (synaptics_intertouch=0)"

echo "=== 2. Creating Sleep/Resume Hook for Touchpad ==="
mkdir -p /etc/systemd/system-sleep
cat << 'EOF' > /etc/systemd/system-sleep/touchpad-reload.sh
#!/usr/bin/env bash
# Ensure ThinkPad touchpad and trackpoint buttons reliably recover after sleep
case "$1" in
    post)
        modprobe -r psmouse 2>/dev/null || true
        sleep 0.5
        modprobe psmouse 2>/dev/null || true
        ;;
esac
EOF
chmod +x /etc/systemd/system-sleep/touchpad-reload.sh
echo "[✓] Configured /etc/systemd/system-sleep/touchpad-reload.sh"

echo "=== 3. Fixing Udev lenovo-charge-fix Rule ==="
if [ -f /etc/udev/rules.d/99-lenovo-charge-fix.rules ]; then
    # Add TEST check so initramfs boot won't log 'No such file or directory' errors
    cat << 'EOF' > /etc/udev/rules.d/99-lenovo-charge-fix.rules
SUBSYSTEM=="power_supply", ACTION=="add", TEST=="/usr/local/sbin/lenovo-charge-fix.sh", RUN+="/usr/local/sbin/lenovo-charge-fix.sh"
EOF
    echo "[✓] Updated /etc/udev/rules.d/99-lenovo-charge-fix.rules with TEST existence check"
fi

echo "=== 4. Fixing ALSA snd-ioctl32 Modprobe Error ==="
if grep -q "snd-ioctl32" /etc/modprobe.d/alsa-base.conf 2>/dev/null; then
    # snd-ioctl32 is obsolete in modern kernels; append '; : ;' so retcode is 0
    sed -i 's|/sbin/modprobe --quiet --use-blacklist snd-ioctl32|/sbin/modprobe --quiet --use-blacklist snd-ioctl32 2>/dev/null \|\| true|g' /etc/modprobe.d/alsa-base.conf
    echo "[✓] Patched obsolete snd-ioctl32 call in /etc/modprobe.d/alsa-base.conf"
fi

echo "=== 5. Clearing Crash Dumps & Resetting Failed Systemd Services ==="
rm -rf /var/crash/*
systemctl reset-failed 2>/dev/null || true
udevadm control --reload 2>/dev/null || true
echo "[✓] Cleared /var/crash and reset failed systemd units"

echo "=== 6. Updating Initramfs ==="
echo "Updating initramfs with new psmouse configuration (may take a few seconds)..."
update-initramfs -u

echo "=== 7. Reloading PS/2 Mouse Driver Now ==="
modprobe -r psmouse 2>/dev/null || true
sleep 0.5
modprobe psmouse 2>/dev/null || true

echo "=== All fixes successfully applied! ==="
