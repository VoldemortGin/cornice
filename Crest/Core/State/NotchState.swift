import Foundation

/// Events that can trigger a sneak peek display.
enum SneakPeekEvent: Equatable, Sendable {
    case trackChange(title: String, artist: String)
    case volume(level: Double)
    case brightness(level: Double)
    case battery(percentage: Int, isCharging: Bool)
    case calendarEvent(title: String, minutesUntil: Int)
    case timerCompleted(label: String)
}

/// Represents the current display state of the notch overlay.
enum NotchState: Equatable, Sendable {
    /// Notch is at its natural resting size, matching the physical notch.
    case closed

    /// Notch is slightly enlarged showing a brief notification. Auto-dismisses.
    case sneakPeek(SneakPeekEvent)

    /// Notch is fully expanded showing the active tab's content.
    case open

    /// Notch is at its largest, showing detailed widget content (lyrics, full shelf, etc.).
    case expandedDetail

    /// Returns whether a transition to the given target state is valid.
    func canTransition(to target: NotchState) -> Bool {
        switch (self, target) {
        case (.closed, .open),
             (.closed, .sneakPeek):
            return true

        case (.sneakPeek, .closed),
             (.sneakPeek, .open):
            return true

        case (.open, .closed),
             (.open, .expandedDetail):
            return true

        case (.expandedDetail, .open),
             (.expandedDetail, .closed):
            return true

        default:
            // Same state to same state is invalid (no-op).
            // closed -> expandedDetail is invalid (must go through open).
            // sneakPeek -> expandedDetail is invalid (must go through open).
            return false
        }
    }
}

// MARK: - Simplified equality for state category checks

extension NotchState {
    var isClosed: Bool {
        if case .closed = self { return true }
        return false
    }

    var isSneakPeek: Bool {
        if case .sneakPeek = self { return true }
        return false
    }

    var isOpen: Bool {
        if case .open = self { return true }
        return false
    }

    var isExpandedDetail: Bool {
        if case .expandedDetail = self { return true }
        return false
    }

    /// Whether the notch is in any expanded state (open or expandedDetail).
    var isExpanded: Bool {
        isOpen || isExpandedDetail
    }
}
