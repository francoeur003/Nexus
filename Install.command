#!/bin/bash
# Nexus — post-install setup
# Run this once after dragging Nexus.app to /Applications

APP="/Applications/Nexus.app"
HELPER="/Users/Shared/Nexus/nexus-helper"
SUDOERS_FILE="/etc/sudoers.d/nexus-helper"

echo ""
echo "Nexus Setup"
echo "────────────────"

# ── 1. Verify app is installed ────────────────────────────────────────────────
if [ ! -d "$APP" ]; then
  echo ""
  echo "Nexus.app not found in /Applications."
  echo "Please drag Nexus.app to your Applications folder first, then run this script again."
  echo ""
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# ── 2. Remove quarantine flag ─────────────────────────────────────────────────
echo ""
echo "→ Removing macOS quarantine flag..."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "  Done."

# ── 3. Grant passwordless sudo for the native helper ─────────────────────────
echo ""
echo "→ Granting Nexus permission to read GPU, temperature, and power data."
echo "  You may be prompted for your macOS password (one time only)."
echo ""
mkdir -p "$(dirname "$HELPER")"
if [ -f "$APP/Contents/MacOS/nexus-helper" ]; then
  sudo cp "$APP/Contents/MacOS/nexus-helper" "$HELPER"
  sudo chmod 755 "$HELPER"
fi
echo "%admin ALL=(ALL) NOPASSWD: $HELPER" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"
echo "  Permission granted."

# ── 4. Launch app ─────────────────────────────────────────────────────────────
echo ""
echo "✓ Setup complete. Launching Nexus..."
echo ""
open "$APP"
