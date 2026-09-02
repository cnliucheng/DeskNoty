#!/bin/bash
# Creates a DMG file for distribution
# Usage: ./create-dmg.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.0.0}"

echo "→ Creating DMG for Noty $VERSION"

# Check if Noty.app exists
if [ ! -d "$ROOT/build/Noty.app" ]; then
    echo "❌ Noty.app not found. Run ./build.sh first"
    exit 1
fi

# Create temporary directory
DMG_TEMP="$ROOT/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy Noty.app to temporary directory
cp -R "$ROOT/build/Noty.app" "$DMG_TEMP/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG file
DMG_FILE="$ROOT/Noty-${VERSION}.dmg"
rm -f "$DMG_FILE"

echo "→ Creating DMG file..."
hdiutil create -volname "Noty" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDZO \
  "$DMG_FILE"

# Clean up
rm -rf "$DMG_TEMP"

echo "✓ DMG created: $DMG_FILE"
echo "→ Size: $(du -h "$DMG_FILE" | cut -f1)"
