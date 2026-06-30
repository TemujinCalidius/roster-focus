#!/usr/bin/env bash
#
# Regenerate the macOS AppIcon set from RosterFocus.svg.
# macOS only (uses qlmanage to rasterize the SVG and sips to resize).
#
#   ./render.sh
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

SVG="RosterFocus.svg"
ICONSET="../RosterFocus/Assets.xcassets/AppIcon.appiconset"

echo "==> Rasterizing $SVG → 1024 master"
rm -f "$SVG.png" RosterFocus-1024.png
qlmanage -t -s 1024 -o . "$SVG" >/dev/null 2>&1
mv "$SVG.png" RosterFocus-1024.png

echo "==> Generating AppIcon sizes into $ICONSET"
for s in 16 32 64 128 256 512 1024; do
  sips -z "$s" "$s" RosterFocus-1024.png --out "$ICONSET/icon_${s}.png" >/dev/null
done

echo "Done. Edit RosterFocus.svg and re-run to update the icon."
