import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    private var windowDelegate: WindowDelegate?

    func showSettings() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = hostingController
        newWindow.title = "Crest Settings"
        newWindow.center()
        newWindow.setFrameAutosaveName("CrestSettings")
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 600, height: 400)
        let delegate = WindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        self.windowDelegate = delegate
        newWindow.delegate = delegate

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = newWindow
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - Window Delegate

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
