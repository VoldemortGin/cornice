import SwiftUI

@main
struct CrestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene (opened via menu bar "Settings..." item).
        Settings {
            SettingsView()
        }
    }
}
