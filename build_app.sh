#!/bin/bash
set -e

echo "🔨 Compiling SmurfAudio..."
swift build -c debug

APP_DIR="SmurfAudio.app/Contents/MacOS"
RES_DIR="SmurfAudio.app/Contents/Resources"

echo "📦 Assembling SmurfAudio.app bundle..."
mkdir -p "$APP_DIR"
mkdir -p "$RES_DIR"

cp .build/debug/SmurfAudio "$APP_DIR/SmurfAudio"
cp Info.plist SmurfAudio.app/Contents/Info.plist

echo "✍️ Signing with entitlements (ScreenCaptureKit & Audio permissions)..."
codesign --force --deep --sign - -r="designated => identifier \"com.smurfaudio.app\"" --entitlements SmurfAudio.entitlements SmurfAudio.app

echo "✅ SmurfAudio.app is ready!"
