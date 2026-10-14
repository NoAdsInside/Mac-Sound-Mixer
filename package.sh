#!/bin/bash
# Builds a universal (Apple Silicon + Intel) "Sound Mixer.app" and packs it into dist/SoundMixer-<version>.dmg.
#
# Without options the app is ad-hoc signed: it runs anywhere, but users must click
# "Open Anyway" once in System Settings → Privacy & Security.
#
# With an Apple Developer ID it's signed and notarized, so it opens with no warning:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE=soundmixer ./package.sh
# (create the profile once with: xcrun notarytool store-credentials soundmixer)
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DIST=dist
APP="$DIST/Sound Mixer.app"
DMG="$DIST/SoundMixer-$VERSION.dmg"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/SoundMixer"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --force --options runtime --timestamp \
        --entitlements Resources/SoundMixer.entitlements --sign "$DEVELOPER_ID" "$APP"
else
    codesign --force --sign - "$APP"
fi

# DMG with an Applications shortcut so users can drag-and-drop install.
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Sound Mixer" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
    fi
fi

echo "Created $DMG"
