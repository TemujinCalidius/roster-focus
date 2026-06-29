#!/usr/bin/env bash
#
# Build a Developer ID-signed, notarized, stapled RosterFocus.app for distribution.
#
# One-time setup (needs the paid Apple Developer Program):
#   1. Create a "Developer ID Application" certificate (Xcode › Settings › Accounts ›
#      Manage Certificates › +, or developer.apple.com).
#   2. Store notary credentials once:
#        xcrun notarytool store-credentials ROSTERFOCUS_NOTARY \
#          --apple-id "<you@example.com>" --team-id "<TEAMID>" --password "<app-specific-password>"
#   3. Set your Team ID in app/project.yml (DEVELOPMENT_TEAM) and regenerate, or pass TEAM_ID below.
#
# Then:
#   TEAM_ID=ABCDE12345 ./scripts/package-notarize.sh
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # -> app/

TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ROSTERFOCUS_NOTARY}"
DD="build-release"
ARCHIVE="$DD/RosterFocus.xcarchive"
EXPORT="$DD/export"

if [ -z "$TEAM_ID" ]; then
  echo "Set TEAM_ID=<your Apple Developer Team ID> (see header for setup)." >&2
  exit 2
fi

command -v xcodegen >/dev/null 2>&1 && xcodegen generate >/dev/null
rm -rf "$DD"; mkdir -p "$DD"

echo "==> Archiving…"
xcodebuild archive -quiet -project RosterFocus.xcodeproj -scheme RosterFocus \
  -configuration Release -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID"

echo "==> Exporting (Developer ID)…"
cat > "$DD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" -exportOptionsPlist "$DD/ExportOptions.plist"

APP="$EXPORT/RosterFocus.app"

# Fail fast — before the multi-minute notary wait — if the export isn't a
# hardened-runtime, Developer ID-signed binary.
echo "==> Pre-flight signature check…"
SIG="$(codesign -dvvv "$APP" 2>&1 || true)"
echo "$SIG" | grep -q 'flags=.*runtime' || { echo "ERROR: app is not hardened-runtime signed"; exit 1; }
echo "$SIG" | grep -q 'Authority=Developer ID Application' || { echo "ERROR: app is not Developer ID signed"; exit 1; }

echo "==> Notarizing (this waits for Apple)…"
ditto -c -k --keepParent "$APP" "$DD/RosterFocus.zip"
xcrun notarytool submit "$DD/RosterFocus.zip" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling…"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=4 "$APP"

echo "==> Done: $APP"
echo "    (zip it or wrap in a DMG to distribute.)"
