#!/bin/bash
set -e

echo "🧪 Running SmurfAudio test suite..."
swift test --no-parallel "$@"
