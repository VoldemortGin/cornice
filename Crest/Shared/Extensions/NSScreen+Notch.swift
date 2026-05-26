import AppKit

extension NSScreen {
    /// Whether this screen has a camera housing (physical notch).
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// The calculated notch width for this screen.
    /// Returns nil for non-notch screens (use virtual notch width instead).
    var notchWidth: CGFloat? {
        guard hasNotch else { return nil }
        let leftWidth = auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = auxiliaryTopRightArea?.width ?? 0
        let rawWidth = frame.width - leftWidth - rightWidth
        return rawWidth + (2 * NotchDetector.horizontalPadding)
    }

    /// The notch height (safe area inset from top).
    /// Returns 0 for non-notch screens.
    var notchHeight: CGFloat {
        safeAreaInsets.top
    }

    /// The Core Graphics display UUID string for this screen.
    var displayUUID: String {
        NotchDetector.displayUUID(for: screenDisplayID)
    }
}
