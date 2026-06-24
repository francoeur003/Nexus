#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Nexus.app"
PRODUCT="$ROOT/build/manual-product/Nexus"
HELPER_PRODUCT="$ROOT/build/manual-product/nexus-helper"
OBJ_DIR="$ROOT/build/manual-objects"
BACKUP_DIR="$ROOT/build/codex-backups"
SIGN_IDENTITY="${SIGN_IDENTITY:-Nexus Local Code Signing}"

if security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  CODESIGN_IDENTITY="$SIGN_IDENTITY"
else
  CODESIGN_IDENTITY="-"
fi

mkdir -p "$OBJ_DIR" "$ROOT/build/manual-product" "$BACKUP_DIR"

clang -target arm64-apple-macos13.0 -I "$ROOT/Nexus" -fobjc-arc \
  -c "$ROOT/Nexus/IOReportWrapper.m" \
  -o "$OBJ_DIR/IOReportWrapper.o"

clang -target arm64-apple-macos13.0 -I "$ROOT/Nexus" \
  -c "$ROOT/Nexus/SMC.c" \
  -o "$OBJ_DIR/SMC.o"

swiftc -swift-version 5 -target arm64-apple-macosx13.0 -O -default-isolation MainActor \
  -import-bridging-header "$ROOT/Nexus/Nexus-Bridging-Header.h" -Xcc -I -Xcc "$ROOT/Nexus" \
  "$ROOT/Nexus/AppDelegate.swift" \
  "$ROOT/Nexus/ConversationCoachWindow.swift" \
  "$ROOT/Nexus/NexusApp.swift" \
  "$ROOT/Nexus/PopoverView.swift" \
  "$ROOT/Nexus/RecordingController.swift" \
  "$ROOT/Nexus/SystemStatsModel.swift" \
  "$ROOT/Nexus/UpdateChecker.swift" \
  "$ROOT/Nexus/WelcomeView.swift" \
  "$OBJ_DIR/IOReportWrapper.o" "$OBJ_DIR/SMC.o" \
  -framework AppKit -framework SwiftUI -framework Combine -framework IOKit -framework DiskArbitration -framework CoreWLAN \
  -framework ScreenCaptureKit -framework AVFoundation -lIOReport \
  -o "$PRODUCT"

clang -target arm64-apple-macos13.0 -I "$ROOT/Nexus" -fobjc-arc \
  "$ROOT/helper/nexus-helper.m" \
  "$ROOT/Nexus/IOReportWrapper.m" \
  "$ROOT/Nexus/SMC.c" \
  -framework Foundation -framework IOKit \
  -F/System/Library/PrivateFrameworks -lIOReport \
  -o "$HELPER_PRODUCT"

old_pid="$(pgrep -f "$APP/Contents/MacOS/Nexus" | head -n 1 || true)"
if [ -n "$old_pid" ]; then
  kill "$old_pid" || true
  sleep 0.5
fi

if [ ! -d "$APP" ]; then
  echo "Missing app bundle: $APP" >&2
  exit 1
fi

backup="$BACKUP_DIR/Nexus.before-local-deploy-$(date +%Y%m%d-%H%M%S)"
cp "$APP/Contents/MacOS/Nexus" "$backup"

install -m 755 "$PRODUCT" "$APP/Contents/MacOS/Nexus"
install -m 755 "$HELPER_PRODUCT" "$APP/Contents/MacOS/nexus-helper"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Nexus" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Nexus" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.abo.Nexus" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Nexus" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 2.0.63" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2063" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription Nexus 需要麦克风权限，用于录制你的声音和通话声音。" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :NSScreenCaptureUsageDescription Nexus 需要录屏与系统录音权限，用于记录会议和电脑声音。" "$APP/Contents/Info.plist"
ICONSET="$ROOT/build/nexus-icon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" "$ICONSET/icon_16x16.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" "$ICONSET/icon_32x32.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_64x64.png" "$ICONSET/icon_32x32@2x.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" "$ICONSET/icon_128x128.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" "$ICONSET/icon_256x256.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" "$ICONSET/icon_512x512.png"
cp "$ROOT/Nexus/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
open -na "$APP"

echo "Deployed with signing identity: $CODESIGN_IDENTITY"
echo "Backup: $backup"
