import SwiftUI

@main
struct CorniceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene (opened via menu bar "Settings..." item).
        Settings {
            SettingsView()
        }
    }
}
