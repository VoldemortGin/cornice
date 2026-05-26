import AppKit

/// Determines how the notch overlay height is calculated.
enum NotchHeightMode: Equatable, Sendable {
    /// Match the physical notch height (safeAreaInsets.top).
    case matchNotch

    /// Match the menu bar thickness.
    case matchMenuBar

    /// User-specified height, clamped to [24, 48].
    case custom(CGFloat)

    /// Calculate the effective height for a given screen descriptor.
    func height(for screen: ScreenDescriptor) -> CGFloat {
        switch self {
        case .matchNotch:
            if screen.safeAreaTop > 0 {
                return screen.safeAreaTop
            }
            // Fallback for non-notch screens: use menu bar height.
            return NSStatusBar.system.thickness

        case .matchMenuBar:
            return NSStatusBar.system.thickness

        case .custom(let value):
            return max(24, min(48, value))
        }
    }

    /// Calculate the effective height directly from a ScreenProviding source.
    func height(for screen: ScreenProviding) -> CGFloat {
        switch self {
        case .matchNotch:
            if screen.safeAreaTop > 0 {
                return screen.safeAreaTop
            }
            return NSStatusBar.system.thickness

        case .matchMenuBar:
            return NSStatusBar.system.thickness

        case .custom(let value):
            return max(24, min(48, value))
        }
    }
}

// MARK: - Codable

extension NotchHeightMode: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ModeType: String, Codable {
        case matchNotch
        case matchMenuBar
        case custom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ModeType.self, forKey: .type)
        switch type {
        case .matchNotch:
            self = .matchNotch
        case .matchMenuBar:
            self = .matchMenuBar
        case .custom:
            let value = try container.decode(CGFloat.self, forKey: .value)
            self = .custom(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .matchNotch:
            try container.encode(ModeType.matchNotch, forKey: .type)
        case .matchMenuBar:
            try container.encode(ModeType.matchMenuBar, forKey: .type)
        case .custom(let value):
            try container.encode(ModeType.custom, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
