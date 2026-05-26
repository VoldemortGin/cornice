import AppKit
import SwiftUI

/// Thin orchestrator: creates ScreenManager and HoverDetector,
/// sets up the menu bar, and delegates to them.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var screenManager: ScreenManager?
    private var hoverDetector: HoverDetector?
    private var statusItem: NSStatusItem?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        PermissionsManager.shared.checkAll()

        setupStatusItem()

        // Initialize screen management.
        ViewCoordinator.shared.setupForCurrentScreens()
        let sm = ScreenManager(coordinator: ViewCoordinator.shared)
        sm.createPanelsForAllScreens()
        self.screenManager = sm

        // Initialize hover detection.
        let hd = HoverDetector(
            coordinator: ViewCoordinator.shared,
            panelControllers: { [weak sm] in sm?.panelControllers ?? [:] }
        )
        hd.start()
        self.hoverDetector = hd

        Log.general.info("Cornice launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverDetector?.stop()
        screenManager?.tearDownAll()
        Log.general.info("Cornice terminating")
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Cornice")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        statusItem?.menu = createStatusMenu()
    }

    private func createStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "About Niya", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Niya", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        return menu
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
