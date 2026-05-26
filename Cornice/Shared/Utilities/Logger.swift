import os

/// Centralized logging for Niya using Apple's unified logging system.
/// Each category maps to a distinct subsystem area for filtering in Console.app.
enum Log {
    private static let subsystem = "com.cornice.app"

    /// General app lifecycle events.
    static let general = Logger(subsystem: subsystem, category: "general")

    /// UI-related events (panel creation, animations, state changes).
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Media player events (now playing, playback state).
    static let media = Logger(subsystem: subsystem, category: "media")

    /// Permission checks and requests.
    static let permissions = Logger(subsystem: subsystem, category: "permissions")

    /// Window management events (panel positioning, screen detection).
    static let window = Logger(subsystem: subsystem, category: "window")

    /// HUD replacement events (volume, brightness interception).
    static let hud = Logger(subsystem: subsystem, category: "hud")

    /// File shelf operations.
    static let shelf = Logger(subsystem: subsystem, category: "shelf")

    /// System monitor data collection.
    static let monitor = Logger(subsystem: subsystem, category: "monitor")

    /// Calendar events.
    static let calendar = Logger(subsystem: subsystem, category: "calendar")

    /// Clipboard history operations.
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")

    /// Settings and configuration changes.
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// System monitor (kept for backward compatibility with existing code).
    static let systemMonitor = Logger(subsystem: subsystem, category: "systemMonitor")
}
