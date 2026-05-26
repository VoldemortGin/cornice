import AppKit

/// Owns panel creation / destruction for all screens.
/// Observes screen parameter changes and keeps the panels dictionary in sync.
@MainActor
final class ScreenManager {

    /// Per-screen panel controllers, keyed by screen UUID.
    private(set) var panelControllers: [String: NotchPanelController] = [:]

    private let coordinator: ViewCoordinator

    /// Observes NSApplication.didChangeScreenParametersNotification.
    private var screenObserver: NSObjectProtocol?

    init(coordinator: ViewCoordinator) {
        self.coordinator = coordinator
        observeScreenChanges()
    }

    // MARK: - Panel Lifecycle

    /// Creates panels for all connected screens (idempotent per screen).
    func createPanelsForAllScreens() {
        for screen in NSScreen.screens {
            let uuid = NotchDetector.displayUUID(for: screen.screenDisplayID)

            guard panelControllers[uuid] == nil else { continue }
            guard let viewModel = coordinator.viewModels[uuid] else { continue }

            let featureVMs = FeatureViewModels()
            let controller = NotchPanelController(screen: screen, viewModel: viewModel, featureViewModels: featureVMs)
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

    /// Tears down all panels.
    func tearDownAll() {
        for (_, controller) in panelControllers {
            controller.tearDown()
        }
        panelControllers.removeAll()
    }

    // MARK: - Screen Change Observation

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenParametersChanged()
            }
        }
    }

    func handleScreenParametersChanged() {
        coordinator.setupForCurrentScreens()
        createPanelsForAllScreens()
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
