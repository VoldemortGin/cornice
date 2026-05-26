import Foundation

/// App-wide constants.
/// Animation values (springs, corner radii) live in AnimationConstants.
/// Geometry values (notch sizes, virtual notch) live here.
enum AppConstants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.cornice.app"
    static let appName = "Cornice"

    /// App version string.
    static let version: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }()

    /// Build number string.
    static let buildNumber: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }()

    /// Default notch dimensions for reference.
    enum NotchDefaults {
        /// Physical notch width on MacBook Pro 14"/16" (approximately).
        static let physicalWidth: CGFloat = 200
        /// Physical notch height (menu bar safe area).
        static let physicalHeight: CGFloat = 38
    }

    /// Virtual notch defaults for non-notch screens.
    enum VirtualNotch {
        static let minWidth: CGFloat = 150
        static let maxWidth: CGFloat = 400
        static let minHeight: CGFloat = 24
        static let maxHeight: CGFloat = 48
    }

    /// URLs for external resources.
    enum URLs {
        static let website = URL(string: "https://niya.app")!
        static let support = URL(string: "https://niya.app/support")!
        static let privacy = URL(string: "https://niya.app/privacy")!
    }
}
