import AppKit
import SwiftUI

/// Global singleton that coordinates all notch panels across screens.
/// Manages per-screen ViewModels, routes system events, and tracks screen changes.
@MainActor
@Observable
final class ViewCoordinator {
    static let shared = ViewCoordinator()

    /// Screen UUID -> NotchViewModel mapping.
    private(set) var viewModels: [String: NotchViewModel] = [:]

    /// The UUID of the screen currently under the mouse cursor.
    private(set) var activeScreenUUID: String?

    /// Current HUD state (if showing a HUD sneak peek).
    private(set) var hudEvent: SneakPeekEvent?

    /// The currently active tab/view identifier.
    var currentTab: String = "home"

    @ObservationIgnored
    private var screenObserver: NSObjectProtocol?

    private init() {
        observeScreenChanges()
    }

    // MARK: - Setup

    /// Creates ViewModels for all currently connected screens.
    func setupForCurrentScreens() {
        let currentScreens = NSScreen.screens
        var newViewModels: [String: NotchViewModel] = [:]

        for screen in currentScreens {
            let uuid = NotchDetector.displayUUID(for: screen.screenDisplayID)

            if let existing = viewModels[uuid] {
                // Keep existing view model for this screen.
                newViewModels[uuid] = existing
            } else {
                // Create new view model.
                let geometry = NotchDetector.geometryInfo(for: screen)
                let vm = NotchViewModel(screenUUID: uuid, geometryInfo: geometry)
                newViewModels[uuid] = vm
            }
        }

        // Clean up view models for disconnected screens.
        for (uuid, vm) in viewModels where newViewModels[uuid] == nil {
            vm.cancelAllTimers()
        }

        viewModels = newViewModels
        Log.general.info("ViewCoordinator: set up \(newViewModels.count) screen(s)")
    }

    // MARK: - Screen Change Observation

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setupForCurrentScreens()
            }
        }
    }

    // MARK: - Active Screen Tracking

    /// Updates the active screen based on the current mouse location.
    func updateActiveScreen(mouseLocation: NSPoint) {
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                let uuid = NotchDetector.displayUUID(for: screen.screenDisplayID)
                if activeScreenUUID != uuid {
                    activeScreenUUID = uuid
                }
                return
            }
        }
    }

    /// Returns the ViewModel for the currently active screen (under mouse).
    var activeViewModel: NotchViewModel? {
        guard let uuid = activeScreenUUID else { return nil }
        return viewModels[uuid]
    }

    // MARK: - Event Routing

    /// Routes a sneak peek event to the active screen (or all screens).
    func routeSneakPeek(_ event: SneakPeekEvent, toAll: Bool = false) {
        if toAll {
            for (_, vm) in viewModels {
                vm.showSneakPeek(event)
            }
        } else if let activeVM = activeViewModel {
            activeVM.showSneakPeek(event)
        } else if let firstVM = viewModels.values.first {
            // Fallback: route to first available screen.
            firstVM.showSneakPeek(event)
        }
    }

    /// Routes a HUD event (volume, brightness) as a sneak peek.
    func showHUD(_ event: SneakPeekEvent) {
        hudEvent = event
        routeSneakPeek(event)
    }

    /// Clears the HUD state.
    func clearHUD() {
        hudEvent = nil
    }

    // MARK: - Cleanup

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
