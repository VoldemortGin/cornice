# PRD-09: Widgets — Camera Mirror & Quick Apps

## 1. Overview

This document specifies two notch widgets: the **Camera Mirror** (a live front-facing camera preview for quick appearance checks) and the **Quick Apps** launcher (a row of pinned application icons for one-click launching). Both integrate into the notch's widget tab system and are independently togglable in settings.

---

## 2. Camera Mirror Widget

### 2.1 Purpose

A small live camera preview embedded in the notch, equivalent to a pocket mirror. Users glance up to check their appearance before a video call without opening Photo Booth or any other app.

### 2.2 Capture Architecture

#### Session Management

```swift
class CameraMirrorManager: ObservableObject {
    private let captureSession = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?

    @Published var isRunning = false
    @Published var isAvailable = false
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
}
```

- **AVCaptureSession** with a single video input, no outputs (preview-only, no recording).
- **Device selection:** default front-facing camera via `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)`. If no front camera, fall back to `AVCaptureDevice.default(for: .video)` (any camera). User can override in settings.
- **Session preset:** `.medium` (640x480) — balances quality against CPU/power. No need for high resolution in a small preview.
- **Threading:** session `startRunning()` and `stopRunning()` called on a dedicated serial `DispatchQueue(label: "com.niya.camera")`, never the main thread.

#### Lifecycle Rules

| Event | Action |
|---|---|
| Widget becomes visible (tab selected) | Start capture session |
| Widget becomes hidden (tab switched, notch collapsed) | Stop capture session |
| App goes to background / screen locked | Stop capture session |
| App returns to foreground + widget visible | Restart capture session |
| Camera disconnected (external camera unplugged) | Show "No camera" placeholder, observe for reconnection |
| System sleep / wake | Stop on sleep, restart on wake if widget was visible |

- Use `NotificationCenter` observers for `AVCaptureDevice.wasConnectedNotification` / `wasDisconnectedNotification`.
- Use `NSWorkspace.shared.notificationCenter` for `willSleepNotification` / `didWakeNotification`.

#### Power Considerations

- Camera must NOT run when the widget is not actively displayed. This is the single most important requirement for this widget.
- CPU overhead target: < 3% on Apple Silicon when running at `.medium` preset.
- If the user has not opened the mirror in the current session, the capture session is not even created (lazy initialization).

### 2.3 Permissions

#### Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>Niya uses your camera for the mirror widget — a quick way to check your appearance.</string>
```

#### Permission Flow

1. On first access to the Mirror widget, check `AVCaptureDevice.authorizationStatus(for: .video)`.
2. If `.notDetermined`, call `AVCaptureDevice.requestAccess(for: .video)` and show a waiting state.
3. If `.authorized`, proceed to start session.
4. If `.denied` or `.restricted`, show a permission-denied view with a button that opens System Settings > Privacy & Security > Camera via `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)`.

#### Graceful Degradation States

| State | UI |
|---|---|
| Permission not determined | "Tap to enable camera" button |
| Permission denied | "Camera access required" + "Open Settings" button |
| Permission restricted (MDM) | "Camera access is restricted on this Mac" |
| No camera hardware | "No camera found" with device icon |
| Camera in use by another app (exclusive access) | "Camera is in use by another app" |
| Session runtime error | "Camera error — tap to retry" |

### 2.4 Preview Layer

#### NSViewRepresentable Wrapper

```swift
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool = true

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = isMirrored
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.connection?.isVideoMirrored = isMirrored
    }
}
```

- `isVideoMirrored = true` by default — matches what users expect from a mirror (left-right flipped).
- `automaticallyAdjustsVideoMirroring = false` — we control mirroring explicitly.
- `videoGravity = .resizeAspectFill` — fills the preview area, crops edges if aspect ratio doesn't match.

### 2.5 UI States

#### Compact State

- Small circular preview (diameter: 28pt) clipped with `.clipShape(Circle())`.
- Positioned in the notch bar, typically at one end.
- Tapping expands to the full mirror widget.
- If camera is not running/available, shows a static SF Symbol `camera.fill` in the circle.

#### Expanded State

- Larger rounded-rect preview filling the widget area.
- Aspect ratio preserved; letterboxed if necessary.
- Overlay controls (semi-transparent bottom bar):
  - **Mirror toggle:** SF Symbol `arrow.left.and.right.righttriangle.left.righttriangle.right` — flips `isMirrored`.
  - **Open Photo Booth:** SF Symbol `camera.aperture` — launches Photo Booth via `NSWorkspace.shared.open(URL(string: "photobooth://")!)`, falls back to bundle ID `com.apple.PhotoBooth`.
  - **Open FaceTime:** SF Symbol `video.fill` — launches FaceTime via bundle ID `com.apple.FaceTime`.
  - **Camera selector** (only if multiple cameras): popup button listing available cameras by `localizedName`.

### 2.6 Camera Selection

```swift
func availableCameras() -> [AVCaptureDevice] {
    let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
        mediaType: .video,
        position: .unspecified
    )
    return discoverySession.devices
}
```

- User can select a non-default camera in the Mirror settings tab.
- Selected camera stored as `Defaults[.mirrorCameraDeviceID]` (device `uniqueID` string).
- On launch, verify stored device still exists; fall back to default if not.

### 2.7 Settings Keys

```swift
extension Defaults.Keys {
    static let mirrorEnabled = Key<Bool>("mirrorEnabled", default: true)
    static let mirrorFlipped = Key<Bool>("mirrorFlipped", default: true)
    static let mirrorCameraDeviceID = Key<String?>("mirrorCameraDeviceID", default: nil)
    static let mirrorShowInCompact = Key<Bool>("mirrorShowInCompact", default: false)
}
```

---

## 3. Quick Apps Widget

### 3.1 Purpose

A row of pinned application icons in the notch for instant launching. Reduces the need to reach for the Dock or Spotlight for frequently-used apps.

### 3.2 Data Model

```swift
struct QuickAppEntry: Codable, Identifiable, Hashable, Defaults.Serializable {
    let id: UUID
    var bundleIdentifier: String   // e.g., "com.apple.Safari"
    var sortOrder: Int

    var displayName: String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
    }
}
```

- Stored in `Defaults[.quickApps]` as `[QuickAppEntry]`.
- Maximum 12 entries (fits comfortably in the notch expanded area).

#### Default Set

If `quickApps` is empty on first launch, populate with:

```swift
static let defaultQuickApps: [String] = [
    "com.apple.finder",
    "com.apple.Safari",
    "com.apple.MobileSMS",    // Messages
    "com.apple.Notes",
    "com.apple.iCal"          // Calendar
]
```

- Only include apps that are actually installed (verify with `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`).

### 3.3 App Icon Resolution

```swift
func iconForApp(bundleIdentifier: String) -> NSImage {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Unknown app")!
    }
    return NSWorkspace.shared.icon(forFile: appURL.path)
}
```

- Returns the app's actual icon as `NSImage`.
- Wrap in SwiftUI `Image(nsImage:)`.
- Cache icons in memory (`NSCache<NSString, NSImage>`) — icons don't change at runtime.
- If an app is uninstalled, show a placeholder dashed-app icon and a badge indicating the app is missing.

### 3.4 Launching Apps

```swift
func launchApp(bundleIdentifier: String) {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
        // Show brief error tooltip: "App not found"
        return
    }
    NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
}
```

- Uses `NSWorkspace.shared.openApplication(at:configuration:)` (modern API, macOS 12+).
- If the app is already running, this brings it to the front.

### 3.5 Running Indicator

- Query running state: `NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == id }`.
- Show a small dot below the icon (similar to macOS Dock behavior).
- Dot color: system accent color.
- Poll running state every 3 seconds via a timer, or observe `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` for real-time updates.
- Prefer notification-based approach to avoid polling overhead.

```swift
private func observeRunningApps() {
    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification,
        object: nil, queue: .main
    ) { [weak self] _ in self?.updateRunningStates() }

    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification,
        object: nil, queue: .main
    ) { [weak self] _ in self?.updateRunningStates() }
}
```

### 3.6 UI States

#### Compact State

- Horizontal row of app icons in the notch bar.
- Icon size: 20x20pt.
- Spacing: 4pt.
- Show up to 5 icons in compact (limited by notch bar width); remaining visible on expand.
- Running dot: 4pt diameter, centered below icon.

#### Expanded State

- Full grid or scrollable row of all configured app icons.
- Icon size: 32x32pt.
- App name label below each icon (truncated, 8pt font).
- Running dot: 5pt diameter.
- Drag to reorder (within the expanded view, not in compact).

### 3.7 Adding Apps

#### From Settings (Primary method)

- Settings > Quick Apps tab.
- "Add App" button opens a file picker filtered to `/Applications` and `~/Applications`.
- File picker uses `NSOpenPanel` with `allowedContentTypes: [.application]`.
- On selection, extract `bundleIdentifier` from the `.app` bundle and add to the list.

#### From Finder Drag (Stretch goal)

- Accept drops of `.app` files onto the Quick Apps expanded area.
- Register for `NSPasteboard.PasteboardType.fileURL` in an `onDrop` modifier.
- Validate that the dropped file is an application bundle.
- Extract bundle identifier and add to list.

### 3.8 Reordering

- In settings: standard SwiftUI `List` with `.onMove` modifier.
- In expanded widget: hold-and-drag reorder (iOS-style long-press jiggle is not standard on macOS; use direct drag).
- `sortOrder` field updated on reorder; list re-sorted.

### 3.9 Settings Keys

```swift
extension Defaults.Keys {
    static let quickAppsEnabled = Key<Bool>("quickAppsEnabled", default: true)
    static let quickApps = Key<[QuickAppEntry]>("quickApps", default: [])
    static let quickAppsIconSize = Key<QuickAppsIconSize>("quickAppsIconSize", default: .medium)
    static let quickAppsShowLabels = Key<Bool>("quickAppsShowLabels", default: false)
    static let quickAppsShowRunningIndicator = Key<Bool>("quickAppsShowRunningIndicator", default: true)
}

enum QuickAppsIconSize: String, Codable, Defaults.Serializable {
    case small   // 16pt compact, 24pt expanded
    case medium  // 20pt compact, 32pt expanded
    case large   // 24pt compact, 40pt expanded
}
```

---

## 4. Requirements Table

### Camera Mirror

| ID | Requirement | Priority | Complexity | Dependencies |
|---|---|---|---|---|
| CM-001 | `CameraMirrorManager` — AVCaptureSession setup with front camera, `.medium` preset | P0 | Medium | AVFoundation |
| CM-002 | Start/stop session tied to widget visibility (not running when hidden) | P0 | Medium | Widget lifecycle, NotificationCenter |
| CM-003 | `CameraPreviewView` NSViewRepresentable with AVCaptureVideoPreviewLayer | P0 | Medium | AVFoundation, SwiftUI |
| CM-004 | `isVideoMirrored` toggle, default `true` | P0 | Low | AVCaptureConnection |
| CM-005 | Camera permission request flow with `NSCameraUsageDescription` | P0 | Medium | AVFoundation permissions |
| CM-006 | Permission denied state — "Open Settings" button linking to System Settings | P0 | Low | NSWorkspace |
| CM-007 | No camera available state — placeholder with SF Symbol | P0 | Low | SwiftUI |
| CM-008 | Camera disconnection/reconnection handling via device notifications | P1 | Medium | AVCaptureDevice notifications |
| CM-009 | Sleep/wake handling — stop on sleep, restart on wake | P1 | Medium | NSWorkspace notifications |
| CM-010 | Compact state — circular 28pt preview in notch bar | P1 | Medium | SwiftUI, CameraPreviewView |
| CM-011 | Expanded state — large preview with overlay controls | P0 | Medium | SwiftUI |
| CM-012 | Open Photo Booth button | P2 | Low | NSWorkspace |
| CM-013 | Open FaceTime button | P2 | Low | NSWorkspace |
| CM-014 | Camera selector popup for multi-camera setups | P2 | Medium | AVCaptureDevice.DiscoverySession |
| CM-015 | Camera session on dedicated DispatchQueue, never main thread | P0 | Low | GCD |
| CM-016 | Lazy session creation — don't create until first mirror access | P1 | Low | Lazy initialization |
| CM-017 | Memory cache for camera preview layer (avoid re-creation) | P2 | Low | Implementation detail |
| CM-018 | Settings keys: mirrorEnabled, mirrorFlipped, mirrorCameraDeviceID, mirrorShowInCompact | P0 | Low | Defaults library |
| CM-019 | Unit tests for CameraMirrorManager lifecycle states | P0 | Medium | XCTest, mock AVCaptureSession |
| CM-020 | Unit tests for permission flow state machine | P0 | Medium | XCTest |
| CM-021 | Unit tests for camera disconnection/reconnection state transitions | P1 | Medium | XCTest |

### Quick Apps

| ID | Requirement | Priority | Complexity | Dependencies |
|---|---|---|---|---|
| QA-001 | `QuickAppEntry` model with Codable + Defaults.Serializable | P0 | Low | Defaults library |
| QA-002 | Default app set populated on first launch (only installed apps) | P0 | Low | NSWorkspace |
| QA-003 | App icon resolution via `NSWorkspace.shared.icon(forFile:)` | P0 | Low | NSWorkspace |
| QA-004 | In-memory icon cache (`NSCache`) | P1 | Low | Foundation |
| QA-005 | App launching via `NSWorkspace.shared.openApplication(at:configuration:)` | P0 | Low | NSWorkspace |
| QA-006 | Running indicator via workspace launch/terminate notifications | P0 | Medium | NSWorkspace notifications |
| QA-007 | Compact state — horizontal icon row (up to 5) with running dots | P0 | Medium | SwiftUI |
| QA-008 | Expanded state — full grid with labels and running indicators | P0 | Medium | SwiftUI |
| QA-009 | Add app via NSOpenPanel file picker in settings | P0 | Medium | NSOpenPanel, UTType |
| QA-010 | Remove app from list | P0 | Low | SwiftUI List |
| QA-011 | Reorder apps via `.onMove` in settings list | P1 | Low | SwiftUI |
| QA-012 | Drag-to-reorder in expanded widget view | P2 | High | SwiftUI drag and drop |
| QA-013 | Accept `.app` file drops from Finder into expanded widget | P3 | High | NSPasteboard, onDrop |
| QA-014 | Missing app detection — placeholder icon for uninstalled apps | P1 | Low | NSWorkspace |
| QA-015 | Maximum 12 apps enforcement | P1 | Low | Validation |
| QA-016 | Settings keys: quickAppsEnabled, quickApps, quickAppsIconSize, quickAppsShowLabels, quickAppsShowRunningIndicator | P0 | Low | Defaults library |
| QA-017 | Unit tests for QuickAppEntry model serialization | P0 | Low | XCTest |
| QA-018 | Unit tests for default app set filtering to installed apps only | P0 | Low | XCTest, mock NSWorkspace |
| QA-019 | Unit tests for icon cache hit/miss behavior | P1 | Low | XCTest |
| QA-020 | Unit tests for running state observation (launch/terminate notifications) | P1 | Medium | XCTest |

---

## 5. Testing Strategy

### Camera Mirror

#### Unit Tests
- `CameraMirrorManager` state transitions: created -> permission requested -> authorized -> running -> stopped.
- Permission denied flow: verify `isAvailable` is `false`, `permissionStatus` is `.denied`.
- Camera disconnection: verify `isRunning` transitions to `false`, placeholder state activates.
- Sleep/wake: verify session stops on sleep notification, restarts on wake when widget was visible.
- Mirror flip toggle: verify `isMirrored` state propagates.

#### Integration Tests
- Verify `NSCameraUsageDescription` exists in Info.plist.
- Verify preview layer renders without crashes (requires physical camera or simulator with virtual camera).

#### Manual Verification
- Visual check that preview is mirrored by default.
- Verify CPU usage stays under 3% during preview on Apple Silicon.
- Verify session truly stops when switching away from mirror tab (Activity Monitor).
- Test with external USB camera: selection, hot-plug, disconnect.

### Quick Apps

#### Unit Tests
- `QuickAppEntry` Codable round-trip.
- Default app set: only includes apps that are "installed" (mock NSWorkspace).
- Icon resolution: returns placeholder for unknown bundle IDs.
- Running state update on launch/terminate notifications.
- Sort order maintained after reorder.

#### Integration Tests
- App launches correctly for known bundle identifiers.
- NSOpenPanel filters to `.application` type only.

#### Manual Verification
- Icons render correctly for all default apps.
- Running indicator appears/disappears when apps launch/quit.
- Reorder persists across app restart.
- Adding an app via file picker works.

---

## 6. Open Questions

1. Should the camera mirror support a "freeze frame" feature (snapshot the current preview)?
2. Should Quick Apps support app badges (unread count)? This would require accessibility API access.
3. Should Quick Apps show a tooltip with the full app name on hover (for truncated labels)?
4. Should the camera preview include any filters (grayscale, brightness adjustment) or keep it strictly mirror-only?
