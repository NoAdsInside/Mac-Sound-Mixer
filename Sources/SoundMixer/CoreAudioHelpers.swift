import CoreAudio
import Foundation

struct CAError: Error, CustomStringConvertible {
    let what: String
    let status: OSStatus
    var description: String { "\(what) failed (\(status))" }
}

func check(_ status: OSStatus, _ what: String) throws {
    if status != noErr { throw CAError(what: what, status: status) }
}

/// Thin wrappers around AudioObjectGetPropertyData.
enum CA {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// Reads a fixed-size (POD) property.
    static func get<T: BitwiseCopyable>(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) -> T? {
        var addr = address(selector)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    static func string(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func objectIDs(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(obj, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func hasOutputStreams(_ device: AudioObjectID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr && size > 0
    }
}

struct OutputDevice: Identifiable, Hashable {
    let uid: String
    let name: String
    var id: String { uid }

    static func all() -> [OutputDevice] {
        CA.objectIDs(CA.system, kAudioHardwarePropertyDevices).compactMap { dev in
            guard CA.hasOutputStreams(dev),
                  let uid = CA.string(dev, kAudioDevicePropertyDeviceUID),
                  !uid.hasPrefix(Route.uidPrefix),  // hide our own aggregates
                  let name = CA.string(dev, kAudioObjectPropertyName)
            else { return nil }
            return OutputDevice(uid: uid, name: name)
        }
    }
}
