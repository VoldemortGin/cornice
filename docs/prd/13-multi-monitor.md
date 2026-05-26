# PRD 13: Multi-Monitor Support

## Overview

Niya must work seamlessly across multiple displays — built-in notch screens, external monitors without notches, and hot-plugged displays. Each notch-equipped display gets its own independent NotchPanel. Non-notch displays get an optional virtual notch bar.

This document specifies how screens are detected, how panels are created and destroyed, how state is managed per-screen, and how user interactions are routed.

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| MM-01 | One NotchPanel per notch-equipped display | P0 |
| MM-02 | Optional virtual notch on non-notch displays | P0 |
| MM-03 | Hot-plug: detect connect/disconnect without restart | P0 |
| MM-04 | Per-screen independent expand/collapse state | P0 |
| MM-05 | Shared media state across all screens | P0 |
| MM-06 | HUD events display on the screen where the mouse cursor is | P0 |
| MM-07 | File shelf drag detection per screen | P1 |
| MM-08 | User setting: show on all displays vs active display only | P0 |
| MM-09 | User setting: preferred primary display for single-display mode | P1 |
| MM-10 | User setting: per-display enable/disable | P1 |
| MM-11 | Panel repositions correctly after display resolution/arrangement changes | P0 |
| MM-12 | Persistent display identification across reboots | P1 |
| MM-13 | Active display follows mouse cursor with configurable delay | P1 |

### Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| MM-NF-01 | Hot-plug detection latency | < 500ms from NSNotification to panel visible |
| MM-NF-02 | Panel repositioning on arrangement change | < 1 frame (16ms) |
| MM-NF-03 | Memory per additional screen | < 15MB overhead |
| MM-NF-04 | CPU per idle additional screen | < 0.1% |

---

## Architecture

### Component Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        ScreenManager                             │
│                    (singleton, @MainActor)                        │
│                                                                  │
│  Responsibilities:                                               │
│  - Detect all connected screens                                  │
│  - Classify screens (notch / non-notch / external)               │
│  - Create/destroy NotchPanelController per screen                │
│  - Handle hot-plug events                                        │
│  - Route events to correct screen                                │
│  - Manage display mode (all / active-only / selected)            │
│                                                                  │
│  Properties:                                                     │
│  - screens: [ScreenInfo]                                         │
│  - controllers: [CGDirectDisplayID: NotchPanelController]        │
│  - activeScreenID: CGDirectDisplayID?                            │
│  - displayMode: DisplayMode                                      │
└──────────┬────────────────────────────────┬──────────────────────┘
           │                                │
   ┌───────▼────────┐              ┌───────▼────────┐
   │ NotchPanel-    │              │ NotchPanel-    │
   │ Controller     │              │ Controller     │
   │ (Screen A)     │              │ (Screen B)     │
   │                │              │                │
   │ - panel        │              │ - panel        │
   │ - viewModel    │              │ - viewModel    │
   │ - mouseTracker │              │ - mouseTracker │
   │ - dragDetector │              │ - dragDetector │
   └───────┬────────┘              └───────┬────────┘
           │                                │
   ┌───────▼────────┐              ┌───────▼────────┐
   │  NotchPanel    │              │  NotchPanel    │
   │  (NSPanel)     │              │  (NSPanel)     │
   │  positioned    │              │  positioned    │
   │  over notch    │              │  over notch    │
   └────────────────┘              └────────────────┘
```

### ScreenInfo Model

```swift
struct ScreenInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let uuid: CFUUID                    // persistent across reboots
    let screen: NSScreen
    let hasPhysicalNotch: Bool
    let notchGeometry: NotchGeometry?   // nil for non-notch screens
    let isBuiltIn: Bool
    let displayName: String             // e.g., "Built-in Retina Display", "LG UltraFine 5K"

    var notchMode: NotchMode {
        if hasPhysicalNotch { return .physical }
        return userOverride ?? .virtual
    }
}

enum NotchMode {
    case physical       // real hardware notch
    case virtual        // software-rendered virtual notch bar
    case disabled       // user explicitly disabled for this screen
}
```

### Display Identification

Screens must be identified persistently so that per-display settings survive reboots, even when display arrangement changes.

**Primary identifier:** `CGDisplayCreateUUIDFromDisplayID(displayID)` returns a `CFUUID` that is stable across reboots for the same physical display. This is the key used for persistent settings.

**Fallback identification:** If UUID is unavailable (rare), fall back to a composite key of:
- `CGDisplayModelNumber(displayID)`
- `CGDisplaySerialNumber(displayID)`
- `CGDisplayVendorNumber(displayID)`
- Screen resolution

```swift
func persistentDisplayID(for displayID: CGDirectDisplayID) -> String {
    if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) {
        return CFUUIDCreateString(nil, uuid) as String
    }
    // Fallback composite key
    let model = CGDisplayModelNumber(displayID)
    let serial = CGDisplaySerialNumber(displayID)
    let vendor = CGDisplayVendorNumber(displayID)
    return "\(vendor)-\(model)-\(serial)"
}
```

---

## Screen Detection

### Initial Detection (App Launch)

```swift
@Observable
@MainActor
final class ScreenManager {
    private(set) var screens: [ScreenInfo] = []
    private var controllers: [CGDirectDisplayID: NotchPanelController] = [:]

    func detectScreens() {
        let nsScreens = NSScreen.screens
        screens = nsScreens.map { screen in
            let displayID = screen.displayID   // via CGDirectDisplayID extension
            return ScreenInfo(
                id: displayID,
                uuid: CGDisplayCreateUUIDFromDisplayID(displayID),
                screen: screen,
                hasPhysicalNotch: screen.safeAreaInsets.top > 0,
                notchGeometry: NotchGeometry.detect(for: screen),
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                displayName: screen.localizedName
            )
        }
        reconcileControllers()
    }
}
```

### NSScreen Extension for Display ID

```swift
extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
```

### Notch Detection Logic

```swift
struct NotchDetector {
    /// Determines whether a screen has a physical notch.
    ///
    /// Detection strategy:
    /// 1. Check `safeAreaInsets.top > 0` (definitive for Apple notch displays)
    /// 2. Cross-reference with known notch dimensions per model
    ///
    /// Returns nil for non-notch screens.
    static func detect(for screen: NSScreen) -> NotchGeometry? {
        guard screen.safeAreaInsets.top > 0 else { return nil }

        let topInset = screen.safeAreaInsets.top
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame

        // Notch width: area between the two "ears" of the menu bar
        // The notch is centered at the top of the screen
        // Approximate: notch width = screen width - 2 * ear width
        // More precisely, we use the auxiliary top-left and top-right areas

        let notchWidth: CGFloat = estimateNotchWidth(
            screenWidth: frame.width,
            topInset: topInset
        )
        let notchHeight: CGFloat = topInset

        return NotchGeometry(
            width: notchWidth,
            height: notchHeight,
            origin: CGPoint(
                x: frame.midX - notchWidth / 2,
                y: frame.maxY - notchHeight
            ),
            screenID: screen.displayID
        )
    }

    /// Known notch widths by screen pixel width
    private static func estimateNotchWidth(screenWidth: CGFloat, topInset: CGFloat) -> CGFloat {
        // MacBook Pro 14" (3024x1964 native, 1512x982 @2x) → notch ~200pt wide
        // MacBook Pro 16" (3456x2234 native, 1728x1117 @2x) → notch ~200pt wide
        // MacBook Air 13" M2 (2560x1664 native, 1470x956 @2x) → notch ~180pt wide
        // MacBook Air 15" M2 (2880x1864 native, 1710x1107 @2x) → notch ~200pt wide
        //
        // A safe default: 200pt centered works for all current models.
        // The exact width is cosmetic; the panel extends beyond the notch anyway.
        return 200
    }
}
```

### Virtual Notch for Non-Notch Screens

```swift
struct NotchGeometry {
    let width: CGFloat
    let height: CGFloat
    let origin: CGPoint        // in screen coordinates
    let screenID: CGDirectDisplayID
    let isVirtual: Bool

    /// Creates a virtual notch geometry for screens without physical notch.
    static func virtual(for screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame
        let virtualWidth: CGFloat = 220
        let virtualHeight: CGFloat = 32
        return NotchGeometry(
            width: virtualWidth,
            height: virtualHeight,
            origin: CGPoint(
                x: frame.midX - virtualWidth / 2,
                y: frame.maxY - virtualHeight
            ),
            screenID: screen.displayID,
            isVirtual: true
        )
    }
}
```

---

## Hot-Plug Handling

### Screen Change Notification

```swift
@Observable
@MainActor
final class ScreenManager {
    private var screenObserver: Any?

    func startObserving() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    private func handleScreenChange() {
        let previousScreenIDs = Set(screens.map(\.id))
        detectScreens()
        let currentScreenIDs = Set(screens.map(\.id))

        let added = currentScreenIDs.subtracting(previousScreenIDs)
        let removed = previousScreenIDs.subtracting(currentScreenIDs)
        let retained = currentScreenIDs.intersection(previousScreenIDs)

        // Destroy controllers for removed screens
        for id in removed {
            controllers[id]?.teardown()
            controllers[id] = nil
        }

        // Create controllers for added screens
        for id in added {
            guard let info = screens.first(where: { $0.id == id }) else { continue }
            createController(for: info)
        }

        // Reposition panels for retained screens (arrangement may have changed)
        for id in retained {
            controllers[id]?.repositionPanel()
        }
    }
}
```

### Controller Reconciliation

The `reconcileControllers()` method is called after `detectScreens()` and ensures the controller set matches the screen set:

```swift
private func reconcileControllers() {
    let currentIDs = Set(screens.map(\.id))
    let controllerIDs = Set(controllers.keys)

    // Remove stale controllers
    for id in controllerIDs.subtracting(currentIDs) {
        controllers[id]?.teardown()
        controllers[id] = nil
    }

    // Add missing controllers
    for info in screens {
        guard shouldShowPanel(for: info) else { continue }
        if controllers[info.id] == nil {
            createController(for: info)
        }
    }
}

private func shouldShowPanel(for info: ScreenInfo) -> Bool {
    // Check user per-display override
    if let override = perDisplaySettings[info.persistentID] {
        return override.isEnabled
    }

    switch displayMode {
    case .allDisplays:
        return true
    case .activeOnly:
        return info.id == activeScreenID
    case .selectedDisplays(let ids):
        return ids.contains(info.persistentID)
    }
}
```

### Panel Creation

```swift
private func createController(for info: ScreenInfo) {
    let geometry: NotchGeometry
    if let detected = info.notchGeometry {
        geometry = detected
    } else if info.notchMode == .virtual {
        geometry = NotchGeometry.virtual(for: info.screen)
    } else {
        return // disabled for this screen
    }

    let viewModel = NotchPanelViewModel(
        screenInfo: info,
        notchGeometry: geometry,
        coordinator: AppCoordinator.shared
    )

    let controller = NotchPanelController(
        screen: info.screen,
        geometry: geometry,
        viewModel: viewModel
    )
    controller.setup()
    controllers[info.id] = controller
}
```

---

## NotchPanelController

Each screen's controller manages the full lifecycle of one NotchPanel:

```swift
@MainActor
final class NotchPanelController {
    let screen: NSScreen
    let geometry: NotchGeometry
    let viewModel: NotchPanelViewModel
    private(set) var panel: NotchPanel?
    private var mouseTracker: MouseTracker?
    private var dragDetector: DragDetector?

    init(screen: NSScreen, geometry: NotchGeometry, viewModel: NotchPanelViewModel) {
        self.screen = screen
        self.geometry = geometry
        self.viewModel = viewModel
    }

    func setup() {
        // 1. Create panel
        let panel = NotchPanel(
            contentRect: panelFrame(for: .closed),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        // 2. Host SwiftUI content
        let hostingView = NSHostingView(rootView:
            NotchContentView(viewModel: viewModel)
        )
        panel.contentView = hostingView

        // 3. Position panel over the notch
        panel.setFrame(panelFrame(for: .closed), display: true)

        // 4. Install mouse tracker
        mouseTracker = MouseTracker(
            panel: panel,
            geometry: geometry,
            onHoverEnter: { [weak self] in self?.viewModel.onHoverEnter() },
            onHoverExit: { [weak self] in self?.viewModel.onHoverExit() }
        )

        // 5. Install drag detector for file shelf
        dragDetector = DragDetector(
            screen: screen,
            geometry: geometry,
            onDragEnter: { [weak self] in self?.viewModel.onDragEnter() },
            onDragExit: { [weak self] in self?.viewModel.onDragExit() },
            onDrop: { [weak self] items in self?.viewModel.onDrop(items: items) }
        )

        // 6. Show panel
        panel.orderFront(nil)
        self.panel = panel
    }

    func teardown() {
        mouseTracker?.uninstall()
        dragDetector?.uninstall()
        panel?.close()
        panel = nil
    }

    func repositionPanel() {
        guard let panel else { return }
        let newFrame = panelFrame(for: viewModel.interactionState)
        panel.setFrame(newFrame, display: true, animate: false)
    }

    private func panelFrame(for state: NotchInteractionState) -> NSRect {
        let screenFrame = screen.frame
        let notchOrigin = geometry.origin

        switch state {
        case .closed:
            return NSRect(
                x: notchOrigin.x,
                y: notchOrigin.y,
                width: geometry.width,
                height: geometry.height
            )
        case .peeking:
            let peekWidth = geometry.width + 80       // 40pt padding each side
            let peekHeight = geometry.height + 20
            return NSRect(
                x: screenFrame.midX - peekWidth / 2,
                y: screenFrame.maxY - peekHeight,
                width: peekWidth,
                height: peekHeight
            )
        case .expanded:
            let expandedWidth: CGFloat = 480
            let expandedHeight: CGFloat = 400
            return NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        case .sneakPeek:
            let peekWidth = geometry.width + 120
            let peekHeight = geometry.height + 30
            return NSRect(
                x: screenFrame.midX - peekWidth / 2,
                y: screenFrame.maxY - peekHeight,
                width: peekWidth,
                height: peekHeight
            )
        }
    }
}
```

---

## Per-Screen ViewModel

```swift
@Observable
@MainActor
final class NotchPanelViewModel {
    // Identity
    let screenInfo: ScreenInfo
    let notchGeometry: NotchGeometry

    // State
    var interactionState: NotchInteractionState = .closed
    var activeTab: FeatureTab = .media
    var isHovered: Bool = false
    var isDragTarget: Bool = false

    // References
    private weak var coordinator: AppCoordinator?

    // Feature ViewModels (per-screen where needed)
    let fileShelf: FileShelfViewModel
    let systemMonitor: SystemMonitorViewModel

    // Shared ViewModels (same instance across screens)
    var musicManager: MusicManager { coordinator?.musicManager ?? .shared }
    var hudViewModel: HUDViewModel { coordinator?.hudViewModel ?? .shared }

    init(
        screenInfo: ScreenInfo,
        notchGeometry: NotchGeometry,
        coordinator: AppCoordinator
    ) {
        self.screenInfo = screenInfo
        self.notchGeometry = notchGeometry
        self.coordinator = coordinator
        self.fileShelf = FileShelfViewModel()
        self.systemMonitor = SystemMonitorViewModel()
    }

    // MARK: - Mouse Interaction

    func onHoverEnter() {
        guard interactionState == .closed else { return }
        isHovered = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            interactionState = .peeking
        }
    }

    func onHoverExit() {
        isHovered = false
        guard interactionState == .peeking else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            interactionState = .closed
        }
    }

    func onTap() {
        switch interactionState {
        case .closed, .peeking:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                interactionState = .expanded
            }
        case .expanded:
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                interactionState = .closed
            }
        case .sneakPeek:
            break // sneak peek dismisses on its own
        }
    }

    // MARK: - Drag

    func onDragEnter() {
        isDragTarget = true
        if interactionState == .closed {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                interactionState = .peeking
                activeTab = .fileShelf
            }
        }
    }

    func onDragExit() {
        isDragTarget = false
        if interactionState == .peeking {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                interactionState = .closed
            }
        }
    }

    func onDrop(items: [NSItemProvider]) {
        isDragTarget = false
        fileShelf.handleDrop(items: items)
    }

    // MARK: - Sneak Peek (HUD)

    func showSneakPeek(duration: TimeInterval = 2.0) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            interactionState = .sneakPeek
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            if interactionState == .sneakPeek {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    interactionState = .closed
                }
            }
        }
    }
}
```

---

## Active Display Tracking

### Mouse-Based Active Display

The "active display" is the screen where the mouse cursor currently resides. This is used for:
- Routing HUD events (volume/brightness changes show on the active screen)
- Single-display mode (only the active screen shows a panel)

```swift
extension ScreenManager {
    private var mouseMonitor: Any?

    func startMouseTracking() {
        // Poll mouse position every 100ms to determine active screen
        // (More efficient than global mouse-move monitoring)
        mouseMonitor = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActiveScreen()
            }
        }
    }

    private func updateActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                let displayID = screen.displayID
                if displayID != activeScreenID {
                    activeScreenID = displayID
                    handleActiveScreenChanged(to: displayID)
                }
                break
            }
        }
    }

    private func handleActiveScreenChanged(to displayID: CGDirectDisplayID) {
        switch displayMode {
        case .activeOnly:
            // Hide all panels except active
            for (id, controller) in controllers {
                if id == displayID {
                    controller.panel?.orderFront(nil)
                } else {
                    controller.panel?.orderOut(nil)
                }
            }
        case .allDisplays, .selectedDisplays:
            // Panels stay visible; just update routing target
            break
        }
    }
}
```

### Configurable Active-Switch Delay

To prevent the panel from rapidly switching when the mouse crosses screen boundaries:

```swift
extension Defaults.Keys {
    /// Delay in seconds before switching active display. 0 = instant.
    static let activeDisplaySwitchDelay = Key<TimeInterval>("activeDisplaySwitchDelay", default: 0.3)
}
```

The `updateActiveScreen()` method uses a debouncer:

```swift
private let activeScreenDebouncer = Debouncer()

private func updateActiveScreen() {
    let mouseLocation = NSEvent.mouseLocation
    for screen in NSScreen.screens {
        if screen.frame.contains(mouseLocation) {
            let displayID = screen.displayID
            if displayID != activeScreenID {
                activeScreenDebouncer.debounce(
                    interval: Defaults[.activeDisplaySwitchDelay]
                ) { [weak self] in
                    self?.activeScreenID = displayID
                    self?.handleActiveScreenChanged(to: displayID)
                }
            }
            break
        }
    }
}
```

---

## HUD Routing

When a HUD event occurs (volume change, brightness change), it must be displayed on the correct screen:

```swift
extension ScreenManager {
    func routeHUDEvent(_ event: HUDEvent) {
        guard let targetID = activeScreenID,
              let controller = controllers[targetID] else {
            // Fallback: show on built-in display
            let builtIn = screens.first(where: \.isBuiltIn)
            if let id = builtIn?.id, let controller = controllers[id] {
                controller.viewModel.showSneakPeek()
            }
            return
        }
        controller.viewModel.showSneakPeek()
    }
}
```

**Brightness HUD special case:** External displays have independent brightness. If the user changes brightness via keyboard, the HUD should show on the built-in display (since keyboard brightness keys control the built-in panel). If brightness is changed via Niya's UI on a specific screen, the HUD shows on that screen.

---

## Drag Detection Per Screen

Each `NotchPanelController` owns a `DragDetector` that monitors for global drags entering the notch area of its specific screen:

```swift
@MainActor
final class DragDetector {
    private let screen: NSScreen
    private let geometry: NotchGeometry
    private var globalMonitor: Any?
    private var isTracking = false

    var onDragEnter: (() -> Void)?
    var onDragExit: (() -> Void)?
    var onDrop: (([NSItemProvider]) -> Void)?

    init(
        screen: NSScreen,
        geometry: NotchGeometry,
        onDragEnter: @escaping () -> Void,
        onDragExit: @escaping () -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Void
    ) {
        self.screen = screen
        self.geometry = geometry
        self.onDragEnter = onDragEnter
        self.onDragExit = onDragExit
        self.onDrop = onDrop
    }

    func install() {
        // Monitor global drag events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleGlobalDrag(event: event)
        }
    }

    func uninstall() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleGlobalDrag(event: NSEvent) {
        let location = NSEvent.mouseLocation

        // Check if drag is within this screen
        guard screen.frame.contains(location) else {
            if isTracking {
                isTracking = false
                onDragExit?()
            }
            return
        }

        // Check if drag is within the notch drop zone (expanded area above notch)
        let dropZone = NSRect(
            x: geometry.origin.x - 40,
            y: geometry.origin.y - 20,
            width: geometry.width + 80,
            height: geometry.height + 40
        )

        if dropZone.contains(location) {
            if !isTracking {
                isTracking = true
                onDragEnter?()
            }
        } else {
            if isTracking {
                isTracking = false
                onDragExit?()
            }
        }

        if event.type == .leftMouseUp && isTracking {
            isTracking = false
            // Resolve dragged items from pasteboard
            let pasteboard = NSPasteboard(name: .drag)
            // Items would be resolved from the drag pasteboard
        }
    }
}
```

**Note:** The global drag monitor approach has limitations — it cannot access the `NSDraggingInfo` from other apps. For full drag-and-drop support, the `NotchPanel` itself also conforms to `NSDraggingDestination` and registers for dragged types:

```swift
extension NotchPanel {
    func setupDragDestination() {
        registerForDraggedTypes([
            .fileURL,
            .png,
            .tiff,
            .string,
            .URL
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Notify the controller's drag detector
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Extract items and forward to file shelf
        return true
    }
}
```

---

## Settings

### Display Mode

```swift
enum DisplayMode: String, Codable, Defaults.Serializable {
    case allDisplays        // Show panel on every connected screen
    case activeOnly         // Show only on the screen with the mouse cursor
    case selectedDisplays   // Show on user-selected screens
}

extension Defaults.Keys {
    static let displayMode = Key<DisplayMode>("displayMode", default: .allDisplays)
    static let activeDisplaySwitchDelay = Key<TimeInterval>("activeDisplaySwitchDelay", default: 0.3)
}
```

### Per-Display Settings

Each display has its own override settings, keyed by persistent display UUID:

```swift
struct PerDisplaySettings: Codable, Defaults.Serializable {
    var isEnabled: Bool = true
    var notchMode: NotchMode = .physical   // physical, virtual, or disabled
    var position: NotchPosition = .auto    // auto (center-top) or custom offset
}

extension Defaults.Keys {
    /// Dictionary keyed by persistent display UUID string
    static let perDisplaySettings = Key<[String: PerDisplaySettings]>(
        "perDisplaySettings",
        default: [:]
    )
}
```

### Settings UI

The multi-monitor settings appear in the Settings window under "Displays":

```
┌──────────────────────────────────────────────────────────────┐
│  Displays                                                     │
│                                                               │
│  Show notch on:                                               │
│  ○ All displays                                               │
│  ○ Active display only                                        │
│  ○ Selected displays                                          │
│                                                               │
│  Active display switch delay: [0.3s ▾]                        │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Connected Displays                                     │   │
│  │                                                         │   │
│  │  ☑ Built-in Retina Display (notch)                      │   │
│  │    Mode: [Physical notch ▾]                             │   │
│  │                                                         │   │
│  │  ☑ LG UltraFine 5K                                     │   │
│  │    Mode: [Virtual notch bar ▾]                          │   │
│  │                                                         │   │
│  │  ☐ Dell U2723QE                                         │   │
│  │    Mode: [Disabled ▾]                                   │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                               │
│  ℹ︎  Display settings are remembered per monitor.              │
└──────────────────────────────────────────────────────────────┘
```

---

## Edge Cases and Error Handling

### Display Arrangement Changes

When the user rearranges displays in System Settings, `NSApplication.didChangeScreenParametersNotification` fires. The handler:

1. Re-detects all screens (some may have new frames)
2. For retained screens: repositions the panel to the new notch location
3. Does not reset interaction state (if the user had the panel expanded, it stays expanded)

### Lid Close on MacBook

When the MacBook lid is closed with an external display connected:
- The built-in display disappears from `NSScreen.screens`
- The `NotchPanelController` for the built-in display is torn down
- If display mode was "active only" and the built-in was active, the active screen switches to the external display

When the lid is reopened:
- The built-in display reappears
- A new controller is created with the persisted settings for that display UUID
- State resets to closed (no stale expanded state)

### Display Goes to Sleep

When an individual display sleeps (e.g., energy saver timeout):
- The panel remains in memory but the display is powered off
- No special handling needed; macOS hides the panel automatically
- When the display wakes, the panel is already positioned correctly

### Resolution Changes

When display resolution changes (e.g., switching between scaled resolutions):
- `didChangeScreenParametersNotification` fires
- Screen frame changes
- Panel is repositioned via `repositionPanel()`
- Notch geometry is re-detected (safe area insets may change)

### Same-Model External Monitors

If a user has two identical external monitors (same vendor, model, serial = 0):
- `CGDisplayCreateUUIDFromDisplayID` still returns unique UUIDs per connection
- Per-display settings work correctly even with identical hardware
- Display names may be identical; the settings UI shows port/position info as disambiguation

---

## Testing

### Unit Tests

| Test | Description |
|---|---|
| `testScreenDetection_builtInWithNotch` | Mock NSScreen with safeAreaInsets.top > 0, verify NotchGeometry is detected |
| `testScreenDetection_externalNoNotch` | Mock NSScreen with safeAreaInsets.top == 0, verify virtual notch geometry |
| `testHotPlug_addScreen` | Start with 1 screen, add second, verify controller created |
| `testHotPlug_removeScreen` | Start with 2 screens, remove one, verify controller torn down |
| `testHotPlug_removeAndReaddSameScreen` | Remove then re-add same UUID, verify settings restored |
| `testDisplayMode_allDisplays` | Set allDisplays, verify all controllers have visible panels |
| `testDisplayMode_activeOnly` | Set activeOnly, verify only active screen panel is visible |
| `testDisplayMode_selectedDisplays` | Set selectedDisplays with subset, verify correct panels visible |
| `testActiveScreenTracking` | Simulate mouse move to different screen, verify activeScreenID changes |
| `testActiveScreenDebounce` | Rapidly switch screens, verify debounce prevents thrashing |
| `testHUDRouting_toActiveScreen` | Fire HUD event, verify it routes to active screen's controller |
| `testHUDRouting_fallbackToBuiltIn` | No active screen set, verify HUD routes to built-in |
| `testPanelRepositioning_arrangementChange` | Change screen frames, verify panels reposition |
| `testPersistentDisplayID_uuid` | Verify CGDisplayCreateUUIDFromDisplayID is used as primary key |
| `testPersistentDisplayID_fallback` | UUID unavailable, verify composite key is used |
| `testPerDisplaySettings_persistence` | Set per-display settings, verify they survive controller recreation |
| `testLidClose_controllerTeardown` | Remove built-in screen, verify controller is cleaned up |
| `testLidReopen_controllerRecreated` | Re-add built-in screen, verify new controller uses persisted settings |

### Integration Tests

| Test | Description |
|---|---|
| `testEndToEnd_twoScreens_independentState` | Two screens, expand one, verify other stays closed |
| `testEndToEnd_hotPlug_whileExpanded` | Expand on screen A, add screen B, verify A stays expanded |
| `testEndToEnd_dragAcrossScreens` | Start drag on screen A, move to screen B, verify B's shelf activates |
| `testEndToEnd_hudWhileDragging` | Volume change during drag, verify HUD shows on active screen without interrupting drag |

### Mock Infrastructure

```swift
/// Protocol for screen detection, mockable in tests
protocol ScreenProviding {
    var screens: [NSScreen] { get }
    func addObserver(_ handler: @escaping () -> Void) -> Any
}

/// Production implementation
struct SystemScreenProvider: ScreenProviding {
    var screens: [NSScreen] { NSScreen.screens }

    func addObserver(_ handler: @escaping () -> Void) -> Any {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}

/// Test mock
class MockScreenProvider: ScreenProviding {
    var mockScreens: [NSScreen] = []
    var screens: [NSScreen] { mockScreens }
    private var handlers: [() -> Void] = []

    func addObserver(_ handler: @escaping () -> Void) -> Any {
        handlers.append(handler)
        return handlers.count - 1
    }

    func simulateScreenChange(screens: [NSScreen]) {
        mockScreens = screens
        handlers.forEach { $0() }
    }
}
```

`ScreenManager` accepts a `ScreenProviding` dependency in its initializer, defaulting to `SystemScreenProvider` in production.
