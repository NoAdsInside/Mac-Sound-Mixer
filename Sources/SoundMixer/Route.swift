import CoreAudio
import Foundation

/// Sends one app's audio to one output device:
/// process tap (mutes the app at the source) -> private aggregate device -> IOProc copies tap input to device output.
final class Route {
    static let uidPrefix = "SoundMixer-"

    let deviceUID: String
    let processObjects: [AudioObjectID]
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(processObjects: [AudioObjectID], deviceUID: String) throws {
        self.processObjects = processObjects
        self.deviceUID = deviceUID
        do { try start() } catch { stop(); throw error }
    }

    deinit { stop() }

    private func start() throws {
        let tap = CATapDescription(stereoMixdownOfProcesses: processObjects)
        tap.muteBehavior = .mutedWhenTapped
        tap.isPrivate = true
        tap.name = "Sound Mixer tap"
        try check(AudioHardwareCreateProcessTap(tap, &tapID), "Creating process tap")

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Sound Mixer",
            kAudioAggregateDeviceUIDKey: Route.uidPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: deviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: deviceUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tap.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID),
                  "Creating aggregate device")

        // nil queue: the block runs directly on the HAL's real-time IO thread.
        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, input, _, output, _ in
            Route.copy(from: UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)),
                       to: UnsafeMutableAudioBufferListPointer(output))
        }, "Creating IOProc")
        try check(AudioDeviceStart(aggregateID, ioProcID), "Starting device")
    }

    func stop() {
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    /// Copies the stereo tap into the device's channels: L/R to the first two channels,
    /// silence on the rest, and an L/R average on a mono device. Assumes Float32 samples (HAL standard).
    private static func copy(from input: UnsafeMutableAudioBufferListPointer,
                             to output: UnsafeMutableAudioBufferListPointer) {
        let outChannels = output.reduce(0) { $0 + Int($1.mNumberChannels) }
        var channelBase = 0
        for buffer in output {
            let n = Int(buffer.mNumberChannels)
            defer { channelBase += n }
            guard n > 0, let data = buffer.mData?.assumingMemoryBound(to: Float32.self) else { continue }
            let frames = Int(buffer.mDataByteSize) / (n * MemoryLayout<Float32>.size)
            for c in 0..<n {
                for f in 0..<frames {
                    data[f * n + c] = outChannels == 1
                        ? (sample(input, channel: 0, frame: f) + sample(input, channel: 1, frame: f)) * 0.5
                        : sample(input, channel: channelBase + c, frame: f)
                }
            }
        }
    }

    /// One sample from a buffer list, whether it is interleaved or not. Returns 0 when out of range.
    private static func sample(_ list: UnsafeMutableAudioBufferListPointer, channel: Int, frame: Int) -> Float32 {
        var base = 0
        for buffer in list {
            let n = Int(buffer.mNumberChannels)
            if channel < base + n {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float32.self),
                      frame < Int(buffer.mDataByteSize) / (n * MemoryLayout<Float32>.size) else { return 0 }
                return data[frame * n + channel - base]
            }
            base += n
        }
        return 0
    }
}
