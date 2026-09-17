#!/bin/bash
set -e

APP_NAME="SmurfAudio"
DMG_NAME="${APP_NAME}.dmg"
STAGING_DIR="dmg_staging"

CONFIG="${1:-${CONFIGURATION:-release}}"

echo "📦 Ensuring installer package is built ($CONFIG)..."
./create_installer.sh "$CONFIG"

echo "🧹 Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

echo "📋 Copying Install ${APP_NAME}.pkg installer into staging..."
cp "SmurfAudioInstaller.pkg" "$STAGING_DIR/Install ${APP_NAME}.pkg"

echo "📋 Copying ${APP_NAME}.app into staging..."
cp -R "${APP_NAME}.app" "$STAGING_DIR/"

echo "🔗 Creating /Applications symlink for drag-and-drop installation..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "📄 Adding quick instructions..."
cat << 'README_EOF' > "$STAGING_DIR/Instructions.txt"
============================================================
              SmurfAudio Installation Options
============================================================

Option 1 (Recommended):
Double-click "Install SmurfAudio.pkg" to install both SmurfAudio
and the BlackHole 2ch audio loopback driver prerequisite.

Option 2:
Drag "SmurfAudio.app" into the "Applications" folder if you
already have BlackHole installed.

============================================================
README_EOF

# Clean macOS extended metadata files
find "$STAGING_DIR" -name "._*" -delete

echo "💿 Creating compressed disk image (${DMG_NAME})..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

echo "🧹 Cleaning up temporary staging directory..."
rm -rf "$STAGING_DIR"

echo "✅ DMG created successfully: ${DMG_NAME}"
ls -lh "$DMG_NAME"
