import Defaults

// MARK: - Settings-only enums (no conflict with existing types)

enum NotchHeightSetting: String, Codable, Defaults.Serializable {
    case matchNotch, matchMenuBar, custom
}

enum MusicSourceSetting: String, Codable, Defaults.Serializable {
    case nowPlaying, appleMusic, spotify
}

enum ThemeSetting: String, Codable, Defaults.Serializable {
    case system, dark
}

// MARK: - Defaults.Serializable conformance for existing types

extension ActivationMethod: Defaults.Serializable {}

// MARK: - Defaults Keys

extension Defaults.Keys {
    // MARK: General

    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let activationMethod = Key<ActivationMethod>("activationMethod", default: .hover)
    static let hoverDelay = Key<Double>("hoverDelay", default: 0.2)
    static let closeDelay = Key<Double>("closeDelay", default: 0.5)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)

    // MARK: Appearance

    static let notchHeightMode = Key<NotchHeightSetting>("notchHeightMode", default: .matchNotch)
    static let customNotchHeight = Key<Double>("customNotchHeight", default: 32)
    static let theme = Key<ThemeSetting>("theme", default: .system)

    // MARK: Media

    static let musicSource = Key<MusicSourceSetting>("musicSource", default: .nowPlaying)
    static let showVisualizer = Key<Bool>("showVisualizer", default: true)
    static let sneakPeekOnTrackChange = Key<Bool>("sneakPeekOnTrackChange", default: true)
    static let sneakPeekDuration = Key<Double>("sneakPeekDuration", default: 3.0)

    // MARK: HUD

    static let hudReplacementEnabled = Key<Bool>("hudReplacementEnabled", default: false)
    static let replaceVolumeHUD = Key<Bool>("replaceVolumeHUD", default: true)
    static let replaceBrightnessHUD = Key<Bool>("replaceBrightnessHUD", default: true)
    static let replaceKeyboardHUD = Key<Bool>("replaceKeyboardHUD", default: true)
    static let hudDuration = Key<Double>("hudDuration", default: 1.5)
    static let hudShowPercentage = Key<Bool>("hudShowPercentage", default: true)

    // MARK: Calendar

    static let showCalendar = Key<Bool>("showCalendar", default: true)
    static let calendarLookahead = Key<Int>("calendarLookahead", default: 24)
    static let showAllDayEvents = Key<Bool>("showAllDayEvents", default: true)
    static let showDeclinedEvents = Key<Bool>("showDeclinedEvents", default: false)

    // MARK: Shelf

    static let shelfEnabled = Key<Bool>("shelfEnabled", default: true)
    static let shelfMaxItems = Key<Int>("shelfMaxItems", default: 20)

    // MARK: Clipboard

    static let clipboardEnabled = Key<Bool>("clipboardEnabled", default: true)
    static let clipboardMaxEntries = Key<Int>("clipboardMaxEntries", default: 50)

    // MARK: Mirror

    static let mirrorEnabled = Key<Bool>("mirrorEnabled", default: false)
    static let mirrorFlipped = Key<Bool>("mirrorFlipped", default: true)

    // MARK: Quick Apps

    static let quickAppsEnabled = Key<Bool>("quickAppsEnabled", default: true)

    // MARK: Shortcuts

    static let shortcutsEnabled = Key<Bool>("shortcutsEnabled", default: true)

    // MARK: Advanced

    static let debugMode = Key<Bool>("debugMode", default: false)
}
