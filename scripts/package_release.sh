#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/kNotes.app"

if [ ! -d "$APP_PATH" ]; then
    echo "kNotes.app not found in project directory. Running build_and_install.sh first..."
    "$SCRIPT_DIR/build_and_install.sh"
fi

echo "--> Packaging kNotes DMG..."
DMG_STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$DMG_STAGING/kNotes.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "kNotes" -srcfolder "$DMG_STAGING" -ov -format UDZO "$PROJECT_DIR/kNotes.dmg"
rm -rf "$DMG_STAGING"
cp "$PROJECT_DIR/kNotes.dmg" "$PROJECT_DIR/kNotes-v0.3-macOS.dmg"

echo "--> Packaging kNotes ZIP..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PROJECT_DIR/kNotes.zip"
cp "$PROJECT_DIR/kNotes.zip" "$PROJECT_DIR/kNotes-v0.3-macOS.zip"

echo "✓ Release assets generated successfully:"
ls -lh "$PROJECT_DIR"/*.dmg "$PROJECT_DIR"/*.zip
