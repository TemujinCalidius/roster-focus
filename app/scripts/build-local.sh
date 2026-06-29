#!/usr/bin/env bash
#
# Build RosterFocus.app locally and ad-hoc sign it with the hardened runtime.
# No Apple Developer account needed — good for running on this machine.
# (A copied/downloaded ad-hoc app needs right-click → Open once; see app/README.)
#
#   ./scripts/build-local.sh           # Release build into app/build/
#   CONFIG=Debug ./scripts/build-local.sh
#   OPEN=1 ./scripts/build-local.sh    # also launch it
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # -> app/

CONFIG="${CONFIG:-Release}"
DD="${DERIVED_DATA:-build}"
ENT="RosterFocus/RosterFocus.entitlements"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate >/dev/null

echo "==> Building ($CONFIG)…"
xcodebuild build -quiet -project RosterFocus.xcodeproj -scheme RosterFocus \
  -configuration "$CONFIG" -destination 'platform=macOS' -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO

APP="$DD/Build/Products/$CONFIG/RosterFocus.app"

echo "==> Ad-hoc signing with hardened runtime…"
codesign --force --sign - --options runtime --timestamp=none \
  "$APP/Contents/Frameworks/RosterFocusCore.framework"
codesign --force --sign - --options runtime --timestamp=none --entitlements "$ENT" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Built: $(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
[ "${OPEN:-0}" = "1" ] && open "$APP" || true
