# Sound Mixer

A small macOS menu bar app that plays each app's audio on a different output device, similar to the Windows volume mixer. It uses Core Audio process taps, so there's no audio driver to install.

## Install

Requires macOS 14.2 or later (Apple Silicon or Intel).

1. Download the latest **SoundMixer-x.x.dmg** from the [Releases page](https://github.com/NoAdsInside/Mac-Sound-Mixer/releases/latest), then open it.
2. Drag **Sound Mixer** onto the **Applications** folder.
3. Open Sound Mixer from Applications.
4. If macOS says it can't verify the app, click **Done**. Then go to System Settings → Privacy & Security, scroll down, and click **Open Anyway** next to Sound Mixer. You only need to do this once. (Apologies but I can't be bothered to pay for teh privilage to sign an app for something that should be shipped with MacOS)

A speaker icon appears in the menu bar at the top of the screen.

## Building from source

Requires a Swift toolchain: Xcode, or just the Command Line Tools (`xcode-select --install`).

To make the installable DMG (universal, written to `dist/`):

```sh
./package.sh
```

To publish a new version, bump `CFBundleShortVersionString` in `Resources/Info.plist`, run `./package.sh`, then attach the DMG to a GitHub release:

```sh
gh release create v0.2 dist/SoundMixer-0.2.dmg --title "Sound Mixer 0.2"
```

The DMG is ad-hoc signed by default, which is why users need the "Open Anyway" step. If you have an Apple Developer ID, `package.sh` can also sign and notarize the DMG so it opens with no warning. See the comment at the top of the script.

### Build and run (development)

```sh
./build.sh
open "Sound Mixer.app"
```

A speaker icon appears in the menu bar. There's no Dock icon.

To start it automatically when you log in, add `Sound Mixer.app` under System Settings → General → Login Items.

## Usage

1. Click the speaker icon. The list shows apps that have used audio. A green dot means the app is playing right now.
2. Pick an output device next to an app. Its audio now plays only on that device.
3. Pick **System Default** to send it back to the normal output.

The first time you route an app, macOS asks for **System Audio Recording** permission. Allow it. You can change it later in System Settings → Privacy & Security → Screen & System Audio Recording.

Routes last until you quit Sound Mixer. Quitting returns every app to the default output.

## Notes

- An app shows up in the list only after it has used audio.
- Audio is mixed down to stereo.
- Each rebuild re-signs the app, so macOS may ask for the audio permission again.
