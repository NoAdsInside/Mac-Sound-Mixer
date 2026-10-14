#!/bin/bash
# Builds "Sound Mixer.app" (ad-hoc signed) next to this script.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="Sound Mixer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/SoundMixer" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"
