# PRD-10: Settings System

## 1. Overview

Niya's settings system is the central configuration hub for every feature. It uses the `Defaults` library (sindresorhus) for type-safe, observable UserDefaults storage and provides a standard macOS preferences window with sidebar navigation across all feature categories.

**Dependencies:** Defaults (sindresorhus), LaunchAtLogin (sindresorhus), KeyboardShortcuts (sindresorhus), Sparkle (sparkle-project)

---

## 2. Storage Architecture

### 2.1 Primary Storage: Defaults Library

All persistent settings use `Defaults.Key<T>` with explicit default values. Custom types conform to `Defaults.Serializable` (which requires `Codable`).

```swift
import Defaults

extension Defaults.Keys {
    // Keys defined per section — see Section 5
}
```

#### Why Defaults over @AppStorage

| Aspect | Defaults | @AppStorage |
|---|---|---|
| Type safety | Full generic type safety with custom types | Limited to property-list types |
| Custom types | `Defaults.Serializable` (Codable) | Manual RawRepresentable |
| Observation | `@Default` property wrapper, Combine publisher | SwiftUI-only |
| Programmatic access | `Defaults[.key]` anywhere | Requires SwiftUI view context |
| Migration | Built-in migration support | None |

`@AppStorage` is acceptable for trivially simple settings that are only read in a single SwiftUI view, but Defaults is the standard for all new settings.

### 2.2 Property Wrapper Usage

```swift
// In SwiftUI views
struct SomeView: View {
    @Default(.hoverDelay) var hoverDelay
    @Default(.accentColor) var accentColor

    var body: some View {
        Slider(value: $hoverDelay, in: 0.1...0.5)
    }
}

// In non-SwiftUI code
func checkSetting() {
    if Defaults[.hudReplacementEnabled] {
        // ...
    }
}

// Observation
let cancellable = Defaults.publisher(.hoverDelay)
    .sink { change in
        print("Hover delay changed from \(change.oldValue) to \(change.newValue)")
    }
```

### 2.3 Settings File Location

- UserDefaults domain: `com.niya.app` (standard app domain).
- File: `~/Library/Preferences/com.niya.app.plist`.
- Export/import uses JSON serialization of all `Defaults.Keys` for portability.

---

## 3. Settings Window

### 3.1 Window Management

```swift
class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Niya Settings"
        window.center()
        window.setFrameAutosaveName("NiyaSettings")
        window.contentView = NSHostingView(rootView: SettingsRootView())
        window.minSize = NSSize(width: 600, height: 400)
        self.init(window: window)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- Single shared instance; calling `show()` multiple times brings the existing window forward.
- Window frame auto-saved between sessions.
- Minimum size: 600x400.
- Resizable with content adapting to width.

### 3.2 Layout: NavigationSplitView

```swift
struct SettingsRootView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
            selectedTab.view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
    }
}
```

### 3.3 Tab Enum

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case media
    case calendar
    case huds
    case battery
    case shelf
    case clipboard
    case shortcuts
    case quickApps
    case mirror
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .media: "Media"
        case .calendar: "Calendar"
        case .huds: "HUDs"
        case .battery: "Battery"
        case .shelf: "File Shelf"
        case .clipboard: "Clipboard"
        case .shortcuts: "Shortcuts"
        case .quickApps: "Quick Apps"
        case .mirror: "Mirror"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .media: "music.note"
        case .calendar: "calendar"
        case .huds: "speaker.wave.2"
        case .battery: "battery.75percent"
        case .shelf: "tray.and.arrow.down"
        case .clipboard: "doc.on.clipboard"
        case .shortcuts: "bolt.fill"
        case .quickApps: "square.grid.2x2"
        case .mirror: "camera"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .general: GeneralSettingsView()
        case .appearance: AppearanceSettingsView()
        case .media: MediaSettingsView()
        case .calendar: CalendarSettingsView()
        case .huds: HUDsSettingsView()
        case .battery: BatterySettingsView()
        case .shelf: ShelfSettingsView()
        case .clipboard: ClipboardSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .quickApps: QuickAppsSettingsView()
        case .mirror: MirrorSettingsView()
        case .advanced: AdvancedSettingsView()
        case .about: AboutSettingsView()
        }
    }
}
```

---

## 4. Tab Specifications

### 4.1 General Tab

Controls core app behavior: launch, activation, display targeting, and updates.

#### UI Layout

```
[ ] Launch at login
[ ] Show menu bar icon

Activation method:  [Hover ▼]
Hover delay:        [====|====] 200ms
Close delay:        [====|====] 500ms

Keyboard shortcut:  [Record Shortcut]

Show on:            (○) All displays
                    (○) Primary display only
                    (○) Specific display [Select ▼]
[ ] Auto-switch to active display

─── Updates ───
[ ] Automatically check for updates
[Check Now]       Last checked: 2 hours ago
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Launch at login | Toggle | on/off | off |
| Menu bar icon | Toggle | on/off | on |
| Activation method | Picker | hover, click | hover |
| Hover delay | Slider + label | 100ms - 500ms, step 50ms | 200ms |
| Close delay | Slider + label | 200ms - 1000ms, step 50ms | 500ms |
| Keyboard shortcut | KeyboardShortcuts.Recorder | any key combo | none |
| Show on displays | Radio group | all / primary / specific | all |
| Specific display | Picker | list of connected displays | — |
| Auto-switch display | Toggle | on/off | true |
| Auto-check updates | Toggle | on/off | true |

#### Libraries

- **LaunchAtLogin:** `LaunchAtLogin.Toggle()` SwiftUI view — handles the login item registration.
- **KeyboardShortcuts:** `KeyboardShortcuts.Recorder(for: .toggleNotch)` — records and persists the shortcut.
- **Sparkle:** `SUUpdater.shared().checkForUpdates()` on button press; `SUUpdater.shared().automaticallyChecksForUpdates` bound to the toggle.

### 4.2 Appearance Tab

Controls the visual presentation of the notch overlay.

#### UI Layout

```
Notch height mode:   [Match real notch ▼]
Custom height:       [====|====] 32px     (visible when mode = custom)

Non-notch display:
  Width:             [====|====] 200px
  Height:            [====|====] 32px

Theme:               [Follow system ▼]
Accent color:        [System ▼]  [●]     (color well when custom)
Transparency:        [====|====] 80%
Animation speed:     [====|====] 1.0x
Corner radius:       [====|====] 10px

[Preview]  (live preview of the notch appearance)
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Notch height mode | Picker | matchNotch, matchMenuBar, custom | matchNotch |
| Custom height | Slider + label | 20 - 60 px, step 1 | 32 |
| Non-notch width | Slider + label | 150 - 400 px, step 10 | 200 |
| Non-notch height | Slider + label | 20 - 60 px, step 1 | 32 |
| Theme | Picker | followSystem, alwaysDark | followSystem |
| Accent color | Picker + ColorWell | system, custom | system |
| Custom accent color | NSColorWell / ColorPicker | any color | — |
| Transparency | Slider + label | 50% - 100%, step 5% | 80% |
| Animation speed | Slider + label | 0.5x - 2.0x, step 0.1 | 1.0 |
| Corner radius | Slider + label | 0 - 30 px, step 1 | 10 |

#### Live Preview

- A miniature notch preview rendered below the controls.
- Updates in real-time as the user adjusts sliders.
- Shows the notch in both compact and expanded states (toggle button).

### 4.3 Media Tab

Controls the Now Playing / music controller widget.

#### UI Layout

```
Music source:         [Auto-detect ▼]

[ ] Show album art
[ ] Show music visualizer
  Visualizer style:   [Waveform ▼]        (visible when visualizer on)
  Custom Lottie URL:  [________________]  (visible when style = custom)

[ ] Sneak peek on track change
  Duration:           [====|====] 3s      (visible when sneak peek on)

[ ] Show lyrics
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Music source | Picker | auto, appleMusic, spotify, nowPlaying | auto |
| Show album art | Toggle | on/off | on |
| Show visualizer | Toggle | on/off | off |
| Visualizer style | Picker | waveform, bars, circular, custom | waveform |
| Custom Lottie URL | TextField | URL string | "" |
| Sneak peek on change | Toggle | on/off | on |
| Sneak peek duration | Slider + label | 1s - 10s, step 0.5 | 3.0 |
| Show lyrics | Toggle | on/off | false |

### 4.4 Calendar Tab

Controls the calendar events widget.

#### UI Layout

```
[ ] Enable calendar widget

Calendars:
  [x] Work           (colored dot)
  [x] Personal       (colored dot)
  [ ] Birthdays      (colored dot)
  ... (fetched from EventKit)

Lookahead window:     [====|====] 12 hours
[ ] Show all-day events
[ ] Show declined events
Reminder lead time:   [====|====] 15 min
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Enable calendar | Toggle | on/off | on |
| Calendar selection | Multi-toggle list | all user calendars | all enabled |
| Lookahead window | Slider + label | 1 - 48 hours, step 1 | 12 |
| Show all-day events | Toggle | on/off | true |
| Show declined events | Toggle | on/off | false |
| Reminder lead time | Slider + label | 0 - 60 min, step 5 | 15 |

#### Calendar List

- Fetched from `EKEventStore` with permission.
- Each row: colored dot matching calendar color, calendar name, toggle.
- Grouped by source (iCloud, Google, Exchange, etc.).
- Selected calendar identifiers stored as `Set<String>` in Defaults.

### 4.5 HUDs Tab

Controls the system HUD replacement feature.

#### UI Layout

```
[ ] Enable HUD replacement

Replace:
  [x] Volume HUD
  [x] Brightness HUD
  [x] Keyboard backlight HUD

Display duration:     [====|====] 1.5s
[ ] Show percentage value
[ ] Play volume tick sound
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Enable HUD replacement | Toggle | on/off | on |
| Replace volume | Toggle | on/off | on |
| Replace brightness | Toggle | on/off | on |
| Replace keyboard backlight | Toggle | on/off | on |
| HUD display duration | Slider + label | 0.5s - 5.0s, step 0.5 | 1.5 |
| Show percentage | Toggle | on/off | true |
| Volume tick sound | Toggle | on/off | false |

### 4.6 Battery Tab

Controls the battery status display in the notch.

#### UI Layout

```
[ ] Show battery in notch

Low battery alert threshold:  [====|====] 20%
[ ] Show time remaining
[ ] Show charging status
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Show battery | Toggle | on/off | on |
| Low battery threshold | Slider + label | 5% - 50%, step 5 | 20 |
| Show time remaining | Toggle | on/off | true |
| Show charging status | Toggle | on/off | true |

### 4.7 Shelf Tab

Controls the file shelf (temporary file staging area in the notch).

#### UI Layout

```
[ ] Enable file shelf

Max items:            [====|====] 20
[ ] Persist across restarts
Auto-clear after:     [Never ▼]
[ ] Show AirDrop zone
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Enable shelf | Toggle | on/off | on |
| Max items | Slider + label | 5 - 50, step 5 | 20 |
| Persist across restarts | Toggle | on/off | true |
| Auto-clear duration | Picker | never, 1h, 4h, 12h, 24h, 7d | never |
| Show AirDrop zone | Toggle | on/off | true |

### 4.8 Clipboard Tab

Controls the clipboard history feature.

#### UI Layout

```
[ ] Enable clipboard history

Max history entries:  [====|====] 50

Excluded apps:
  + Safari (Private Browsing)
  + 1Password
  [Add App...]  [Remove]

Auto-prune interval:  [====|====] 7 days
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Enable clipboard | Toggle | on/off | on |
| Max entries | Slider + label | 10 - 200, step 10 | 50 |
| Excluded apps | List + add/remove | bundle identifiers | [] |
| Auto-prune interval | Picker | 1d, 3d, 7d, 14d, 30d, never | 7d |

#### Excluded Apps

- List of bundle identifiers whose clipboard changes are not recorded.
- "Add App" opens an NSOpenPanel filtered to `.application`.
- Shows app icon + name in the list.
- Default exclusions: none (user configures based on their security needs).

### 4.9 Shortcuts Tab

Controls the Apple Shortcuts integration (running shortcuts FROM the notch).

#### UI Layout

```
Display mode:         [Grid ▼]
Grid columns:         [====|====] 3       (visible when grid mode)
[ ] Show in notch bar

─── Configured Shortcuts ───
  ≡  Morning Routine    ★  [Test] [✕]
  ≡  Toggle Dark Mode   ◆  [Test] [✕]
  ≡  Quick Note         ●  [Test] [✕]
  (drag to reorder)

[Add Shortcut...]
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Display mode | Picker | grid, list | grid |
| Grid columns | Slider + label | 2 - 4, step 1 | 3 |
| Show in notch bar | Toggle | on/off | false |
| Shortcut entries | Reorderable list | ShortcutEntry[] | [] |

See PRD-09 Shortcuts for `ShortcutEntry` model and add/edit sheet details.

### 4.10 Quick Apps Tab

Controls the pinned app launcher widget.

#### UI Layout

```
Icon size:            [Medium ▼]
[ ] Show app labels
[ ] Show running indicator

─── Pinned Apps ───
  ≡  [icon] Finder
  ≡  [icon] Safari
  ≡  [icon] Messages
  ≡  [icon] Notes
  ≡  [icon] Calendar
  (drag to reorder)

[Add App...]  [Remove Selected]

Maximum: 12 apps
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Icon size | Picker | small, medium, large | medium |
| Show labels | Toggle | on/off | false |
| Show running indicator | Toggle | on/off | true |
| App list | Reorderable list | QuickAppEntry[] | default set |

See PRD-09 Widgets for `QuickAppEntry` model and app management details.

### 4.11 Mirror Tab

Controls the camera mirror widget.

#### UI Layout

```
[ ] Enable camera mirror

[ ] Mirror (flip horizontally)

Default camera:       [FaceTime HD Camera ▼]
[ ] Show preview in compact notch bar
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Enable mirror | Toggle | on/off | true |
| Mirror flip | Toggle | on/off | true |
| Default camera | Picker | available cameras by localizedName | nil (system default) |
| Show in compact | Toggle | on/off | false |

#### Camera Picker

- Populated from `AVCaptureDevice.DiscoverySession`.
- Shows `localizedName` for each device.
- First entry: "System Default" (nil value — use whatever macOS picks).
- Refreshes when cameras are connected/disconnected.

### 4.12 Advanced Tab

Power-user and debugging features.

#### UI Layout

```
─── Reset ───
[Reset All Settings]  (confirmation alert)

─── Export / Import ───
[Export Settings...]
[Import Settings...]

─── Debug ───
[ ] Debug mode
Log level:            [Info ▼]
[Clear Cache]         (confirmation alert)
[Open Log Folder]
```

#### Controls Detail

| Setting | Control | Range/Options | Default |
|---|---|---|---|
| Debug mode | Toggle | on/off | false |
| Log level | Picker | debug, info, warning, error | info |

#### Reset All Settings

1. Show confirmation alert: "This will reset all Niya settings to their defaults. This cannot be undone."
2. On confirm: call `Defaults.removeAll()`.
3. Restart relevant subsystems (HUD monitor, media controller, etc.) by posting a `SettingsDidReset` notification.
4. Reset window position.

#### Export Settings

1. Serialize all `Defaults.Keys` values to a JSON dictionary.
2. Present `NSSavePanel` with default filename `niya-settings.json`.
3. Write JSON to selected path.

```swift
func exportSettings() -> [String: Any] {
    var dict: [String: Any] = [:]
    dict["menubarIcon"] = Defaults[.menubarIcon]
    dict["activationMethod"] = Defaults[.activationMethod].rawValue
    // ... all keys
    dict["_exportVersion"] = 1
    dict["_exportDate"] = ISO8601DateFormatter().string(from: Date())
    return dict
}
```

#### Import Settings

1. Present `NSOpenPanel` filtered to `.json`.
2. Parse JSON.
3. Validate `_exportVersion` for compatibility.
4. Show confirmation: "Import settings from file? This will overwrite your current settings."
5. Apply each key.
6. Post `SettingsDidReset` notification.

#### Clear Cache

- Removes cached album art, app icons, and temporary files.
- Shows byte count freed.
- Cache location: `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)`.

### 4.13 About Tab

App information and links.

#### UI Layout

```
        [App Icon — 64pt]
           Niya
        Version 1.0.0 (42)

Made by [Author Name]

[Website]  [GitHub]  [Support]

[Check for Updates]

─── Acknowledgments ───
Defaults — sindresorhus
LaunchAtLogin — sindresorhus
KeyboardShortcuts — sindresorhus
Sparkle — sparkle-project
Lottie — airbnb
... (scrollable list)
```

#### Content

| Item | Value |
|---|---|
| App icon | `NSApp.applicationIconImage` at 64pt |
| Version | `Bundle.main.infoDictionary["CFBundleShortVersionString"]` |
| Build number | `Bundle.main.infoDictionary["CFBundleVersion"]` |
| Website link | Opens URL in default browser |
| GitHub link | Opens URL in default browser |
| Support link | Opens URL in default browser (or mailto:) |
| Check for Updates | Triggers Sparkle update check |
| Acknowledgments | Scrollable list of open-source dependencies with links to their repos |

---

## 5. Complete Settings Keys Definition

```swift
import Defaults

// MARK: - Custom Types

enum ActivationMethod: String, Codable, Defaults.Serializable {
    case hover
    case click
}

enum NotchHeightMode: String, Codable, Defaults.Serializable {
    case matchNotch
    case matchMenuBar
    case custom
}

enum AppTheme: String, Codable, Defaults.Serializable {
    case followSystem
    case alwaysDark
}

enum AccentColorMode: String, Codable, Defaults.Serializable {
    case system
    case custom
}

enum MusicSource: String, Codable, Defaults.Serializable {
    case auto
    case appleMusic
    case spotify
    case nowPlaying
}

enum VisualizerStyle: String, Codable, Defaults.Serializable {
    case waveform
    case bars
    case circular
    case custom
}

enum AutoClearDuration: String, Codable, Defaults.Serializable {
    case never
    case oneHour
    case fourHours
    case twelveHours
    case oneDay
    case sevenDays
}

enum ClipboardPruneInterval: String, Codable, Defaults.Serializable {
    case oneDay
    case threeDays
    case sevenDays
    case fourteenDays
    case thirtyDays
    case never
}

enum LogLevel: String, Codable, Defaults.Serializable {
    case debug
    case info
    case warning
    case error
}

enum DisplayTarget: String, Codable, Defaults.Serializable {
    case all
    case primaryOnly
    case specific
}

enum ShortcutsDisplayMode: String, Codable, Defaults.Serializable {
    case grid
    case list
}

enum QuickAppsIconSize: String, Codable, Defaults.Serializable {
    case small
    case medium
    case large
}

// MARK: - Settings Keys

extension Defaults.Keys {

    // ── General ──────────────────────────────────────────────

    /// Show Niya icon in the menu bar
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)

    /// How the notch activates: hover or click
    static let activationMethod = Key<ActivationMethod>("activationMethod", default: .hover)

    /// Delay before notch expands on hover (seconds)
    static let hoverDelay = Key<Double>("hoverDelay", default: 0.2)

    /// Delay before notch collapses when cursor leaves (seconds)
    static let closeDelay = Key<Double>("closeDelay", default: 0.5)

    /// Which displays show the notch overlay
    static let displayTarget = Key<DisplayTarget>("displayTarget", default: .all)

    /// Specific display ID when displayTarget == .specific
    static let specificDisplayID = Key<UInt32?>("specificDisplayID", default: nil)

    /// Automatically move notch to the display with the active window
    static let autoSwitchDisplay = Key<Bool>("autoSwitchDisplay", default: true)

    /// Automatically check for updates via Sparkle
    static let autoCheckUpdates = Key<Bool>("autoCheckUpdates", default: true)

    // ── Appearance ───────────────────────────────────────────

    /// How the notch height is determined
    static let notchHeightMode = Key<NotchHeightMode>("notchHeightMode", default: .matchNotch)

    /// Custom notch height in points (used when notchHeightMode == .custom)
    static let customNotchHeight = Key<Double>("customNotchHeight", default: 32)

    /// Width of the notch on displays without a physical notch
    static let nonNotchWidth = Key<Double>("nonNotchWidth", default: 200)

    /// Height of the notch on displays without a physical notch
    static let nonNotchHeight = Key<Double>("nonNotchHeight", default: 32)

    /// Color theme
    static let appTheme = Key<AppTheme>("appTheme", default: .followSystem)

    /// Accent color mode
    static let accentColorMode = Key<AccentColorMode>("accentColorMode", default: .system)

    /// Custom accent color as hex string (used when accentColorMode == .custom)
    static let customAccentColor = Key<String>("customAccentColor", default: "#007AFF")

    /// Notch background transparency (0.5 to 1.0)
    static let transparency = Key<Double>("transparency", default: 0.8)

    /// Animation speed multiplier (0.5 to 2.0)
    static let animationSpeed = Key<Double>("animationSpeed", default: 1.0)

    /// Corner radius of the notch in points
    static let cornerRadius = Key<Double>("cornerRadius", default: 10)

    // ── Media ────────────────────────────────────────────────

    /// Preferred music source
    static let musicSource = Key<MusicSource>("musicSource", default: .auto)

    /// Show album art in the media widget
    static let showAlbumArt = Key<Bool>("showAlbumArt", default: true)

    /// Show music visualizer animation
    static let showVisualizer = Key<Bool>("showVisualizer", default: false)

    /// Visualizer animation style
    static let visualizerStyle = Key<VisualizerStyle>("visualizerStyle", default: .waveform)

    /// URL for custom Lottie animation (used when visualizerStyle == .custom)
    static let customLottieURL = Key<String>("customLottieURL", default: "")

    /// Briefly expand notch on track change
    static let sneakPeekOnTrackChange = Key<Bool>("sneakPeekOnTrackChange", default: true)

    /// Duration of the sneak peek expansion in seconds
    static let sneakPeekDuration = Key<Double>("sneakPeekDuration", default: 3.0)

    /// Show synchronized lyrics
    static let showLyrics = Key<Bool>("showLyrics", default: false)

    // ── Calendar ─────────────────────────────────────────────

    /// Enable the calendar widget
    static let calendarEnabled = Key<Bool>("calendarEnabled", default: true)

    /// Set of enabled calendar identifiers (from EKCalendar.calendarIdentifier)
    static let enabledCalendarIDs = Key<Set<String>>("enabledCalendarIDs", default: [])

    /// How many hours ahead to show events
    static let calendarLookahead = Key<Int>("calendarLookahead", default: 12)

    /// Include all-day events in the widget
    static let showAllDayEvents = Key<Bool>("showAllDayEvents", default: true)

    /// Include declined events in the widget
    static let showDeclinedEvents = Key<Bool>("showDeclinedEvents", default: false)

    /// Minutes before event to show reminder highlight
    static let eventReminderLeadTime = Key<Int>("eventReminderLeadTime", default: 15)

    // ── HUDs ─────────────────────────────────────────────────

    /// Master toggle for replacing system HUDs
    static let hudReplacementEnabled = Key<Bool>("hudReplacementEnabled", default: true)

    /// Replace the system volume HUD
    static let replaceVolumeHUD = Key<Bool>("replaceVolumeHUD", default: true)

    /// Replace the system brightness HUD
    static let replaceBrightnessHUD = Key<Bool>("replaceBrightnessHUD", default: true)

    /// Replace the keyboard backlight HUD
    static let replaceKeyboardBacklightHUD = Key<Bool>("replaceKeyboardBacklightHUD", default: true)

    /// How long the HUD stays visible (seconds)
    static let hudDisplayDuration = Key<Double>("hudDisplayDuration", default: 1.5)

    /// Show numeric percentage alongside the HUD bar
    static let hudShowPercentage = Key<Bool>("hudShowPercentage", default: true)

    /// Play the volume tick sound on volume change
    static let volumeTickSound = Key<Bool>("volumeTickSound", default: false)

    // ── Battery ──────────────────────────────────────────────

    /// Show battery status in the notch
    static let showBattery = Key<Bool>("showBattery", default: true)

    /// Battery percentage at which to show a low battery alert
    static let lowBatteryThreshold = Key<Int>("lowBatteryThreshold", default: 20)

    /// Show estimated time remaining on battery
    static let showTimeRemaining = Key<Bool>("showTimeRemaining", default: true)

    /// Show charging indicator when plugged in
    static let showChargingStatus = Key<Bool>("showChargingStatus", default: true)

    // ── File Shelf ───────────────────────────────────────────

    /// Enable the file shelf widget
    static let shelfEnabled = Key<Bool>("shelfEnabled", default: true)

    /// Maximum number of items on the shelf
    static let shelfMaxItems = Key<Int>("shelfMaxItems", default: 20)

    /// Persist shelf contents across app restarts
    static let shelfPersistAcrossRestarts = Key<Bool>("shelfPersistAcrossRestarts", default: true)

    /// Duration after which shelf items are automatically cleared
    static let shelfAutoClearDuration = Key<AutoClearDuration>("shelfAutoClearDuration", default: .never)

    /// Show the AirDrop quick-send zone in the shelf
    static let shelfShowAirDropZone = Key<Bool>("shelfShowAirDropZone", default: true)

    // ── Clipboard ────────────────────────────────────────────

    /// Enable clipboard history tracking
    static let clipboardEnabled = Key<Bool>("clipboardEnabled", default: true)

    /// Maximum number of clipboard entries to retain
    static let clipboardMaxEntries = Key<Int>("clipboardMaxEntries", default: 50)

    /// Bundle identifiers of apps whose clipboard changes are ignored
    static let clipboardExcludedApps = Key<[String]>("clipboardExcludedApps", default: [])

    /// How often old clipboard entries are pruned
    static let clipboardPruneInterval = Key<ClipboardPruneInterval>("clipboardPruneInterval", default: .sevenDays)

    // ── Shortcuts (running FROM notch) ───────────────────────

    /// Configured shortcut entries for the shortcuts panel
    static let shortcutEntries = Key<[ShortcutEntry]>("shortcutEntries", default: [])

    /// Display mode for the shortcuts panel
    static let shortcutsDisplayMode = Key<ShortcutsDisplayMode>("shortcutsDisplayMode", default: .grid)

    /// Number of columns in grid display mode
    static let shortcutsGridColumns = Key<Int>("shortcutsGridColumns", default: 3)

    /// Show shortcuts indicator in the compact notch bar
    static let shortcutsShowInNotchBar = Key<Bool>("shortcutsShowInNotchBar", default: false)

    // ── Quick Apps ───────────────────────────────────────────

    /// Enable the quick apps launcher widget
    static let quickAppsEnabled = Key<Bool>("quickAppsEnabled", default: true)

    /// Configured quick app entries
    static let quickApps = Key<[QuickAppEntry]>("quickApps", default: [])

    /// Icon size for quick apps
    static let quickAppsIconSize = Key<QuickAppsIconSize>("quickAppsIconSize", default: .medium)

    /// Show app name labels below icons
    static let quickAppsShowLabels = Key<Bool>("quickAppsShowLabels", default: false)

    /// Show running indicator dot below active apps
    static let quickAppsShowRunningIndicator = Key<Bool>("quickAppsShowRunningIndicator", default: true)

    // ── Mirror ───────────────────────────────────────────────

    /// Enable the camera mirror widget
    static let mirrorEnabled = Key<Bool>("mirrorEnabled", default: true)

    /// Flip camera preview horizontally (true = mirror behavior)
    static let mirrorFlipped = Key<Bool>("mirrorFlipped", default: true)

    /// Preferred camera device uniqueID (nil = system default)
    static let mirrorCameraDeviceID = Key<String?>("mirrorCameraDeviceID", default: nil)

    /// Show small camera preview in the compact notch bar
    static let mirrorShowInCompact = Key<Bool>("mirrorShowInCompact", default: false)

    // ── Advanced ─────────────────────────────────────────────

    /// Enable debug mode (extra logging, debug overlays)
    static let debugMode = Key<Bool>("debugMode", default: false)

    /// Minimum log level to write
    static let logLevel = Key<LogLevel>("logLevel", default: .info)
}
```

---

## 6. Keyboard Shortcuts Keys

Defined separately using the KeyboardShortcuts library:

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut to toggle the notch
    static let toggleNotch = Self("toggleNotch")

    /// Global shortcut to open the shortcuts panel
    static let openShortcutsPanel = Self("openShortcutsPanel")

    /// Global shortcut to open clipboard history
    static let openClipboardHistory = Self("openClipboardHistory")
}
```

---

## 7. Settings Migration

When settings schema changes between versions:

```swift
struct SettingsMigrator {
    static func migrateIfNeeded() {
        let currentVersion = Defaults[.settingsSchemaVersion]

        if currentVersion < 2 {
            migrateV1ToV2()
        }
        // future migrations...

        Defaults[.settingsSchemaVersion] = Self.latestVersion
    }

    static let latestVersion = 1
}

extension Defaults.Keys {
    /// Internal: tracks settings schema version for migration
    static let settingsSchemaVersion = Key<Int>("settingsSchemaVersion", default: 1)
}
```

- Run `SettingsMigrator.migrateIfNeeded()` at app launch, before any settings are read.
- Each migration function handles one version bump.
- Old keys are read, transformed, written to new keys, then old keys removed.

---

## 8. Requirements Table

| ID | Requirement | Priority | Complexity | Dependencies |
|---|---|---|---|---|
| ST-001 | `Defaults.Keys` extension with all keys and default values as specified in Section 5 | P0 | Low | Defaults library |
| ST-002 | All custom enum types conforming to Codable + Defaults.Serializable | P0 | Low | Defaults library |
| ST-003 | `SettingsWindowController` — singleton, `NSWindow` with `NSHostingView` | P0 | Medium | AppKit, SwiftUI |
| ST-004 | `SettingsRootView` with `NavigationSplitView` sidebar | P0 | Medium | SwiftUI |
| ST-005 | `SettingsTab` enum with title, icon, and view builder | P0 | Low | SwiftUI |
| ST-006 | `GeneralSettingsView` — all controls per Section 4.1 | P0 | High | LaunchAtLogin, KeyboardShortcuts, Sparkle |
| ST-007 | `AppearanceSettingsView` — all controls per Section 4.2 | P0 | High | SwiftUI, ColorPicker |
| ST-008 | Live appearance preview in Appearance tab | P2 | Medium | SwiftUI |
| ST-009 | `MediaSettingsView` — all controls per Section 4.3 | P0 | Medium | SwiftUI |
| ST-010 | `CalendarSettingsView` — all controls per Section 4.4 | P0 | Medium | EventKit |
| ST-011 | Calendar list fetched from EKEventStore with permission | P0 | Medium | EventKit permissions |
| ST-012 | `HUDsSettingsView` — all controls per Section 4.5 | P0 | Low | SwiftUI |
| ST-013 | `BatterySettingsView` — all controls per Section 4.6 | P0 | Low | SwiftUI |
| ST-014 | `ShelfSettingsView` — all controls per Section 4.7 | P0 | Low | SwiftUI |
| ST-015 | `ClipboardSettingsView` — all controls per Section 4.8 | P0 | Medium | SwiftUI, NSOpenPanel |
| ST-016 | Excluded apps list with icon resolution and add/remove | P1 | Medium | NSWorkspace |
| ST-017 | `ShortcutsSettingsView` — all controls per Section 4.9 | P1 | Medium | SwiftUI |
| ST-018 | `QuickAppsSettingsView` — all controls per Section 4.10 | P1 | Medium | SwiftUI, NSOpenPanel |
| ST-019 | `MirrorSettingsView` — all controls per Section 4.11 | P1 | Medium | AVFoundation, SwiftUI |
| ST-020 | Camera picker populated from AVCaptureDevice.DiscoverySession | P1 | Low | AVFoundation |
| ST-021 | `AdvancedSettingsView` — all controls per Section 4.12 | P1 | Medium | SwiftUI |
| ST-022 | Reset all settings with confirmation alert | P1 | Low | Defaults |
| ST-023 | Export settings to JSON file via NSSavePanel | P1 | Medium | Foundation, NSSavePanel |
| ST-024 | Import settings from JSON file via NSOpenPanel with validation | P1 | Medium | Foundation, NSOpenPanel |
| ST-025 | `AboutSettingsView` — all content per Section 4.13 | P1 | Low | SwiftUI |
| ST-026 | Open-source acknowledgments list | P2 | Low | SwiftUI |
| ST-027 | `SettingsMigrator` — version-tracked schema migration at launch | P1 | Medium | Defaults |
| ST-028 | `KeyboardShortcuts.Name` extensions for global shortcuts | P0 | Low | KeyboardShortcuts |
| ST-029 | `SettingsDidReset` notification posted after reset/import | P1 | Low | NotificationCenter |
| ST-030 | Window frame auto-save between sessions | P1 | Low | NSWindow.setFrameAutosaveName |
| ST-031 | Slider labels showing live value (e.g., "200ms", "80%") | P1 | Low | SwiftUI |
| ST-032 | Conditional control visibility (e.g., custom height only when mode = custom) | P0 | Low | SwiftUI |
| ST-033 | Unit tests for all Defaults.Keys default values (verify non-nil, correct type) | P0 | Low | XCTest |
| ST-034 | Unit tests for all custom enum Codable round-trip | P0 | Low | XCTest |
| ST-035 | Unit tests for settings export/import serialization round-trip | P1 | Medium | XCTest |
| ST-036 | Unit tests for SettingsMigrator (mock old schema, verify migration) | P1 | Medium | XCTest |
| ST-037 | Unit tests for reset all settings (verify all keys return to defaults) | P0 | Low | XCTest |
| ST-038 | UI test: navigate to each settings tab without crash | P1 | Medium | XCUITest |
| ST-039 | UI test: toggle a boolean setting and verify persistence | P2 | Medium | XCUITest |
| ST-040 | UI test: adjust a slider and verify value label updates | P2 | Medium | XCUITest |

---

## 9. Testing Strategy

### Unit Tests

- **Default values:** iterate all `Defaults.Keys` via reflection or explicit enumeration; verify each has a non-nil default and correct type.
- **Enum serialization:** for every custom enum, encode to JSON, decode back, assert equal.
- **Export/Import:** export all settings, modify some values, import the export file, assert values match the export (not the modified values).
- **Migration:** set `settingsSchemaVersion` to an old version, seed old-format keys, run `migrateIfNeeded()`, assert new keys are correctly populated.
- **Reset:** set several non-default values, call `Defaults.removeAll()`, assert all keys return to their specified defaults.

### Integration Tests

- Verify `SettingsWindowController.shared` creates a window with correct properties.
- Verify `SettingsRootView` renders without crash.
- Verify each `SettingsTab.view` instantiates without crash.

### Manual Verification

- Walk through every tab, adjust every control, verify persistence across app restart.
- Test LaunchAtLogin toggle — verify login item appears in System Settings > General > Login Items.
- Test KeyboardShortcuts recorder — set a shortcut, verify it triggers the notch.
- Test Sparkle update check — verify no crash (update server need not be configured).
- Test export to file, quit app, delete preferences, import from file — verify full restoration.
- Test reset all settings — verify everything returns to defaults.

---

## 10. Open Questions

1. Should we support iCloud sync of settings across Macs? (Would require migrating from UserDefaults to NSUbiquitousKeyValueStore for some keys.)
2. Should we provide a "profiles" feature — save/restore named settings configurations (e.g., "Work", "Presenting", "Minimal")?
3. Should the settings window use a toolbar-style tab bar (like System Settings) instead of a sidebar, for better macOS convention alignment?
4. Should we detect first-launch and show an onboarding flow that walks through key settings?
