#!/usr/bin/env bash
#
# Build a Developer ID-signed, notarized, stapled RosterFocus.app + DMG for
# distribution. Uses build + manual codesign (not archive/exportArchive), so it
# works with only a "Developer ID Application" certificate — no "Mac Development"
# cert or provisioning profile required.
#
# One-time setup (needs the paid Apple Developer Program):
#   1. Create a "Developer ID Application" certificate (Xcode › Settings › Accounts ›
#      Manage Certificates › +, or developer.apple.com).
#   2. Store notary credentials once:
#        xcrun notarytool store-credentials ROSTERFOCUS_NOTARY \
#          --apple-id "<you@example.com>" --team-id "<TEAMID>" --password "<app-specific-password>"
#
# Then (TEAM_ID is optional — only used to sanity-check the cert):
#   ./scripts/package-notarize.sh
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # -> app/

NOTARY_PROFILE="${NOTARY_PROFILE:-ROSTERFOCUS_NOTARY}"
SIGN_ID="${SIGN_ID:-Developer ID Application}"   # codesign matches by this (unique) substring
ENT="RosterFocus/RosterFocus.entitlements"
DD="build-release"
APP="$DD/dd/Build/Products/Release/RosterFocus.app"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate >/dev/null
rm -rf "$DD"; mkdir -p "$DD"

echo "==> Building (Release, unsigned)…"
xcodebuild build -quiet -project RosterFocus.xcodeproj -scheme RosterFocus \
  -configuration Release -derivedDataPath "$DD/dd" CODE_SIGNING_ALLOWED=NO

echo "==> Signing with Developer ID (framework, then app)…"
codesign --force --options runtime --timestamp --sign "$SIGN_ID" \
  "$APP/Contents/Frameworks/RosterFocusCore.framework"
codesign --force --options runtime --timestamp --entitlements "$ENT" --sign "$SIGN_ID" "$APP"

# Fail fast — before the multi-minute notary wait — if signing didn't take.
echo "==> Pre-flight signature check…"
SIG="$(codesign -dvvv "$APP" 2>&1 || true)"
echo "$SIG" | grep -q 'flags=.*runtime' || { echo "ERROR: app is not hardened-runtime signed"; exit 1; }
echo "$SIG" | grep -q 'Authority=Developer ID Application' || { echo "ERROR: app is not Developer ID signed"; exit 1; }
codesign --verify --strict --verbose=2 "$APP"

echo "==> Notarizing (this waits for Apple)…"
ditto -c -k --keepParent "$APP" "$DD/RosterFocus.zip"
xcrun notarytool submit "$DD/RosterFocus.zip" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling…"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=4 "$APP"

echo "==> Creating DMG…"
DMG="$DD/RosterFocus.dmg"
STAGING="$DD/dmg-staging"
rm -rf "$STAGING" "$DMG"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "RosterFocus" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

# Sign + notarize + staple the DMG itself too, so it opens cleanly even after a
# download/AirDrop adds the quarantine attribute (the app inside is already stapled).
echo "==> Signing the DMG…"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
echo "==> Notarizing the DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true

echo "==> Done."
echo "    App: $APP        (notarized + stapled)"
echo "    DMG: $DMG  (notarized + stapled, drag-to-Applications installer)"
