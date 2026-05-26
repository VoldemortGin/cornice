# PRD 00: Master Architecture

## Product Vision

Niya transforms the MacBook notch into a powerful, beautiful Dynamic Island. It is a full-featured macOS notch utility built entirely with SwiftUI (with AppKit integration where necessary), shipping with every major feature from day one:

- **Now Playing** media controls with album art and audio visualizer
- **File Shelf** for drag-and-drop temporary file storage
- **AirDrop** quick-send from the notch
- **Calendar** glanceable upcoming events
- **System Monitors** for CPU, RAM, network throughput, and battery
- **Clipboard History** with rich preview
- **HUD Replacement** for volume, brightness, and keyboard backlight
- **Shortcuts** integration with Apple Shortcuts
- **Camera Mirror** for quick webcam preview
- **Quick Apps** launcher for frequently used apps

### Target Platform

| Requirement | Value |
|---|---|
| Minimum macOS | 14.0 Sonoma |
| Architecture | Apple Silicon (arm64) + Intel (x86_64) Universal Binary |
| Distribution | Direct download (non-App Store), notarized with Developer ID |
| Pricing model | Freemium with in-app purchase for Pro features |

### Design Principles

1. **Never steal focus.** The notch panel must never become the key or main window. Users must be able to interact with it without losing focus in their current app.
2. **Always accessible.** The panel must be reachable in every Space, including fullscreen apps and the lock screen.
3. **Zero-config useful.** Works immediately after install with sensible defaults. Every feature is independently toggleable.
4. **Native and fast.** No Electron, no web views. SwiftUI for all UI, AppKit only where SwiftUI lacks API surface (window management, event taps, private frameworks).
5. **Modular.** Each feature is an independent module with its own MVVM stack. Features can be enabled/disabled, reordered, and tested in isolation.

---

## Tech Stack

### Language & Tooling

| Component | Choice | Rationale |
|---|---|---|
| Language | Swift 5.9+ | Modern concurrency (async/await, actors), macros, Observation framework |
| UI | SwiftUI | Declarative, animation-first, native macOS rendering |
| AppKit bridge | NSHostingView / NSViewRepresentable | Window management, event taps, menu bar, NSPanel |
| Build system | Xcode project + Swift Package Manager | SPM for dependencies, Xcode for signing/notarization/entitlements |
| Min deployment | macOS 14.0 | @Observable macro, SwiftUI improvements, required API surface |

### Frameworks

#### Apple Frameworks (Public)

| Framework | Usage |
|---|---|
| SwiftUI | All UI rendering |
| AppKit | NSPanel, NSEvent, NSScreen, NSWorkspace, NSPasteboard |
| AVFoundation | Camera preview (AVCaptureSession) |
| CoreAudio | Volume get/set, audio device monitoring |
| EventKit | Calendar event access |
| IOKit | Battery info, power source monitoring |
| CoreGraphics | Display configuration, CGEvent taps |
| ServiceManagement | Login item registration (SMAppService) |
| UserNotifications | Permission prompts, optional alerts |
| UniformTypeIdentifiers | File type detection for file shelf |
| Network | NWPathMonitor for connectivity, network throughput |

#### Apple Frameworks (Private)

| Framework | Usage | Risk Mitigation |
|---|---|---|
| MediaRemote | Now Playing info, playback controls | Access via mediaremote-adapter; fallback to MRMediaRemoteGetNowPlayingInfo C API |
| CoreDisplay | Brightness get/set (CoreDisplay_Display_GetUserBrightness / SetUserBrightness) | Fallback to IOKit brightness via IODisplaySetFloatParameter |
| SkyLight | Window visibility on lock screen space (SLSSetWindowLevel, SLSSpaceSetCompatibilityMode) | Graceful degradation: hide on lock screen if unavailable |
| CGSPrivate | CGSSpace API for z-order above fullscreen apps | Feature-flagged; degrade to .floating level if unavailable |

#### Third-Party Dependencies (via SPM)

| Dependency | Version | Purpose |
|---|---|---|
| [Defaults](https://github.com/sindresorhus/Defaults) | 8.x | Type-safe UserDefaults with @Default property wrapper |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.x | Global keyboard shortcut recording and handling |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.x | Auto-update framework for direct distribution |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | 1.x | SMAppService wrapper for login item |

#### Internal Packages

| Package | Purpose |
|---|---|
| mediaremote-adapter | Perl bridge to MRMediaRemote private framework for macOS 15.4+ compatibility. Provides NowPlayingInfo struct and playback control commands. |

---

## Project Structure

```
Niya/
├── Niya.xcodeproj
├── Package.swift                          # SPM dependencies
├── NiyaApp/
│   ├── App/
│   │   ├── NiyaApp.swift                  # @main, SwiftUI App entry
│   │   ├── AppDelegate.swift              # NSApplicationDelegate for AppKit setup
│   │   ├── AppCoordinator.swift           # Global coordinator (singleton)
│   │   ├── StatusBarController.swift      # Menu bar icon and menu
│   │   └── AppLifecycle.swift             # Activation policy, login item
│   │
│   ├── Core/
│   │   ├── Window/
│   │   │   ├── NotchPanel.swift           # NSPanel subclass (non-activating)
│   │   │   ├── NotchPanelController.swift # Per-screen panel lifecycle
│   │   │   ├── PanelWindowLevel.swift     # Window level constants
│   │   │   ├── ScreenManager.swift        # Multi-monitor orchestration
│   │   │   └── MouseTracker.swift         # NSTrackingArea for hover detection
│   │   │
│   │   ├── Notch/
│   │   │   ├── NotchShape.swift           # Custom Shape for notch outline
│   │   │   ├── NotchGeometry.swift        # Notch size/position per model
│   │   │   ├── NotchDetector.swift        # Detect built-in notch vs virtual
│   │   │   └── NotchConfiguration.swift   # Per-screen notch params
│   │   │
│   │   ├── Animation/
│   │   │   ├── AnimationConstants.swift   # Spring configs, durations
│   │   │   ├── ExpandTransition.swift     # Notch expand/collapse animation
│   │   │   ├── SneakPeekAnimation.swift   # Temporary peek for HUD/alerts
│   │   │   └── BouncySpring.swift         # Custom spring interpolation
│   │   │
│   │   ├── Permissions/
│   │   │   ├── PermissionManager.swift    # Centralized permission checks
│   │   │   ├── AccessibilityPermission.swift
│   │   │   ├── CameraPermission.swift
│   │   │   ├── CalendarPermission.swift
│   │   │   └── PermissionOnboardingView.swift
│   │   │
│   │   └── PrivateAPI/
│   │       ├── CGSPrivate.swift           # CGSSpace, CGSWindow bindings
│   │       ├── SkyLightBridge.swift       # Lock screen space API
│   │       ├── CoreDisplayBridge.swift    # Brightness get/set
│   │       └── MediaRemoteBridge.swift    # MRMediaRemote C function wrappers
│   │
│   ├── Features/
│   │   ├── MediaPlayer/
│   │   │   ├── Models/
│   │   │   │   ├── NowPlayingInfo.swift   # Track title, artist, album art, duration, elapsed
│   │   │   │   └── PlaybackState.swift    # playing, paused, stopped
│   │   │   ├── ViewModels/
│   │   │   │   └── MusicManager.swift     # @Observable, subscribes to MediaRemote notifications
│   │   │   ├── Views/
│   │   │   │   ├── MediaPlayerView.swift          # Expanded media controls
│   │   │   │   ├── MediaCompactView.swift         # Collapsed inline (album art + title)
│   │   │   │   ├── AlbumArtView.swift             # Async image loading with placeholder
│   │   │   │   ├── PlaybackControlsView.swift     # Play/pause, skip, scrub bar
│   │   │   │   └── AudioVisualizerView.swift      # Live audio waveform (CoreAudio tap)
│   │   │   └── Services/
│   │   │       ├── MediaRemoteService.swift       # Wraps mediaremote-adapter
│   │   │       └── AudioVisualizerService.swift   # Audio tap for waveform data
│   │   │
│   │   ├── FileShelf/
│   │   │   ├── Models/
│   │   │   │   ├── ShelfItem.swift        # URL, thumbnail, file type, timestamp
│   │   │   │   └── ShelfPersistence.swift # Bookmark data for sandbox-safe persistence
│   │   │   ├── ViewModels/
│   │   │   │   └── FileShelfViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── FileShelfView.swift    # Grid of shelf items
│   │   │   │   ├── ShelfItemView.swift    # Single item with thumbnail
│   │   │   │   └── ShelfDropZone.swift    # Drop target overlay
│   │   │   └── Services/
│   │   │       ├── DragDetector.swift     # Global drag monitoring (NSEvent.addGlobalMonitorForEvents)
│   │   │       └── ThumbnailGenerator.swift # QuickLookThumbnailing
│   │   │
│   │   ├── AirDrop/
│   │   │   ├── Models/
│   │   │   │   └── AirDropRecipient.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── AirDropViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── AirDropView.swift
│   │   │   │   └── AirDropRecipientView.swift
│   │   │   └── Services/
│   │   │       └── AirDropService.swift   # NSSharingService(named: .sendViaAirDrop)
│   │   │
│   │   ├── Calendar/
│   │   │   ├── Models/
│   │   │   │   └── CalendarEvent.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── CalendarViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── CalendarWidgetView.swift       # Compact: next event countdown
│   │   │   │   └── CalendarExpandedView.swift     # Expanded: upcoming events list
│   │   │   └── Services/
│   │   │       └── CalendarService.swift  # EKEventStore wrapper
│   │   │
│   │   ├── SystemMonitor/
│   │   │   ├── Models/
│   │   │   │   ├── CPUUsage.swift
│   │   │   │   ├── MemoryUsage.swift
│   │   │   │   ├── NetworkThroughput.swift
│   │   │   │   └── BatteryInfo.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── SystemMonitorViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── SystemMonitorView.swift        # Combined dashboard
│   │   │   │   ├── CPUGaugeView.swift
│   │   │   │   ├── MemoryGaugeView.swift
│   │   │   │   ├── NetworkSpeedView.swift
│   │   │   │   └── BatteryView.swift
│   │   │   └── Services/
│   │   │       ├── CPUMonitorService.swift        # host_processor_info via Mach
│   │   │       ├── MemoryMonitorService.swift     # host_statistics64 via Mach
│   │   │       ├── NetworkMonitorService.swift    # getifaddrs + NWPathMonitor
│   │   │       └── BatteryMonitorService.swift    # IOKit IOPSCopyPowerSourcesInfo
│   │   │
│   │   ├── ClipboardHistory/
│   │   │   ├── Models/
│   │   │   │   └── ClipboardEntry.swift   # Content (text/image/file), timestamp, pinned
│   │   │   ├── ViewModels/
│   │   │   │   └── ClipboardViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── ClipboardHistoryView.swift
│   │   │   │   └── ClipboardEntryView.swift
│   │   │   └── Services/
│   │   │       └── ClipboardMonitor.swift # Timer-based NSPasteboard.changeCount polling
│   │   │
│   │   ├── HUDReplacement/
│   │   │   ├── Models/
│   │   │   │   └── HUDEvent.swift         # volume, brightness, keyboardBacklight, with level 0..1
│   │   │   ├── ViewModels/
│   │   │   │   └── HUDViewModel.swift
│   │   │   ├── Views/
│   │   │   │   ├── HUDView.swift          # Animated bar in notch
│   │   │   │   ├── VolumeHUDView.swift
│   │   │   │   └── BrightnessHUDView.swift
│   │   │   └── Services/
│   │   │       ├── HUDInterceptor.swift   # CGEvent tap for media keys (NX_KEYTYPE_SOUND_UP, etc.)
│   │   │       ├── VolumeService.swift    # CoreAudio kAudioHardwareServiceDeviceProperty_VirtualMainVolume
│   │   │       ├── BrightnessService.swift # CoreDisplay or IOKit fallback
│   │   │       └── KeyboardBacklightService.swift # IOKit keyboard backlight
│   │   │
│   │   ├── Shortcuts/
│   │   │   ├── Models/
│   │   │   │   └── ShortcutItem.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── ShortcutsViewModel.swift
│   │   │   ├── Views/
│   │   │   │   └── ShortcutsView.swift
│   │   │   └── Services/
│   │   │       └── ShortcutsService.swift # WFWorkflowController or shell to `shortcuts run`
│   │   │
│   │   ├── Mirror/
│   │   │   ├── ViewModels/
│   │   │   │   └── MirrorViewModel.swift
│   │   │   ├── Views/
│   │   │   │   └── MirrorView.swift       # AVCaptureVideoPreviewLayer hosted in NSViewRepresentable
│   │   │   └── Services/
│   │   │       └── CameraService.swift    # AVCaptureSession management
│   │   │
│   │   └── QuickApps/
│   │       ├── Models/
│   │       │   └── QuickApp.swift         # Bundle ID, name, icon
│   │       ├── ViewModels/
│   │       │   └── QuickAppsViewModel.swift
│   │       ├── Views/
│   │       │   └── QuickAppsView.swift
│   │       └── Services/
│   │           └── AppLaunchService.swift # NSWorkspace.open
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift             # Main settings window (tabbed)
│   │   ├── GeneralSettingsView.swift
│   │   ├── AppearanceSettingsView.swift
│   │   ├── FeaturesSettingsView.swift     # Per-feature enable/disable toggles
│   │   ├── AboutView.swift
│   │   └── SettingsKeys.swift             # All Defaults.Key declarations
│   │
│   ├── Shared/
│   │   ├── Extensions/
│   │   │   ├── NSScreen+Notch.swift       # Notch detection, safe area insets
│   │   │   ├── NSImage+Resize.swift
│   │   │   ├── Color+Hex.swift
│   │   │   ├── View+ConditionalModifier.swift
│   │   │   └── CGRect+Helpers.swift
│   │   ├── Utilities/
│   │   │   ├── Logger.swift               # os.Logger wrappers per subsystem
│   │   │   ├── Debouncer.swift
│   │   │   └── WeakArray.swift            # Weak reference collection
│   │   └── Constants/
│   │       ├── AppConstants.swift         # Bundle ID, app name, URLs
│   │       └── AnimationPresets.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Sounds/                        # HUD feedback sounds
│       └── Niya.entitlements
│
├── NiyaHelper/                            # XPC helper for privileged ops
│   ├── NiyaHelper.swift
│   ├── HelperProtocol.swift
│   └── Info.plist
│
├── NiyaTests/
│   ├── Core/
│   ├── Features/
│   └── TestHelpers/
│
└── NiyaUITests/
```

### Feature Module MVVM Convention

Every feature follows this internal structure:

```
Feature/
├── Models/          # Plain data types (structs, enums). No imports of SwiftUI.
├── ViewModels/      # @Observable classes. Depend on Models and Services.
├── Views/           # SwiftUI views. Depend on ViewModels (via @State or @Environment).
└── Services/        # System API wrappers. Pure logic, no UI. Async where possible.
```

Rules:
- **Models** are `Sendable` structs or enums. They own no state and have no side effects.
- **ViewModels** are `@Observable` classes annotated `@MainActor`. They expose published properties and action methods.
- **Views** receive their ViewModel as `@State` (owned) or `@Environment` (shared). Views contain zero business logic.
- **Services** are injected into ViewModels. They are protocol-based for testability. System API calls live only in Services.

---

## Architecture Decisions

### AD-01: Window — Non-Activating NSPanel

The notch panel is an `NSPanel` subclass with these critical properties:

```swift
class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

Configuration:
- `styleMask`: `.borderless | .nonactivatingPanel | .fullSizeContentView`
- `level`: `.mainMenu + 3` (above menu bar, below screen saver)
- `collectionBehavior`: `.canJoinAllSpaces | .stationary | .fullScreenAuxiliary | .ignoresCycle`
- `isOpaque`: `false`
- `backgroundColor`: `.clear`
- `hasShadow`: `false`
- `ignoresMouseEvents`: `false` (accepts mouse, but never activates)

The panel hosts a single `NSHostingView<NotchContentView>` as its content view.

**Rationale:** NSPanel with `.nonactivatingPanel` is the only way to receive mouse events without stealing focus from the user's current app. This is the same approach used by Spotlight, menu bar extras, and Boring.Notch.

### AD-02: Z-Order — Above Fullscreen Apps

Standard NSWindow levels cannot appear above fullscreen apps. We use `CGSSpace` private API:

```swift
// Add the panel's window to the fullscreen space
let spaceID = CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), screenUUID)
CGSAddWindowToSpace(CGSMainConnectionID(), panel.windowNumber, spaceID)
```

Combined with `.fullScreenAuxiliary` collection behavior, this ensures visibility in fullscreen mode.

**Fallback:** If CGSSpace API is unavailable (future macOS version), degrade to `.floating` window level. The panel will be hidden during fullscreen apps. Users can opt in to "reduced mode" in settings.

### AD-03: Media — MRMediaRemote via Adapter

macOS 15.4 broke direct linking to `/System/Library/PrivateFrameworks/MediaRemote.framework`. The solution is a Perl-based adapter (mediaremote-adapter) that:

1. Loads MediaRemote.framework via Objective-C bridge at runtime
2. Exposes a JSON-based IPC protocol over stdout/stdin
3. Publishes now-playing info changes as JSON events

The `MediaRemoteService` spawns this adapter as a child process and parses its output.

**Data flow:**

```
MediaRemote.framework
    └─▶ mediaremote-adapter (Perl process)
         └─▶ JSON over pipe
              └─▶ MediaRemoteService (Swift, parses JSON)
                   └─▶ MusicManager (@Observable ViewModel)
                        └─▶ MediaPlayerView (SwiftUI)
```

**Fallback chain:**
1. mediaremote-adapter (preferred, works on macOS 15.4+)
2. Direct MRMediaRemote C function calls via dlopen (macOS < 15.4)
3. NSDistributedNotificationCenter for basic now-playing info (least data, always works)

### AD-04: HUD Replacement — CGEvent Tap Interception

To replace the system HUD for volume/brightness, we intercept hardware key events before they reach the system:

```swift
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << NX_SYSDEFINED),
    callback: hudEventCallback,
    userInfo: pointer
)
```

The callback inspects `NX_KEYTYPE_SOUND_UP`, `NX_KEYTYPE_SOUND_DOWN`, `NX_KEYTYPE_ILLUMINATION_UP`, etc., suppresses the system event (returns `nil`), and routes to `HUDViewModel`.

**Requirements:**
- Accessibility permission (Settings > Privacy & Security > Accessibility)
- The event tap is registered in `HUDInterceptor` which manages the `CFRunLoopSource`

**Volume control:** `AudioObjectSetPropertyData` with `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the default output device.

**Brightness control:** `CoreDisplay_Display_SetUserBrightness` (private API). Fallback: `IODisplaySetFloatParameter` via IOKit.

**Keyboard backlight:** `IOKit` calls to `AppleLMUController` service.

### AD-05: Settings — Defaults Library

All persistent settings use sindresorhus/Defaults with `@Default` property wrapper:

```swift
// SettingsKeys.swift
extension Defaults.Keys {
    static let isEnabled = Key<Bool>("isEnabled", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: true)
    static let enabledFeatures = Key<Set<FeatureID>>("enabledFeatures", default: FeatureID.allCases.asSet)
    static let mediaPlayerStyle = Key<MediaPlayerStyle>("mediaPlayerStyle", default: .standard)
    static let hudAnimationStyle = Key<HUDAnimationStyle>("hudAnimationStyle", default: .smooth)
    static let fileShelfMaxItems = Key<Int>("fileShelfMaxItems", default: 20)
    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 50)
}
```

**Usage in ViewModels:**

```swift
@Observable
class MusicManager {
    @ObservationIgnored
    @Default(.mediaPlayerStyle) var style
}
```

**Structural changes** (e.g., enabling/disabling a feature) additionally post a `NotificationCenter` notification so that the panel can rebuild its view hierarchy.

### AD-06: Multi-Monitor — Per-Screen ViewModel

See [PRD 13: Multi-Monitor](./13-multi-monitor.md) for full specification.

Summary: Each notch-equipped screen gets its own `NotchPanel` + `NotchPanelController`. A `ScreenManager` singleton detects screens, creates/destroys controllers on hot-plug, and routes events to the correct screen.

### AD-07: Distribution — Direct, Notarized

Niya is distributed outside the App Store to allow:
- Private framework usage (MediaRemote, CoreDisplay, SkyLight, CGSPrivate)
- CGEvent tap for HUD interception
- XPC helper for privileged operations
- Unrestricted entitlements

**Entitlements** (`Niya.entitlements`):

```xml
<key>com.apple.security.app-sandbox</key>        <false/>
<key>com.apple.security.cs.disable-library-validation</key>  <true/>
<key>com.apple.security.device.camera</key>      <true/>
<key>com.apple.security.personal-information.calendars</key>  <true/>
```

Note: App sandbox is disabled. The hardened runtime is enabled (required for notarization) with `disable-library-validation` to load private frameworks.

**Auto-update:** Sparkle framework with EdDSA-signed appcast. Update checks on launch + every 6 hours.

### AD-08: Non-Notch Macs — Virtual Notch

For MacBooks without a notch (pre-2021) and external displays:

1. `NotchDetector` checks `NSScreen.safeAreaInsets.top > 0` to identify notch screens
2. For non-notch screens, a virtual notch bar is rendered at top-center
3. Virtual notch dimensions: 220pt wide x 32pt tall (matches iPhone Dynamic Island proportions)
4. The virtual notch has a subtle dark background shape to visually anchor it
5. All features work identically on virtual notch

**Setting:** Users can choose per-screen: "Auto-detect", "Force notch", "Force virtual bar", "Disabled".

### AD-09: XPC Helper — Privilege Separation

The `NiyaHelper` XPC service runs in a separate process for operations that benefit from privilege separation:

**Operations:**
- Display brightness set/get (requires IOKit access)
- Keyboard backlight control
- Accessibility permission status check (without triggering the prompt)
- System sleep/wake notifications

**Protocol:**

```swift
@objc protocol NiyaHelperProtocol {
    func getBrightness(for displayID: UInt32, reply: @escaping (Float) -> Void)
    func setBrightness(for displayID: UInt32, value: Float, reply: @escaping (Bool) -> Void)
    func getKeyboardBacklight(reply: @escaping (Float) -> Void)
    func setKeyboardBacklight(value: Float, reply: @escaping (Bool) -> Void)
}
```

The helper is embedded in the app bundle at `Contents/Library/LoginItems/NiyaHelper.app` and registered via `SMAppService`.

### AD-10: Lock Screen Visibility

To show the notch panel on the lock screen, we use the SkyLight private framework:

```swift
// Move panel to lock screen space
SLSSetWindowLevel(CGSMainConnectionID(), panel.windowNumber, kCGScreenSaverWindowLevel + 1)
SLSSpaceSetCompatibilityMode(CGSMainConnectionID(), lockScreenSpaceID, 0x1)
```

**Behavior on lock screen:**
- Media controls are visible and interactive (matches macOS behavior for media on lock screen)
- System monitors remain visible
- File shelf, clipboard history, and camera mirror are hidden (privacy)
- Calendar shows only "next event in X minutes" without event details

**Fallback:** If SkyLight API is unavailable, the panel is simply hidden on the lock screen. This is the safe default.

---

## Data Flow

### Global State Architecture

```
┌─────────────────────────────────────────────────┐
│                  AppCoordinator                  │
│              (singleton, @MainActor)             │
│                                                  │
│  - currentView: NotchViewState                   │
│  - sneakPeekState: SneakPeekState?               │
│  - hudState: HUDState?                           │
│  - isExpanded: Bool                              │
│  - activeScreenID: CGDirectDisplayID?            │
│                                                  │
│  Owns:                                           │
│  - ScreenManager (multi-monitor)                 │
│  - MusicManager (shared media state)             │
│  - PermissionManager                             │
│  - HUDViewModel (shared HUD state)               │
└──────────┬──────────────────────┬────────────────┘
           │                      │
    ┌──────▼──────┐       ┌──────▼──────┐
    │  Screen A   │       │  Screen B   │
    │  Controller │       │  Controller │
    │             │       │             │
    │ NotchPanel  │       │ NotchPanel  │
    │ + hosting   │       │ + hosting   │
    │   view      │       │   view      │
    └──────┬──────┘       └──────┬──────┘
           │                      │
    ┌──────▼──────┐       ┌──────▼──────┐
    │ Per-Screen  │       │ Per-Screen  │
    │ ViewModel   │       │ ViewModel   │
    │             │       │             │
    │ - screenID  │       │ - screenID  │
    │ - notchGeo  │       │ - notchGeo  │
    │ - expanded  │       │ - expanded  │
    │ - features  │       │ - features  │
    └─────────────┘       └─────────────┘
```

### State Categories

| Category | Owner | Scope | Propagation |
|---|---|---|---|
| App-wide state | AppCoordinator | Global | @Observable, direct reference |
| Media playback | MusicManager | Global (one now-playing across screens) | @Observable |
| HUD events | HUDViewModel | Global (event triggers on any screen) | @Observable + route to active screen |
| Per-screen layout | NotchPanelController | Per-screen | @Observable on per-screen ViewModel |
| Feature state | Feature ViewModel | Per-feature | @Observable, owned by per-screen ViewModel or shared |
| Persistent settings | Defaults | Global | @Default property wrapper, NotificationCenter for structural |

### Media Data Flow (Detailed)

```
┌──────────────────┐
│ MediaRemote.fwk  │
│ (system daemon)  │
└────────┬─────────┘
         │ MRMediaRemoteRegisterForNowPlayingNotifications
         ▼
┌──────────────────┐
│ mediaremote-     │  spawned as child process
│ adapter (Perl)   │  communicates via stdin/stdout JSON
└────────┬─────────┘
         │ {"event":"nowPlayingChanged","data":{...}}
         ▼
┌──────────────────┐
│ MediaRemote-     │  parses JSON, decodes to NowPlayingInfo
│ Service.swift    │  manages adapter lifecycle
└────────┬─────────┘
         │ async stream of NowPlayingInfo
         ▼
┌──────────────────┐
│ MusicManager     │  @Observable, @MainActor
│ (ViewModel)      │  exposes: nowPlaying, isPlaying, artwork
│                  │  actions: play(), pause(), next(), previous()
└────────┬─────────┘
         │ SwiftUI observation
         ▼
┌──────────────────┐
│ MediaPlayerView  │  reads MusicManager via @Environment
│ (SwiftUI)        │  renders album art, controls, visualizer
└──────────────────┘
```

### HUD Data Flow (Detailed)

```
┌────────────────┐
│ Hardware Key    │  user presses volume up/down on keyboard
│ (NX_SYSDEFINED)│
└───────┬────────┘
        │ CGEvent tap (headInsert, .defaultTap)
        ▼
┌────────────────┐
│ HUDInterceptor │  filters NX_KEYTYPE_SOUND_*, NX_KEYTYPE_ILLUMINATION_*
│ (Service)      │  returns nil to suppress system HUD
│                │  notifies HUDViewModel
└───────┬────────┘
        │ HUDEvent(type: .volume, level: 0.75)
        ▼
┌────────────────┐
│ HUDViewModel   │  @Observable, @MainActor
│                │  manages auto-dismiss timer (2s)
│                │  sneak-peek animation trigger
└───────┬────────┘
        │ tells AppCoordinator to show sneak peek
        ▼
┌────────────────┐
│ AppCoordinator │  sets sneakPeekState = .hud(event)
│                │  routes to active screen's panel
└───────┬────────┘
        │
        ▼
┌────────────────┐
│ NotchPanel     │  animates expansion to show HUD
│ (active screen)│  auto-collapses after timeout
└───────┬────────┘
        │ SwiftUI observation
        ▼
┌────────────────┐
│ HUDView        │  animated volume/brightness bar
│ (SwiftUI)      │  icon + level indicator
└────────────────┘
```

### Settings Data Flow

```
┌─────────────────┐     @Default property wrapper
│  SettingsView    │ ──────────────────────────────┐
│  (SwiftUI)      │     writes to UserDefaults     │
└─────────────────┘                                │
                                                   ▼
                                          ┌─────────────────┐
                                          │  UserDefaults    │
                                          │  (Defaults lib)  │
                                          └────────┬────────┘
                                                   │
                        ┌──────────────────────────┼──────────────────────────┐
                        │ KVO observation          │ KVO observation          │ NotificationCenter
                        ▼                          ▼                          ▼
                ┌───────────────┐          ┌───────────────┐          ┌───────────────┐
                │ ViewModel A   │          │ ViewModel B   │          │ ScreenManager  │
                │ (@Default)    │          │ (@Default)    │          │ (rebuilds UI)  │
                └───────────────┘          └───────────────┘          └───────────────┘
```

---

## Lifecycle

### App Startup Sequence

```
1. NiyaApp.init()
   └─▶ AppDelegate.applicationDidFinishLaunching()
       ├─▶ Set activation policy to .accessory (no dock icon)
       ├─▶ PermissionManager.checkAll()
       ├─▶ StatusBarController.setup() (menu bar icon)
       ├─▶ AppCoordinator.shared.start()
       │   ├─▶ ScreenManager.detectScreens()
       │   │   └─▶ For each screen: create NotchPanelController
       │   │       └─▶ NotchPanel positioned over notch
       │   │           └─▶ NSHostingView<NotchContentView>
       │   ├─▶ MusicManager.startListening()
       │   ├─▶ HUDInterceptor.install() (if accessibility permitted)
       │   ├─▶ ClipboardMonitor.start()
       │   └─▶ SystemMonitorService.start()
       └─▶ Sparkle.SUUpdater.checkForUpdatesInBackground()
```

### Notch Interaction States

```
┌─────────┐  mouse hover   ┌──────────┐  click/expand    ┌──────────┐
│ Closed  │ ──────────────▶ │ Peeking  │ ───────────────▶ │ Expanded │
│ (idle)  │ ◀────────────── │ (compact)│ ◀─────────────── │ (full)   │
└─────────┘  mouse exit     └──────────┘  click/mouse exit └──────────┘
     ▲                            │                              │
     │                            │ HUD/alert                    │
     │                       ┌────▼─────┐                        │
     │                       │ SneakPeek│                        │
     └───────────────────────│ (timed)  │────────────────────────┘
                             └──────────┘
                              auto-dismiss (2s)
```

| State | Panel Size | Content | Trigger |
|---|---|---|---|
| Closed | Matches physical notch exactly | Nothing (transparent) | Default, mouse exit, click outside |
| Peeking | Slightly larger than notch | Compact media info, tiny indicators | Mouse hover over notch area |
| Expanded | Large dropdown from notch | Full feature views, tabs | Click on notch, global shortcut |
| Sneak Peek | Slightly larger than notch | HUD bar, incoming alert | Volume/brightness change, notification |

---

## Testing Strategy

### Unit Tests (NiyaTests/)

| Layer | What to Test | Mocking Strategy |
|---|---|---|
| Models | Encoding/decoding, equality, computed properties | None needed |
| ViewModels | State transitions, action results, error handling | Protocol-based service mocks |
| Services | API call formatting, response parsing, error mapping | Mock system APIs via protocols |

### Integration Tests

| Scenario | Approach |
|---|---|
| Multi-monitor | Mock NSScreen array with varying configurations |
| Media flow | Mock MediaRemoteService, verify MusicManager state transitions |
| HUD flow | Inject synthetic HUDEvents, verify sneak peek timing |
| Settings | Write to in-memory UserDefaults suite, verify propagation |

### UI Tests (NiyaUITests/)

| Scenario | Approach |
|---|---|
| Hover expand | Use CGEvent to synthesize mouse move into notch area |
| Click interaction | Verify panel expands, shows correct feature tab |
| File shelf drag | Programmatic drag via NSDraggingSession |

### Test Principles

1. All Services are protocol-based. Every ViewModel receives its dependencies via init injection.
2. `@MainActor` ViewModels are testable with `@MainActor` test functions.
3. Private API calls are wrapped in single-method protocols so they can be swapped in tests.
4. No test depends on real hardware (camera, notch, multiple monitors).

---

## Security Considerations

1. **File Shelf:** Files stored as security-scoped bookmarks. Bookmark data is encrypted at rest via Data Protection (FileProtectionType.complete).
2. **Clipboard History:** Stored in-memory only by default. Optional persistence uses Keychain for sensitive entries. Auto-purge after configurable TTL.
3. **Camera Mirror:** AVCaptureSession is created on-demand and torn down when mirror view is dismissed. No frames are persisted.
4. **Private APIs:** All private API calls are wrapped in availability checks and try/catch. App degrades gracefully if APIs change.
5. **XPC Helper:** Communication uses NSXPCConnection with strict interface type checking. Helper validates the calling app's code signature.

---

## Performance Targets

| Metric | Target |
|---|---|
| Cold launch to visible panel | < 500ms |
| Hover to peek animation start | < 16ms (1 frame at 60fps) |
| Expand animation duration | 300ms (spring) |
| Idle CPU usage | < 0.5% (no media playing) |
| Idle memory | < 50MB |
| Media playing CPU | < 2% (with visualizer) |
| System monitor polling interval | 2s (configurable) |
| Clipboard polling interval | 500ms |
