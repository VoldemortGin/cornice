# PRD-07: Clipboard History

| Field         | Value                          |
|---------------|--------------------------------|
| **Feature**   | Clipboard History              |
| **PRD ID**    | PRD-07                         |
| **Status**    | Draft                          |
| **Author**    | Lin Han                        |
| **Created**   | 2026-05-26                     |
| **Updated**   | 2026-05-26                     |
| **Priority**  | P1 (Core)                      |
| **Depends On**| PRD-01 (Notch Window), PRD-02 (Expand/Collapse) |

---

## 1. Overview

Clipboard History monitors `NSPasteboard.general` for changes and maintains a searchable, reverse-chronological history of everything the user copies. Users access history from the expanded notch to re-copy past entries, search by content or source app, and pin important entries.

This replaces the need for third-party clipboard managers by embedding the feature directly into the notch, making it faster to access and visually integrated with the rest of Niya.

---

## 2. Goals

- Capture all clipboard changes transparently with minimal CPU overhead.
- Support text, images, file URLs, and rich text.
- Provide instant search across all stored entries.
- Let users re-copy any entry with a single click.
- Respect user privacy: no data leaves the device, configurable exclusions.

## 3. Non-Goals

- Clipboard sync across devices (V1 is local only).
- Full image storage (thumbnails only to bound disk usage).
- Rich text editing within clipboard history.
- OCR of image clipboard content (future consideration).

---

## 4. Clipboard Monitoring

### 4.1 Polling Strategy

macOS provides no notification for clipboard changes. The standard approach is polling `NSPasteboard.general.changeCount`.

```swift
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pollInterval: TimeInterval = 0.5  // 500ms

    func startMonitoring()
    func stopMonitoring()
    func pauseMonitoring()    // User-triggered pause
    func resumeMonitoring()
}
```

**Why 0.5s**: Balances responsiveness with CPU overhead. At 0.5s intervals, the monitor performs one integer comparison per tick -- negligible CPU impact. Sub-100ms polling is unnecessary since users rarely need sub-second clipboard history granularity.

### 4.2 Change Detection Flow

```
Timer fires every 0.5s
  -> Read NSPasteboard.general.changeCount
  -> If changeCount == lastChangeCount: return (no change)
  -> If changeCount != lastChangeCount:
       -> Update lastChangeCount
       -> Read pasteboard contents
       -> Determine content type
       -> Check exclusion list (source app bundle ID)
       -> If not excluded: create ClipboardEntry, add to store
```

### 4.3 Content Extraction

On each change, attempt to extract content in priority order:

| Priority | Type Check                                    | Content Type     | Extraction                                      |
|----------|-----------------------------------------------|------------------|--------------------------------------------------|
| 1        | `types.contains(.fileURL)`                    | `.fileURL`       | Extract file URLs array.                         |
| 2        | `types.contains(.tiff)` or `.png`             | `.image`         | Extract image data, generate thumbnail (max 256x256, JPEG 0.7 quality). |
| 3        | `types.contains(.rtf)` or `.rtfd`             | `.richText`      | Extract plain text representation + store RTF data reference. |
| 4        | `types.contains(.string)`                     | `.text`          | Extract string content.                          |

**Source app detection**: Use `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` at capture time. This is a best-effort heuristic (the frontmost app is usually the one that initiated the copy).

### 4.4 Content Size Limits

| Content Type | Max Stored Size | Behavior on Exceed                           |
|-------------|-----------------|----------------------------------------------|
| Text        | 50,000 chars    | Truncate, store flag `isTruncated = true`.   |
| Image       | 256x256 thumb   | Always downscale to thumbnail. Original not stored. |
| Rich Text   | 50,000 chars    | Store plain text fallback, drop RTF data.    |
| File URLs   | 100 URLs        | Truncate list, store flag `isTruncated = true`. |

---

## 5. Data Model

### 5.1 ClipboardContentType

```swift
enum ClipboardContentType: String, Codable {
    case text
    case image
    case fileURL
    case richText
}
```

### 5.2 ClipboardEntry

```swift
struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let contentType: ClipboardContentType
    let textContent: String?           // For .text and .richText (plain text fallback)
    let imageData: Data?               // Thumbnail JPEG data (max ~50KB per entry)
    let fileURLs: [URL]?              // For .fileURL type
    let sourceAppBundleID: String?     // e.g., "com.apple.Safari"
    let sourceAppName: String?         // e.g., "Safari" (for display)
    var isPinned: Bool                 // Pinned entries survive auto-pruning
    var isTruncated: Bool              // Content was too large, stored partially

    // Computed
    var previewText: String            // First 200 chars for list display
    var contentSizeDescription: String // "1.2 KB", "3 files", "Image"
}
```

### 5.3 ClipboardHistoryStore

```swift
protocol ClipboardHistoryStoreProtocol: ObservableObject {
    var entries: [ClipboardEntry] { get }          // Reverse-chronological
    var pinnedEntries: [ClipboardEntry] { get }    // Pinned subset
    var maxEntries: Int { get set }

    func add(_ entry: ClipboardEntry)
    func remove(id: UUID)
    func removeAll()
    func pin(id: UUID)
    func unpin(id: UUID)
    func copyToClipboard(id: UUID)                 // Re-copy entry to NSPasteboard
    func search(query: String) -> [ClipboardEntry]
}
```

---

## 6. Storage

### 6.1 Persistence

- Encode `[ClipboardEntry]` as JSON.
- Write to: `Application Support/Niya/clipboard-history.json`.
- Atomic writes via `Data.write(to:options: .atomic)`.
- Debounced save: coalesce writes, max once per 3 seconds.
- Immediate save on: app resign active, app terminate.

### 6.2 Image Data Storage

Image thumbnails are stored inline as Base64-encoded JPEG in the JSON. At max 50KB per thumbnail and 50 entries, worst case is ~2.5MB for the history file. This is acceptable for JSON-based storage.

If future versions increase `maxEntries` significantly, migrate to a SQLite store with BLOB columns.

### 6.3 Capacity Management

| Setting               | Default | Description                                    |
|-----------------------|---------|------------------------------------------------|
| `clipboard.maxEntries`| 50      | Maximum entries before auto-pruning.           |

**Pruning rules** (applied after each new entry):

1. Count total entries.
2. If count > `maxEntries`:
   - Sort unpinned entries by timestamp ascending (oldest first).
   - Remove oldest unpinned entries until count <= `maxEntries`.
   - Pinned entries are NEVER auto-pruned.
   - If all entries are pinned and count > `maxEntries`, log a warning but do not prune. Show a UI hint suggesting the user unpin some entries.

### 6.4 Migration

- Include a `version: Int` in the persisted JSON wrapper.
- Provide `migrate(from:to:)` for schema changes.
- On corrupt data: log, back up, start fresh.

---

## 7. User Interface

### 7.1 Layout

The clipboard history occupies the expanded notch panel (same slot as file shelf -- user switches between them via tabs or the panel is contextually chosen).

```
+-----------------------------------------------------------+
|  [Search field: "Search clipboard..."]    [Pause] [Clear] |
+-----------------------------------------------------------+
|  [Pinned Section - only if pinned items exist]            |
|  +------+ +------+ +------+                               |
|  | pin1 | | pin2 | | pin3 |                               |
|  +------+ +------+ +------+                               |
+-----------------------------------------------------------+
|  [History List - vertical scroll, reverse-chronological]  |
|  +-------------------------------------------------------+|
|  | [App Icon] Preview text...           2 min ago   [x]  ||
|  | Safari     "The quick brown fox..."               pin ||
|  +-------------------------------------------------------+|
|  | [App Icon] [Image Thumbnail]         5 min ago   [x]  ||
|  | Preview    256x256                                pin ||
|  +-------------------------------------------------------+|
|  | [App Icon] 3 files                  12 min ago   [x]  ||
|  | Finder     document.pdf, image.png...             pin ||
|  +-------------------------------------------------------+|
|  ...                                                      |
+-----------------------------------------------------------+
```

### 7.2 Entry Row

Each row displays:

| Element           | Description                                      |
|-------------------|--------------------------------------------------|
| Source App Icon    | 16x16 icon from `NSWorkspace.shared.icon(forFile:)` using the app's bundle path. Falls back to a generic clipboard icon if source unknown. |
| Content Preview   | Text: first 200 chars, single line, truncated. Image: 48x48 thumbnail. File URLs: file count + first file name. |
| Timestamp         | Relative time ("just now", "2 min ago", "1 hour ago", "Yesterday"). Switch to absolute date after 7 days. |
| Delete Button     | Small "x" button on trailing edge. |
| Pin Button        | Pin icon, toggles `isPinned`. Visible on hover. |

### 7.3 Search

- Live search as user types (debounced 200ms).
- Searches across:
  - `textContent` (substring match, case-insensitive).
  - `sourceAppName` (prefix match).
  - File names in `fileURLs` (substring match).
- Results replace the history list, maintaining the same row layout.
- Empty search restores the full history.
- Keyboard shortcut to focus search: Cmd+F when clipboard panel is visible.

### 7.4 Interactions

| Interaction          | Action                                           |
|----------------------|--------------------------------------------------|
| Click entry          | Copy content back to `NSPasteboard.general`. Show brief "Copied" toast. |
| Right-click entry    | Context menu: Copy, Pin/Unpin, Delete.           |
| Click delete (x)     | Remove entry from history. No confirmation for single delete. |
| Click "Clear All"    | Confirmation dialog: "Clear all clipboard history? Pinned items will be kept." -> clears unpinned entries. |
| Click "Pause"        | Toggle monitoring. Icon changes to indicate paused state. Tooltip: "Clipboard monitoring paused". |
| Hover entry          | Highlight row. Show pin button if not already visible. |
| Double-click entry   | Copy AND paste to frontmost app (simulate Cmd+V after copying). |

### 7.5 "Copied" Toast

When the user clicks an entry to re-copy it:

- A small toast appears at the top of the clipboard panel: "Copied to clipboard" with a checkmark.
- Toast auto-dismisses after 1.5 seconds.
- Toast uses `.ultraThinMaterial` background with green checkmark icon.

### 7.6 Empty State

```
+-------------------------------------------+
|                                           |
|   [clipboard icon]                        |
|   No clipboard history yet                |
|   Copy something to get started           |
|                                           |
+-------------------------------------------+
```

### 7.7 Paused State

When monitoring is paused, show a banner at the top of the panel:

```
+-------------------------------------------+
| [pause icon] Monitoring paused   [Resume] |
+-------------------------------------------+
```

---

## 8. Privacy

### 8.1 Principles

- All clipboard data is stored locally. No network transmission.
- Users control what is captured via the exclusion list.
- Pause/resume gives instant control over monitoring.
- Clear All removes data immediately and irreversibly.

### 8.2 App Exclusion List

Certain apps handle sensitive data (passwords, tokens, credentials). Users can exclude these by bundle ID.

```swift
struct ClipboardPrivacySettings: Codable {
    var excludedBundleIDs: Set<String>
    var isMonitoringEnabled: Bool
    var autoClearOnSleep: Bool        // Clear history when Mac sleeps
    var autoClearOnLock: Bool         // Clear history when screen locks
}
```

**Default exclusions** (pre-populated, user can remove):

| Bundle ID                        | App Name           |
|----------------------------------|--------------------|
| `com.agilebits.onepassword7`     | 1Password 7        |
| `com.1password.1password`        | 1Password 8        |
| `com.apple.keychainaccess`       | Keychain Access     |
| `com.lastpass.LastPass`          | LastPass            |
| `com.bitwarden.desktop`         | Bitwarden           |
| `org.keepassxc.keepassxc`       | KeePassXC           |
| `com.dashlane.Dashlane`         | Dashlane            |

### 8.3 Sensitive Content Heuristics

In addition to app-based exclusion, apply heuristic detection:

| Heuristic                                         | Action                           |
|---------------------------------------------------|----------------------------------|
| Text matches credit card pattern (16 digits)      | Do not capture. Log skip reason. |
| Text matches SSN pattern (XXX-XX-XXXX)            | Do not capture. Log skip reason. |
| Pasteboard contains `concealed` type              | Do not capture (password manager convention). |
| Pasteboard contains `org.nspasteboard.ConcealedType` | Do not capture. |

### 8.4 Auto-Clear Options

| Setting                      | Default | Description                              |
|------------------------------|---------|------------------------------------------|
| `clipboard.autoClearOnSleep` | false   | Clear all unpinned entries when Mac enters sleep. |
| `clipboard.autoClearOnLock`  | false   | Clear all unpinned entries when screen locks. |
| `clipboard.autoClearAfter`   | nil     | Auto-clear entries older than N hours (nil = never). |

---

## 9. Re-Copy Behavior

When the user selects an entry to re-copy:

### 9.1 Content Restoration

| Content Type | Restoration                                      |
|-------------|--------------------------------------------------|
| `.text`     | Set `NSPasteboard.general` with `.string` type.  |
| `.image`    | Set pasteboard with stored thumbnail data as `.tiff`. Note: only thumbnail quality is available. |
| `.richText` | Set pasteboard with plain text (RTF data not retained). |
| `.fileURL`  | Set pasteboard with `.fileURL` type for each URL. Validate files still exist first. |

### 9.2 Change Count Handling

After programmatically setting the pasteboard, the `ClipboardMonitor` must NOT re-capture the content as a new entry. Strategy:

```
ClipboardMonitor sets self.isRestoring = true
  -> Set pasteboard content
  -> Record new changeCount as lastChangeCount
  -> Set self.isRestoring = false after next poll cycle
```

This prevents an infinite loop of capture -> restore -> capture.

---

## 10. Settings

| Setting                        | Type       | Default          | Description                              |
|--------------------------------|------------|------------------|------------------------------------------|
| `clipboard.maxEntries`         | Int        | 50               | Max history entries before pruning.      |
| `clipboard.pollInterval`       | Double     | 0.5              | Polling interval in seconds.             |
| `clipboard.monitoringEnabled`  | Bool       | true             | Master toggle for clipboard monitoring.  |
| `clipboard.excludedBundleIDs`  | [String]   | (see 8.2)        | Apps excluded from capture.              |
| `clipboard.autoClearOnSleep`   | Bool       | false            | Clear on Mac sleep.                      |
| `clipboard.autoClearOnLock`    | Bool       | false            | Clear on screen lock.                    |
| `clipboard.autoClearAfter`     | Int?       | nil              | Hours after which entries auto-expire.   |
| `clipboard.captureImages`      | Bool       | true             | Whether to capture image clipboard content. |
| `clipboard.doubleClickPastes`  | Bool       | true             | Double-click copies AND pastes.          |

---

## 11. Error Handling

| Error                              | Handling                                         |
|------------------------------------|--------------------------------------------------|
| Pasteboard read fails              | Skip this poll cycle, log warning. Retry next cycle. |
| Image thumbnail generation fails   | Store entry without image data, set `imageData = nil`. |
| Source app detection fails         | Store entry with `sourceAppBundleID = nil`. Display generic icon. |
| Persistence save fails             | Retry once after 1s. Log error. Data preserved in memory until next successful save. |
| Persistence load fails (corrupt)   | Log error, back up corrupt file, start with empty history. |
| File URL no longer valid on re-copy| Show toast: "File not found: [filename]". Remove or badge the entry. |
| Max pinned entries exceed maxEntries | Log warning. Show UI hint. Do not force-unpin. |

---

## 12. Performance

### 12.1 CPU Budget

- Polling: < 0.1% CPU (one integer comparison per 0.5s).
- Content extraction: < 50ms per clipboard change (on main thread is acceptable given infrequency).
- Thumbnail generation: offloaded to background queue, < 200ms per image.
- Search: < 10ms for 50 entries (in-memory linear scan, no index needed at this scale).

### 12.2 Memory Budget

- In-memory store: ~3MB worst case (50 entries with thumbnails).
- No lazy loading needed at V1 scale (50 entries).
- If `maxEntries` is increased beyond 500, consider lazy loading and SQLite.

### 12.3 Disk Budget

- JSON file: ~2.5MB worst case.
- Acceptable for Application Support directory.

---

## 13. Testing Strategy

### 13.1 Unit Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| ClipboardMonitor         | Change detection; no-change skip; pause/resume; polling interval. |
| Content Extraction       | Each content type; priority ordering; size limits; truncation. |
| ClipboardHistoryStore    | Add/remove/pin/unpin; pruning logic; search; re-copy change-count guard. |
| Privacy                  | Exclusion by bundle ID; sensitive content heuristics; concealed type detection. |
| Persistence              | Save/load round-trip; corrupt data recovery; migration. |
| ClipboardEntry           | Codable round-trip; previewText generation; equality. |

### 13.2 Integration Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| Monitor-to-Store         | Simulate pasteboard change -> entry appears in store -> persists to disk. |
| Re-Copy                  | Select entry -> pasteboard updated -> monitor does NOT re-capture. |
| Exclusion                | Copy from excluded app -> entry NOT created.      |

### 13.3 UI Tests

| Test Area                | Key Scenarios                                    |
|--------------------------|--------------------------------------------------|
| Entry display            | Text, image, file URL entries render correctly.  |
| Search                   | Typing filters list; clearing restores full list.|
| Click-to-copy            | Click entry -> toast appears -> pasteboard has content. |
| Clear All                | Confirmation shown -> unpinned entries removed -> pinned remain. |
| Pause state              | Banner shown -> new copies not captured -> resume resumes. |

---

## 14. Requirements

| ID       | Priority | Requirement                                              | Acceptance Criteria                              |
|----------|----------|----------------------------------------------------------|--------------------------------------------------|
| CH-001   | P0       | Monitor NSPasteboard.general.changeCount at 0.5s intervals. | `ClipboardMonitor` detects pasteboard changes within 0.5s. CPU overhead < 0.1% during idle. Verified via unit test with mock pasteboard. |
| CH-002   | P0       | Capture text, image, file URL, and rich text content.    | Each content type is correctly extracted and stored in `ClipboardEntry` with appropriate fields populated. Verified via unit tests per content type. |
| CH-003   | P0       | Store clipboard history in reverse-chronological order.  | Newest entries appear first. `ClipboardHistoryStore.entries` is sorted by timestamp descending. Verified via unit test. |
| CH-004   | P0       | Re-copy entries to clipboard with single click.          | Clicking an entry sets `NSPasteboard.general` with the entry's content. Pasteboard content matches original. Verified via integration test. |
| CH-005   | P0       | Persist history across app restarts.                     | After app restart, all entries (including pinned) are restored from disk. Verified via persistence round-trip test. |
| CH-006   | P0       | Prevent re-capture loop when restoring clipboard content.| Programmatic pasteboard writes by re-copy do NOT create new entries. Verified via integration test: re-copy -> no duplicate entry. |
| CH-007   | P1       | Searchable history by text content and source app.       | Typing in search field filters entries by substring match on text and prefix match on app name. Results update within 200ms. Verified via unit test. |
| CH-008   | P1       | Exclude apps from capture by bundle ID.                  | Copies originating from excluded apps are not captured. Default exclusion list includes common password managers. Verified via unit test with mock frontmost app. |
| CH-009   | P1       | Detect and skip sensitive content patterns.              | Credit card numbers, SSNs, and `ConcealedType` pasteboard items are not captured. Verified via unit test with pattern samples. |
| CH-010   | P1       | Auto-prune oldest unpinned entries when exceeding maxEntries. | When entry count exceeds `maxEntries`, oldest unpinned entries are removed. Pinned entries are never removed. Verified via unit test. |
| CH-011   | P1       | Pin entries to prevent auto-pruning.                     | Pinned entries survive pruning cycles. Pin/unpin toggle works from UI and context menu. Verified via unit test. |
| CH-012   | P1       | Pause and resume clipboard monitoring.                   | Pause button stops capture. Resume button restarts. Paused state is visually indicated. Verified via UI test. |
| CH-013   | P2       | Display source app icon and name per entry.              | Each entry shows the icon and name of the app that originated the copy. Falls back to generic icon when unknown. Verified via UI test. |
| CH-014   | P2       | Image entries stored as thumbnails (max 256x256).        | Image data is downscaled before storage. Stored size < 50KB per thumbnail. Verified via unit test with large image input. |
| CH-015   | P2       | Clear All with confirmation, preserving pinned entries.  | Clear All shows confirmation dialog. After confirmation, all unpinned entries are removed. Pinned entries remain. Verified via UI test. |
| CH-016   | P2       | Auto-clear on sleep/lock (configurable).                 | When enabled, unpinned entries are cleared on sleep or lock events. Configurable in settings. Verified via unit test with mock system events. |
| CH-017   | P2       | "Copied" toast notification on re-copy.                  | After clicking an entry, a toast "Copied to clipboard" appears for 1.5s. Verified via UI test. |
| CH-018   | P3       | Double-click to copy AND paste to frontmost app.         | Double-clicking an entry copies content and simulates Cmd+V in the previously frontmost app. Configurable toggle. Verified via integration test. |
| CH-019   | P3       | Configurable auto-clear after N hours.                   | Entries older than the configured threshold are removed on each poll cycle. Verified via unit test with manipulated timestamps. |
| CH-020   | P3       | Persistence schema migration.                            | When persisted JSON version changes, old data is migrated to new schema. Verified via unit test with old-format JSON fixtures. |

---

## 15. Open Questions

1. Should we store full RTF data for rich text entries (increases storage) or plain text only?
2. Should double-click paste use Accessibility API or simulated keypress for Cmd+V?
3. Should we add a keyboard shortcut to show clipboard history without expanding the notch (global hotkey)?
4. Maximum `maxEntries` ceiling to prevent performance degradation (500? 1000?)?
5. Should image entries offer a "Save full resolution" action that re-reads from pasteboard if the content is still there?
