# PRD-01: Core Notch UI Foundation

| Field         | Value                          |
|---------------|--------------------------------|
| Document ID   | PRD-01                         |
| Title         | Core Notch UI Foundation       |
| Status        | Draft                          |
| Author        | Niya Team                      |
| Created       | 2026-05-26                     |
| Last Updated  | 2026-05-26                     |
| Target        | macOS 14.0+ (Sonoma and later) |
| Framework     | SwiftUI + AppKit               |

---

## Table of Contents

1. [Notch Detection & Geometry](#1-notch-detection--geometry)
2. [Window Management](#2-window-management)
3. [Notch Shape](#3-notch-shape)
4. [Activation Methods](#4-activation-methods)
5. [Animation System](#5-animation-system)
6. [States & State Machine](#6-states--state-machine)
7. [Content Layout](#7-content-layout)
8. [Mouse & Gesture Handling](#8-mouse--gesture-handling)
9. [Requirements Table](#9-requirements-table)

---

## 1. Notch Detection & Geometry

### 1.1 Detecting Whether a Display Has a Notch

The built-in display on MacBook Pro 14"/16" (2021+) and MacBook Air 15" (2023+) contains a camera housing notch that intrudes into the screen area. The system exposes this via `NSScreen.safeAreaInsets`.

**Detection logic:**

```
let hasNotch = screen.safeAreaInsets.top > 0
```

When `safeAreaInsets.top > 0`, the display has a physical notch. The value of `safeAreaInsets.top` equals the height of the menu bar area that accommodates the notch (typically 37-38 points on current hardware).

When `safeAreaInsets.top == 0`, the display is either an external monitor or an older MacBook without a notch. In this case, Niya renders a **virtual notch** (see Section 1.4).

### 1.2 Calculating Exact Notch Geometry

macOS provides `NSScreen.auxiliaryTopLeftArea` and `NSScreen.auxiliaryTopRightArea` (available since macOS 12.0). These `NSRect` values describe the usable screen regions to the left and right of the notch.

**Notch width calculation:**

```
let screenWidth = screen.frame.width
let leftAreaWidth = screen.auxiliaryTopLeftArea?.width ?? 0
let rightAreaWidth = screen.auxiliaryTopRightArea?.width ?? 0
let rawNotchWidth = screenWidth - leftAreaWidth - rightAreaWidth
let notchWidth = rawNotchWidth + (2 * horizontalPadding)
```

- `horizontalPadding`: A small value (default: 4 points) added on each side so the Niya overlay slightly exceeds the physical notch boundary, preventing a visible gap between the notch edge and the overlay edge. This value is **not** user-configurable; it is a hardcoded visual polish constant.

**Notch height:**

The notch height is configurable via settings with three modes:

| Mode              | Height Value                      | Description                                          |
|-------------------|-----------------------------------|------------------------------------------------------|
| `matchNotch`      | `screen.safeAreaInsets.top`       | Exactly matches the physical notch height            |
| `matchMenuBar`    | `NSStatusBar.system.thickness`    | Matches the system menu bar height                   |
| `custom(CGFloat)` | User-provided value (24-48 pts)   | User sets an explicit height within the allowed range |

Default mode: `matchMenuBar`.

**Notch position:**

The notch is always horizontally centered on the screen. The top edge is pinned to the top of the screen frame (`screen.frame.maxY` in AppKit's flipped coordinate system for window positioning).

```
let notchOriginX = screen.frame.midX - (notchWidth / 2)
let notchOriginY = screen.visibleFrame.maxY  // top of visible frame in AppKit coords
```

### 1.3 Screen Identification

Each display is uniquely identified by a UUID derived from the Core Graphics display ID:

```
let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
let uuid = CGDisplayCreateUUIDFromDisplayID(displayID).takeRetainedValue() as CFUUID
let screenID = CFUUIDCreateString(nil, uuid) as String
```

**Purpose:** Niya persists per-screen preferences (notch height mode, virtual notch dimensions, enabled widgets) keyed by this UUID. When the user reconnects a monitor, their previous configuration is restored automatically.

**Behavior:**

- On app launch, enumerate all screens via `NSScreen.screens`.
- Register for `NSApplication.didChangeScreenParametersNotification` to detect display attach/detach/resolution changes.
- When a screen is added: look up stored preferences by UUID, create a `NotchPanel` for it if none exists.
- When a screen is removed: remove the corresponding `NotchPanel`, keep preferences in storage.
- When screen parameters change (resolution, scaling): recalculate notch geometry and reposition the panel.

### 1.4 Virtual Notch for Non-Notch Displays

On displays where `safeAreaInsets.top == 0`, Niya renders a **virtual notch** — a floating overlay at the top-center of the screen that mimics the notch appearance.

**Configurable parameters (per-screen, persisted by UUID):**

| Parameter             | Default   | Range        | Description                              |
|-----------------------|-----------|--------------|------------------------------------------|
| `virtualNotchWidth`   | 230 pts   | 150-400 pts  | Width of the virtual notch               |
| `virtualNotchHeight`  | 32 pts    | 24-48 pts    | Height of the virtual notch              |
| `virtualNotchEnabled` | true      | true/false   | Whether to show the notch on this screen |

The virtual notch uses the same `NotchShape`, `NotchPanel`, animation system, and state machine as the physical-notch overlay. The only difference is the closed-state dimensions.

### 1.5 Multi-Monitor Behavior

- One `NotchPanel` per connected screen.
- Each panel operates independently — one screen's notch can be open while another is closed.
- Mouse tracking is per-screen: only the panel on the screen where the cursor resides responds to hover/click events.
- Active screen detection: compare `NSEvent.mouseLocation` against each `screen.frame` to determine which screen the cursor is on.

---

## 2. Window Management

### 2.1 NotchPanel Class

Niya uses a custom `NSPanel` subclass named `NotchPanel` to host the notch overlay. `NSPanel` is chosen over `NSWindow` because panels support non-activating behavior — they do not steal focus from the user's current application.

**Class definition:**

```swift
class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Initialization properties (set at creation time, never changed):**

| Property                | Value                                                                             | Rationale                                                             |
|-------------------------|-----------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| `styleMask`             | `[.borderless, .nonactivatingPanel, .fullSizeContentView]`                        | No title bar, no focus stealing, content fills the entire panel frame |
| `isOpaque`              | `false`                                                                           | Transparent background required for the notch shape clipping          |
| `backgroundColor`       | `.clear`                                                                          | No window chrome or background color                                  |
| `hasShadow`             | `false`                                                                           | The notch shape provides its own shadow via SwiftUI                   |
| `level`                 | `.mainMenu + 3` (i.e., `NSWindow.Level(rawValue: 27)`)                            | Above the menu bar and most overlays                                  |
| `isFloatingPanel`       | `true`                                                                            | Stays above regular windows                                           |
| `hidesOnDeactivate`     | `false`                                                                           | Remains visible when the app is not frontmost                         |
| `ignoresMouseEvents`    | `false` (default; toggled dynamically)                                            | Must receive mouse events in its visible region                       |
| `animationBehavior`     | `.none`                                                                           | No system-provided window animations                                  |
| `isMovableByWindowBackground` | `false`                                                                     | User cannot drag the notch panel                                      |
| `titlebarAppearsTransparent` | `true`                                                                       | Belt-and-suspenders: ensures no titlebar artifacts                    |
| `titleVisibility`       | `.hidden`                                                                         | No title text                                                         |

**Collection behavior:**

```swift
panel.collectionBehavior = [
    .canJoinAllSpaces,       // Visible on all Mission Control Spaces
    .fullScreenAuxiliary,    // Visible when another app is in full-screen mode
    .stationary,             // Not affected by Mission Control/Exposé rearrangement
    .ignoresCycle            // Does not appear in Cmd+Tab or Window menu
]
```

### 2.2 Window Level & CGSSpace

The `NSWindow.Level` of `.mainMenu + 3` places the panel above the menu bar, Spotlight, and most third-party overlays. However, some system HUDs (volume, brightness) may still appear above it.

For scenarios where the panel must be **above everything** (e.g., during a sneak peek notification that must not be occluded), Niya optionally uses the private `CGSSpace` API to set the window at the maximum space level:

```
CGSSpaceSetAbsoluteLevel(CGSMainConnectionID(), spaceID, 2147483647)  // Int32.max
```

**Important constraints:**

- This API is **private** and may break across macOS versions. It must be loaded dynamically via `dlsym` and wrapped in availability/crash-safety guards.
- This elevated level is used **only** during sneak peek or first-launch animation, then reverted to the standard `.mainMenu + 3`.
- If the private API is unavailable or fails, the panel falls back gracefully to `.mainMenu + 3` with no user-visible error.

### 2.3 Window Positioning

The panel frame is calculated and applied whenever:

- The app launches.
- A screen is added/removed/resized.
- The notch state changes (the frame expands for open/expanded states).

**Positioning formula:**

```swift
let panelWidth = currentNotchWidth    // varies by state
let panelHeight = currentNotchHeight  // varies by state
let originX = screen.frame.midX - (panelWidth / 2)
let originY = screen.frame.maxY - panelHeight  // AppKit: origin is bottom-left
panel.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
```

The panel is always:

- **Horizontally centered** on its associated screen.
- **Pinned to the top edge** of the screen frame (not the visible frame — the actual top).

### 2.4 Content Hosting

SwiftUI content is hosted inside the panel via `NSHostingView`:

```swift
let hostingView = NSHostingView(rootView: NotchContentView(vm: viewModel))
hostingView.frame = panel.contentView!.bounds
hostingView.autoresizingMask = [.width, .height]
panel.contentView = hostingView
```

The `NSHostingView` fills the entire panel content area. The `NotchShape` (Section 3) clips the visible region within SwiftUI — the panel itself has no visible frame or background.

### 2.5 Hit Testing

The panel must be **click-through** in its transparent regions. Only the area inside the notch shape should receive mouse events.

**Implementation:** Override `NSView.hitTest(_:)` on the hosting view (or a custom container view) to return `nil` for points outside the current notch shape path. This allows clicks on the menu bar or other UI behind the transparent panel regions to pass through normally.

```swift
override func hitTest(_ point: NSPoint) -> NSView? {
    let localPoint = convert(point, from: nil)
    guard currentNotchPath.contains(localPoint) else { return nil }
    return super.hitTest(point)
}
```

`currentNotchPath` is an `NSBezierPath` (or `CGPath`) that mirrors the current SwiftUI `NotchShape` geometry, updated whenever the notch state or size changes.

---

## 3. Notch Shape

### 3.1 Shape Definition

The notch overlay's visible area is defined by a custom SwiftUI `Shape` called `NotchShape`. This shape is used as a `.clipShape()` modifier on the content view, ensuring that only pixels inside the shape are visible — everything outside is fully transparent.

```swift
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // Generates a rounded rectangle path using the two radii
    }
}
```

### 3.2 Animatable Corner Radii

By conforming `animatableData` to `AnimatablePair<CGFloat, CGFloat>`, SwiftUI can interpolate between corner radius values during state transitions. This enables smooth morphing from the tight notch shape to the expanded rounded rectangle.

**Corner radius values by state:**

| State           | `topCornerRadius` | `bottomCornerRadius` | Rationale                                          |
|-----------------|-------------------|----------------------|----------------------------------------------------|
| Closed          | 10 pts            | 14 pts               | Closely matches the physical notch's rounded edges |
| Sneak Peek      | 14 pts            | 18 pts               | Slightly softer than closed                        |
| Open            | 18 pts            | 24 pts               | Comfortable rounded rectangle                      |
| Expanded Detail | 18 pts            | 28 pts               | Larger content area, more pronounced rounding      |

These values are design constants, not user-configurable. They may be tuned during development.

### 3.3 Shape Path Construction

The `path(in:)` method constructs a path that:

1. Starts at the top-left of the rect, offset inward by `topCornerRadius`.
2. Draws the top edge as a straight line (or near-straight, with the top corners being small arcs).
3. At each top corner: an arc with radius `topCornerRadius`.
4. Down each side as a straight vertical line.
5. At each bottom corner: an arc with radius `bottomCornerRadius`.
6. Along the bottom edge back to the start.

The path is a **single closed subpath** — no holes, no compound shapes. It is essentially a rounded rectangle with independent top and bottom corner radii.

### 3.4 Closed-State Shape Matching

In the **closed** state, the `NotchShape` must visually match the physical notch as closely as possible. The shape sits directly over the camera housing, creating the illusion that the notch itself is the Niya UI.

**Matching criteria:**

- Width: exactly `notchWidth` (calculated per Section 1.2).
- Height: exactly `notchHeight` (per the configured mode in Section 1.2).
- Corner radii: tuned to match the curvature of the physical notch corners. On current hardware the physical notch has approximately 10pt top corners and 14pt bottom corners, but these may need per-model calibration. The initial values serve as reasonable defaults.
- The overlay background in closed state is a solid black (`Color.black`) to blend seamlessly with the notch's black camera housing.

### 3.5 Open-State Shape

In the **open** state, the shape expands to a larger rounded rectangle:

- **Default open size:** 640 x 190 points. These are starting defaults and are tuned based on content needs.
- The shape remains horizontally centered; it grows downward from the top edge.
- `topCornerRadius` and `bottomCornerRadius` smoothly animate from closed values to open values.

### 3.6 Usage in View Hierarchy

```swift
NotchContentView(vm: viewModel)
    .frame(width: vm.notchSize.width, height: vm.notchSize.height)
    .clipShape(NotchShape(
        topCornerRadius: vm.topCornerRadius,
        bottomCornerRadius: vm.bottomCornerRadius
    ))
    .background(
        NotchShape(
            topCornerRadius: vm.topCornerRadius,
            bottomCornerRadius: vm.bottomCornerRadius
        )
        .fill(Color.black)
    )
```

The `.clipShape()` defines the visible region. The `.background()` fills the shape with black. Content (widgets, media player, etc.) renders on top of the black background within the clipped region.

---

## 4. Activation Methods

### 4.1 Overview

The user can choose how the notch responds to interaction. Activation methods control the **Closed -> Open** transition. Each method is independently configurable per-screen, but only one activation method is active at a time.

**Settings model:**

```swift
enum ActivationMethod: String, Codable, CaseIterable {
    case hover
    case click
    case swipe
}
```

Default: `hover`.

### 4.2 Hover Activation

**Trigger:** Mouse cursor enters the notch region.

**Behavior sequence:**

1. Mouse enters the notch bounding rect (the closed-state frame, with a small inset tolerance of 4 pts on each side to forgive near-misses).
2. A timer starts with duration = `hoverActivationDelay` (configurable, default: 200ms, range: 50-1000ms).
3. If the mouse is still within the notch region when the timer fires, transition to **Open** state.
4. If the mouse leaves the notch region before the timer fires, cancel the timer — no state change.

**Rationale for delay:** A small delay prevents accidental activation when the user is simply moving the cursor across the top of the screen to reach a menu bar item.

### 4.3 Click Activation

**Trigger:** Mouse click (left button, `mouseDown`) within the notch region.

**Behavior:**

1. If current state is **Closed**: transition to **Open**.
2. If current state is **Open** or **Expanded Detail**: transition to **Closed**.
3. If current state is **Sneak Peek**: transition to **Open** (the user is expressing interest in the notification).

This is a simple toggle. No delay, no timer.

### 4.4 Swipe Activation

**Trigger:** A vertical pan/swipe gesture over the notch region.

**Behavior:**

- **Swipe down** (positive vertical delta): Transition from **Closed** to **Open**. The gesture is interactive — the notch expands proportionally to the swipe distance (see Section 5.5 for gesture-based animation).
- **Swipe up** (negative vertical delta): Transition from **Open** to **Closed**.
- Minimum swipe distance to commit: 20 points. If the user releases before reaching this threshold, the notch snaps back to its original state.

**Gesture recognizer:** An `NSPanGestureRecognizer` is attached to the `NotchPanel`'s content view. The gesture's translation is used to drive a `scaleEffect` that interpolates between closed and open sizes.

### 4.5 Deactivation (Closing)

Deactivation (the **Open -> Closed** transition) is consistent regardless of which activation method is active:

| Trigger                          | Behavior                                                                 |
|----------------------------------|--------------------------------------------------------------------------|
| Mouse leaves expanded area       | Start collapse timer (`collapseDelay`, default: 500ms, range: 200-2000ms) |
| Mouse re-enters expanded area    | Cancel the collapse timer                                                |
| Collapse timer fires             | Transition to **Closed**                                                 |
| Click outside the notch panel    | Immediate transition to **Closed** (no delay)                            |
| Press Escape key                 | Immediate transition to **Closed** (requires focus; see Section 4.6)     |
| Global hotkey toggle             | Immediate transition to **Closed**                                       |

**"Expanded area"** is defined as the current notch shape frame plus a margin of 20 points on the left, right, and bottom edges. This margin prevents the notch from collapsing when the user slightly overshoots while moving the mouse within the expanded notch.

### 4.6 Global Hotkey

A keyboard shortcut to toggle the notch open/closed on the screen where the cursor currently resides.

- Default binding: `Option + N`.
- Configurable via the [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) library.
- The hotkey is a toggle: if closed, open; if open, close; if sneak peeking, open.
- The hotkey acts on the **active screen** (the screen containing the mouse cursor), not the screen with key focus.

**Registration:**

```swift
KeyboardShortcuts.Name("toggleNotch", default: .init(.n, modifiers: [.option]))
```

### 4.7 Mouse Tracking Implementation

All hover and leave detection is implemented via global and local event monitors:

**Global monitor (for hover detection when the panel is in closed state):**

```swift
NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
    let mouseLocation = NSEvent.mouseLocation // in screen coordinates
    // Check if mouseLocation falls within any notch panel's activation region
}
```

**Local monitor (for interactions within the expanded panel):**

```swift
NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .scrollWheel]) { event in
    // Handle interactions within the panel
    return event
}
```

**Performance considerations:**

- The global `.mouseMoved` handler is called on **every** mouse movement system-wide. The handler must be extremely lightweight — a single `NSRect.contains(NSPoint)` check per screen, no allocations, no blocking.
- If the mouse is not near any notch region (a coarse pre-check using an inflated rect, e.g., top 50 points of each screen), the handler returns immediately.
- The monitor is registered at app launch and removed at app termination. It is never temporarily removed or re-added.

---

## 5. Animation System

### 5.1 Spring Animation Parameters

All notch state transitions use spring animations for a natural, physical feel. Three spring configurations are defined:

**Open animation (Closed -> Open, Sneak Peek -> Open):**

```swift
.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
```

- `response: 0.42` — moderately fast, feels responsive without being jarring.
- `dampingFraction: 0.8` — slight overshoot for a lively feel, settles quickly.
- `blendDuration: 0` — no blending with previous animations; the new animation fully takes over.

**Close animation (Open -> Closed, Expanded Detail -> Closed):**

```swift
.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
```

- `response: 0.45` — slightly slower than open to feel deliberate.
- `dampingFraction: 1.0` — critically damped, no overshoot. Closing should feel clean and decisive.

**Interactive spring (gesture-driven transitions):**

```swift
.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
```

- `response: 0.38` — faster response for gesture tracking to minimize perceived lag.
- `dampingFraction: 0.8` — same overshoot as open animation for visual consistency.
- Used when the user releases a swipe gesture and the notch animates to its final state.

### 5.2 Size Transition

The notch size is stored in the view model as a `CGSize`:

```swift
@Published var notchSize: CGSize
```

When the state changes, `notchSize` is updated inside a `withAnimation` block:

```swift
withAnimation(openSpring) {
    vm.notchSize = openSize       // e.g., CGSize(width: 640, height: 190)
    vm.topCornerRadius = 18
    vm.bottomCornerRadius = 24
}
```

The SwiftUI `.frame(width:height:)` modifier on the content view reads `vm.notchSize`, and because the change is wrapped in `withAnimation`, SwiftUI interpolates the frame size over the spring curve.

Simultaneously, the `NotchPanel`'s `NSWindow` frame must be updated to match. This is done via `NSAnimationContext` synchronized with the SwiftUI animation timing:

```swift
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.42  // match spring response
    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    panel.animator().setFrame(newFrame, display: true)
}
```

**Note:** Perfect synchronization between NSWindow frame animation and SwiftUI content animation is difficult. The recommended approach is to set the panel frame to the **final** (largest needed) size immediately and let SwiftUI handle the visual size transition within the fixed panel frame via `.clipShape()` and `.frame()`. This avoids visible desynchronization.

### 5.3 Corner Radius Transition

Because `NotchShape.animatableData` is declared as `AnimatablePair<CGFloat, CGFloat>`, SwiftUI automatically interpolates `topCornerRadius` and `bottomCornerRadius` when they change inside a `withAnimation` block. No additional animation code is needed — the spring animation that drives the size transition also drives the corner radius transition.

### 5.4 Content Transitions

When the notch opens or closes, the inner content (widgets, media player, etc.) should transition smoothly rather than abruptly appearing/disappearing.

**Transition definition:**

```swift
.transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
```

- `.scale(scale: 0.8, anchor: .top)` — content scales from 80% at the top anchor point, giving the appearance of "emerging from" the notch.
- `.opacity` — simultaneous fade-in/fade-out.
- These transitions are applied to the content views that appear/disappear during state changes (using `if`/`switch` in the view body with the state-change `withAnimation`).

**Tab content transitions (switching between tabs in the open state):**

```swift
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal: .move(edge: .leading).combined(with: .opacity)
))
```

This produces a horizontal slide effect when switching tabs, with the new tab sliding in from the right and the old tab sliding out to the left (reversed for backward navigation).

### 5.5 Gesture-Based Interactive Animation

When swipe activation is enabled (Section 4.4), the notch expansion is driven interactively by the gesture's vertical translation:

**During the gesture (state: `.changed`):**

```swift
let progress = min(max(translation.y / fullExpansionDistance, 0), 1)
let interpolatedWidth = closedSize.width + (openSize.width - closedSize.width) * progress
let interpolatedHeight = closedSize.height + (openSize.height - closedSize.height) * progress
vm.notchSize = CGSize(width: interpolatedWidth, height: interpolatedHeight)
```

- `fullExpansionDistance`: the vertical distance (in points) that corresponds to a complete open. Default: 80 points.
- No `withAnimation` wrapping during the gesture — direct property assignment for immediate response.
- A `scaleEffect` is additionally applied to the content during the gesture to provide a "stretchy" feel:

```swift
.scaleEffect(x: 1.0, y: 0.9 + (0.1 * progress), anchor: .top)
```

**On gesture end (state: `.ended`):**

```swift
let committed = translation.y >= commitThreshold  // 20 points
withAnimation(interactiveSpring) {
    if committed {
        vm.notchState = .open
        vm.notchSize = openSize
    } else {
        vm.notchState = .closed
        vm.notchSize = closedSize
    }
}
```

### 5.6 First-Launch "Hello" Animation

On the very first launch after installation (tracked via `UserDefaults` key `hasCompletedFirstLaunch`), Niya plays a brief attention-getting animation:

1. The notch area subtly glows with a gradient animation (a rounded-rect stroke cycling through accent colors over 2 seconds).
2. The notch smoothly expands to a small sneak-peek size showing a "Welcome to Niya" message.
3. After 3 seconds, it collapses back to the closed state.
4. `hasCompletedFirstLaunch` is set to `true`.

This animation is purely decorative and has no functional impact. It may be deferred to a later development phase. It does not block any other feature.

---

## 6. States & State Machine

### 6.1 State Definitions

```swift
enum NotchState: String, CaseIterable {
    case closed
    case sneakPeek
    case open
    case expandedDetail
}
```

| State            | Notch Size (W x H)           | Description                                                                 |
|------------------|-------------------------------|-----------------------------------------------------------------------------|
| `closed`         | notchWidth x notchHeight      | Matches the physical notch. Shows minimal status indicators.                |
| `sneakPeek`      | ~400 x 56 pts (content-dependent) | Temporarily expands to show a brief notification. Auto-dismisses.        |
| `open`           | ~640 x 190 pts (default)      | Fully expanded. Shows the active tab's content.                             |
| `expandedDetail` | ~700 x 380 pts (widget-dependent) | Largest expansion. Shows detailed widget content (e.g., lyrics, full file shelf). |

Sizes listed are defaults. Actual sizes may vary based on screen resolution, user preferences, and widget content.

### 6.2 State Transition Diagram

```
                    ┌──────────────────────┐
                    │                      │
    ┌───────────────▼──────────────┐       │
    │           CLOSED             │       │
    │                              │       │
    │  Minimal indicators:         │       │
    │  battery, music, status      │       │
    └──┬──────────┬────────────────┘       │
       │          │                        │
       │ user     │ system                 │
       │ action   │ event                  │
       │          │                        │
       ▼          ▼                        │
  ┌─────────┐  ┌──────────────┐            │
  │  OPEN   │  │  SNEAK PEEK  │            │
  │         │  │              │            │
  │ Tab bar │  │ Brief info   │            │
  │ Content │  │ Auto-dismiss │            │
  │         │  │              │            │
  └──┬──────┘  └──┬───────┬───┘            │
     │            │       │                │
     │ widget     │ user  │ timeout        │
     │ action     │ tap   │ (3s)           │
     │            │       │                │
     ▼            ▼       └────────────────┘
  ┌───────────────────┐
  │  EXPANDED DETAIL  │
  │                   │
  │  Full widget view │
  │  (lyrics, shelf,  │
  │   calendar, etc.) │
  └───────────────────┘
```

### 6.3 Transition Rules

Each transition has a **trigger**, an **animation**, and **post-conditions**:

| #  | From            | To              | Trigger                                          | Animation      | Post-Conditions                                   |
|----|-----------------|-----------------|--------------------------------------------------|----------------|----------------------------------------------------|
| T1 | Closed          | Open            | Hover delay elapsed / Click / Swipe / Hotkey     | Open spring    | Tab bar visible, last-active tab content shown     |
| T2 | Closed          | Sneak Peek      | System event: track change, volume, battery, etc.| Open spring    | Notification content shown, dismiss timer started  |
| T3 | Sneak Peek      | Closed          | Dismiss timer fires (default: 3s)                | Close spring   | Notification content removed                       |
| T4 | Sneak Peek      | Open            | User clicks/hovers/interacts during sneak peek   | Open spring    | Dismiss timer canceled, tab bar visible            |
| T5 | Open            | Closed          | Mouse leaves + collapse delay / Click outside / Escape / Hotkey | Close spring | Content transitions out, indicators return |
| T6 | Open            | Expanded Detail | User action within a widget (e.g., "show lyrics")| Open spring    | Widget-specific expanded content shown             |
| T7 | Expanded Detail | Open            | User clicks "collapse" within widget / Back      | Close spring   | Returns to standard open layout                    |
| T8 | Expanded Detail | Closed          | Mouse leaves + collapse delay / Hotkey / Escape  | Close spring   | Full collapse from expanded to closed              |

### 6.4 Invalid Transitions

The following transitions are **not allowed** and must be rejected by the state machine:

- Closed -> Expanded Detail (must go through Open first).
- Sneak Peek -> Expanded Detail (must go through Open first).
- Any state -> same state (no-op, ignored).

### 6.5 Sneak Peek Behavior

Sneak peek is a **system-driven** state. The user does not directly trigger it — it is activated by registered system events.

**Triggering events (each is an independently enabled/disabled setting):**

| Event                      | Default Enabled | Content Shown                                |
|----------------------------|-----------------|----------------------------------------------|
| Now Playing track change   | Yes             | Album art (small), track name, artist name   |
| Volume change (system HUD) | Yes             | Volume slider icon and level                 |
| Brightness change          | Yes             | Brightness slider icon and level             |
| Battery reaches threshold  | Yes             | Battery icon and percentage                  |
| Calendar event imminent    | No              | Event name and time                          |
| Timer/Stopwatch completion | No              | Timer label and "done" indicator             |

**Dismiss timer:**

- Default duration: 3 seconds.
- Configurable range: 1-10 seconds.
- The timer starts when the sneak peek content is fully visible (after the open animation completes).
- If the user interacts (clicks, hovers with intent) during the sneak peek, the timer is canceled and the state transitions to Open (T4).

**Queueing:**

If multiple sneak-peek events arrive in rapid succession (e.g., skipping through tracks), the previous sneak peek is immediately replaced with the new one. There is no queue or stacking — only the latest event is shown. The dismiss timer restarts from the beginning.

### 6.6 State Persistence

The current notch state is **not** persisted across app launches. On every launch, all notch panels start in the **Closed** state. The rationale: persisting an open state would be confusing if the user had switched contexts.

What **is** persisted (in UserDefaults or a plist, keyed by screen UUID):

- Last-active tab (which tab was selected when the user last closed the notch).
- Activation method preference.
- Timing preferences (hover delay, collapse delay, sneak peek duration).
- Notch height mode.
- Virtual notch dimensions.
- Enabled sneak peek event types.

---

## 7. Content Layout

### 7.1 Closed-State Layout

The closed state shows a minimal horizontal strip of status indicators within the notch shape. The layout is a single `HStack` with the following structure:

```
┌────────────────────────────────────────────────┐
│  [Battery]     [Music Indicator]     [Status]  │
│    left              center             right   │
└────────────────────────────────────────────────┘
```

| Position | Content                          | Size          | Details                                                |
|----------|----------------------------------|---------------|--------------------------------------------------------|
| Left     | Battery icon                     | 16 x 10 pts   | SF Symbol `battery.100`, colored by charge level       |
| Center   | Music playing indicator          | 16 x 12 pts   | Animated equalizer bars when audio is playing; hidden when not |
| Right    | Status indicators                | 16 x 16 pts   | Mic mute, Do Not Disturb, or other active status icons |

- All icons use SF Symbols with `.font(.system(size: 10))`.
- Icon color: `Color.white.opacity(0.7)` to remain subtle.
- The entire layout is clipped by `NotchShape` to the closed-state dimensions.
- If no status indicators are active, the closed state shows only the black notch shape with no visible content (just the physical notch overlay).

### 7.2 Open-State Layout

The open state has two main regions: a **tab bar** at the top and a **content area** below.

```
┌──────────────────────────────────────────────────────────────┐
│  [Home]  [Shelf]  [Calendar]  [Settings]          Tab Bar   │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                                                              │
│                    Main Content Area                         │
│                    (varies by tab)                           │
│                                                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Tab bar:**

- Height: 32 points.
- Background: slightly lighter than pure black (`Color.white.opacity(0.06)`).
- Layout: `HStack` with equal-spacing icons.
- Each tab is an SF Symbol icon (16 x 16 pts) with a label below (8pt font) or tooltip on hover.
- Active tab: icon is white, with a subtle underline indicator (2pt tall, accent color).
- Inactive tab: icon is `Color.white.opacity(0.5)`.
- Tabs are defined by the widget system — the Home and Shelf tabs are always present; other tabs correspond to enabled widgets.
- The tab bar supports scrolling if there are more tabs than fit the width (horizontal `ScrollView` with hidden indicators).

**Home tab content (default):**

```
┌──────────────────────────┬───────────────────────────────────┐
│                          │                                   │
│    Media Player          │    Widget Grid                    │
│    (album art,           │    (2-column grid of              │
│     track info,          │     compact widgets:              │
│     playback controls)   │     calendar, weather,            │
│                          │     battery, timer, etc.)         │
│                          │                                   │
└──────────────────────────┴───────────────────────────────────┘
       ~50% width                    ~50% width
```

- Left side: media player widget. Occupies approximately 50% of the content width. Shows album art (48 x 48 pts), track name, artist name, and playback controls (previous, play/pause, next).
- Right side: a 2-column `LazyVGrid` of compact widgets. Each widget cell is approximately 80 x 60 pts. Widgets include: calendar (next event), weather (current conditions), battery (percentage + time remaining), timer/stopwatch.
- If no media is playing, the media player area shows a "No media" placeholder and the widget grid expands to fill the full width.

**Shelf tab content:**

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│    Drop Zone: "Drag files here"                              │
│                                                              │
│    [File 1]  [File 2]  [File 3]  [File 4]  ...             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- A horizontal scrolling list of shelved file thumbnails (48 x 48 pts each).
- A drop zone area that accepts dragged files.
- Details of the Shelf feature are covered in a separate PRD.

**Other widget tabs:**

Each enabled widget can register a full-width tab view. When selected, the tab's content fills the entire content area below the tab bar. Widget tab content specifications are covered in per-widget PRDs.

### 7.3 Sneak Peek Layout

The sneak peek shows a compact, single-line notification:

```
┌──────────────────────────────────────────────┐
│  [Icon]  Primary Text        Secondary Text  │
└──────────────────────────────────────────────┘
```

| Element        | Size / Style                          | Example                                |
|----------------|---------------------------------------|----------------------------------------|
| Icon           | 24 x 24 pts, SF Symbol or album art   | Album art for music, speaker for volume |
| Primary text   | 14pt, semibold, white                 | "Song Title"                           |
| Secondary text | 12pt, regular, white 60% opacity      | "Artist Name" or "75%"                 |

- The entire sneak peek is an `HStack(spacing: 12)`.
- A subtle progress bar (2pt tall) at the bottom of the sneak peek shows the dismiss timer countdown (animated width from 100% to 0%).

### 7.4 Expanded Detail Layout

The expanded detail layout is widget-specific. The frame expands to accommodate the widget's full content. Examples:

- **Music + Lyrics:** Album art (large, 120 x 120 pts) on the left, track info and playback controls in the center, scrolling lyrics on the right.
- **Full File Shelf:** Multi-row grid of file thumbnails with file names, sizes, and action buttons.
- **Calendar:** Full day/week view.

Each widget defines its own expanded layout. The core UI framework provides:

- The expanded frame size (requested by the widget, capped at a maximum of `screen.frame.width * 0.6` wide and `screen.frame.height * 0.5` tall).
- The `NotchShape` clipping at the expanded dimensions.
- A "collapse" affordance (a small chevron-up button at the top-right of the expanded area, or a swipe-up gesture).

---

## 8. Mouse & Gesture Handling

### 8.1 Event Monitor Architecture

Niya uses two layers of event monitoring:

**Layer 1 — Global monitor:**

Registered via `NSEvent.addGlobalMonitorForEvents(matching:handler:)`. This captures mouse events **outside** the Niya panel (i.e., when the panel is not the event target). Used for:

- Detecting hover near the notch region (to trigger activation).
- Detecting clicks outside the panel (to trigger deactivation).
- Tracking mouse movement for the collapse delay (detecting when the mouse leaves the expanded area).

Events monitored globally: `.mouseMoved`, `.leftMouseDown`, `.leftMouseDragged`.

**Layer 2 — Local monitor:**

Registered via `NSEvent.addLocalMonitorForEvents(matching:handler:)`. This captures mouse events **within** the Niya panel. Used for:

- Button clicks, slider interactions, and other UI within the notch content.
- Scroll wheel events within scrollable content.
- Detecting mouse movement within the panel (for hover effects on buttons, etc.).

Events monitored locally: `.mouseMoved`, `.leftMouseDown`, `.leftMouseUp`, `.rightMouseDown`, `.scrollWheel`.

### 8.2 Hover Detection Logic

The global `.mouseMoved` handler implements the following logic:

```swift
func handleGlobalMouseMoved(_ event: NSEvent) {
    let mouseLocation = NSEvent.mouseLocation  // screen coordinates

    for (screenID, panel) in notchPanels {
        let screen = panel.screen ?? continue
        let notchRect = panel.activationRect  // closed-state rect + tolerance

        // Coarse check: is the mouse in the top region of this screen?
        let topRegion = NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - 50,
            width: screen.frame.width,
            height: 50
        )
        guard topRegion.contains(mouseLocation) else { continue }

        // Fine check: is the mouse in the notch activation rect?
        if notchRect.contains(mouseLocation) {
            handleMouseEnteredNotch(panel: panel)
        } else if panel.state == .open || panel.state == .expandedDetail {
            let expandedRect = panel.expandedRect.insetBy(dx: -20, dy: -20) // margin
            if !expandedRect.contains(mouseLocation) {
                handleMouseLeftNotch(panel: panel)
            }
        }
    }
}
```

### 8.3 Click-Through for Transparent Areas

As described in Section 2.5, the panel overrides `hitTest(_:)` to return `nil` for points outside the notch shape. This ensures:

- Clicks on the menu bar items that are geometrically behind the panel's transparent area pass through to the menu bar.
- Clicks on other application windows behind the panel pass through normally.
- Only clicks within the visible notch shape are captured by the panel.

The `hitTest` must use the **current** shape path, which changes size during animations. During an animation, the hit-test region should use the **target** (final) shape, not the in-flight interpolated shape, to prevent flickering hit-test behavior.

### 8.4 Swipe / Pan Gesture

When swipe activation is enabled:

```swift
let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
panel.contentView?.addGestureRecognizer(panGesture)
```

The gesture handler maps vertical translation to notch expansion (see Section 5.5).

**Edge cases:**

- Horizontal panning is ignored (only the vertical component is used).
- If the user swipes down to partially open, then reverses direction to swipe up without lifting the finger, the notch should smoothly track the reversal.
- The gesture recognizer has `delaysOtherMouseButtonEvents = false` to not interfere with click handling.

### 8.5 Drag-and-Drop Detection (for Shelf)

The notch must respond to file drags — when the user drags a file near the notch, it should open to reveal the Shelf drop zone.

**Detection:**

```swift
// Periodic check (every 500ms) via a timer when the notch is closed
if NSPasteboard(name: .drag).changeCount != lastDragChangeCount {
    // A drag operation is in progress
    // Check if the drag is near the notch region
    let mouseLocation = NSEvent.mouseLocation
    if notchProximityRect.contains(mouseLocation) {
        // Open the notch to the Shelf tab
    }
}
```

- `notchProximityRect`: the closed-state notch rect expanded by 60 points in all directions. This gives the user a generous target when dragging.
- When a drag is detected near the notch, the notch auto-opens to the Shelf tab, regardless of the current activation method.
- When the drag ends or the mouse leaves the proximity rect, the normal collapse delay applies.

### 8.6 Right-Click Context Menu

Right-clicking within the expanded notch area opens a context menu:

| Menu Item          | Action                           |
|--------------------|----------------------------------|
| Settings...        | Opens the Niya settings window   |
| Restart Niya       | Restarts the overlay process     |
| Close Niya         | Hides the notch overlay          |
| Quit Niya          | Terminates the application       |

The context menu is a standard `NSMenu` attached to the panel's content view via `menu` property or `rightMouseDown` override.

---

## 9. Requirements Table

### Notch Detection & Geometry

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| ND-001   | Detect physical notch via `NSScreen.safeAreaInsets.top > 0`                 | P0       | On a notch MacBook, `hasNotch` returns `true`. On an external monitor, returns `false`.                                                               |
| ND-002   | Calculate notch width from `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`| P0       | Calculated width matches physical notch width within 2 points on all supported MacBook models.                                                        |
| ND-003   | Support three notch height modes: `matchNotch`, `matchMenuBar`, `custom`   | P1       | Each mode produces the documented height value. Custom mode clamps to 24-48pt range. Default is `matchMenuBar`.                                       |
| ND-004   | Identify screens by UUID via `CGDisplayCreateUUIDFromDisplayID`            | P0       | Each connected screen has a unique, stable UUID. Disconnecting and reconnecting a monitor produces the same UUID.                                     |
| ND-005   | Persist per-screen preferences keyed by screen UUID                        | P1       | After changing settings for screen A, disconnecting it, reconnecting it, and relaunching the app, the settings for screen A are restored.             |
| ND-006   | React to display configuration changes                                     | P0       | Adding/removing a monitor or changing resolution triggers notch geometry recalculation and panel repositioning within 500ms.                           |
| ND-007   | Render virtual notch on non-notch displays                                 | P1       | On an external monitor, a virtual notch appears at top-center with default 230x32pt dimensions.                                                       |
| ND-008   | Virtual notch width and height are user-configurable                       | P2       | User can set width (150-400pt) and height (24-48pt) in settings. Changes are reflected immediately.                                                   |
| ND-009   | Support multiple simultaneous monitors                                     | P0       | Each connected screen has its own independent notch panel. Opening the notch on screen A does not affect screen B.                                    |

### Window Management

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| WM-001   | `NotchPanel` is an `NSPanel` subclass with documented properties           | P0       | Panel is borderless, non-activating, transparent, shadow-free, always-on-top, and visible on all Spaces.                                              |
| WM-002   | Panel does not steal focus from current application                        | P0       | Clicking within the notch panel does not bring the Niya app to the foreground. The previously active application remains active. `canBecomeKey` and `canBecomeMain` both return `false`. |
| WM-003   | Panel is visible on all Mission Control Spaces                             | P0       | Switching Spaces via `Ctrl+Left/Right` — the notch panel remains visible on every Space.                                                              |
| WM-004   | Panel is visible during full-screen app usage                              | P0       | When another app is in full-screen mode, the notch panel is still visible and interactive.                                                             |
| WM-005   | Panel does not appear in Cmd+Tab, Window menu, or Mission Control          | P0       | The panel has `.ignoresCycle` behavior. It does not appear in the app switcher or any window listing.                                                  |
| WM-006   | Panel is positioned horizontally centered, pinned to top of screen         | P0       | The panel's horizontal center matches the screen's horizontal center within 1 point. The panel's top edge matches the screen's top edge.              |
| WM-007   | Panel frame updates when notch state changes                               | P0       | Transitioning from closed to open increases the panel frame to accommodate the open-state content. Transitioning back restores the closed frame.      |
| WM-008   | Transparent areas are click-through                                        | P0       | Clicking on the menu bar through the panel's transparent region activates the menu bar item. Verified by clicking a known menu bar icon position.     |
| WM-009   | Content is hosted via `NSHostingView` bridging SwiftUI                     | P0       | SwiftUI views render correctly within the panel. Interactive SwiftUI controls (buttons, sliders) respond to input.                                    |
| WM-010   | Panel remains visible when Niya app is not frontmost                       | P0       | Launch another app and bring it to the foreground. The notch panel remains visible and functional.                                                     |

### Notch Shape

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| NS-001   | `NotchShape` conforms to SwiftUI `Shape` protocol                          | P0       | `NotchShape` can be used with `.clipShape()`, `.background()`, and `.overlay()` modifiers.                                                            |
| NS-002   | Shape has independently animatable top and bottom corner radii             | P0       | Changing `topCornerRadius` and `bottomCornerRadius` within `withAnimation` produces a smooth interpolation of both values simultaneously.             |
| NS-003   | Closed-state shape matches physical notch dimensions                       | P0       | Side-by-side screenshot comparison: the overlay shape aligns with the physical notch edges within 2 points on all edges.                              |
| NS-004   | Closed-state background is solid black                                     | P0       | The overlay is visually indistinguishable from the physical notch at normal viewing distance. No visible seam or color mismatch.                      |
| NS-005   | Open-state shape is a larger rounded rectangle                             | P0       | The open shape has the documented default dimensions (640x190pt) and corner radii (18pt top, 24pt bottom).                                           |
| NS-006   | Shape clips content correctly                                              | P0       | Content inside the shape is visible. Content outside the shape is fully transparent — no bleeding, no anti-aliasing artifacts at the edges.           |

### Activation Methods

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| AM-001   | Hover activation: notch opens after configurable delay                     | P0       | With hover mode and 200ms delay: move cursor into notch region, hold for 200ms — notch opens. Move cursor into region and out within 100ms — notch does not open. |
| AM-002   | Click activation: single click toggles notch                               | P0       | Click on closed notch — it opens. Click on open notch — it closes. Double-click is treated as two toggles (net: no change).                          |
| AM-003   | Swipe activation: downward swipe opens, upward swipe closes                | P1       | Swipe down 30pt on closed notch — it opens. Swipe up 30pt on open notch — it closes. Swipe down 10pt and release — notch snaps back (below 20pt threshold). |
| AM-004   | Only one activation method is active at a time                             | P0       | Changing activation method in settings immediately disables the previous method. No dual-activation scenarios.                                         |
| AM-005   | Collapse on mouse leave with configurable delay                            | P0       | With 500ms delay: move cursor out of expanded area, wait 500ms — notch closes. Move cursor out and back within 300ms — notch stays open.             |
| AM-006   | Collapse on click outside the notch panel                                  | P0       | With notch open, click anywhere outside the notch panel — notch closes immediately (no delay).                                                        |
| AM-007   | Collapse on Escape key press                                               | P1       | With notch open, press Escape — notch closes immediately.                                                                                             |
| AM-008   | Global hotkey toggles notch on the active screen                           | P1       | Press `Option+N` (default) — if closed, notch opens on the screen where the cursor is. If open, it closes. Hotkey is re-bindable in settings.       |
| AM-009   | Hover delay is configurable (50-1000ms)                                    | P1       | Set delay to 500ms in settings. Move cursor into notch region — notch does not open until 500ms have elapsed.                                        |
| AM-010   | Collapse delay is configurable (200-2000ms)                                | P1       | Set delay to 1000ms. Move cursor out of expanded area — notch does not close until 1000ms have elapsed.                                              |
| AM-011   | Expanded area includes a 20pt margin for collapse detection                | P0       | Mouse positioned 15pt outside the open notch's visual boundary does not trigger collapse. Mouse positioned 25pt outside does trigger collapse timer.  |

### Animation System

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| AN-001   | Open animation uses spring with response 0.42, damping 0.8                 | P0       | Measured animation duration is approximately 0.42s. Slight overshoot visible before settling. No jank or frame drops.                                 |
| AN-002   | Close animation uses spring with response 0.45, damping 1.0                | P0       | Measured animation duration is approximately 0.45s. No overshoot (critically damped). Smooth deceleration.                                            |
| AN-003   | Interactive spring has response 0.38, damping 0.8                          | P1       | When a swipe gesture is released, the animation to the final state takes approximately 0.38s with slight overshoot.                                   |
| AN-004   | Size transitions animate smoothly between closed and open dimensions       | P0       | Frame-by-frame analysis: width and height interpolate continuously (no jumps) from closed to open size over the spring curve.                         |
| AN-005   | Corner radii animate smoothly during state transitions                     | P0       | Frame-by-frame analysis: corner radii interpolate continuously from closed to open values. No sudden radius changes.                                  |
| AN-006   | Content transitions use scale+opacity combination                          | P0       | When the notch opens, content scales from 0.8 to 1.0 while fading in. When closing, the reverse. Anchor point is `.top`.                             |
| AN-007   | Gesture-driven expansion tracks finger position in real-time               | P1       | During a swipe, the notch size is proportional to the vertical translation. No perceptible lag between finger movement and notch size change.         |
| AN-008   | Swipe below commit threshold (20pt) snaps back                             | P1       | Swipe down 15pt and release — notch animates back to closed state. Swipe down 25pt and release — notch animates to fully open state.                 |
| AN-009   | First-launch "hello" animation plays once                                  | P2       | On first launch: glow animation plays, welcome sneak peek shows for 3s, then collapses. On second launch: no hello animation. `UserDefaults` key is set after first play. |
| AN-010   | Animations do not cause frame drops below 60fps                            | P0       | Instruments profiling during open/close transitions shows consistent 60fps (or display refresh rate). No hitches > 8ms.                               |

### State Machine

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| SM-001   | Four states: closed, sneakPeek, open, expandedDetail                       | P0       | The `NotchState` enum contains exactly these four cases. State is queryable at any time.                                                              |
| SM-002   | Transition T1: Closed -> Open on user activation                           | P0       | Any of the three activation methods (hover, click, swipe) successfully transitions from closed to open.                                               |
| SM-003   | Transition T2: Closed -> Sneak Peek on system event                        | P0       | Changing the now-playing track while notch is closed triggers a sneak peek showing the new track info.                                                |
| SM-004   | Transition T3: Sneak Peek -> Closed on dismiss timeout                     | P0       | Sneak peek auto-dismisses after the configured timeout (default 3s). State returns to closed.                                                         |
| SM-005   | Transition T4: Sneak Peek -> Open on user interaction                      | P0       | Clicking on the sneak peek content transitions to open state. Dismiss timer is canceled.                                                              |
| SM-006   | Transition T5: Open -> Closed on deactivation                              | P0       | Mouse leaving the expanded area triggers collapse after the configured delay. Escape key and hotkey trigger immediate collapse.                        |
| SM-007   | Transition T6: Open -> Expanded Detail on widget action                    | P1       | Clicking "show lyrics" in the music widget expands the notch to the expanded detail size showing lyrics.                                              |
| SM-008   | Transition T7: Expanded Detail -> Open on collapse action                  | P1       | Clicking the collapse chevron or pressing a back button returns to the standard open layout.                                                          |
| SM-009   | Transition T8: Expanded Detail -> Closed on deactivation                   | P1       | Mouse leaving the expanded detail area triggers collapse after delay, just as with the open state.                                                    |
| SM-010   | Invalid transition: Closed -> Expanded Detail is rejected                  | P0       | Programmatically attempting to transition from closed to expandedDetail is a no-op. State remains closed.                                             |
| SM-011   | Invalid transition: Same state -> Same state is a no-op                    | P0       | Triggering a transition to the current state produces no animation, no side effects, no errors.                                                       |
| SM-012   | Sneak peek events replace (not stack) when arriving in succession          | P0       | Skip 3 tracks rapidly — only the last track's info is shown. No queue of sneak peeks. Dismiss timer resets on each new event.                        |
| SM-013   | Sneak peek dismiss duration is configurable (1-10s)                        | P1       | Set dismiss duration to 5s. Sneak peek remains visible for 5s before auto-dismissing.                                                                |
| SM-014   | Each sneak peek event type can be individually enabled/disabled            | P1       | Disable "volume change" in settings. Change system volume — no sneak peek. Change track — sneak peek appears (still enabled).                        |

### Content Layout

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| CL-001   | Closed state shows battery, music indicator, and status icons              | P1       | In closed state with music playing: battery icon visible on left, animated equalizer in center, any active status icons on right.                     |
| CL-002   | Closed state shows only black shape when no indicators are active          | P0       | With no music playing and no active status: the closed notch is a plain black shape with no visible content.                                          |
| CL-003   | Open state has tab bar at top with icons                                   | P0       | Tab bar is visible at the top of the open notch. Home and Shelf tabs are always present. Active tab has a visual indicator.                           |
| CL-004   | Home tab shows media player (left) and widget grid (right)                 | P1       | In the Home tab with media playing: left 50% shows album art + controls, right 50% shows widget grid. Both are interactive.                          |
| CL-005   | Widget grid expands to full width when no media is playing                 | P1       | With no active media: the widget grid occupies the full content width. No empty media player area visible.                                           |
| CL-006   | Tab switching has horizontal slide transition                              | P1       | Switching from Home to Shelf: Home slides left and fades, Shelf slides in from right and fades in. Reverse for backward navigation.                  |
| CL-007   | Sneak peek shows icon, primary text, and secondary text in a single row   | P0       | Track change sneak peek: album art (24pt), track name (semibold), artist name (light). All in one horizontal line.                                   |
| CL-008   | Sneak peek has a countdown progress bar                                    | P2       | A thin bar at the bottom of the sneak peek animates from full width to zero over the dismiss duration.                                               |
| CL-009   | Expanded detail size is capped at 60% screen width and 50% screen height  | P1       | A widget requesting a larger expanded size is clamped to these maximums. The shape never exceeds the caps.                                            |
| CL-010   | Expanded detail has a collapse affordance                                  | P1       | A visible chevron-up icon or button in the expanded state returns to the standard open layout when clicked.                                           |

### Mouse & Gesture Handling

| ID       | Description                                                                 | Priority | Acceptance Criteria                                                                                                                                   |
|----------|-----------------------------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| MG-001   | Global mouse monitor tracks cursor position across all screens             | P0       | Moving the cursor to any screen's notch region is detected. The correct panel responds.                                                               |
| MG-002   | Global mouse monitor has negligible CPU overhead                           | P0       | With the notch closed and the mouse not near the notch: CPU usage from the mouse monitor is below 0.1% as measured by Instruments.                   |
| MG-003   | Local mouse monitor handles clicks within the panel                        | P0       | Buttons, sliders, and other controls within the open notch respond to clicks.                                                                         |
| MG-004   | Pan gesture recognizer works for swipe activation                          | P1       | Vertical panning on the notch region is recognized. Horizontal panning is ignored. Gesture reversal mid-swipe is tracked smoothly.                   |
| MG-005   | File drag near notch opens Shelf tab                                       | P1       | Begin dragging a file from Finder. Move it near the notch (within 60pt proximity). The notch opens to the Shelf tab automatically.                   |
| MG-006   | Right-click within the expanded notch shows context menu                   | P1       | Right-clicking in the open notch shows a menu with: Settings, Restart Niya, Close Niya, Quit Niya.                                                   |
| MG-007   | Click-through works during animation                                       | P0       | During the open/close animation, clicking on a menu bar item behind the animating transparent area passes through to the menu bar.                    |
| MG-008   | Drag-and-drop detection does not false-trigger                             | P1       | Moving the cursor near the notch without a drag operation in progress does not trigger the Shelf auto-open behavior.                                  |

---

## Appendix A: Configuration Defaults Summary

| Setting                   | Key                        | Default     | Range           |
|---------------------------|----------------------------|-------------|-----------------|
| Activation method         | `activationMethod`         | `hover`     | hover/click/swipe |
| Hover activation delay    | `hoverActivationDelay`     | 200 ms      | 50-1000 ms      |
| Collapse delay            | `collapseDelay`            | 500 ms      | 200-2000 ms     |
| Sneak peek dismiss time   | `sneakPeekDismissTime`     | 3 s         | 1-10 s          |
| Notch height mode         | `notchHeightMode`          | `matchMenuBar` | matchNotch/matchMenuBar/custom |
| Custom notch height       | `customNotchHeight`        | 32 pts      | 24-48 pts       |
| Virtual notch width       | `virtualNotchWidth`        | 230 pts     | 150-400 pts     |
| Virtual notch height      | `virtualNotchHeight`       | 32 pts      | 24-48 pts       |
| Virtual notch enabled     | `virtualNotchEnabled`      | true        | true/false      |
| Global hotkey             | `toggleHotkey`             | `Option+N`  | Any key combo   |
| First launch completed    | `hasCompletedFirstLaunch`  | false       | true/false      |

## Appendix B: Coordinate System Notes

macOS uses a **bottom-left origin** coordinate system for `NSWindow` and `NSScreen`. This means:

- `screen.frame.origin.y` is the **bottom** edge of the screen.
- `screen.frame.maxY` is the **top** edge of the screen.
- To pin a window to the **top** of the screen: `window.origin.y = screen.frame.maxY - windowHeight`.

SwiftUI views within `NSHostingView` use a **top-left origin** coordinate system internally. The `NSHostingView` handles the coordinate transformation.

When converting between mouse event coordinates (`NSEvent.mouseLocation`, which is in screen coordinates with bottom-left origin) and SwiftUI coordinates, use the `NSView.convert(_:from:)` methods rather than manual arithmetic.

## Appendix C: Private API Risk Assessment

| API                        | Usage                              | Risk Level | Fallback                        |
|----------------------------|------------------------------------|------------|---------------------------------|
| `CGSSpaceSetAbsoluteLevel` | Elevate panel above all windows    | High       | `.mainMenu + 3` (standard level) |
| `CGSMainConnectionID`      | Required for CGSSpace calls        | High       | Skip CGSSpace elevation entirely  |

Private APIs are:

- Loaded dynamically via `dlsym` — if the symbol is missing, the call is silently skipped.
- Wrapped in `try`/`catch` or crash-guard (`NSSetUncaughtExceptionHandler`) to prevent app termination.
- Tested on each new macOS beta. If broken, the feature is disabled in that version via a compile-time or runtime flag.
- Never required for core functionality — only for the "above absolutely everything" positioning edge case.

## Appendix D: Dependencies

| Dependency           | Purpose                    | Source                                           |
|----------------------|----------------------------|--------------------------------------------------|
| KeyboardShortcuts    | Global hotkey registration | https://github.com/sindresorhus/KeyboardShortcuts |

No other external dependencies are required for the core notch UI. All other functionality uses macOS system frameworks: AppKit, SwiftUI, CoreGraphics, MediaPlayer.
