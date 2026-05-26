# PRD-08: Custom HUD Replacement (Volume / Brightness / Keyboard Backlight)

## 1. Overview

Niya replaces the macOS system volume, display brightness, and keyboard backlight HUDs with custom overlays rendered inside the Dynamic Island notch area. The system HUD is suppressed by intercepting the underlying hardware key events via a `CGEvent` tap and handling the volume/brightness adjustments directly through CoreAudio and CoreDisplay private APIs.

A privileged **XPC helper** handles operations that require different entitlements (display brightness via `DisplayServices`, keyboard backlight via IOKit).

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Niya (main app)                       │
│                                                         │
│  ┌───────────────┐   ┌──────────────┐   ┌───────────┐  │
│  │ HIDKeyMonitor │──>│ HUDManager   │──>│ HUDView   │  │
│  │ (CGEvent tap) │   │ (coordinator)│   │ (SwiftUI) │  │
│  └───────────────┘   └──────┬───────┘   └───────────┘  │
│                             │                           │
│              ┌──────────────┼──────────────┐            │
│              │              │              │            │
│  ┌───────────▼──┐  ┌───────▼──────┐  ┌───▼──────────┐ │
│  │VolumeControl │  │ XPCClient    │  │ KeyboardBL   │ │
│  │ (CoreAudio)  │  │              │  │ (via XPC)    │ │
│  └──────────────┘  └───────┬──────┘  └──────────────┘ │
│                            │                           │
└────────────────────────────┼───────────────────────────┘
                             │ XPC connection
┌────────────────────────────▼───────────────────────────┐
│              NiyaHelper (XPC service)                   │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ DisplayBrightness│  │ KeyboardBacklightService   │  │
│  │ (CoreDisplay)    │  │ (IOKit)                    │  │
│  └──────────────────┘  └────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Key Interception: HIDKeyMonitor

### 3.1 CGEvent Tap Setup

```swift
final class HIDKeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() throws {
        let mask: CGEventMask = 1 << CGEventType.systemDefined.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,           // intercept at HID level
            place: .headInsertEventTap,     // before other taps
            options: .defaultTap,           // active tap (can modify/swallow)
            eventsOfInterest: mask,
            callback: hidEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HUDError.eventTapCreationFailed
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
```

### 3.2 Event Parsing

The callback receives `NX_SYSDEFINED` events with subtype 8 (media/special keys).

```swift
private func hidEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard type == .systemDefined else {
        return Unmanaged.passRetained(event)
    }

    let nsEvent = NSEvent(cgEvent: event)!
    guard nsEvent.subtype.rawValue == 8 else {
        return Unmanaged.passRetained(event)
    }

    let data1 = nsEvent.data1
    let keyCode    = (data1 & 0xFFFF0000) >> 16
    let keyFlags   = (data1 & 0x0000FF00) >> 8
    let keyState   = (keyFlags & 0x01)          // 0 = key up, 1 = key down (NX_KEYTYPE_SOUND_UP uses bit 0 inverted in some docs)
    let isKeyDown  = ((data1 & 0xFF00) >> 8) & 0x0A != 0  // more reliable: check bit pattern
    let isRepeat   = (keyFlags & 0x02) != 0

    let modifiers  = nsEvent.modifierFlags

    // ... dispatch based on keyCode
}
```

### 3.3 Key Code Mapping

| Key Code | Constant | Key |
|----------|----------|-----|
| 0 | `NX_KEYTYPE_SOUND_UP` | Volume Up |
| 1 | `NX_KEYTYPE_SOUND_DOWN` | Volume Down |
| 2 | `NX_KEYTYPE_BRIGHTNESS_UP` | Display Brightness Up |
| 3 | `NX_KEYTYPE_BRIGHTNESS_DOWN` | Display Brightness Down |
| 7 | `NX_KEYTYPE_MUTE` | Mute Toggle |
| 21 | `NX_KEYTYPE_ILLUMINATION_UP` | Keyboard Backlight Up |
| 22 | `NX_KEYTYPE_ILLUMINATION_DOWN` | Keyboard Backlight Down |

### 3.4 Event Swallowing

To prevent the system HUD from appearing, the callback returns `nil` for intercepted key codes:

```swift
// Key matched and handled -> swallow the event
return nil

// Key not matched -> pass through
return Unmanaged.passRetained(event)
```

### 3.5 Modifier Key Handling

| Modifier Combination | Behavior |
|----------------------|----------|
| No modifier | Standard adjustment (1/16 step). |
| Option (alone) + Volume Up/Down | Open System Settings > Sound. |
| Option (alone) + Brightness Up/Down | Open System Settings > Displays. |
| Option + Shift + Volume Up/Down | Fine adjustment (1/64 step, i.e., 1/4 of standard step). |
| Option + Shift + Brightness Up/Down | Fine adjustment (1/64 step). |

Detection:

```swift
let hasOption = modifiers.contains(.option)
let hasShift  = modifiers.contains(.shift)

if hasOption && !hasShift {
    // Open System Settings pane
    openSystemSettings(for: keyCode)
    return nil
}

let stepSize: Float = (hasOption && hasShift) ? (1.0 / 64.0) : (1.0 / 16.0)
```

### 3.6 Permission: Accessibility

`CGEvent.tapCreate` with `.defaultTap` (active, can swallow events) requires the app to be in System Settings > Privacy & Security > Accessibility.

If the tap cannot be created (permission denied), `HIDKeyMonitor.start()` throws `HUDError.accessibilityPermissionDenied`. The app should:

1. Show a one-time dialog explaining why the permission is needed.
2. Open `tccutil` or deep-link: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
3. Retry on `NSWorkspace.shared.notificationCenter` app activation.

---

## 4. Volume Control

### 4.1 CoreAudio API

```swift
import CoreAudio

struct VolumeControl {
    /// Get/set the default output device volume (0.0 ... 1.0).
    static var volume: Float {
        get {
            var deviceID = defaultOutputDeviceID
            var volume: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
            return volume
        }
        set {
            var deviceID = defaultOutputDeviceID
            var volume = newValue.clamped(to: 0.0...1.0)
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &volume)
        }
    }

    /// Get/set mute state.
    static var isMuted: Bool {
        get { /* kAudioDevicePropertyMute, scope output */ }
        set { /* kAudioDevicePropertyMute, scope output */ }
    }

    /// Resolve the current default output device.
    private static var defaultOutputDeviceID: AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }
}
```

### 4.2 Step Sizes

| Context | Step Size | Value |
|---------|-----------|-------|
| Standard | 1/16 | 0.0625 |
| Fine (Option+Shift) | 1/64 | 0.015625 |

Volume is clamped to `[0.0, 1.0]` after each step.

### 4.3 Mute Toggle

- Key code 7 (`NX_KEYTYPE_MUTE`) toggles `VolumeControl.isMuted`.
- When unmuting, restore the volume to the level it was before muting (stored in a local variable, not persisted).
- HUD shows the mute icon and 0% when muted; on unmute, shows the restored level.

### 4.4 Volume Tick Sound

After adjusting volume (not when muting/unmuting), play the system volume tick:

```swift
import AppKit

let tickSoundPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"

func playVolumeTick() {
    guard let sound = NSSound(contentsOfFile: tickSoundPath, byReference: true) else { return }
    sound.play()
}
```

The tick sound is suppressed during fine adjustment (Option+Shift) to match macOS behavior.

### 4.5 External Volume Change Monitoring

Register a listener so the HUD appears when volume is changed by other means (e.g., Control Center, another app):

```swift
AudioObjectAddPropertyListenerBlock(
    deviceID,
    &volumeAddress,
    DispatchQueue.main
) { _, _ in
    // Read new volume, show HUD briefly
}
```

Also monitor default device changes (e.g., switching from speakers to headphones):

```swift
AudioObjectAddPropertyListenerBlock(
    AudioObjectID(kAudioObjectSystemObject),
    &defaultDeviceAddress,
    DispatchQueue.main
) { _, _ in
    // Re-register volume listener on new device
}
```

---

## 5. Brightness Control

### 5.1 CoreDisplay Private API

Display brightness requires the private `CoreDisplay` framework loaded via `dlopen`.

```swift
import Foundation

final class DisplayBrightnessControl {
    typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID) -> Double
    typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Double) -> Void

    private let getBrightness: GetBrightnessFn
    private let setBrightness: SetBrightnessFn

    init() throws {
        guard let handle = dlopen(
            "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
            RTLD_LAZY
        ) else {
            throw HUDError.frameworkLoadFailed("CoreDisplay")
        }

        guard let getPtr = dlsym(handle, "CoreDisplay_Display_GetUserBrightness"),
              let setPtr = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else {
            throw HUDError.symbolNotFound("CoreDisplay brightness functions")
        }

        self.getBrightness = unsafeBitCast(getPtr, to: GetBrightnessFn.self)
        self.setBrightness = unsafeBitCast(setPtr, to: SetBrightnessFn.self)
    }

    var brightness: Double {
        get { getBrightness(CGMainDisplayID()) }
        set { setBrightness(CGMainDisplayID(), newValue.clamped(to: 0.0...1.0)) }
    }
}
```

### 5.2 Step Sizes

| Context | Step Size | Value |
|---------|-----------|-------|
| Standard | 1/16 | 0.0625 |
| Fine (Option+Shift) | 1/64 | 0.015625 |

Brightness is clamped to `[0.0, 1.0]`.

### 5.3 XPC Alternative

If direct `dlopen` of CoreDisplay fails (sandboxing, SIP policy changes), the main app delegates to the XPC helper which has a different entitlement profile. See Section 7.

---

## 6. Keyboard Backlight Control

Keyboard backlight is controlled via IOKit, which may require elevated privileges on some configurations.

```swift
import IOKit

final class KeyboardBacklightControl {
    private var connect: io_connect_t = 0

    init() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleLMUController")
        )
        guard service != IO_OBJECT_NULL else {
            throw HUDError.serviceNotFound("AppleLMUController")
        }
        let kr = IOServiceOpen(service, mach_task_self_, 0, &connect)
        IOObjectRelease(service)
        guard kr == KERN_SUCCESS else {
            throw HUDError.ioServiceOpenFailed(kr)
        }
    }

    deinit {
        if connect != 0 { IOServiceClose(connect) }
    }

    var brightness: Float {
        get {
            var outputCount: UInt32 = 1
            var output: UInt64 = 0
            IOConnectCallScalarMethod(connect, 1, nil, 0, &output, &outputCount)
            return Float(output) / Float(UInt16.max)
        }
        set {
            let value = UInt64(newValue.clamped(to: 0.0...1.0) * Float(UInt16.max))
            var input = value
            IOConnectCallScalarMethod(connect, 2, &input, 1, nil, nil)
        }
    }
}
```

Step sizes match volume/brightness (1/16 standard, 1/64 fine).

---

## 7. XPC Helper: NiyaHelper

### 7.1 Purpose

Privilege separation. The main app runs as a regular user-level process. Some operations benefit from running in a separate XPC service with its own entitlements:

| Operation | Why XPC? |
|-----------|----------|
| Display brightness (CoreDisplay) | May require different sandbox profile; isolates private API crashes. |
| Keyboard backlight (IOKit) | IOServiceOpen may need specific entitlements. |
| Accessibility status check | Query TCC database without main app needing full disk access. |

### 7.2 XPC Protocol

```swift
@objc protocol NiyaHelperProtocol {
    // Display brightness
    func getDisplayBrightness(reply: @escaping (Double, Error?) -> Void)
    func setDisplayBrightness(_ value: Double, reply: @escaping (Error?) -> Void)

    // Keyboard backlight
    func getKeyboardBrightness(reply: @escaping (Float, Error?) -> Void)
    func setKeyboardBrightness(_ value: Float, reply: @escaping (Error?) -> Void)

    // Accessibility
    func isAccessibilityEnabled(reply: @escaping (Bool) -> Void)
}
```

### 7.3 Connection Management

```swift
final class XPCClient {
    private var connection: NSXPCConnection?

    func connect() {
        let conn = NSXPCConnection(serviceName: "com.niya.helper")
        conn.remoteObjectInterface = NSXPCInterface(with: NiyaHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            self?.connection = nil
            // Attempt reconnect after 1 second
        }
        conn.interruptionHandler = { [weak self] in
            // XPC service crashed; reconnect
            self?.connect()
        }
        conn.resume()
        self.connection = conn
    }

    var proxy: NiyaHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { error in
            // Log XPC communication error
        } as? NiyaHelperProtocol
    }
}
```

### 7.4 Deployment

The XPC service is embedded in the app bundle at `Niya.app/Contents/XPCServices/NiyaHelper.xpc`. It has its own `Info.plist` and entitlements.

---

## 8. HUD Manager (Coordinator)

`HUDManager` connects `HIDKeyMonitor` events to the correct control module and triggers the HUD UI.

```swift
@MainActor
final class HUDManager: ObservableObject {
    static let shared = HUDManager()

    @Published private(set) var activeHUD: HUDType?
    @Published private(set) var level: Double = 0      // 0.0 ... 1.0
    @Published private(set) var isMuted: Bool = false

    private let volumeControl = VolumeControl()
    private let xpcClient = XPCClient()
    private let keyMonitor = HIDKeyMonitor()
    private var dismissTask: Task<Void, Never>?
    private var preMuteVolume: Float = 0.5

    enum HUDType: Equatable {
        case volume
        case brightness
        case keyboardBrightness
    }

    func start() throws {
        try keyMonitor.start()
        keyMonitor.onKeyEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }
    }

    private func handleKeyEvent(_ event: HIDKeyEvent) {
        switch event.keyCode {
        case .soundUp, .soundDown:
            handleVolume(direction: event.keyCode == .soundUp ? .up : .down,
                         stepSize: event.stepSize)
        case .mute:
            handleMuteToggle()
        case .brightnessUp, .brightnessDown:
            handleBrightness(direction: event.keyCode == .brightnessUp ? .up : .down,
                             stepSize: event.stepSize)
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            handleKeyboardBrightness(
                direction: event.keyCode == .keyboardBrightnessUp ? .up : .down,
                stepSize: event.stepSize)
        }
    }

    private func showHUD(_ type: HUDType, level: Double) {
        self.activeHUD = type
        self.level = level
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self.activeHUD = nil
        }
    }
}
```

---

## 9. Custom HUD UI

### 9.1 Layout

The HUD renders as a **sneak peek** inside the notch area:

```
+-------------------------------------------------------+
|  [Icon]  [============================--------]  72%  |
+-------------------------------------------------------+
```

- **Icon** (20x20pt SF Symbol): changes based on HUD type and level.
- **Progress bar**: horizontal, rounded caps, filled portion colored by theme.
- **Percentage label**: right-aligned, monospaced digits for stable width.

### 9.2 Icon Selection

#### Volume

| Condition | SF Symbol |
|-----------|-----------|
| Muted (level = 0 or mute toggled) | `speaker.slash.fill` |
| 0.01 - 0.33 | `speaker.wave.1.fill` |
| 0.34 - 0.66 | `speaker.wave.2.fill` |
| 0.67 - 1.0 | `speaker.wave.3.fill` |

#### Display Brightness

| Condition | SF Symbol |
|-----------|-----------|
| 0.0 - 0.5 | `sun.min.fill` |
| 0.51 - 1.0 | `sun.max.fill` |

#### Keyboard Backlight

| Condition | SF Symbol |
|-----------|-----------|
| Any | `keyboard.badge.ellipsis` (or `light.max` for brightness-like icon) |

### 9.3 Animation

| Phase | Duration | Description |
|-------|----------|-------------|
| Appear | 200ms | Slide down from notch + fade in (ease-out). |
| Hold | 1.5s | Visible, updates in-place on repeated key presses (timer resets). |
| Dismiss | 300ms | Slide up into notch + fade out (ease-in). |

Repeated key presses while the HUD is visible:
- Update the progress bar and percentage with a 100ms spring animation.
- Reset the 1.5s dismiss timer.

### 9.4 SwiftUI View

```swift
struct HUDOverlayView: View {
    @ObservedObject var hudManager: HUDManager

    var body: some View {
        if let hudType = hudManager.activeHUD {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: hudType, level: hudManager.level, muted: hudManager.isMuted))
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(barColor(for: hudType))
                            .frame(width: geo.size.width * hudManager.level)
                            .animation(.spring(duration: 0.1), value: hudManager.level)
                    }
                }
                .frame(height: 4)

                Text("\(Int(hudManager.level * 100))%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeOut(duration: 0.2), value: hudManager.activeHUD)
        }
    }
}
```

### 9.5 Color Theming

| Source | Behavior |
|--------|----------|
| System accent color | Default. Progress bar fill uses `NSColor.controlAccentColor`. |
| Custom theme | If user has set a custom notch color theme, the HUD respects it. |
| Media dominant color | If music is playing and album-art theming is enabled, the volume HUD optionally uses the dominant color (configurable). |

---

## 10. Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Replace system HUDs | Bool | true | Master toggle. When off, key events pass through to system. |
| Show volume HUD | Bool | true | Show custom HUD for volume keys. |
| Show brightness HUD | Bool | true | Show custom HUD for brightness keys. |
| Show keyboard backlight HUD | Bool | true | Show custom HUD for keyboard backlight keys. |
| HUD dismiss delay | Double | 1.5 | Seconds before HUD auto-dismisses (0.5 - 3.0). |
| Play volume tick sound | Bool | true | Play the system volume tick on volume change. |
| Fine step multiplier | Double | 0.25 | Multiplier applied to step size for Option+Shift. Default 0.25 = 1/4 of standard step. |
| Use media color for volume HUD | Bool | false | Tint volume HUD bar with album art dominant color when music is playing. |

---

## 11. Permissions

| Permission | Why | How to Request | Fallback if Denied |
|------------|-----|----------------|-------------------|
| Accessibility | Required for `CGEvent.tapCreate` with `.defaultTap` to intercept and swallow key events. | System dialog on first launch; guide user to System Settings > Privacy > Accessibility. | HUD replacement is completely disabled. Keys pass through to macOS system HUDs. Show a settings banner: "Enable Accessibility to use custom HUDs." |

---

## 12. Error Handling

```swift
enum HUDError: Error, LocalizedError {
    case accessibilityPermissionDenied
    case eventTapCreationFailed
    case frameworkLoadFailed(String)
    case symbolNotFound(String)
    case serviceNotFound(String)
    case ioServiceOpenFailed(kern_return_t)
    case xpcConnectionFailed

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
        case .xpcConnectionFailed:
            return "Failed to connect to NiyaHelper XPC service."
        }
    }
}
```

---

## 13. Requirements

| ID | Description | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| HUD-001 | Intercept volume up/down key events via CGEvent tap at HID level. | P0 | Pressing volume keys triggers Niya's handler; system HUD does not appear. |
| HUD-002 | Intercept brightness up/down key events via CGEvent tap. | P0 | Pressing brightness keys triggers Niya's handler; system HUD does not appear. |
| HUD-003 | Intercept keyboard backlight up/down key events. | P1 | Pressing keyboard backlight keys triggers Niya's handler; system HUD does not appear. |
| HUD-004 | Intercept mute toggle key event. | P0 | Pressing mute key toggles mute state; system HUD does not appear. |
| HUD-005 | Swallow intercepted events (return nil from callback) to prevent system HUD. | P0 | No macOS system HUD overlay appears for any intercepted key. |
| HUD-006 | Adjust system volume via CoreAudio on volume key press. | P0 | Volume increases/decreases by 1/16 per press; audible change matches expectation. |
| HUD-007 | Fine volume adjustment with Option+Shift (1/64 step). | P1 | Holding Option+Shift and pressing volume keys changes volume by 1/64 per press. |
| HUD-008 | Mute toggle preserves pre-mute volume and restores on unmute. | P0 | Muting sets volume to 0; unmuting restores previous volume level. |
| HUD-009 | Play volume tick sound (`volume.aiff`) on volume change. | P1 | System tick sound plays on each volume step; suppressed during fine adjustment and when muted. |
| HUD-010 | Adjust display brightness via CoreDisplay private API. | P0 | Brightness increases/decreases by 1/16 per press; display visibly changes. |
| HUD-011 | Fine brightness adjustment with Option+Shift (1/64 step). | P1 | Holding Option+Shift and pressing brightness keys changes brightness by 1/64 per press. |
| HUD-012 | Adjust keyboard backlight via IOKit. | P1 | Keyboard backlight increases/decreases by 1/16 per press; backlight visibly changes. |
| HUD-013 | Option + Volume opens System Settings > Sound. | P1 | Pressing Option + Volume Up or Down opens the Sound preference pane. |
| HUD-014 | Option + Brightness opens System Settings > Displays. | P1 | Pressing Option + Brightness Up or Down opens the Displays preference pane. |
| HUD-015 | Custom HUD renders in the notch area with icon, progress bar, and percentage. | P0 | HUD appears inside the Dynamic Island notch region with correct icon, bar fill, and percentage text. |
| HUD-016 | HUD icon changes based on level (volume: 4 states, brightness: 2 states). | P0 | Volume icon transitions through muted/low/medium/high; brightness icon transitions through dim/bright. |
| HUD-017 | HUD appears with slide-down animation (200ms ease-out). | P1 | HUD slides down from the notch smoothly. |
| HUD-018 | HUD dismisses after 1.5s with slide-up animation (300ms ease-in). | P1 | HUD slides back up into the notch after the configured delay. |
| HUD-019 | Repeated key presses reset the dismiss timer and animate the bar update. | P0 | Rapidly pressing volume keys keeps the HUD visible and smoothly updates the bar without flickering. |
| HUD-020 | HUD respects custom color theme or system accent color. | P1 | Progress bar fill color matches the user's theme setting. |
| HUD-021 | Monitor external volume changes and show HUD. | P2 | Changing volume via Control Center or another app briefly shows Niya's volume HUD. |
| HUD-022 | Monitor default audio device changes and re-register listeners. | P1 | Switching from speakers to headphones updates the volume listener without crash; HUD shows new device volume. |
| HUD-023 | XPC helper handles display brightness get/set. | P0 | Main app can read and write display brightness via XPC; changes take effect. |
| HUD-024 | XPC helper handles keyboard backlight get/set. | P1 | Main app can read and write keyboard backlight via XPC; changes take effect. |
| HUD-025 | XPC helper auto-reconnects after crash or interruption. | P1 | If NiyaHelper crashes, the main app reconnects within 2 seconds; brightness controls resume working. |
| HUD-026 | Accessibility permission check with user guidance. | P0 | On first launch, if Accessibility is not granted, show a dialog explaining why it is needed and link to System Settings. |
| HUD-027 | Graceful degradation when Accessibility permission is denied. | P0 | All volume/brightness keys pass through to macOS unchanged; no crash; settings banner indicates HUD replacement is disabled. |
| HUD-028 | Master toggle to disable all HUD replacement. | P1 | Turning off "Replace system HUDs" in settings re-enables macOS system HUDs for all keys. |
| HUD-029 | Per-HUD-type toggles (volume, brightness, keyboard). | P2 | User can disable replacement for individual HUD types while keeping others active. |
| HUD-030 | CoreDisplay fallback to XPC if direct dlopen fails. | P1 | If CoreDisplay cannot be loaded directly, brightness control falls back to XPC helper transparently. |

---

## 14. Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| External keyboard without media keys | No events to intercept; HUD replacement is effectively a no-op. No errors. |
| Multiple displays | Brightness control targets `CGMainDisplayID()`. External monitors are unaffected (they typically lack CoreDisplay support). |
| Bluetooth headphones with hardware volume | Headphone volume buttons typically do not generate `NX_SYSDEFINED` events; they are handled by the Bluetooth stack. Niya does not interfere. |
| Lid closed (clamshell mode) | Keyboard backlight keys may not be present. `AppleLMUController` service not found is handled gracefully (logged, not thrown to UI). |
| App crash during event tap | `CGEvent` tap is invalidated when the process dies; macOS automatically restores normal key handling. No stuck keys. |
| Event tap disabled by macOS | macOS may disable taps after timeout. Register for `CGEventTapInformation` and re-enable: `CGEvent.tapEnable(tap:enable:)`. |
| Volume at 0 with further volume-down presses | Volume stays at 0; HUD shows 0%; tick sound is suppressed. |
| Brightness at 0 or 1 with further presses | Value stays clamped; HUD shows correct percentage. |
| Rapid key repeat (holding key down) | Each repeat fires the handler; dismiss timer resets each time. Bar animates smoothly via spring animation. |
| System wakes from sleep | Re-verify event tap is active on `NSWorkspace.didWakeNotification`. Re-read current volume/brightness. |
| Default output device has no volume control (e.g., some HDMI) | `AudioObjectGetPropertyData` may return error. Show HUD with "N/A" instead of percentage. |

---

## 15. Testing Strategy

| Layer | Tool | What to test |
|-------|------|-------------|
| Unit | XCTest | `VolumeControl` get/set/mute round-trip. Brightness/keyboard backlight clamping. Step size calculations. Icon selection logic for all level ranges. |
| Unit | XCTest + mock | `HUDManager` with mock `HIDKeyMonitor` and mock controls — verify correct control is called for each key code, correct HUD type is set, dismiss timer works. |
| Unit | XCTest | Modifier key detection: Option alone opens settings, Option+Shift triggers fine step, no modifier triggers standard step. |
| Unit | XCTest | Mute toggle: verify pre-mute volume is saved and restored on unmute. |
| Integration | XCTest | `HIDKeyMonitor.start()` succeeds when Accessibility is granted; throws when denied. |
| Integration | XCTest | XPC round-trip: set brightness via XPC, read back, verify value matches. |
| Integration | XCTest | External volume change via `AudioObjectSetPropertyData` triggers the listener callback. |
| UI | XCTest UI / Previews | HUD renders with correct icon, bar fill, and percentage for volume/brightness/keyboard at various levels (0%, 25%, 50%, 75%, 100%, muted). |
| Snapshot | swift-snapshot-testing | HUD view at key states: volume muted, volume 33%, volume 66%, volume 100%, brightness 0%, brightness 50%, brightness 100%. |
| Manual | QA checklist | Hold volume key for 5 seconds: HUD stays visible and bar moves smoothly. Disconnect/reconnect headphones: volume listener transfers to new device. Close lid and reopen: keyboard backlight HUD still works. |
