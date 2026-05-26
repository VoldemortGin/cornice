# PRD-03: File Shelf

| Field         | Value                          |
|---------------|--------------------------------|
| **Feature**   | File Shelf                     |
| **PRD ID**    | PRD-03                         |
| **Status**    | Draft                          |
| **Author**    | Lin Han                        |
| **Created**   | 2026-05-26                     |
| **Updated**   | 2026-05-26                     |
| **Priority**  | P1 (Core)                      |
| **Depends On**| PRD-01 (Notch Window), PRD-02 (Expand/Collapse) |

---

## 1. Overview

The File Shelf is a temporary staging area that lives inside the notch. Users drag files, text snippets, URLs, or arbitrary data onto the notch, and the shelf holds them until they are dragged out to another destination, shared via AirDrop, or manually removed.

The shelf solves the "I need a place to put this while I switch contexts" problem -- a persistent, always-accessible drop zone that is faster than creating a desktop folder and more visible than minimized Finder windows.

---

## 2. Goals

- Provide a zero-friction drop target for any draggable content on macOS.
- Persist shelf items across app restarts via security-scoped bookmarks.
- Support bidirectional drag: INTO the shelf from any app, OUT of the shelf to any app.
- Handle all pasteboard content types gracefully with a clear priority chain.
- Integrate with AirDrop for instant sharing from the shelf (see PRD-04).

## 3. Non-Goals

- The shelf is NOT a permanent file manager or Finder replacement.
- No cloud sync of shelf items (local only, V1).
- No folder/grouping hierarchy within the shelf (flat list, V1).
- No automatic organization or tagging.

---

## 4. Drag Detection

### 4.1 Global Event Monitoring

The app must detect drags that originate anywhere on screen, not just within our window.

```
Monitoring chain:
  NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
```

- **`.leftMouseDown`**: Record the starting position. Begin watching for drag distance threshold (8pt).
- **`.leftMouseDragged`**: Once threshold exceeded, check if a real pasteboard drag is in progress by monitoring `NSPasteboard(name: .drag).changeCount`. If `changeCount` has incremented since the last known value, a genuine drag operation is active.
- **`.leftMouseUp`**: End tracking. If the cursor is within the notch hit-test region and a drag was active, treat as a drop.

### 4.2 Notch Region Hit-Testing

The notch region is defined by the current expansion state:

| State      | Hit-Test Region                                    |
|------------|----------------------------------------------------|
| Collapsed  | Hardware notch bounds + 12pt padding on each side  |
| Hover      | Expanded hover frame                               |
| Expanded   | Full shelf panel frame                             |

When dragged content enters the notch hit-test region:

1. Auto-expand the notch to the shelf view (animated, 200ms spring).
2. Show a visual drop indicator (pulsing border, dimmed background).
3. If the drag leaves the region for > 300ms, collapse back (unless shelf is pinned open).

### 4.3 Multi-Monitor Support

- Each screen with a built-in notch gets its own `DragDetector` instance.
- `DragDetector` is scoped to the `NSScreen` it monitors.
- Shelf items are shared across all screens (single `ShelfStore`), but the drop animation plays on the screen where the drop occurred.
- External monitors without a notch: no drag detection (shelf accessible via keyboard shortcut or menu bar only).

### 4.4 DragDetector Protocol

```swift
protocol DragDetectorDelegate: AnyObject {
    func dragDetector(_ detector: DragDetector, didDetectDragEnteringNotch event: NSEvent)
    func dragDetector(_ detector: DragDetector, didDetectDropInNotch event: NSEvent, pasteboard: NSPasteboard)
    func dragDetector(_ detector: DragDetector, didDetectDragLeavingNotch event: NSEvent)
}

final class DragDetector {
    let screen: NSScreen
    weak var delegate: DragDetectorDelegate?
    private var lastChangeCount: Int
    private var isDragActive: Bool
    private var monitors: [Any] = []

    func startMonitoring()
    func stopMonitoring()
}
```

---

## 5. Drop Processing

When a drop is detected, the pasteboard content is resolved through a priority chain. The **first** extractor that succeeds wins. This ordering ensures the most specific/useful representation is preferred.

### 5.1 Priority Chain

| Priority | Extractor            | Input                                    | Output                           |
|----------|----------------------|------------------------------------------|----------------------------------|
| 1        | `extractFileURL()`   | `NSPasteboard.PasteboardType.fileURL`    | `.file(bookmark:)` via security-scoped bookmark |
| 2        | `extractURL()`       | `NSPasteboard.PasteboardType.URL`        | File URLs -> `.file(bookmark:)`, Web URLs -> `.link(url:)` |
| 3        | `extractText()`      | `NSPasteboard.PasteboardType.string`     | `.text(string:)` (trimmed, max 10,000 chars) |
| 4        | `loadData()`         | `NSPasteboard.PasteboardType` raw data   | Save to temp file -> `.file(bookmark:)` |
| 5        | `extractItem()`      | Any remaining `NSPasteboardItem`         | Best-effort extraction, `.text(string:)` fallback |

### 5.2 Drop Processing Service

```swift
struct DropResult {
    let item: ShelfItem
    let wasDeduped: Bool  // true if item matched an existing shelf item
}

protocol DropProcessorProtocol {
    func process(pasteboard: NSPasteboard) async throws -> DropResult
}

final class DropProcessor: DropProcessorProtocol {
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol
    private let tempStorage: TemporaryFileStorageServiceProtocol
    private let shelfStore: ShelfStoreProtocol

    func process(pasteboard: NSPasteboard) async throws -> DropResult
}
```

### 5.3 Deduplication

Before adding a new item, check existing shelf items using `identityKey`:

- Files: canonical file path at drop time.
- URLs: normalized URL string (lowercase scheme/host, strip trailing slash).
- Text: SHA-256 hash of the trimmed content.

If a duplicate is found, bump the existing item's `createdAt` to now (moves it to front) rather than creating a new entry.

---

## 6. Data Model

### 6.1 ShelfItemKind

```swift
enum ShelfItemKind: Codable, Equatable {
    case file(bookmark: Data)     // Security-scoped bookmark data
    case text(string: String)     // Plain text snippet (max 10,000 chars)
    case link(url: URL)           // Web URL
}
```

### 6.2 ShelfItem

```swift
struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ShelfItemKind
    var createdAt: Date           // Mutable: updated on dedup bump
    var name: String              // Display name (editable by user)
    var identityKey: String       // For deduplication (see 5.3)
    var isPinned: Bool            // Pinned items resist auto-cleanup

    // Computed
    var typeLabel: String         // "PDF", "Image", "Text", "Link", etc.
    var iconName: String          // SF Symbol name for the item type
}
```

### 6.3 ShelfStore

```swift
protocol ShelfStoreProtocol: ObservableObject {
    var items: [ShelfItem] { get }
    var maxItems: Int { get set }

    func add(_ item: ShelfItem) throws
    func remove(id: UUID)
    func removeAll()
    func move(fromOffsets: IndexSet, toOffset: Int)
    func pin(id: UUID)
    func unpin(id: UUID)
    func item(for identityKey: String) -> ShelfItem?
}
```

---

## 7. Security-Scoped Bookmarks

### 7.1 Why Bookmarks

macOS sandboxing means file paths alone are insufficient. Once the user's drag session ends, the app loses access to the file unless a security-scoped bookmark is created during the drop.

### 7.2 Bookmark Lifecycle

```
Drop detected
  -> URL extracted from pasteboard
  -> URL.bookmarkData(options: .withSecurityScope, ...) called IMMEDIATELY
  -> Bookmark Data stored in ShelfItem.kind = .file(bookmark:)

User opens/drags item from shelf
  -> URL resolved from bookmark data via URL(resolvingBookmarkData:options:bookmarkDataIsStale:)
  -> url.startAccessingSecurityScopedResource() called
  -> File access performed
  -> url.stopAccessingSecurityScopedResource() called in defer block
```

### 7.3 Bookmark Service

```swift
protocol SecurityScopedBookmarkServiceProtocol {
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
    func accessResource<T>(bookmark: Data, operation: (URL) throws -> T) throws -> T
    func validateBookmarks(_ items: [ShelfItem]) -> [UUID]  // Returns IDs of invalid bookmarks
}
```

### 7.4 Stale Bookmark Handling

- On app launch, validate all stored bookmarks via `resolveBookmark`.
- If `bookmarkDataIsStale == true`, attempt to recreate the bookmark from the resolved URL.
- If resolution fails entirely (file deleted, volume unmounted), mark the item with a "broken" badge in the UI. Auto-remove after 7 days or on user action.
- Log stale/broken bookmarks for diagnostics.

---

## 8. Temporary File Storage

### 8.1 Purpose

When pasteboard data cannot be resolved to an existing file URL (e.g., image data dragged from a browser, raw binary blobs), the data must be written to a temporary file so it can be bookmarked and later provided via `NSItemProvider`.

### 8.2 Service

```swift
protocol TemporaryFileStorageServiceProtocol {
    func store(data: Data, suggestedName: String?, utType: UTType?) throws -> URL
    func store(text: String, suggestedName: String?) throws -> URL
    func createWebloc(for url: URL, name: String?) throws -> URL
    func cleanup(olderThan: TimeInterval)
    func cleanupAll()
    var storageDirectory: URL { get }
}
```

### 8.3 Storage Layout

```
NSTemporaryDirectory()/
  niya-shelf/
    <UUID>/
      image.png           // Actual file
    <UUID>/
      snippet.txt
    <UUID>/
      Example Site.webloc  // URL bookmark file
```

- Each item gets a UUID subdirectory to avoid name collisions.
- File names are derived from `suggestedName` or pasteboard metadata, sanitized for filesystem safety.
- UTType used to determine file extension when the name has none.

### 8.4 Cleanup Policy

| Trigger         | Behavior                                           |
|-----------------|----------------------------------------------------|
| App quit        | Remove all temp files for non-persisted shelf items |
| App launch      | Remove orphaned temp directories (no matching shelf item) |
| Manual clear    | Remove temp files for cleared items immediately     |
| Age limit       | Remove temp files older than 7 days on launch       |

---

## 9. Persistence

### 9.1 ShelfPersistenceService

```swift
protocol ShelfPersistenceServiceProtocol {
    func load() throws -> [ShelfItem]
    func save(_ items: [ShelfItem]) throws
    func clear() throws
}
```

### 9.2 Storage Format

- Encode `[ShelfItem]` as JSON via `JSONEncoder` with `.iso8601` date strategy.
- Write to: `Application Support/Niya/shelf-items.json`.
- Atomic write via `Data.write(to:options: .atomic)` to prevent corruption on crash.

### 9.3 Save Strategy

- Debounced save: coalesce rapid changes, write at most once per 2 seconds.
- Immediate save on: app resign active (`NSApplication.willResignActiveNotification`), app terminate.
- On load failure (corrupt JSON): log error, back up corrupt file, start with empty shelf.

### 9.4 Migration

- Include a `version: Int` field in the persisted JSON wrapper.
- When the schema changes, write a migration function `migrate(from:to:)` that transforms old JSON to new format before decoding.

---

## 10. User Interface

### 10.1 Layout

```
+-------------------------------------------------------+
|  [Shelf Items (horizontal scroll)]   [AirDrop Zone]   |
+-------------------------------------------------------+
|  item  item  item  item  item  ...   |   AirDrop      |
|  [ic]  [ic]  [ic]  [ic]  [ic]       |   [icon]        |
|  name  name  name  name  name        |   Drop here     |
+-------------------------------------------------------+
```

- Horizontal `ScrollView` with `LazyHGrid` for shelf items.
- Fixed-width AirDrop drop zone on the trailing edge (see PRD-04).
- Minimum shelf width: 400pt. Maximum: screen width - 100pt.
- Item cell size: 72x88pt (icon 48x48, label below).

### 10.2 Shelf Item Cell

Each cell displays:

| Element        | Description                                      |
|----------------|--------------------------------------------------|
| Icon/Thumbnail | File icon from `NSWorkspace.shared.icon(forFile:)` or generated thumbnail (images). Text items show a text snippet icon. Links show favicon or globe. |
| Name           | Truncated to 2 lines, 11pt system font.          |
| Type Badge     | Small colored dot: blue=file, green=text, orange=link. |
| Pin Indicator  | Small pin icon overlay if `isPinned == true`.    |
| Broken Badge   | Warning icon overlay if bookmark is stale/invalid. |

### 10.3 Item Interactions

| Interaction          | Action                                           |
|----------------------|--------------------------------------------------|
| Single click         | Select item (highlight border).                  |
| Double click         | Open item (files: default app, links: browser, text: copy to clipboard). |
| Right click          | Context menu (see below).                        |
| Drag out             | Provide item via `NSItemProvider` to other apps.  |
| Long press (0.5s)    | Enter reorder mode.                              |
| Swipe up (trackpad)  | Quick delete with confirmation.                  |

### 10.4 Context Menu

```
- Open
- Open With...          (files only)
- Copy
- Copy Path             (files only)
- Share...              (NSSharingServicePicker)
- AirDrop               (NSSharingService sendViaAirDrop)
- Quick Look            (QLPreviewPanel)
- Rename
- Pin / Unpin
- ──────────
- Remove from Shelf
```

### 10.5 Drag OUT from Shelf

When the user drags an item out of the shelf:

1. Create `NSItemProvider` with appropriate content:
   - `.file`: Resolve bookmark, provide file URL.
   - `.text`: Provide as `UTType.utf8PlainText`.
   - `.link`: Provide as `UTType.url`.
2. Attach drag preview (item thumbnail).
3. On successful drop to external target: optionally remove from shelf (configurable: "Remove after drag out" toggle in settings, default OFF).
4. On failed/cancelled drag: no change.

### 10.6 Empty State

When the shelf is empty:

```
+-----------------------------------------------+
|                                               |
|   [drop icon]                                 |
|   Drag files, text, or links here             |
|   They'll be waiting when you need them       |
|                                               |
+-----------------------------------------------+
```

### 10.7 Animations

| Event              | Animation                                      |
|--------------------|-------------------------------------------------|
| Item added         | Scale from 0.5 to 1.0 with spring, slide in from drop point. |
| Item removed       | Fade out + scale to 0.8, items reflow.          |
| Drop hover         | Shelf border pulses blue, slight scale up (1.02x). |
| Reorder            | Standard SwiftUI reorder with drag shadow.       |
| Shelf expand       | Spring animation, 200ms.                        |
| Shelf collapse     | Ease-out, 150ms.                                |

---

## 11. AirDrop Integration (Within Shelf)

See PRD-04 for the full AirDrop specification. Within the shelf context:

### 11.1 AirDrop Drop Zone

- Fixed 80pt-wide zone on the trailing edge of the shelf.
- Displays AirDrop icon + "AirDrop" label.
- Visual states: idle (dimmed), drag-hover (highlighted blue), unavailable (grayed out with "AirDrop Off" label).

### 11.2 AirDrop Flow

```
User drags item onto AirDrop zone
  -> Resolve item to shareable content (file URL, text, URL)
  -> NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [content])
  -> System AirDrop picker appears
  -> User selects device
  -> Transfer completes (or user cancels)
```

### 11.3 AirDrop Availability

- Check `NSSharingService(named: .sendViaAirDrop)?.canPerform(withItems:)` before showing the zone as active.
- If AirDrop is disabled in system settings, show disabled state with tooltip: "Enable AirDrop in System Settings > General > AirDrop & Handoff".

---

## 12. Settings

| Setting                      | Type    | Default | Description                              |
|------------------------------|---------|---------|------------------------------------------|
| `shelf.maxItems`             | Int     | 20      | Maximum shelf items before oldest auto-removed. |
| `shelf.removeAfterDragOut`   | Bool    | false   | Remove item from shelf after successful drag out. |
| `shelf.showTypeIndicator`    | Bool    | true    | Show colored type badge on items.         |
| `shelf.autoExpandOnDrag`     | Bool    | true    | Auto-expand notch when drag enters region.|
| `shelf.dragLeaveTimeout`     | Double  | 0.3     | Seconds before collapsing after drag leaves. |
| `shelf.persistAcrossRestart` | Bool    | true    | Persist shelf items across app restarts.  |

---

## 13. Error Handling

| Error                          | Handling                                         |
|--------------------------------|--------------------------------------------------|
| Bookmark creation fails        | Fall back to `loadData()` extractor (temp file). |
| Bookmark resolution fails      | Show broken badge, offer "Relocate" or "Remove". |
| Temp directory not writable    | Show user alert, log error, reject drop.         |
| Pasteboard empty on drop       | Ignore silently (race condition with drag cancel).|
| Max items exceeded             | Remove oldest unpinned item, add new item.       |
| Persistence load fails         | Start with empty shelf, log warning.             |
| Persistence save fails         | Retry once after 1s, log error, alert on second failure. |
| AirDrop unavailable            | Gray out AirDrop zone, show tooltip.             |

---

## 14. Testing Strategy

### 14.1 Unit Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| DropProcessor            | Each extractor in priority chain; deduplication; max-length text truncation; malformed pasteboard data. |
| SecurityScopedBookmark   | Create/resolve/stale/invalid lifecycle; concurrent access. |
| TemporaryFileStorage     | Store data/text/webloc; cleanup policies; disk full handling. |
| ShelfStore               | Add/remove/reorder/pin/unpin; max items enforcement; dedup. |
| ShelfPersistence         | Save/load round-trip; corrupt data recovery; migration. |
| ShelfItem                | Codable round-trip; identityKey generation; equality. |

### 14.2 Integration Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| Drop-to-Persist          | Drop file -> item appears in store -> app restart -> item still present -> bookmark resolves. |
| Drag-Out                 | Item in shelf -> drag to Finder -> file appears in Finder. |
| AirDrop                  | Item in shelf -> drag to AirDrop zone -> sharing service invoked. |

### 14.3 UI Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| Empty state              | Shelf shows empty message when no items.         |
| Item display             | Correct icon, name, type badge for each kind.    |
| Context menu             | All actions present and functional.              |
| Drag hover               | Shelf expands on drag enter, collapses on leave. |
| Reorder                  | Long press + drag reorders items.                |

---

## 15. Requirements

| ID       | Priority | Requirement                                              | Acceptance Criteria                              |
|----------|----------|----------------------------------------------------------|--------------------------------------------------|
| FS-001   | P0       | Detect drags anywhere on screen using global event monitoring. | `DragDetector` fires delegate callback when drag with pasteboard content enters notch region. Verified via unit test with mock events. |
| FS-002   | P0       | Process drops through the 5-step priority chain.         | Each extractor handles its content type correctly. Extractors are attempted in order; first success wins. Verified via unit tests with mock pasteboards. |
| FS-003   | P0       | Store file references as security-scoped bookmarks.      | Files dropped onto shelf can be opened after app restart. Bookmark data persists in `ShelfItem`. Verified via integration test: drop file, restart, open. |
| FS-004   | P0       | Persist shelf items across app restarts.                 | `ShelfPersistenceService` saves items to disk. After app restart, all items reload with correct kind, name, and identity. Verified via persistence round-trip test. |
| FS-005   | P0       | Display shelf items in a horizontal scrollable grid.     | Items render with correct icon, name, and type badge. Scroll works with 20+ items. Verified via UI test. |
| FS-006   | P0       | Support drag OUT from shelf to external apps.            | Dragging a file item from shelf to Finder creates the file. Dragging text to TextEdit pastes the text. Verified via integration test. |
| FS-007   | P1       | Deduplicate items by identity key on drop.               | Dropping the same file twice does not create two items. The existing item's timestamp is bumped. Verified via unit test. |
| FS-008   | P1       | Auto-expand notch when drag enters notch region.         | Notch expands within 200ms of drag entering the hit-test region. Collapses after drag leaves for 300ms. Verified via UI test. |
| FS-009   | P1       | Support multi-monitor with per-screen drag detection.    | Each notch-equipped screen gets its own `DragDetector`. Drops on screen 2 animate on screen 2. Shared shelf store. Verified manually on dual-monitor setup. |
| FS-010   | P1       | Context menu with Open, Copy, Share, Quick Look, Remove. | Right-clicking a shelf item shows the full context menu. Each action performs correctly. Verified via UI test. |
| FS-011   | P1       | Handle stale/broken bookmarks gracefully.                | Stale bookmarks are auto-refreshed. Unresolvable bookmarks show a broken badge. Items with broken bookmarks for 7+ days are auto-removed. Verified via unit test with simulated stale bookmarks. |
| FS-012   | P1       | Store raw data drops as temporary files.                 | Data without a file URL is saved to temp directory and bookmarked. Temp files are cleaned up per the cleanup policy. Verified via unit test. |
| FS-013   | P1       | AirDrop zone in shelf for instant sharing.               | Dragging an item onto the AirDrop zone invokes `NSSharingService(named: .sendViaAirDrop)`. Zone shows disabled state when AirDrop is off. Verified via integration test with mock sharing service. |
| FS-014   | P2       | Pin items to prevent auto-pruning.                       | Pinned items survive max-items enforcement. Pin/unpin via context menu. Verified via unit test. |
| FS-015   | P2       | Configurable max items with auto-pruning.                | When shelf exceeds `maxItems`, the oldest unpinned item is removed. Configurable in settings. Verified via unit test. |
| FS-016   | P2       | Item reordering via long press and drag.                 | Long pressing an item enters reorder mode. Dragging rearranges items. New order persists. Verified via UI test. |
| FS-017   | P2       | Quick Look preview for shelf items.                      | Selecting Quick Look from context menu opens `QLPreviewPanel` with the item. Verified via UI test. |
| FS-018   | P2       | Rename shelf items.                                      | Selecting Rename from context menu makes the name label editable. New name persists. Verified via UI test. |
| FS-019   | P3       | "Remove after drag out" setting.                         | When enabled, items are automatically removed from shelf after a successful drag-out. Verified via integration test. |
| FS-020   | P3       | Persistence schema migration.                            | When the persisted JSON version changes, old data is migrated to the new schema. Verified via unit test with old-format JSON fixtures. |

---

## 16. Open Questions

1. Should the shelf support folders/groups in a future version?
2. Maximum file size for temporary file storage (currently unbounded)?
3. Should shelf items be accessible from the menu bar icon as well?
4. Keyboard shortcut for opening/focusing the shelf without drag?
