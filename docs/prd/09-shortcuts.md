# PRD-09: Apple Shortcuts Integration

## 1. Overview

Niya exposes its core actions to the system-wide Apple Shortcuts ecosystem via the App Intents framework, making every major feature automatable. Users can trigger Niya actions from Shortcuts, Siri, the menu bar, Spotlight, and other automation tools. Conversely, Niya provides a panel inside the notch for launching the user's own Apple Shortcuts with a single click.

**Platform:** macOS 13+ (App Intents), macOS 14+ (AppShortcutsProvider)
**Dependency:** App Intents framework (system), no third-party libraries

---

## 2. Exposing Niya Actions via App Intents

### 2.1 Architecture

All intents live in a dedicated `Intents/` group inside the Xcode target. Each intent is a `struct` conforming to `AppIntent`. A single `NiyaShortcutsProvider` conforming to `AppShortcutsProvider` registers them for automatic discoverability in the Shortcuts app (macOS 14+).

```
Sources/
  Intents/
    ToggleNotchIntent.swift
    ShowWidgetIntent.swift
    ShowNowPlayingIntent.swift
    ToggleMediaIntent.swift
    NextTrackIntent.swift
    PreviousTrackIntent.swift
    ClearShelfIntent.swift
    ShowClipboardHistoryIntent.swift
    ToggleHUDReplacementIntent.swift
    NiyaShortcutsProvider.swift
```

### 2.2 Intent Catalog

#### ToggleNotchIntent

| Field | Value |
|---|---|
| **Title** | "Toggle Notch" |
| **Description** | Expand or collapse the Niya notch overlay |
| **Parameters** | `targetState: ToggleState?` — `.expand`, `.collapse`, or `nil` (toggle) |
| **Return** | `IntentResult<Bool>` — new expanded state |
| **Errors** | None expected |

- When `targetState` is `nil`, flip the current state.
- When a specific state is given, set to that state (no-op if already in that state).
- Posts `NotchStateChanged` notification on the main actor.

#### ShowWidgetIntent

| Field | Value |
|---|---|
| **Title** | "Show Widget" |
| **Description** | Open a specific widget inside the notch |
| **Parameters** | `widgetName: NiyaWidgetType` — enum: `.nowPlaying`, `.calendar`, `.battery`, `.shelf`, `.clipboard`, `.mirror`, `.quickApps`, `.shortcuts` |
| **Return** | `IntentResult<Void>` |
| **Errors** | `WidgetNotAvailableError` if widget is disabled in settings |

- Expands the notch if collapsed.
- Navigates to the specified widget tab/view.
- `NiyaWidgetType` conforms to `AppEnum` with `typeDisplayRepresentation` and `caseDisplayRepresentations` for Shortcuts UI.

#### ShowNowPlayingIntent

| Field | Value |
|---|---|
| **Title** | "Show Now Playing" |
| **Description** | Expand the notch to the media player widget |
| **Parameters** | None |
| **Return** | `IntentResult<Void>` |
| **Errors** | None |

- Convenience intent — equivalent to `ShowWidgetIntent(widgetName: .nowPlaying)`.
- Separate intent for better Siri discoverability ("Show now playing in Niya").

#### ToggleMediaIntent

| Field | Value |
|---|---|
| **Title** | "Toggle Media Playback" |
| **Description** | Play or pause the current media |
| **Parameters** | `targetState: PlaybackState?` — `.play`, `.pause`, or `nil` (toggle) |
| **Return** | `IntentResult<Bool>` — `true` if now playing |
| **Errors** | `NoMediaSessionError` if nothing is playing |

- Delegates to `MediaController.shared.togglePlayback()`.
- When `targetState` is specified, forces that state.

#### NextTrackIntent

| Field | Value |
|---|---|
| **Title** | "Next Track" |
| **Description** | Skip to the next track |
| **Parameters** | None |
| **Return** | `IntentResult<Void>` |
| **Errors** | `NoMediaSessionError` |

#### PreviousTrackIntent

| Field | Value |
|---|---|
| **Title** | "Previous Track" |
| **Description** | Go to the previous track |
| **Parameters** | None |
| **Return** | `IntentResult<Void>` |
| **Errors** | `NoMediaSessionError` |

#### ClearShelfIntent

| Field | Value |
|---|---|
| **Title** | "Clear File Shelf" |
| **Description** | Remove all items from the Niya file shelf |
| **Parameters** | None |
| **Return** | `IntentResult<Int>` — number of items cleared |
| **Errors** | None (returns 0 if already empty) |

#### ShowClipboardHistoryIntent

| Field | Value |
|---|---|
| **Title** | "Show Clipboard History" |
| **Description** | Expand the notch to clipboard history |
| **Parameters** | None |
| **Return** | `IntentResult<Void>` |
| **Errors** | `FeatureDisabledError` if clipboard history is off |

#### ToggleHUDReplacementIntent

| Field | Value |
|---|---|
| **Title** | "Toggle HUD Replacement" |
| **Description** | Enable or disable Niya's custom HUD overlays |
| **Parameters** | `enabled: Bool?` — `nil` toggles |
| **Return** | `IntentResult<Bool>` — new state |
| **Errors** | None |

- Persists to `Defaults[.hudReplacementEnabled]`.

### 2.3 AppShortcutsProvider (macOS 14+)

```swift
struct NiyaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleNotchIntent(),
            phrases: ["Toggle \(.applicationName)", "Show \(.applicationName)"],
            shortTitle: "Toggle Notch",
            systemImageName: "rectangle.topthird.inset.filled"
        )
        AppShortcut(
            intent: ShowNowPlayingIntent(),
            phrases: ["Show now playing in \(.applicationName)"],
            shortTitle: "Now Playing",
            systemImageName: "music.note"
        )
        AppShortcut(
            intent: ToggleMediaIntent(),
            phrases: ["Play pause in \(.applicationName)"],
            shortTitle: "Play/Pause",
            systemImageName: "playpause.fill"
        )
        // ... remaining intents
    }
}
```

- Compile-time validated by Xcode.
- `@available(macOS 14, *)` guard; on macOS 13 intents still work via manual Shortcuts creation.

### 2.4 Enums for Parameters

```swift
enum ToggleState: String, AppEnum {
    case expand, collapse
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Notch State")
    static var caseDisplayRepresentations: [ToggleState: DisplayRepresentation] = [
        .expand: "Expand",
        .collapse: "Collapse"
    ]
}

enum PlaybackState: String, AppEnum {
    case play, pause
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Playback State")
    static var caseDisplayRepresentations: [PlaybackState: DisplayRepresentation] = [
        .play: "Play",
        .pause: "Pause"
    ]
}

enum NiyaWidgetType: String, AppEnum {
    case nowPlaying, calendar, battery, shelf, clipboard, mirror, quickApps, shortcuts
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget")
    static var caseDisplayRepresentations: [NiyaWidgetType: DisplayRepresentation] = [
        .nowPlaying: "Now Playing",
        .calendar: "Calendar",
        .battery: "Battery",
        .shelf: "File Shelf",
        .clipboard: "Clipboard History",
        .mirror: "Camera Mirror",
        .quickApps: "Quick Apps",
        .shortcuts: "Shortcuts"
    ]
}
```

### 2.5 Error Types

```swift
enum NiyaIntentError: Error, CustomLocalizedStringResourceConvertible {
    case widgetNotAvailable(String)
    case noMediaSession
    case featureDisabled(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .widgetNotAvailable(let name):
            "The \(name) widget is not available"
        case .noMediaSession:
            "No media is currently playing"
        case .featureDisabled(let name):
            "\(name) is disabled in Niya settings"
        }
    }
}
```

---

## 3. Running Shortcuts FROM the Notch

### 3.1 User Experience

The Shortcuts panel lives inside the notch as a dedicated widget tab. It displays a configurable grid of the user's favorite Apple Shortcuts, each represented by an icon and label. Tapping a shortcut runs it immediately.

#### Compact State
- Small Shortcuts icon indicator in the notch bar (optional, user-configured).
- Tapping opens the expanded shortcuts panel.

#### Expanded State
- Title bar: "Shortcuts" with a gear icon to configure.
- Grid of shortcut buttons (configurable: 2, 3, or 4 columns).
- Each button shows: shortcut icon (SF Symbol or first emoji from name, fallback to `star.fill`), shortcut name (truncated with ellipsis if too long).
- Scroll if more shortcuts than visible area.
- Empty state: "Add shortcuts in settings" with a button to open the Shortcuts settings tab.

### 3.2 Launching Mechanism

```swift
func runShortcut(named name: String) {
    let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
    let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)")!
    NSWorkspace.shared.open(url)
}
```

- Uses `shortcuts://run-shortcut?name=ShortcutName` URL scheme.
- Input passing: `shortcuts://run-shortcut?name=Name&input=text&text=value` for shortcuts that accept input.
- The URL scheme is synchronous-fire — Niya does not receive a callback. The shortcut runs in the Shortcuts app.

### 3.3 Shortcut Discovery and Configuration

#### Fetching Available Shortcuts

There is no public macOS API to enumerate user shortcuts programmatically. Niya uses these strategies:

1. **Manual entry** — user types the shortcut name. Always available.
2. **Shortcuts folder scanning** (best-effort) — on macOS 14+, the Shortcuts app stores data in `~/Library/Shortcuts/`. Niya attempts to read folder names for autocomplete suggestions. This requires Full Disk Access or the data may not be accessible.
3. **Import from Shortcuts app** — user opens Shortcuts.app, right-clicks a shortcut, selects "Copy Link", and pastes into Niya. Niya parses the iCloud link to extract the name.

#### Configuration Model

```swift
struct ShortcutEntry: Codable, Identifiable, Hashable, Defaults.Serializable {
    let id: UUID
    var name: String           // exact shortcut name as in Shortcuts.app
    var displayName: String?   // optional override for display
    var iconSymbol: String     // SF Symbol name, default "star.fill"
    var iconColor: String      // hex color, default system accent
    var folderName: String?    // optional folder filter
    var sortOrder: Int
}
```

- Stored in `Defaults[.shortcutEntries]` as `[ShortcutEntry]`.
- Maximum 24 entries (3 pages of 8 in a 2x4 grid).

#### Settings UI (in Shortcuts Tab)

- List of configured shortcuts with drag-to-reorder.
- "Add Shortcut" button opens a sheet:
  - Text field for shortcut name (with autocomplete if folder scanning works).
  - Optional display name override.
  - SF Symbol picker for icon.
  - Color picker for icon background.
  - Optional folder assignment.
- "Test" button next to each entry — runs the shortcut to verify it works.
- "Remove" swipe action / delete button.
- Display mode picker: Grid / List.
- Column count picker (grid mode): 2, 3, 4.

### 3.4 Folder Filtering

- User can assign shortcuts to virtual folders/groups for organization.
- The expanded panel shows a segmented control or tab bar at the top for folder filtering.
- "All" shows everything; individual folder names filter.
- Folder names are derived from the `folderName` field on each `ShortcutEntry`.

---

## 4. Keyboard Shortcut Support

- Global keyboard shortcut to open the Shortcuts panel: configurable via KeyboardShortcuts library.
- Default: none (user must set in General settings).
- When panel is open, number keys 1-9 trigger shortcuts by position for power users.

---

## 5. Settings Keys

```swift
extension Defaults.Keys {
    // Shortcuts — Running FROM notch
    static let shortcutEntries = Key<[ShortcutEntry]>("shortcutEntries", default: [])
    static let shortcutsDisplayMode = Key<ShortcutsDisplayMode>("shortcutsDisplayMode", default: .grid)
    static let shortcutsGridColumns = Key<Int>("shortcutsGridColumns", default: 3)
    static let shortcutsShowInNotchBar = Key<Bool>("shortcutsShowInNotchBar", default: false)
}

enum ShortcutsDisplayMode: String, Codable, Defaults.Serializable {
    case grid, list
}
```

---

## 6. Requirements Table

| ID | Requirement | Priority | Complexity | Dependencies |
|---|---|---|---|---|
| SC-001 | Implement `ToggleNotchIntent` with expand/collapse/toggle states | P0 | Low | App Intents framework, NotchController |
| SC-002 | Implement `ShowWidgetIntent` with `NiyaWidgetType` enum parameter | P0 | Medium | App Intents, widget navigation system |
| SC-003 | Implement `ShowNowPlayingIntent` as convenience intent | P1 | Low | SC-002 |
| SC-004 | Implement `ToggleMediaIntent` with play/pause/toggle states | P0 | Low | App Intents, MediaController |
| SC-005 | Implement `NextTrackIntent` | P0 | Low | MediaController |
| SC-006 | Implement `PreviousTrackIntent` | P0 | Low | MediaController |
| SC-007 | Implement `ClearShelfIntent` returning cleared count | P1 | Low | ShelfManager |
| SC-008 | Implement `ShowClipboardHistoryIntent` with feature-disabled guard | P1 | Low | SC-002, clipboard settings |
| SC-009 | Implement `ToggleHUDReplacementIntent` persisting to Defaults | P1 | Low | Defaults, HUD system |
| SC-010 | Create `NiyaShortcutsProvider` registering all intents with phrases | P1 | Medium | macOS 14+, all intents |
| SC-011 | Define `ToggleState`, `PlaybackState`, `NiyaWidgetType` AppEnum types | P0 | Low | App Intents |
| SC-012 | Define `NiyaIntentError` with localized descriptions | P0 | Low | App Intents |
| SC-013 | Shortcuts panel UI — expanded grid/list layout | P1 | Medium | SwiftUI, ShortcutEntry model |
| SC-014 | Shortcut launch via `shortcuts://run-shortcut` URL scheme | P1 | Low | NSWorkspace |
| SC-015 | ShortcutEntry model with Codable + Defaults.Serializable | P1 | Low | Defaults library |
| SC-016 | Settings UI for managing shortcut entries (add/remove/reorder) | P1 | High | SwiftUI, ShortcutEntry |
| SC-017 | SF Symbol picker in shortcut entry editor | P2 | Medium | SwiftUI |
| SC-018 | Folder filtering with segmented control in panel | P2 | Medium | ShortcutEntry.folderName |
| SC-019 | Number key 1-9 quick trigger when panel is open | P2 | Low | Key event handling |
| SC-020 | Shortcut autocomplete via Shortcuts folder scanning (best-effort) | P3 | High | File system access, macOS 14+ |
| SC-021 | Compact notch bar indicator for shortcuts | P2 | Low | Notch bar layout system |
| SC-022 | "Test" button to verify shortcut works | P2 | Low | SC-014 |
| SC-023 | Empty state with call-to-action to open settings | P1 | Low | SwiftUI |
| SC-024 | Unit tests for all AppIntent perform() methods | P0 | Medium | XCTest, mock controllers |
| SC-025 | Unit tests for ShortcutEntry model serialization | P1 | Low | XCTest |
| SC-026 | Unit tests for URL encoding of shortcut names (special characters, spaces, unicode) | P1 | Low | XCTest |

---

## 7. Testing Strategy

### Unit Tests
- Each intent's `perform()` method tested in isolation with mocked dependencies.
- `NiyaWidgetType` round-trip encoding/decoding.
- `ShortcutEntry` Codable serialization and Defaults storage.
- URL encoding edge cases: spaces, ampersands, unicode, emoji in shortcut names.

### Integration Tests
- Verify `NiyaShortcutsProvider.appShortcuts` compiles and contains expected intents.
- Verify intent parameter types resolve correctly in Shortcuts app (manual test).

### Manual Verification
- Create test shortcuts in Shortcuts.app, verify they run from the Niya panel.
- Verify intents appear in Shortcuts.app under Niya's section.
- Test Siri invocation of each phrase (macOS 14+).
- Test with no media playing — verify `NoMediaSessionError` surfaces correctly.

---

## 8. Open Questions

1. Should we support passing clipboard content as input to a shortcut? (e.g., run a text-processing shortcut on the current clipboard)
2. Do we want a "Shortcut result" callback display? The URL scheme is fire-and-forget, but we could monitor pasteboard changes as a heuristic.
3. Should we support Shortcuts input/output via the newer `AppIntent` `openAppWhenRun` vs background execution?
