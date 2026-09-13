#!/bin/bash
set -e

APP_NAME="SmurfAudio"
DMG_NAME="${APP_NAME}.dmg"
STAGING_DIR="dmg_staging"

echo "📦 Ensuring app bundle is built and signed..."
./build_app.sh

echo "🧹 Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

echo "📋 Copying ${APP_NAME}.app into staging..."
cp -R "${APP_NAME}.app" "$STAGING_DIR/"

echo "🔗 Creating /Applications symlink for drag-and-drop installation..."
ln -s /Applications "$STAGING_DIR/Applications"

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
