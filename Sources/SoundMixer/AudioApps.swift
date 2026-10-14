import AppKit
import CoreAudio

/// An app plus every Core Audio process object that belongs to it (helpers included).
struct AudioApp: Identifiable {
    let id: String  // owning app's bundle ID, or the process's own ID if no owner
    let name: String
    let icon: NSImage?
    let isRegular: Bool  // a normal Dock app, as opposed to a daemon/agent
    var isPlaying: Bool
    var processObjects: [AudioObjectID]

    static func current() -> [AudioApp] {
        let regularApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }
        var groups: [String: AudioApp] = [:]

        for obj in CA.objectIDs(CA.system, kAudioHardwarePropertyProcessObjectList) {
            guard let pid = CA.get(obj, kAudioProcessPropertyPID, initial: pid_t(0)),
                  pid != getpid() else { continue }
            let bundleID = CA.string(obj, kAudioProcessPropertyBundleID) ?? ""
            let playing = (CA.get(obj, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0)) ?? 0) != 0

            // Helpers (e.g. com.google.Chrome.helper) are grouped under the app whose
            // bundle ID is the longest prefix of theirs.
            let owner = regularApps
                .filter { app in
                    let b = app.bundleIdentifier!
                    return app.processIdentifier == pid || bundleID == b || bundleID.hasPrefix(b + ".")
                }
                .max { $0.bundleIdentifier!.count < $1.bundleIdentifier!.count }
            let process = NSRunningApplication(processIdentifier: pid)
            let key = owner?.bundleIdentifier ?? (bundleID.isEmpty ? "pid:\(pid)" : bundleID)

            if groups[key] == nil {
                groups[key] = AudioApp(
                    id: key,
                    name: owner?.localizedName ?? process?.localizedName ?? (bundleID.isEmpty ? "PID \(pid)" : bundleID),
                    icon: owner?.icon ?? process?.icon,
                    isRegular: owner != nil,
                    isPlaying: false,
                    processObjects: [])
            }
            groups[key]!.processObjects.append(obj)
            groups[key]!.isPlaying = groups[key]!.isPlaying || playing
        }

        return groups.values.sorted {
            $0.isPlaying != $1.isPlaying ? $0.isPlaying : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
