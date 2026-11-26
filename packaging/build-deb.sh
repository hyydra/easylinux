#!/usr/bin/env bash
# Build dist/easylinux_<version>_all.deb  (needs: dpkg-deb, make)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
VERSION="$(cat VERSION)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

make install DESTDIR="$STAGE" PREFIX=/usr >/dev/null
# normalise permissions (mktemp makes the root 0700; the user's umask leaks into modes)
chmod 755 "$STAGE"
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -perm -u+x -exec chmod 755 {} +
find "$STAGE" -type f ! -perm -u+x -exec chmod 644 {} +
mkdir -p "$STAGE/DEBIAN" dist
SIZE="$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)"
sed -e "s/@VERSION@/$VERSION/" -e "s/@SIZE@/$SIZE/" packaging/debian/control.in > "$STAGE/DEBIAN/control"
install -m 755 packaging/debian/postinst "$STAGE/DEBIAN/postinst"
echo /etc/easylinux/easylinux.conf > "$STAGE/DEBIAN/conffiles"

dpkg-deb --root-owner-group --build "$STAGE" "dist/easylinux_${VERSION}_all.deb" >/dev/null
echo "Built dist/easylinux_${VERSION}_all.deb"
