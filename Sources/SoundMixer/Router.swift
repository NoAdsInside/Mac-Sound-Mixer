import CoreAudio
import Foundation
import Observation

/// App state: which apps are using audio, which output devices exist, and the active routes.
/// Everything runs on the main queue (Core Audio listeners are registered on .main).
@Observable
final class Router {
    static let shared = Router()

    private(set) var apps: [AudioApp] = []
    private(set) var devices: [OutputDevice] = []
    private(set) var routes: [String: Route] = [:]  // AudioApp.id -> route
    private(set) var lastError: String?
    @ObservationIgnored private var watchedProcesses = Set<AudioObjectID>()

    /// Dock apps that use audio, plus anything currently playing or routed.
    var visibleApps: [AudioApp] {
        apps.filter { $0.isRegular || $0.isPlaying || routes[$0.id] != nil }
    }

    private init() {
        listen(CA.system, kAudioHardwarePropertyProcessObjectList)
        listen(CA.system, kAudioHardwarePropertyDevices)
        refresh()
    }

    func setRoute(_ appID: String, to deviceUID: String?) {
        routes.removeValue(forKey: appID)?.stop()  // release the old tap first
        lastError = nil
        guard let deviceUID, let app = apps.first(where: { $0.id == appID }) else { return }
        do {
            routes[appID] = try Route(processObjects: app.processObjects, deviceUID: deviceUID)
        } catch {
            lastError = "\(app.name): \(error)"
        }
    }

    func stopAll() {
        routes.values.forEach { $0.stop() }
        routes.removeAll()
    }

    private func refresh() {
        devices = OutputDevice.all()
        apps = AudioApp.current()

        // Start/stop playing doesn't change the process list, so watch each process too.
        for app in apps {
            for obj in app.processObjects where !watchedProcesses.contains(obj) {
                watchedProcesses.insert(obj)
                listen(obj, kAudioProcessPropertyIsRunningOutput)
            }
        }

        for (appID, route) in routes {
            guard let app = apps.first(where: { $0.id == appID }),
                  devices.contains(where: { $0.uid == route.deviceUID })
            else {
                // App quit or device went away: fall back to the system default.
                routes.removeValue(forKey: appID)?.stop()
                continue
            }
            if Set(app.processObjects) != Set(route.processObjects) {
                setRoute(appID, to: route.deviceUID)  // e.g. a new helper process started
            }
        }
    }

    private func listen(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) {
        var addr = CA.address(selector)
        AudioObjectAddPropertyListenerBlock(obj, &addr, .main) { [weak self] _, _ in
            self?.refresh()
        }
    }
}
