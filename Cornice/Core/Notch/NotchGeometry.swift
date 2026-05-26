import AppKit

/// Calculates notch dimensions and positioning for a given screen.
/// This is the primary API for computing notch geometry from a live NSScreen.
struct NotchGeometry {
    let screen: NSScreen
    let heightMode: NotchHeightMode

    init(screen: NSScreen, heightMode: NotchHeightMode = .matchMenuBar) {
        self.screen = screen
        self.heightMode = heightMode
    }

    // MARK: - Physical Notch Detection

    /// Whether this screen has a physical notch.
    var hasPhysicalNotch: Bool {
        NotchDetector.hasNotch(screen: screen)
    }

    // MARK: - Closed State (matches physical notch)

    /// Width of the notch in the closed state.
    var closedWidth: CGFloat {
        NotchDetector.notchWidth(for: screen)
    }

    /// Height of the notch in the closed state.
    var closedHeight: CGFloat {
        NotchDetector.notchHeight(for: screen, mode: heightMode)
    }

    /// Size in the closed state.
    var closedSize: CGSize {
        CGSize(width: closedWidth, height: closedHeight)
    }

    // MARK: - Open State

    /// Width of the notch in the open state (default 640, capped at 60% screen width).
    var openWidth: CGFloat {
        min(AnimationConstants.Sizes.openWidth, screen.frame.width * 0.6)
    }

    /// Height of the notch in the open state.
    var openHeight: CGFloat {
        AnimationConstants.Sizes.openHeight
    }

    /// Size in the open state.
    var openSize: CGSize {
        CGSize(width: openWidth, height: openHeight)
    }

    // MARK: - Sneak Peek State

    /// Width of the notch in the sneak peek state.
    var sneakPeekWidth: CGFloat {
        min(AnimationConstants.Sizes.sneakPeekWidth, screen.frame.width * 0.4)
    }

    /// Height of the notch in the sneak peek state.
    var sneakPeekHeight: CGFloat {
        AnimationConstants.Sizes.sneakPeekHeight
    }

    /// Size in the sneak peek state.
    var sneakPeekSize: CGSize {
        CGSize(width: sneakPeekWidth, height: sneakPeekHeight)
    }

    // MARK: - Expanded Detail State

    /// Width of the notch in the expanded detail state (capped at 60% screen width).
    var expandedDetailWidth: CGFloat {
        min(AnimationConstants.Sizes.expandedDetailWidth, screen.frame.width * 0.6)
    }

    /// Height of the notch in the expanded detail state (capped at 50% screen height).
    var expandedDetailHeight: CGFloat {
        min(AnimationConstants.Sizes.expandedDetailHeight, screen.frame.height * 0.5)
    }

    /// Size in the expanded detail state.
    var expandedDetailSize: CGSize {
        CGSize(width: expandedDetailWidth, height: expandedDetailHeight)
    }

    // MARK: - Virtual Notch (non-notch screens)

    /// Default dimensions for the virtual notch on non-notch screens.
    var virtualNotchSize: CGSize {
        CGSize(
            width: AnimationConstants.Sizes.virtualNotchWidth,
            height: AnimationConstants.Sizes.virtualNotchHeight
        )
    }

    // MARK: - Frame Calculations

    /// The frame of the notch overlay in screen coordinates (AppKit bottom-left origin).
    var notchFrame: NSRect {
        let screenFrame = screen.frame
        let width = closedWidth
        let height = closedHeight
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Returns the panel frame for a given state.
    func frame(for state: NotchState) -> NSRect {
        let size = size(for: state)
        let screenFrame = screen.frame
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.maxY - size.height
        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// Returns the notch size for a given state.
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

    /// Generates the full NotchGeometryInfo for this screen.
    func geometryInfo() -> NotchGeometryInfo {
        NotchGeometryInfo(
            hasPhysicalNotch: hasPhysicalNotch,
            notchRect: notchFrame,
            closedSize: closedSize,
            openSize: openSize,
            sneakPeekSize: sneakPeekSize,
            expandedDetailSize: expandedDetailSize,
            screenFrame: screen.frame
        )
    }
}
