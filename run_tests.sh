#!/bin/bash
set -e

echo "🧪 Running SmurfAudio test suite..."
swift test -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks --no-parallel "$@"
