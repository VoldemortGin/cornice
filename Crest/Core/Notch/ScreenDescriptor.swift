import AppKit

/// A value type capturing the relevant geometry of a screen,
/// suitable for testing without requiring a live NSScreen.
struct ScreenDescriptor: Equatable, Sendable {
    var frame: NSRect
    var safeAreaTop: CGFloat
    var auxiliaryTopLeftArea: NSRect?
    var auxiliaryTopRightArea: NSRect?
    var displayID: CGDirectDisplayID
    var localizedName: String

    /// Whether this screen has a physical notch.
    var hasNotch: Bool {
        safeAreaTop > 0
    }

    /// Calculated notch width from auxiliary areas.
    var notchWidth: CGFloat {
        guard hasNotch else {
            return AnimationConstants.Sizes.virtualNotchWidth
        }
        let leftWidth = auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = auxiliaryTopRightArea?.width ?? 0
        let rawWidth = frame.width - leftWidth - rightWidth
        return rawWidth + (2 * NotchDetector.horizontalPadding)
    }

    init(
        frame: NSRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftArea: NSRect? = nil,
        auxiliaryTopRightArea: NSRect? = nil,
        displayID: CGDirectDisplayID,
        localizedName: String = ""
    ) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
        self.displayID = displayID
        self.localizedName = localizedName
    }
}

// MARK: - Factory from NSScreen

extension ScreenDescriptor {
    /// Creates a ScreenDescriptor from a live NSScreen.
    init(screen: NSScreen) {
        self.frame = screen.frame
        self.safeAreaTop = screen.safeAreaInsets.top
        self.auxiliaryTopLeftArea = screen.auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = screen.auxiliaryTopRightArea
        self.displayID = screen.screenDisplayID
        self.localizedName = screen.localizedName
    }
}

// MARK: - Known Mac Model Presets

extension ScreenDescriptor {
    /// MacBook Pro 14" (2021+): 3024x1964 native, 1512x982 logical.
    /// Notch width: 1512 - 656 - 656 = 200pt raw + 8pt padding = 208pt.
    static let macBookPro14 = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTop: 38,
        auxiliaryTopLeftArea: NSRect(x: 0, y: 944, width: 656, height: 38),
        auxiliaryTopRightArea: NSRect(x: 856, y: 944, width: 656, height: 38),
        displayID: 1,
        localizedName: "MacBook Pro 14\""
    )

    /// MacBook Pro 16" (2021+): 3456x2234 native, 1728x1117 logical.
    /// Notch width: 1728 - 764 - 764 = 200pt raw + 8pt padding = 208pt.
    static let macBookPro16 = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 1728, height: 1117),
        safeAreaTop: 38,
        auxiliaryTopLeftArea: NSRect(x: 0, y: 1079, width: 764, height: 38),
        auxiliaryTopRightArea: NSRect(x: 964, y: 1079, width: 764, height: 38),
        displayID: 2,
        localizedName: "MacBook Pro 16\""
    )

    /// MacBook Air 13" (M2, 2022+): 2560x1664 native, 1470x956 logical.
    /// Notch width: 1470 - 645 - 645 = 180pt raw + 8pt padding = 188pt.
    static let macBookAir13 = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 1470, height: 956),
        safeAreaTop: 38,
        auxiliaryTopLeftArea: NSRect(x: 0, y: 918, width: 645, height: 38),
        auxiliaryTopRightArea: NSRect(x: 825, y: 918, width: 645, height: 38),
        displayID: 3,
        localizedName: "MacBook Air 13\""
    )

    /// MacBook Air 15" (M2, 2023+): 2880x1864 native, 1710x1107 logical.
    /// Notch width: 1710 - 755 - 755 = 200pt raw + 8pt padding = 208pt.
    static let macBookAir15 = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 1710, height: 1107),
        safeAreaTop: 38,
        auxiliaryTopLeftArea: NSRect(x: 0, y: 1069, width: 755, height: 38),
        auxiliaryTopRightArea: NSRect(x: 955, y: 1069, width: 755, height: 38),
        displayID: 4,
        localizedName: "MacBook Air 15\""
    )

    /// MacBook Pro 14" M3 (2023+): Same logical resolution as M1/M2 14".
    static let macBookPro14M3 = macBookPro14

    /// MacBook Pro 16" M3 (2023+): Same logical resolution as M1/M2 16".
    static let macBookPro16M3 = macBookPro16

    /// External 4K display (no notch).
    static let external4K = ScreenDescriptor(
        frame: NSRect(x: 1512, y: 0, width: 3840, height: 2160),
        safeAreaTop: 0,
        displayID: 10,
        localizedName: "External 4K"
    )

    /// External 1080p display (no notch, offset position).
    static let external1080p = ScreenDescriptor(
        frame: NSRect(x: -1920, y: 0, width: 1920, height: 1080),
        safeAreaTop: 0,
        displayID: 11,
        localizedName: "External 1080p"
    )

    /// Pre-2021 MacBook (no notch).
    static let legacyMacBook = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        safeAreaTop: 0,
        displayID: 20,
        localizedName: "Legacy MacBook"
    )

    /// Apple Studio Display (no notch, 5K).
    static let studioDisplay = ScreenDescriptor(
        frame: NSRect(x: 0, y: 0, width: 2560, height: 1440),
        safeAreaTop: 0,
        displayID: 30,
        localizedName: "Apple Studio Display"
    )
}
