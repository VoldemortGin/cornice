import Foundation

/// App-wide constants.
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
        /// Closed state corner radius (top).
        static let closedTopRadius: CGFloat = 10
        /// Closed state corner radius (bottom).
        static let closedBottomRadius: CGFloat = 14
    }

    /// Virtual notch defaults for non-notch screens.
    enum VirtualNotch {
        static let defaultWidth: CGFloat = 230
        static let defaultHeight: CGFloat = 32
        static let minWidth: CGFloat = 150
        static let maxWidth: CGFloat = 400
        static let minHeight: CGFloat = 24
        static let maxHeight: CGFloat = 48
    }

    /// Default timing values.
    enum Timing {
        static let hoverDelay: TimeInterval = 0.2
        static let collapseDelay: TimeInterval = 0.5
        static let sneakPeekDuration: TimeInterval = 3.0
        static let hudDuration: TimeInterval = 2.0
    }

    /// URLs for external resources.
    enum URLs {
        static let website = URL(string: "https://niya.app")!
        static let support = URL(string: "https://niya.app/support")!
        static let privacy = URL(string: "https://niya.app/privacy")!
    }
}
