import AppKit
@testable import Niya

// Production types ScreenDescriptor, NotchGeometryInfo, and NotchHeightMode
// are defined in the Niya target. Do NOT redefine them here.

// MARK: - ScreenProviding Protocol

/// Abstraction over NSScreen enumeration for testability.
protocol ScreenProviding: AnyObject {
    var screens: [NSScreen] { get }
    func addObserver(_ handler: @escaping () -> Void) -> Any
}

// MARK: - SystemScreenProvider

final class SystemScreenProvider: ScreenProviding {
    var screens: [NSScreen] { NSScreen.screens }

    func addObserver(_ handler: @escaping () -> Void) -> Any {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}

// MARK: - MockScreenProvider

final class MockScreenProvider: ScreenProviding {
    var mockScreens: [NSScreen] = []
    var screens: [NSScreen] { mockScreens }
    private var handlers: [() -> Void] = []

    func addObserver(_ handler: @escaping () -> Void) -> Any {
        handlers.append(handler)
        return handlers.count - 1
    }

    func simulateScreenChange(screens: [NSScreen]) {
        mockScreens = screens
        handlers.forEach { $0() }
    }
}

// MARK: - NotchDetecting Protocol

/// Protocol abstracting notch detection for mock injection.
protocol NotchDetecting {
    func hasNotch(screen: NSScreen) -> Bool
    func detectGeometry(for screen: NSScreen) -> NotchGeometryInfo?
}

// MARK: - MockNotchDetector

final class MockNotchDetector: NotchDetecting {
    var hasNotchResults: [CGDirectDisplayID: Bool] = [:]
    var geometryResults: [CGDirectDisplayID: NotchGeometryInfo] = [:]

    func hasNotch(screen: NSScreen) -> Bool {
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
        return hasNotchResults[displayID] ?? false
    }

    func detectGeometry(for screen: NSScreen) -> NotchGeometryInfo? {
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
        return geometryResults[displayID]
    }
}

// MARK: - MockNotchPanel

/// Lightweight stand-in for NotchPanel that avoids creating real NSWindows.
final class MockNotchPanel {
    var isVisible: Bool = false
    var currentFrame: NSRect
    var windowLevel: Int = 24
    var isOrderedFront: Bool = false

    init(frame: NSRect = .zero) {
        self.currentFrame = frame
    }

    func orderFront() {
        isVisible = true
        isOrderedFront = true
    }

    func orderOut() {
        isVisible = false
        isOrderedFront = false
    }

    func setFrame(_ frame: NSRect) {
        currentFrame = frame
    }

    func close() {
        isVisible = false
        isOrderedFront = false
    }
}

// MARK: - MockViewCoordinator

/// Tracks ViewCoordinator method calls for verification in tests.
final class MockViewCoordinator {
    private(set) var currentViewName: String = "none"
    private(set) var sneakPeekTriggerCount: Int = 0
    private(set) var lastSneakPeekContent: String?
    private(set) var isHUDActive: Bool = false
    private(set) var viewSwitchHistory: [String] = []

    func setCurrentView(_ name: String) {
        currentViewName = name
        viewSwitchHistory.append(name)
    }

    func triggerSneakPeek(content: String) {
        sneakPeekTriggerCount += 1
        lastSneakPeekContent = content
    }

    func setHUDActive(_ active: Bool) {
        isHUDActive = active
    }

    func reset() {
        currentViewName = "none"
        sneakPeekTriggerCount = 0
        lastSneakPeekContent = nil
        isHUDActive = false
        viewSwitchHistory = []
    }
}

// MARK: - NotchInteractionState

/// The four possible interaction states for a notch panel.
/// More granular than the production NotchState, used for state machine testing.
enum NotchInteractionState: Equatable {
    case closed
    case sneakPeek
    case open
    case expandedDetail

    /// Returns whether a transition from self to the target state is valid.
    func canTransition(to target: NotchInteractionState) -> Bool {
        if self == target { return false }
        switch (self, target) {
        case (.closed, .open): return true
        case (.closed, .sneakPeek): return true
        case (.sneakPeek, .closed): return true
        case (.sneakPeek, .open): return true
        case (.open, .closed): return true
        case (.open, .expandedDetail): return true
        case (.expandedDetail, .open): return true
        case (.expandedDetail, .closed): return true
        default: return false
        }
    }
}

// MARK: - DisplayMode

/// Controls which screens show a notch panel.
enum DisplayMode: String {
    case allDisplays
    case activeOnly
    case selectedDisplays
}
