import AppKit

/// Test-side type definitions used across all test files.
/// These model the contracts expected of the production types once implemented.
/// When the production Niya target defines these types, these definitions
/// should be removed and tests should import from the main module instead.

// MARK: - ScreenDescriptor

/// Describes mock screen properties for building test scenarios.
/// Values mirror real hardware measurements from Apple's laptop lineup.
struct ScreenDescriptor {
    var frame: NSRect
    var visibleFrame: NSRect
    var safeAreaTop: CGFloat
    var auxiliaryTopLeftArea: NSRect?
    var auxiliaryTopRightArea: NSRect?
    var displayID: CGDirectDisplayID
    var localizedName: String
    var isBuiltIn: Bool
    var backingScaleFactor: CGFloat

    init(
        frame: NSRect = NSRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: NSRect = NSRect(x: 0, y: 0, width: 1512, height: 945),
        safeAreaTop: CGFloat = 0,
        auxiliaryTopLeftArea: NSRect? = nil,
        auxiliaryTopRightArea: NSRect? = nil,
        displayID: CGDirectDisplayID = 1,
        localizedName: String = "Mock Display",
        isBuiltIn: Bool = false,
        backingScaleFactor: CGFloat = 2.0
    ) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
        self.displayID = displayID
        self.localizedName = localizedName
        self.isBuiltIn = isBuiltIn
        self.backingScaleFactor = backingScaleFactor
    }

    /// MacBook Pro 14-inch (2021+) with notch
    static var macBookPro14: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 945),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 944, width: 656, height: 38),
            auxiliaryTopRightArea: NSRect(x: 856, y: 944, width: 656, height: 38),
            displayID: 1,
            localizedName: "Built-in Retina Display",
            isBuiltIn: true,
            backingScaleFactor: 2.0
        )
    }

    /// MacBook Pro 16-inch (2021+) with notch
    static var macBookPro16: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1728, height: 1117),
            visibleFrame: NSRect(x: 0, y: 0, width: 1728, height: 1079),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 1079, width: 764, height: 38),
            auxiliaryTopRightArea: NSRect(x: 964, y: 1079, width: 764, height: 38),
            displayID: 2,
            localizedName: "Built-in Retina Display",
            isBuiltIn: true,
            backingScaleFactor: 2.0
        )
    }

    /// MacBook Air 13-inch M2 with notch
    static var macBookAir13: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: NSRect(x: 0, y: 0, width: 1470, height: 918),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 918, width: 645, height: 38),
            auxiliaryTopRightArea: NSRect(x: 825, y: 918, width: 645, height: 38),
            displayID: 3,
            localizedName: "Built-in Retina Display",
            isBuiltIn: true,
            backingScaleFactor: 2.0
        )
    }

    /// MacBook Air 15-inch (2023+) with notch
    static var macBookAir15: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1710, height: 1107),
            visibleFrame: NSRect(x: 0, y: 0, width: 1710, height: 1069),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 1069, width: 755, height: 38),
            auxiliaryTopRightArea: NSRect(x: 955, y: 1069, width: 755, height: 38),
            displayID: 4,
            localizedName: "Built-in Retina Display",
            isBuiltIn: true,
            backingScaleFactor: 2.0
        )
    }

    /// External 4K display, no notch
    static var external4K: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 1512, y: 0, width: 3840, height: 2160),
            visibleFrame: NSRect(x: 1512, y: 0, width: 3840, height: 2135),
            safeAreaTop: 0,
            displayID: 10,
            localizedName: "LG UltraFine 4K",
            isBuiltIn: false,
            backingScaleFactor: 2.0
        )
    }

    /// External 1080p display, no notch
    static var external1080p: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: -1920, y: 0, width: 1920, height: 1055),
            safeAreaTop: 0,
            displayID: 11,
            localizedName: "Dell U2723QE",
            isBuiltIn: false,
            backingScaleFactor: 1.0
        )
    }

    /// Pre-2021 MacBook Pro (no notch, no safe area insets)
    static var legacyMacBook: ScreenDescriptor {
        ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 875),
            safeAreaTop: 0,
            displayID: 20,
            localizedName: "Built-in Retina Display",
            isBuiltIn: true,
            backingScaleFactor: 2.0
        )
    }
}

// MARK: - NotchGeometryInfo

/// Describes the detected notch geometry for a screen.
struct NotchGeometryInfo: Equatable {
    let width: CGFloat
    let height: CGFloat
    let origin: CGPoint
    let screenDisplayID: CGDirectDisplayID
    let isVirtual: Bool

    init(
        width: CGFloat,
        height: CGFloat,
        origin: CGPoint,
        screenDisplayID: CGDirectDisplayID,
        isVirtual: Bool = false
    ) {
        self.width = width
        self.height = height
        self.origin = origin
        self.screenDisplayID = screenDisplayID
        self.isVirtual = isVirtual
    }
}

// MARK: - NotchHeightMode

/// Notch height calculation mode, matching PRD-01 Section 1.2.
enum NotchHeightMode: Equatable {
    case matchNotch
    case matchMenuBar
    case custom(CGFloat)

    func height(for descriptor: ScreenDescriptor) -> CGFloat {
        switch self {
        case .matchNotch:
            return descriptor.safeAreaTop
        case .matchMenuBar:
            return 24 // typical menu bar thickness
        case .custom(let value):
            return max(24, min(48, value))
        }
    }
}
