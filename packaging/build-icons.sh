#!/usr/bin/env bash
# Build dist/easyset-icons-<version>.tar.gz: the standalone minimalist icon theme
# (grey outline icons, ~440 SVGs). Needs only python3 and tar.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
VERSION="$(cat VERSION)"
NAME=easyset
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
DIR="$STAGE/$NAME"; mkdir -p "$DIR"
python3 -I desktop/theme/make-icons.py "$DIR" >/dev/null
cat > "$DIR/index.theme" <<EOF
[Icon Theme]
Name=easyset linux
Comment=Minimalist grey outline icons (CC0)
Inherits=Adwaita,hicolor
Directories=scalable

[scalable]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications
EOF
cp iconset/README.md iconset/LICENSE "$DIR/"
mkdir -p dist
tar -C "$STAGE" -czf "dist/$NAME-icons-$VERSION.tar.gz" "$NAME"
echo "Built dist/$NAME-icons-$VERSION.tar.gz"
