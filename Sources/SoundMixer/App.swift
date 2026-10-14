import AppKit
import SwiftUI

@main
struct SoundMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Sound Mixer", systemImage: "speaker.wave.2") {
            ContentView(router: .shared)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        Router.shared.stopAll()
    }
}

struct ContentView: View {
    let router: Router

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if router.visibleApps.isEmpty {
                Text("No apps are using audio").foregroundStyle(.secondary)
            }
            ForEach(router.visibleApps) { app in
                HStack {
                    Image(nsImage: app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(app.name).lineLimit(1)
                    Circle()
                        .fill(app.isPlaying ? Color.green : Color.clear)
                        .frame(width: 6, height: 6)
                    Spacer()
                    Picker("Output", selection: Binding(
                        get: { router.routes[app.id]?.deviceUID },
                        set: { router.setRoute(app.id, to: $0) }
                    )) {
                        Text("System Default").tag(String?.none)
                        Divider()
                        ForEach(router.devices) { device in
                            Text(device.name).tag(Optional(device.uid))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
            }
            if let error = router.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Divider()
            Button("Quit Sound Mixer") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 380)
    }
}
