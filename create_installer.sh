#!/bin/bash
set -e

PACKAGE_NAME="SmurfAudioInstaller.pkg"
BUILD_ROOT="pkg_build_root"

CONFIG="${1:-${CONFIGURATION:-release}}"

echo "🔨 Ensuring SmurfAudio.app is compiled ($CONFIG)..."
./build_app.sh "$CONFIG"

echo "🔍 Verifying BlackHole prerequisite driver..."
if [ ! -d "Prerequisites/BlackHole2ch.driver" ]; then
    if [ -d "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" ]; then
        mkdir -p Prerequisites
        cp -R "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" Prerequisites/
    else
        echo "❌ Error: BlackHole2ch.driver not found in Prerequisites/ or /Library/Audio/Plug-Ins/HAL/"
        exit 1
    fi
fi

echo "📦 Preparing payload directory structure..."
rm -rf "$BUILD_ROOT" "$PACKAGE_NAME"
mkdir -p "$BUILD_ROOT/Applications"
mkdir -p "$BUILD_ROOT/Library/Audio/Plug-Ins/HAL"

cp -R "SmurfAudio.app" "$BUILD_ROOT/Applications/"
cp -R "Prerequisites/BlackHole2ch.driver" "$BUILD_ROOT/Library/Audio/Plug-Ins/HAL/"

# Clean macOS extended metadata files
find "$BUILD_ROOT" -name "._*" -delete

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.4.0")
echo "📦 Building macOS installer package with pkgbuild (v$VERSION)..."
pkgbuild \
    --root "$BUILD_ROOT" \
    --scripts "installer_scripts" \
    --identifier "com.smurfaudio.installer" \
    --version "$VERSION" \
    --install-location "/" \
    "$PACKAGE_NAME"

echo "🧹 Cleaning up payload build root..."
rm -rf "$BUILD_ROOT"

echo "✅ Package created successfully: $PACKAGE_NAME"
ls -lh "$PACKAGE_NAME"
