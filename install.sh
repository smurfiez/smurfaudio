#!/bin/bash
set -e

echo "🚀 Installing SmurfAudio and Prerequisites..."

# 1. Build SmurfAudio
./build_app.sh

# 2. Check BlackHole driver
if [ ! -d "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" ]; then
    echo "⚙️ BlackHole 2ch driver not detected in CoreAudio HAL plugins."
    echo "🔐 Administrator password required to install the BlackHole driver into /Library/Audio/Plug-Ins/HAL/..."
    sudo cp -R "Prerequisites/BlackHole2ch.driver" "/Library/Audio/Plug-Ins/HAL/"
    sudo chown -R root:wheel "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver"
    sudo chmod -R 755 "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver"
    echo "🔄 Restarting CoreAudio daemon to activate BlackHole..."
    sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod 2>/dev/null || sudo killall -9 coreaudiod 2>/dev/null || true
    echo "✅ BlackHole 2ch driver installed successfully."
else
    echo "✅ BlackHole 2ch driver is already installed."
fi

# 3. Copy SmurfAudio.app to /Applications
echo "📋 Installing SmurfAudio.app to /Applications..."
rm -rf "/Applications/SmurfAudio.app"
cp -R "SmurfAudio.app" "/Applications/"
echo "✅ SmurfAudio installed to /Applications/SmurfAudio.app"

# 4. Permissions info
echo ""
echo "================================================================="
echo "🎉 Installation Complete!"
echo "================================================================="
echo "To start SmurfAudio, run:"
echo "    open /Applications/SmurfAudio.app"
echo ""
echo "Note: When launching for the first time, please ensure you allow:"
echo "  1. Screen & System Audio Recording (for per-app audio capture)"
echo "  2. Accessibility (optional, for hardware media keys)"
echo "================================================================="
