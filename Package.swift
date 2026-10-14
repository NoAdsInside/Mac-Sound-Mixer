// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SoundMixer",
    platforms: [.macOS("14.2")],  // Core Audio process taps arrived in 14.2
    targets: [
        .executableTarget(name: "SoundMixer", path: "Sources/SoundMixer"),
    ]
)
