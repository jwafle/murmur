import SwiftUI
import AppKit

@main
struct MacWisperApp: App {
    @State private var controller = DictationController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
                .task { await controller.start() }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        Settings {
            SettingsView(controller: controller)
                .frame(width: 560, height: 540)
        }
    }
}
