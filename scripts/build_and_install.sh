#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "  KNotes Build & Installation Script      "
echo "=========================================="
echo "Project directory: $PROJECT_DIR"

cd "$PROJECT_DIR"

# 1. Run backend test suite
echo ""
echo "--> [1/5] Running Backend Test Suite..."
PYTHONPATH=backend ./.venv/bin/pytest backend/tests/test_api.py -v

# 2. Compile Swift release binary
echo ""
echo "--> [2/5] Building Native Swift Release Binary..."
swift build -c release

# 3. Prepare Application Bundle
APP_NAME="kNotes.app"
APPLICATIONS_DIR="/Applications"
TARGET_APP="$APPLICATIONS_DIR/$APP_NAME"
LOCAL_APP="$PROJECT_DIR/$APP_NAME"

echo ""
echo "--> [3/5] Packaging $APP_NAME bundle..."
rm -rf "$TARGET_APP" "$LOCAL_APP"
mkdir -p "$TARGET_APP/Contents/MacOS"
mkdir -p "$TARGET_APP/Contents/Resources/backend"

# Copy executable
cp ".build/release/KNotes" "$TARGET_APP/Contents/MacOS/KNotes"
chmod +x "$TARGET_APP/Contents/MacOS/KNotes"

# Copy metadata and icon
cp "Resources/Info.plist" "$TARGET_APP/Contents/Info.plist"
echo -n "APPL????" > "$TARGET_APP/Contents/PkgInfo"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$TARGET_APP/Contents/Resources/AppIcon.icns"
fi

# Bundle backend service
cp -R backend/app backend/requirements.txt backend/run.py "$TARGET_APP/Contents/Resources/backend/"
cp backend/run_backend.sh "$TARGET_APP/Contents/Resources/backend/" 2>/dev/null || true
chmod +x "$TARGET_APP/Contents/Resources/backend/run_backend.sh" 2>/dev/null || true

# 4. Set up ~/.knotes runtime environment and CLI/Raycast integrations
echo ""
echo "--> [4/5] Configuring ~/.knotes runtime and integrations..."
mkdir -p ~/.knotes/backend ~/.knotes/bin
cp -R backend/app backend/requirements.txt backend/run.py ~/.knotes/backend/
cp backend/run_backend.sh ~/.knotes/backend/ 2>/dev/null || true
chmod +x ~/.knotes/backend/run_backend.sh 2>/dev/null || true
cp bin/knotes ~/.knotes/bin/knotes
chmod +x ~/.knotes/bin/knotes
# If ~/.knotes/venv is a legacy symlink (e.g. pointing to Downloads), remove it
if [ -L "$HOME/.knotes/venv" ]; then
    echo "  Removing legacy symlinked virtual environment at ~/.knotes/venv..."
    rm -f "$HOME/.knotes/venv"
fi

# Ensure ~/.knotes/venv is an isolated, standalone virtual environment
if [ ! -f "$HOME/.knotes/venv/bin/python3" ]; then
    echo "  Creating isolated ~/.knotes/venv virtual environment..."
    python3 -m venv "$HOME/.knotes/venv"
    "$HOME/.knotes/venv/bin/pip" install --quiet --disable-pip-version-check -r backend/requirements.txt
fi
chmod 700 ~/.knotes

# Install Raycast script commands
mkdir -p ~/.config/raycast/commands
cp integrations/raycast/*.sh ~/.config/raycast/commands/ 2>/dev/null || true
chmod +x ~/.config/raycast/commands/knotes-*.sh 2>/dev/null || true

# Duplicate to local project directory
cp -R "$TARGET_APP" "$LOCAL_APP"

# 5. Ad-hoc codesign
echo ""
echo "--> [5/5] Codesigning $TARGET_APP..."
codesign --force --deep --sign - "$TARGET_APP"
codesign --force --deep --sign - "$LOCAL_APP"

echo ""
echo "=========================================="
echo "✓ kNotes successfully installed to: $TARGET_APP"
echo "✓ Bundle verification:"
codesign -v "$TARGET_APP" && echo "  Signature: Valid (Ad-hoc)"
echo "=========================================="
