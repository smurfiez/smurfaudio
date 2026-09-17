#!/bin/bash
set -e

CONFIG="${1:-${CONFIGURATION:-debug}}"

echo "🔨 Compiling SmurfAudio ($CONFIG)..."
swift build -c "$CONFIG"

APP_DIR="SmurfAudio.app/Contents/MacOS"
RES_DIR="SmurfAudio.app/Contents/Resources"

echo "📦 Assembling SmurfAudio.app bundle..."
mkdir -p "$APP_DIR"
mkdir -p "$RES_DIR"

cp ".build/$CONFIG/SmurfAudio" "$APP_DIR/SmurfAudio"
cp Info.plist SmurfAudio.app/Contents/Info.plist

if [ -d "Resources" ]; then
    cp -R Resources/* "$RES_DIR/"
fi

echo "✍️ Signing with entitlements (ScreenCaptureKit & Audio permissions)..."
codesign --force --deep --sign - -r="designated => identifier \"com.smurfaudio.app\"" --entitlements SmurfAudio.entitlements SmurfAudio.app

echo "✅ SmurfAudio.app is ready ($CONFIG)!"
