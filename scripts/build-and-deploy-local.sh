#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/MacMonitor Hermes.app"
PRODUCT="$ROOT/build/manual-product/Macmonitor"
OBJ_DIR="$ROOT/build/manual-objects"
BACKUP_DIR="$ROOT/build/codex-backups"
SIGN_IDENTITY="${SIGN_IDENTITY:-MacMonitor Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  echo "Missing stable signing identity: $SIGN_IDENTITY" >&2
  echo "Refusing to deploy with ad-hoc signing because it resets macOS privacy permissions." >&2
  exit 1
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
  -framework AppKit -framework SwiftUI -framework Combine -framework IOKit -framework DiskArbitration \
  -framework ScreenCaptureKit -framework AVFoundation -lIOReport \
  -o "$PRODUCT"

old_pid="$(pgrep -f "$APP/Contents/MacOS/Macmonitor" | head -n 1 || true)"
backup="$BACKUP_DIR/Macmonitor.before-local-deploy-$(date +%Y%m%d-%H%M%S)"
cp "$APP/Contents/MacOS/Macmonitor" "$backup"

install -m 755 "$PRODUCT" "$APP/Contents/MacOS/Macmonitor"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ -n "$old_pid" ]; then
  kill "$old_pid" || true
fi
open -na "$APP"

echo "Deployed with stable signing identity: $SIGN_IDENTITY"
echo "Backup: $backup"
