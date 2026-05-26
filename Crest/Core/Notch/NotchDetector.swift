import AppKit

// MARK: - ScreenProviding Protocol

/// Abstracts NSScreen for testability.
protocol ScreenProviding: AnyObject {
    var frame: NSRect { get }
    var visibleFrame: NSRect { get }
    var safeAreaTop: CGFloat { get }
    var screenAuxiliaryTopLeftArea: NSRect? { get }
    var screenAuxiliaryTopRightArea: NSRect? { get }
    var screenDisplayID: CGDirectDisplayID { get }
    var screenLocalizedName: String { get }
}

/// Make NSScreen conform to ScreenProviding.
extension NSScreen: ScreenProviding {
    var safeAreaTop: CGFloat {
        safeAreaInsets.top
    }

    var screenAuxiliaryTopLeftArea: NSRect? {
        auxiliaryTopLeftArea
    }

    var screenAuxiliaryTopRightArea: NSRect? {
        auxiliaryTopRightArea
    }

    var screenDisplayID: CGDirectDisplayID {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    var screenLocalizedName: String {
        localizedName
    }
}

// MARK: - NotchDetector

/// Detects whether screens have a physical notch and computes notch geometry.
final class NotchDetector {

    /// Horizontal padding added to each side of the calculated notch width.
    /// This ensures the overlay slightly exceeds the physical notch boundary.
    static let horizontalPadding: CGFloat = 4.0

    /// Returns true if the given screen has a camera housing (notch).
    static func hasNotch(screen: ScreenProviding) -> Bool {
        return screen.safeAreaTop > 0
    }

    /// Calculates the notch width for a screen with a physical notch.
    /// Uses auxiliary top areas to determine the gap.
    static func notchWidth(for screen: ScreenProviding) -> CGFloat {
        guard hasNotch(screen: screen) else {
            return AnimationConstants.Sizes.virtualNotchWidth
        }

        let screenWidth = screen.frame.width
        let leftWidth = screen.screenAuxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.screenAuxiliaryTopRightArea?.width ?? 0

        let rawNotchWidth = screenWidth - leftWidth - rightWidth
        return rawNotchWidth + (2 * horizontalPadding)
    }

    /// Calculates the notch height based on the height mode.
    static func notchHeight(for screen: ScreenProviding, mode: NotchHeightMode) -> CGFloat {
        let descriptor = screenDescriptor(from: screen)
        return mode.height(for: descriptor)
    }

    /// Computes full geometry info for a given screen.
    static func geometryInfo(
        for screen: ScreenProviding,
        heightMode: NotchHeightMode = .matchMenuBar
    ) -> NotchGeometryInfo {
        let hasPhysical = hasNotch(screen: screen)
        let width = notchWidth(for: screen)
        let height = notchHeight(for: screen, mode: heightMode)

        let notchRect = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )

        let closedSize = CGSize(width: width, height: height)

        let openWidth = min(AnimationConstants.Sizes.openWidth, screen.frame.width * 0.6)
        let openHeight = AnimationConstants.Sizes.openHeight
        let openSize = CGSize(width: openWidth, height: openHeight)

        let sneakPeekWidth = min(AnimationConstants.Sizes.sneakPeekWidth, screen.frame.width * 0.4)
        let sneakPeekHeight = AnimationConstants.Sizes.sneakPeekHeight
        let sneakPeekSize = CGSize(width: sneakPeekWidth, height: sneakPeekHeight)

        let expandedWidth = min(AnimationConstants.Sizes.expandedDetailWidth, screen.frame.width * 0.6)
        let expandedHeight = min(AnimationConstants.Sizes.expandedDetailHeight, screen.frame.height * 0.5)
        let expandedDetailSize = CGSize(width: expandedWidth, height: expandedHeight)

        return NotchGeometryInfo(
            hasPhysicalNotch: hasPhysical,
            notchRect: notchRect,
            closedSize: closedSize,
            openSize: openSize,
            sneakPeekSize: sneakPeekSize,
            expandedDetailSize: expandedDetailSize,
            screenFrame: screen.frame
        )
    }

    /// Creates a ScreenDescriptor from a ScreenProviding instance.
    static func screenDescriptor(from screen: ScreenProviding) -> ScreenDescriptor {
        ScreenDescriptor(
            frame: screen.frame,
            safeAreaTop: screen.safeAreaTop,
            auxiliaryTopLeftArea: screen.screenAuxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.screenAuxiliaryTopRightArea,
            displayID: screen.screenDisplayID,
            localizedName: screen.screenLocalizedName
        )
    }

    /// Returns all connected screens that have a physical notch.
    static func screensWithNotch() -> [NSScreen] {
        NSScreen.screens.filter { hasNotch(screen: $0) }
    }

    /// Returns the display UUID string for a given display ID.
    static func displayUUID(for displayID: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return "\(displayID)"
        }
        let cfUUID = uuid.takeRetainedValue()
        return CFUUIDCreateString(nil, cfUUID) as String
    }
}
