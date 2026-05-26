import Foundation

// MARK: - HUD Type

enum HUDType: Equatable, Sendable {
    case volume
    case brightness
    case keyboardBrightness
    case mute
}

// MARK: - HUD State

struct HUDState: Equatable, Sendable {
    var type: HUDType
    var value: Double  // 0.0 - 1.0
    var isMuted: Bool = false
    var isVisible: Bool = false
}

// MARK: - Volume Icon

enum VolumeIcon: Sendable {
    case muted
    case low
    case medium
    case high

    var systemName: String {
        switch self {
        case .muted: return "speaker.slash.fill"
        case .low: return "speaker.wave.1.fill"
        case .medium: return "speaker.wave.2.fill"
        case .high: return "speaker.wave.3.fill"
        }
    }

    static func forLevel(_ level: Double, muted: Bool) -> VolumeIcon {
        if muted || level <= 0 { return .muted }
        if level <= 0.33 { return .low }
        if level <= 0.66 { return .medium }
        return .high
    }
}

// MARK: - Brightness Icon

enum BrightnessIcon: Sendable {
    case dim
    case bright

    var systemName: String {
        switch self {
        case .dim: return "sun.min.fill"
        case .bright: return "sun.max.fill"
        }
    }

    static func forLevel(_ level: Double) -> BrightnessIcon {
        level <= 0.5 ? .dim : .bright
    }
}

// MARK: - HUD Error

enum HUDError: Error, LocalizedError, Sendable {
    case accessibilityPermissionDenied
    case eventTapCreationFailed
    case frameworkLoadFailed(String)
    case symbolNotFound(String)
    case serviceNotFound(String)
    case ioServiceOpenFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to intercept volume and brightness keys."
        case .eventTapCreationFailed:
            return "Failed to create event tap. Ensure Accessibility permission is granted."
        case .frameworkLoadFailed(let name):
            return "Failed to load \(name) framework."
        case .symbolNotFound(let name):
            return "Required symbol not found: \(name)."
        case .serviceNotFound(let name):
            return "IOKit service not found: \(name)."
        case .ioServiceOpenFailed(let kr):
            return "Failed to open IO service (kern_return: \(kr))."
        }
    }
}

// MARK: - HID Key Event

struct HIDKeyEvent: Sendable {
    enum KeyCode: UInt16, Sendable {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case keyboardBrightnessUp = 21
        case keyboardBrightnessDown = 22
    }

    enum Direction: Sendable {
        case up
        case down
    }

    let keyCode: KeyCode
    let isKeyDown: Bool
    let isRepeat: Bool
    let hasOption: Bool
    let hasShift: Bool

    var stepSize: Float {
        (hasOption && hasShift) ? (1.0 / 64.0) : (1.0 / 16.0)
    }

    var isFineAdjustment: Bool {
        hasOption && hasShift
    }

    var shouldOpenSettings: Bool {
        hasOption && !hasShift
    }
}
