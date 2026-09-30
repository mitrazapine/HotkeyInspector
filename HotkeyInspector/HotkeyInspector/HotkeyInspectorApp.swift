import SwiftUI

@main
struct HotkeyInspectorApp: App {
    @AppStorage("keepOnTop") private var keepOnTop = true

    var body: some Scene {
        Window("Hotkey Inspector", id: "inspector") {
            ContentView()
        }
        .defaultSize(width: 1050, height: 700)
        .windowLevel(keepOnTop ? .floating : .normal)
        .commands { InspectorCommands() }
    }
}
