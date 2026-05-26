import AppKit

/// Describes the computed geometry of a notch (physical or virtual) for a given screen.
struct NotchGeometryInfo: Equatable, Sendable {
    /// Whether this screen has a physical camera housing notch.
    var hasPhysicalNotch: Bool

    /// The rect of the notch area in screen coordinates (AppKit bottom-left origin).
    var notchRect: NSRect

    /// Size of the notch overlay in the closed state.
    var closedSize: CGSize

    /// Size of the notch overlay in the open state.
    var openSize: CGSize

    /// Size of the notch overlay in the sneak peek state.
    var sneakPeekSize: CGSize

    /// Size of the notch overlay in the expanded detail state.
    var expandedDetailSize: CGSize

    /// The full frame of the associated screen.
    var screenFrame: NSRect

    init(
        hasPhysicalNotch: Bool,
        notchRect: NSRect,
        closedSize: CGSize,
        openSize: CGSize,
        sneakPeekSize: CGSize,
        expandedDetailSize: CGSize,
        screenFrame: NSRect
    ) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.notchRect = notchRect
        self.closedSize = closedSize
        self.openSize = openSize
        self.sneakPeekSize = sneakPeekSize
        self.expandedDetailSize = expandedDetailSize
        self.screenFrame = screenFrame
    }

    /// Returns the appropriate size for a given notch state.
    func size(for state: NotchState) -> CGSize {
        switch state {
        case .closed:
            return closedSize
        case .sneakPeek:
            return sneakPeekSize
        case .open:
            return openSize
        case .expandedDetail:
            return expandedDetailSize
        }
    }

    /// Returns the panel frame (in screen coordinates) for a given notch state.
    /// The panel is horizontally centered and pinned to the top of the screen.
    func panelFrame(for state: NotchState) -> NSRect {
        let size = size(for: state)
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.maxY - size.height
        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// The activation rect for hover detection (closed state + tolerance).
    var activationRect: NSRect {
        let tolerance = AnimationConstants.hoverTolerance
        return notchRect.insetBy(dx: -tolerance, dy: -tolerance)
    }

    /// The expanded area rect with margin for collapse detection.
    func expandedRect(for state: NotchState) -> NSRect {
        let frame = panelFrame(for: state)
        let margin = AnimationConstants.expandedAreaMargin
        return frame.insetBy(dx: -margin, dy: -margin)
    }
}
