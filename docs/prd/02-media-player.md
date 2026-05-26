# PRD-02: Now Playing / Media Player Integration

## 1. Overview

Niya displays the currently playing track in the Dynamic Island notch area and provides full playback controls. Because macOS 15.4+ restricts direct use of `MediaRemote.framework` to apps with a private Apple entitlement, Niya uses a **mediaremote-adapter** approach: a bundled Objective-C framework paired with a Perl helper script that bridges Now Playing data over stdout as JSON lines.

The media subsystem follows a **strategy pattern** so the active controller can be swapped at runtime (system-wide Now Playing, Apple Music AppleScript, Spotify AppleScript, or browser-based YouTube Music).

---

## 2. Architecture

### 2.1 Now Playing Data Acquisition

#### Primary path: mediaremote-adapter (macOS 15.4+)

| Component | Role |
|-----------|------|
| `MediaRemoteAdapter.framework` | Bundled Obj-C framework that dynamically loads `MediaRemote.framework` via `dlopen` and exposes C-callable wrappers for registration, info dictionary access, and command dispatch. |
| `nowplaying-cli` (Perl script) | Launched as a child process. In **stream** mode it registers for `MRMediaRemoteRegisterForNowPlayingNotifications` and prints one JSON object per line to stdout on every state change. |
| `NowPlayingBridge` (Swift) | Spawns the Perl process via `Process`, reads stdout with `FileHandle.readabilityHandler`, decodes each JSON line into `NowPlayingState`. |

**Stream JSON schema** (one object per line):

```jsonc
{
  "title": "string",
  "artist": "string",
  "album": "string | null",
  "artworkData": "base64-encoded PNG | null",
  "duration": 245.0,        // seconds, Double
  "elapsedTime": 112.3,     // seconds, Double
  "playbackRate": 1.0,      // 0.0 = paused, 1.0 = playing
  "timestamp": 1716700000.0 // CFAbsoluteTime of this snapshot
}
```

#### Fallback path: direct MediaRemote dlopen (macOS < 15.4)

On older systems the private framework can be loaded directly from Swift without the adapter. `NowPlayingController` detects the OS version at init and chooses the appropriate path.

```
if ProcessInfo.processInfo.operatingSystemVersion.minorVersion < 4 {
    // direct dlopen path
} else {
    // mediaremote-adapter subprocess path
}
```

### 2.2 Strategy Pattern: MediaControllerProtocol

```swift
import Combine

enum RepeatMode: Int, Sendable {
    case off = 0
    case all = 1
    case one = 2
}

struct PlaybackState: Sendable {
    let title: String
    let artist: String
    let album: String?
    let artworkData: Data?
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double       // 0 = paused, 1 = playing
    let shuffleEnabled: Bool?
    let repeatMode: RepeatMode?
}

protocol MediaControllerProtocol: AnyObject, Sendable {
    /// Continuous stream of playback state updates.
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }

    // Transport controls
    func play() async throws
    func pause() async throws
    func togglePlay() async throws
    func nextTrack() async throws
    func previousTrack() async throws

    // Seek & volume
    func seek(to position: TimeInterval) async throws
    func setVolume(_ level: Float) async throws   // 0.0 ... 1.0

    // Shuffle & repeat
    func setShuffle(_ enabled: Bool) async throws
    func setRepeatMode(_ mode: RepeatMode) async throws
}
```

### 2.3 Controller Implementations

| # | Class | Data Source | Notes |
|---|-------|-----------|-------|
| 1 | `NowPlayingController` | mediaremote-adapter / direct dlopen | System-wide; works with any app. Cannot control shuffle/repeat. |
| 2 | `AppleMusicController` | AppleScript (`Music` app) | Richer metadata (genre, loved status). Volume is per-app. |
| 3 | `SpotifyController` | AppleScript (`Spotify` app) | Per-app volume, shuffle, repeat. |
| 4 | `YouTubeMusicController` | Browser automation (AppleScript to Chrome/Safari tab) | Requires user to have YouTube Music open. |

Each implementation conforms to `MediaControllerProtocol`. Methods that the controller cannot support throw `MediaControllerError.unsupported`.

```swift
enum MediaControllerError: Error, LocalizedError {
    case unsupported
    case connectionLost
    case appNotRunning(String)
    case scriptError(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:           return "This control is not supported by the current media source."
        case .connectionLost:        return "Lost connection to the media source."
        case .appNotRunning(let app): return "\(app) is not running."
        case .scriptError(let msg):  return "Script error: \(msg)"
        }
    }
}
```

### 2.4 MusicManager (Singleton)

`MusicManager` is the single point of truth for all media state consumed by UI.

```swift
@MainActor
final class MusicManager: ObservableObject {
    static let shared = MusicManager()

    // MARK: - Published state
    @Published private(set) var songTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var albumName: String = ""
    @Published private(set) var albumArt: NSImage?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var shuffleEnabled: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var volume: Float = 0.5
    @Published private(set) var dominantColor: NSColor = .controlAccentColor
    @Published private(set) var visualizerSamples: [Float] = []

    // MARK: - Active controller
    private(set) var activeController: (any MediaControllerProtocol)?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Controller management
    func setController(_ controller: any MediaControllerProtocol) { ... }

    // MARK: - Internal
    /// Extracts average color from artwork for theming.
    private func extractDominantColor(from image: NSImage) -> NSColor { ... }

    /// Triggers sneak peek notification on track change.
    private func onTrackChanged(old: PlaybackState?, new: PlaybackState) { ... }
}
```

**Responsibilities:**

1. Hold a reference to the active `MediaControllerProtocol` implementation.
2. Subscribe to `playbackStatePublisher` via Combine; update all `@Published` properties on main actor.
3. Detect track changes (title + artist differ from previous) and call `NotchViewModel.triggerSneakPeek(.trackChange)`.
4. Extract the dominant color from album artwork for Dynamic Island theming.
5. Maintain an elapsed-time timer (1 Hz) that interpolates between server updates when `playbackRate > 0`.
6. Forward control actions (play, pause, next, etc.) to the active controller.

---

## 3. UI Components

### 3.1 Closed State Indicator

When the notch is in its default closed state and music is playing, a subtle indicator appears adjacent to the notch.

| Variant | Description |
|---------|-------------|
| Animated bars | Three thin vertical bars that oscillate height in a staggered sine pattern. Bars freeze when paused. |
| Music note | A single eighth-note glyph that gently pulses opacity. |

The user selects their preferred variant in Settings > Media > Closed Indicator Style.

### 3.2 Sneak Peek

Triggered automatically on track change or manually via a gesture.

```
+-------------------------------------------------------+
|  [Album Art 32x32]  Song Title - Artist Name           |
+-------------------------------------------------------+
```

- Appears as a pill below the notch.
- Auto-dismisses after 3 seconds (configurable 1-5s in settings).
- Tap the sneak peek to expand to compact media view.
- Album art corner radius: 4pt.
- Text truncates with ellipsis if wider than available space.

### 3.3 Open State: Compact

Activated by clicking the notch or tapping the sneak peek.

```
+---------------------------------------------------------------+
|                                                               |
|  +----------+   Song Title                                    |
|  | Album    |   Artist Name                                   |
|  |  Art     |   [====---------] 1:52 / 3:45                  |
|  | (60x60)  |   [<<]  [Play/Pause]  [>>]                     |
|  +----------+                                                 |
|                                                               |
+---------------------------------------------------------------+
```

- Album art: 60x60pt, corner radius 8pt.
- Progress bar: draggable. Tap anywhere to seek.
- Controls: SF Symbols `backward.fill`, `play.fill`/`pause.fill`, `forward.fill`.
- Elapsed / duration labels in `mm:ss` format.
- Background tinted with dominant album color at 15% opacity.

### 3.4 Open State: Expanded

Activated by clicking an expand chevron or dragging down from compact view.

```
+---------------------------------------------------------------+
|                                                               |
|              +-------------------+                            |
|              |                   |                            |
|              |    Album Art      |                            |
|              |    (200x200)      |                            |
|              |                   |                            |
|              +-------------------+                            |
|                                                               |
|              Song Title                                       |
|              Artist Name - Album Name                         |
|                                                               |
|  [============================---------] 2:45 / 4:10          |
|                                                               |
|  [Shuffle]   [<<]  [Play/Pause]  [>>]   [Repeat]            |
|                                                               |
|  Volume: [======------] 60%                                   |
|                                                               |
|  +---------------------------------------------------+       |
|  |  Lyrics line 1 (dimmed)                            |       |
|  |  ► Current lyrics line (highlighted)               |       |
|  |  Lyrics line 3 (dimmed)                            |       |
|  +---------------------------------------------------+       |
|                                                               |
|  [Visualizer: |||||||||| spectrum bars]                       |
|                                                               |
+---------------------------------------------------------------+
```

- Album art: 200x200pt, corner radius 12pt, shadow.
- Lyrics panel: scrolling, time-synced if available (Apple Music provides timed lyrics via AppleScript). Falls back to static lyrics or "No lyrics available."
- Volume slider: system volume by default; per-app volume when using AppleMusic/Spotify controller.
- Shuffle button: toggles state; highlighted when active.
- Repeat button: cycles through off (no highlight) -> all (highlight) -> one (highlight + "1" badge).

### 3.5 Music Visualizer

Displayed in the expanded view. Configurable in Settings > Media > Visualizer.

| Mode | Description |
|------|-------------|
| Spectrum bars | 16-32 vertical bars reflecting frequency bands. Data sourced from audio tap (if available) or simulated from playback rate. |
| Waveform | Smooth sine-wave animation. Amplitude modulated by volume level. |
| Lottie custom | User provides a URL to a Lottie JSON file. Playback speed tied to `playbackRate`. |
| None | Visualizer hidden. |

**Audio data source priority:**

1. Core Audio tap on the output device (requires Screen Recording permission on macOS 14+).
2. Simulated: generate plausible bar heights from a seeded random generator modulated by `isPlaying` and `volume`.

---

## 4. Playback Controls Detail

### 4.1 Play / Pause

- `MusicManager.togglePlay()` -> `activeController.togglePlay()`
- For NowPlayingController: sends `MRMediaRemoteCommandTogglePlayPause`.
- For AppleScript controllers: `tell application "Music" to playpause`.
- Keyboard shortcut in expanded view: Space bar.

### 4.2 Next / Previous Track

- `MusicManager.nextTrack()` / `.previousTrack()`
- NowPlayingController: `MRMediaRemoteCommandNextTrack` / `MRMediaRemoteCommandPreviousTrack`.
- Previous track behavior: if elapsed > 3s, restart current track; else go to previous.

### 4.3 Seek

- User drags the progress bar thumb or clicks a position on the bar.
- Computes target position as `proportion * duration`.
- `MusicManager.seek(to: targetSeconds)` -> `activeController.seek(to:)`.
- During drag, elapsed label updates in real-time (scrub preview) but the actual seek command fires on drag end (debounce).

### 4.4 Volume

- System volume: controlled via CoreAudio `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`.
- Per-app volume (Apple Music): `tell application "Music" to set sound volume to X` (0-100 integer).
- Per-app volume (Spotify): `tell application "Spotify" to set sound volume to X` (0-100 integer).
- The slider range is always 0.0 - 1.0; the controller scales internally.
- Volume icon changes:
  - 0.0: `speaker.slash.fill`
  - 0.01 - 0.33: `speaker.wave.1.fill`
  - 0.34 - 0.66: `speaker.wave.2.fill`
  - 0.67 - 1.0: `speaker.wave.3.fill`

### 4.5 Shuffle

- `MusicManager.toggleShuffle()`
- NowPlayingController: `MRMediaRemoteCommandSetShuffleMode`.
- AppleScript: `tell application "Music" to set shuffle enabled to (not shuffle enabled)`.
- Button tint: accent color when enabled, secondary label color when disabled.

### 4.6 Repeat Mode

- Cycles: `.off` -> `.all` -> `.one` -> `.off`
- `MusicManager.cycleRepeatMode()`
- NowPlayingController: `MRMediaRemoteCommandSetRepeatMode`.
- AppleScript: `tell application "Music" to set song repeat to {off, all, one}`.
- Visual states:
  - `.off`: `repeat` SF Symbol, secondary color.
  - `.all`: `repeat` SF Symbol, accent color.
  - `.one`: `repeat.1` SF Symbol, accent color.

---

## 5. Artwork Color Extraction

The dominant color from album artwork is used for:
- Tinting the Dynamic Island background in compact/expanded media views.
- Tinting the progress bar fill color.
- Sneak peek pill background subtle tint.

**Algorithm:**

1. Downscale image to 40x40 pixels using `NSImage.cgImage` + `vImage`.
2. Iterate all pixels; accumulate weighted RGB (weight = saturation * brightness to avoid grays).
3. Find the top color cluster via simple k-means (k=3) on the weighted pixels.
4. Select the cluster with highest saturation. If all clusters are below saturation threshold 0.15, fall back to `NSColor.controlAccentColor`.
5. Ensure sufficient contrast against the notch background (black): if luminance < 0.25, lighten by 30%.
6. Cache color per artwork hash (`SHA256` of `artworkData`).

---

## 6. Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Preferred controller | Enum | NowPlaying | Which `MediaControllerProtocol` to use. |
| Closed indicator style | Enum | Animated bars | `animatedBars`, `musicNote`, `none`. |
| Sneak peek on track change | Bool | true | Show sneak peek when track changes. |
| Sneak peek duration | Double | 3.0 | Seconds before auto-dismiss (1.0 - 5.0). |
| Visualizer mode | Enum | Spectrum bars | `spectrumBars`, `waveform`, `lottieCustom`, `none`. |
| Lottie URL | String? | nil | URL to custom Lottie JSON for visualizer. |
| Show lyrics in expanded | Bool | true | Display lyrics panel in expanded view. |
| Album art color theming | Bool | true | Tint UI with album art dominant color. |

---

## 7. Permissions

| Permission | Why | Fallback if denied |
|------------|-----|--------------------|
| Accessibility | Not needed for media (only for HUD). | N/A for this module. |
| Automation (AppleScript) | Required for Apple Music, Spotify, YouTube Music controllers. | Fall back to NowPlayingController. |
| Screen Recording | Required for audio tap (visualizer real data). | Use simulated visualizer data. |

---

## 8. Requirements

| ID | Description | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| MP-001 | Display Now Playing data (title, artist, album art) from any media app via mediaremote-adapter. | P0 | When any app plays audio, Niya shows correct title and artist within 2 seconds. |
| MP-002 | Fallback to direct MediaRemote dlopen on macOS < 15.4. | P0 | On macOS 15.3 and earlier, Now Playing data is acquired without the Perl subprocess. |
| MP-003 | Implement `MediaControllerProtocol` with NowPlayingController. | P0 | `playbackStatePublisher` emits updates; `play()`, `pause()`, `togglePlay()`, `nextTrack()`, `previousTrack()` send correct MR commands. |
| MP-004 | Implement `AppleMusicController` via AppleScript. | P1 | When Apple Music is running and selected as controller, all transport controls work and per-app volume is adjustable. |
| MP-005 | Implement `SpotifyController` via AppleScript. | P1 | When Spotify is running and selected as controller, all transport controls work including shuffle and repeat. |
| MP-006 | Implement `YouTubeMusicController` via browser AppleScript. | P2 | When YouTube Music is open in Chrome/Safari and selected, play/pause and next/previous work. |
| MP-007 | `MusicManager` singleton publishes all playback state as `@Published` properties. | P0 | SwiftUI views bound to `MusicManager` update reactively on every state change. |
| MP-008 | Closed state indicator shows animated bars or music note when music is playing. | P0 | Indicator is visible next to the notch; freezes when paused; hidden when no media is active. |
| MP-009 | Sneak peek appears on track change with album art, title, artist. | P0 | Sneak peek pill appears within 0.5s of track change, shows correct data, auto-dismisses after configured duration. |
| MP-010 | Compact open view displays album art, track info, progress bar, transport controls. | P0 | All elements render correctly; progress bar reflects actual playback position; controls function. |
| MP-011 | Expanded open view adds lyrics, shuffle, repeat, volume, visualizer. | P1 | All additional controls function; lyrics scroll in sync (when available); visualizer animates. |
| MP-012 | Progress bar is draggable for seeking. | P0 | Dragging the progress bar thumb seeks to the corresponding position in the track; elapsed label updates during drag. |
| MP-013 | Volume slider controls system or per-app volume depending on active controller. | P1 | Volume changes are audible and reflected in the OS volume indicator; per-app volume works for Apple Music and Spotify. |
| MP-014 | Shuffle toggle works for controllers that support it. | P1 | Shuffle state toggles and UI reflects the new state; unsupported controllers show the button disabled. |
| MP-015 | Repeat mode cycles through off/all/one. | P1 | Each press advances the mode; UI icon and tint update accordingly. |
| MP-016 | Album art dominant color extraction tints the media UI. | P1 | Background tint, progress bar color, and sneak peek tint reflect the dominant album art color; fallback to accent color for low-saturation artwork. |
| MP-017 | Music visualizer displays spectrum bars or waveform when enabled. | P2 | Visualizer animates in time with audio; freezes when paused; respects selected mode in settings. |
| MP-018 | User can select preferred media controller in Settings. | P1 | Changing the controller in settings switches the active controller; playback state updates from the new source. |
| MP-019 | Lottie custom visualizer loads from user-provided URL. | P2 | Providing a valid Lottie JSON URL displays the animation; invalid URLs show a fallback or error message. |
| MP-020 | Elapsed time interpolates smoothly between server updates. | P0 | Elapsed time label and progress bar advance at 1 Hz without visible jumps when no seek or track change occurs. |
| MP-021 | Elapsed time resets correctly on track change. | P0 | When a new track starts, elapsed resets to 0 (or the reported elapsed) without showing stale data from the previous track. |
| MP-022 | Perl subprocess is managed reliably (launch, crash recovery, cleanup on quit). | P0 | If the Perl process crashes, it is relaunched within 2 seconds; on app quit, the process is terminated. No zombie processes. |

---

## 9. Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| No media playing | Closed indicator hidden; opening notch shows "Nothing Playing" placeholder. |
| Media app quits mid-playback | State resets to idle within 3 seconds; sneak peek not triggered. |
| Artwork unavailable | Display a generic music note placeholder image; dominant color falls back to accent color. |
| Very long track title / artist | Text truncates with trailing ellipsis; tooltip shows full text on hover. |
| Multiple media apps playing | NowPlayingController reports whichever app macOS considers the active Now Playing app. |
| Network album art (Spotify web) | Artwork may arrive asynchronously after title/artist; UI updates art when received without layout jump. |
| macOS version detection fails | Default to mediaremote-adapter path (safer). |
| AppleScript permission denied | Show one-time prompt guiding user to System Settings > Privacy > Automation; fall back to NowPlayingController. |

---

## 10. Testing Strategy

| Layer | Tool | What to test |
|-------|------|-------------|
| Unit | XCTest | `PlaybackState` parsing from JSON, dominant color extraction, repeat mode cycling, elapsed time interpolation logic. |
| Unit | XCTest + mock | `MusicManager` with a mock `MediaControllerProtocol` — verify `@Published` properties update, sneak peek triggers, track change detection. |
| Integration | XCTest | `NowPlayingBridge` with a fake Perl process that emits known JSON lines — verify stream parsing and error recovery. |
| Integration | XCTest | Each AppleScript controller against a running app (manual / CI with Xcode UI testing host). |
| UI | XCTest UI / Swift Previews | Compact view, expanded view, sneak peek appearance and dismissal, progress bar drag. |
| Snapshot | swift-snapshot-testing | Closed indicator, sneak peek pill, compact view, expanded view at various states (playing, paused, no art). |
