#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${HERMES_VERSION:-2.0.59}"
BUILD="${HERMES_BUILD:-2059}"
APP_SOURCE="${APP_SOURCE:-/Applications/MacMonitor Hermes.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:-MacMonitor Local Code Signing}"
DIST="$ROOT/dist/hermes-release-$VERSION"
STAGING="$DIST/staging"
APP_NAME="MacMonitor Hermes.app"
DMG_NAME="MacMonitor-Hermes-$VERSION.dmg"
ZIP_NAME="MacMonitor-Hermes-$VERSION.zip"

if [ ! -d "$APP_SOURCE" ]; then
  echo "Missing app source: $APP_SOURCE" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$STAGING"

ditto "$APP_SOURCE" "$STAGING/$APP_NAME"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$STAGING/$APP_NAME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$STAGING/$APP_NAME/Contents/Info.plist"

if security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$STAGING/$APP_NAME"
fi
codesign --verify --deep --strict --verbose=2 "$STAGING/$APP_NAME"

ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "MacMonitor Hermes $VERSION" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DIST/$DMG_NAME" > /dev/null

ditto -c -k --sequesterRsrc --keepParent "$STAGING/$APP_NAME" "$DIST/$ZIP_NAME"
cp "$DIST/$DMG_NAME" "$DIST/MacMonitor-Hermes.dmg"

hdiutil verify "$DIST/$DMG_NAME" > /dev/null
shasum -a 256 "$DIST/$DMG_NAME" "$DIST/$ZIP_NAME" > "$DIST/SHA256SUMS.txt"

echo "$DIST/$DMG_NAME"
echo "$DIST/$ZIP_NAME"
echo "$DIST/SHA256SUMS.txt"
