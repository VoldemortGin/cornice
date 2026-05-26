import AppKit
import SwiftUI

/// NSApplicationDelegate that manages the entire notch overlay lifecycle.
/// Creates NotchPanelControllers for all screens, sets up event monitors,
/// and coordinates global state.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Per-screen panel controllers, keyed by screen UUID.
    private var panelControllers: [String: NotchPanelController] = [:]

    /// Menu bar status item.
    private var statusItem: NSStatusItem?

    /// Global mouse move event monitor for hover detection.
    private var globalMouseMonitor: Any?

    /// Global mouse down event monitor for click-outside detection.
    private var globalMouseDownMonitor: Any?

    /// Local event monitor for interactions within panels.
    private var localEventMonitor: Any?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon).
        NSApplication.shared.setActivationPolicy(.accessory)

        // Check permissions.
        PermissionsManager.shared.checkAll()

        // Set up the menu bar status item.
        setupStatusItem()

        // Initialize ViewCoordinator and create panels for all screens.
        ViewCoordinator.shared.setupForCurrentScreens()
        createPanelsForAllScreens()

        // Set up global event monitors for mouse tracking.
        setupEventMonitors()

        Log.general.info("Crest launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        tearDownEventMonitors()
        tearDownPanels()
        Log.general.info("Crest terminating")
    }

    // MARK: - Panel Management

    private func createPanelsForAllScreens() {
        for screen in NSScreen.screens {
            let uuid = NotchDetector.displayUUID(for: screen.screenDisplayID)

            guard panelControllers[uuid] == nil else { continue }
            guard let viewModel = ViewCoordinator.shared.viewModels[uuid] else { continue }

            let controller = NotchPanelController(screen: screen, viewModel: viewModel)
            controller.show()
            panelControllers[uuid] = controller

            Log.window.info("Created panel for screen: \(uuid)")
        }

        // Remove controllers for disconnected screens.
        let currentUUIDs = Set(NSScreen.screens.map { NotchDetector.displayUUID(for: $0.screenDisplayID) })
        for (uuid, controller) in panelControllers where !currentUUIDs.contains(uuid) {
            controller.tearDown()
            panelControllers.removeValue(forKey: uuid)
            Log.window.info("Removed panel for disconnected screen: \(uuid)")
        }
    }

    private func tearDownPanels() {
        for (_, controller) in panelControllers {
            controller.tearDown()
        }
        panelControllers.removeAll()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Crest")
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

    // MARK: - Event Monitors

    private func setupEventMonitors() {
        // Global mouse moved: detect hover near notch regions.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseMoved()
            }
        }

        // Global mouse down: detect click outside the notch panel.
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseDown()
            }
        }

        // Local event monitor: interactions within panels.
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .scrollWheel]
        ) { event in
            // Pass through: the SwiftUI hosting view handles interactions.
            return event
        }
    }

    private func tearDownEventMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Mouse Handling

    private func handleGlobalMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation
        ViewCoordinator.shared.updateActiveScreen(mouseLocation: mouseLocation)

        for (uuid, controller) in panelControllers {
            guard let viewModel = ViewCoordinator.shared.viewModels[uuid] else { continue }
            let geometryInfo = viewModel.geometryInfo

            if viewModel.state.isExpanded {
                // When expanded, use the full expanded rect (with margin) for containment check.
                let expandedRect = geometryInfo.expandedRect(for: viewModel.state)
                if expandedRect.contains(mouseLocation) {
                    if !viewModel.isHovered {
                        viewModel.onHoverEnter()
                    }
                } else {
                    if viewModel.isHovered {
                        viewModel.onHoverExit()
                    }
                }
            } else {
                // When closed/sneakPeek, use the activation rect for hover detection.
                let activationRect = geometryInfo.activationRect
                if activationRect.contains(mouseLocation) {
                    if !viewModel.isHovered {
                        viewModel.onHoverEnter()
                    }
                } else if viewModel.isHovered {
                    viewModel.onHoverExit()
                }
            }

            // Update panel frame to match current state.
            controller.updateFrame()
        }
    }

    private func handleGlobalMouseDown() {
        let mouseLocation = NSEvent.mouseLocation

        for (uuid, _) in panelControllers {
            guard let viewModel = ViewCoordinator.shared.viewModels[uuid] else { continue }
            guard viewModel.state.isExpanded else { continue }

            let expandedRect = viewModel.geometryInfo.expandedRect(for: viewModel.state)
            if !expandedRect.contains(mouseLocation) {
                // Click outside: immediate close.
                viewModel.close()
            }
        }
    }

    // MARK: - Screen Changes

    func handleScreenParametersChanged() {
        ViewCoordinator.shared.setupForCurrentScreens()
        createPanelsForAllScreens()
    }
}
