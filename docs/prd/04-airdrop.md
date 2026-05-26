# PRD-04: AirDrop Quick Share

| Field         | Value                          |
|---------------|--------------------------------|
| **Feature**   | AirDrop Quick Share            |
| **PRD ID**    | PRD-04                         |
| **Status**    | Draft                          |
| **Author**    | Lin Han                        |
| **Created**   | 2026-05-26                     |
| **Updated**   | 2026-05-26                     |
| **Priority**  | P1 (Core)                      |
| **Depends On**| PRD-01 (Notch Window), PRD-02 (Expand/Collapse), PRD-03 (File Shelf) |

---

## 1. Overview

AirDrop Quick Share provides instant AirDrop access directly from the notch. It works in two modes:

1. **Shelf-integrated**: Users drag shelf items onto an AirDrop drop zone within the File Shelf panel.
2. **Standalone**: Users invoke AirDrop for the most recent clipboard content or a manually selected file via a dedicated AirDrop action in the notch.

Both modes use `NSSharingService(named: .sendViaAirDrop)` for direct AirDrop transfers and `NSSharingServicePicker` for broader sharing options.

---

## 2. Goals

- Reduce AirDrop to a single drag or click from the notch.
- Provide real-time AirDrop availability feedback.
- Support all content types: files, images, text, URLs.
- Fall back to full sharing options when AirDrop is unavailable.

## 3. Non-Goals

- AirDrop receiving (Niya is a sender, not a receiver; macOS handles inbound AirDrop).
- Custom AirDrop device discovery UI (we rely on the system AirDrop picker).
- Bluetooth/Wi-Fi management (if AirDrop is off, we direct the user to System Settings).

---

## 4. macOS AirDrop API

### 4.1 NSSharingService

macOS provides AirDrop through the sharing service framework:

```swift
// Direct AirDrop
let airdropService = NSSharingService(named: .sendViaAirDrop)

// Check availability
let canPerform = airdropService?.canPerform(withItems: [fileURL])

// Perform
airdropService?.perform(withItems: [fileURL])
```

### 4.2 Supported Item Types

`NSSharingService(named: .sendViaAirDrop)` accepts:

| Item Type       | Swift Type          | Notes                                    |
|-----------------|---------------------|------------------------------------------|
| File            | `URL` (file URL)    | Must be a valid, accessible file path.   |
| Image           | `NSImage`           | In-memory images.                        |
| Text            | `String`            | Sent as a text clipping.                 |
| URL             | `URL` (web URL)     | Sent as a URL reference.                 |
| Data            | `Data`              | Raw data with UTI.                       |

### 4.3 NSSharingServicePicker

For broader sharing (not just AirDrop):

```swift
let picker = NSSharingServicePicker(items: [fileURL])
picker.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY)
```

### 4.4 Delegate

```swift
protocol AirDropServiceDelegateProtocol: NSSharingServiceDelegate {
    // NSSharingServiceDelegate conformance provides:
    // - sharingService(_:didShareItems:)           -> Transfer succeeded
    // - sharingService(_:didFailToShareItems:error:) -> Transfer failed
    // - sharingService(_:sourceWindowForShareItems:sharingContentScope:)
}
```

---

## 5. Integration Points

### 5.1 From File Shelf (PRD-03)

The primary AirDrop integration point. Users drag shelf items onto the AirDrop zone.

**Flow**:
```
User drags ShelfItem onto AirDrop zone in shelf panel
  -> Resolve ShelfItem to shareable content:
       .file(bookmark:) -> Resolve bookmark to URL, validate access
       .text(string:)   -> Use string directly
       .link(url:)      -> Use URL directly
  -> Check NSSharingService.canPerform(withItems:)
  -> If can perform: NSSharingService.perform(withItems:)
  -> If cannot perform: Show error state on drop zone
  -> System AirDrop device picker appears
  -> User selects recipient device
  -> Transfer completes or user cancels
```

**Multi-item AirDrop**: If user selects multiple shelf items (Cmd+click) and drags to AirDrop zone, all items are sent in a single `perform(withItems:)` call.

### 5.2 From Clipboard (PRD-07)

Quick share the most recent clipboard content via AirDrop.

**Flow**:
```
User clicks AirDrop action in clipboard history panel
  -> Read selected ClipboardEntry
  -> Convert to shareable content:
       .text       -> String
       .image      -> NSImage from stored thumbnail
       .fileURL    -> File URLs array
       .richText   -> String (plain text fallback)
  -> NSSharingService.perform(withItems:)
```

### 5.3 Standalone AirDrop (Keyboard Shortcut)

A global keyboard shortcut can trigger AirDrop for the current clipboard content without opening the shelf.

**Flow**:
```
User presses keyboard shortcut (configurable, default: Ctrl+Option+A)
  -> Read NSPasteboard.general
  -> Extract shareable content (same priority chain as clipboard monitor)
  -> If content found: NSSharingService.perform(withItems:)
  -> If no content: Show brief toast "Nothing to AirDrop"
```

---

## 6. AirDrop Availability

### 6.1 Checking Availability

AirDrop availability depends on system settings and hardware state:

```swift
protocol AirDropAvailabilityCheckerProtocol {
    var isAvailable: Bool { get }
    func checkAvailability(for items: [Any]) -> Bool
    func startMonitoring()   // Periodic re-check
    func stopMonitoring()
}
```

**Check method**:
```swift
func checkAvailability(for items: [Any]) -> Bool {
    guard let service = NSSharingService(named: .sendViaAirDrop) else {
        return false  // AirDrop service not found (very old macOS)
    }
    return service.canPerform(withItems: items)
}
```

### 6.2 Availability States

| State                   | Detection                                    | UI                                           |
|-------------------------|----------------------------------------------|----------------------------------------------|
| Available               | `canPerform == true`                         | AirDrop zone active, blue icon.              |
| Unavailable (off)       | `canPerform == false`, service exists         | Grayed zone, "AirDrop Off" label, tooltip with instructions. |
| Unavailable (no service)| `NSSharingService(named:) == nil`            | AirDrop zone hidden entirely.                |

### 6.3 Monitoring Interval

- Check availability every 5 seconds when the shelf/notch is expanded.
- Stop checking when collapsed (save CPU).
- Immediate re-check when the shelf is expanded.

---

## 7. User Interface

### 7.1 AirDrop Zone in File Shelf

Located on the trailing edge of the shelf panel (see PRD-03 section 10.1).

```
+----------+
|          |
| [AirDrop |
|   icon]  |
|          |
| AirDrop  |
|          |
+----------+
  80pt wide
```

**Visual States**:

| State          | Appearance                                       |
|----------------|--------------------------------------------------|
| Idle           | Semi-transparent AirDrop icon + label. Border: `.quaternaryLabel`. |
| Drag Hover     | Bright blue background pulse. Icon scaled 1.1x. Border: `.blue`. "Drop to AirDrop" label. |
| Unavailable    | Grayed out icon. "AirDrop Off" label. Tooltip: "Enable AirDrop in System Settings > General > AirDrop & Handoff". |
| Transfer Active| Spinning progress indicator replacing icon. "Sending..." label. |
| Success        | Green checkmark icon, 1.5s, then return to idle. |
| Failure        | Red X icon + error message, 3s, then return to idle. |

### 7.2 AirDrop Button in Clipboard History

Each clipboard entry's context menu includes an "AirDrop" action (when AirDrop is available). Additionally, a floating AirDrop button appears when an entry is selected.

```
+-------------------------------------------------------+
| [entry row]                    [AirDrop btn] [pin] [x] |
+-------------------------------------------------------+
```

### 7.3 Standalone AirDrop Status (Collapsed Notch)

When the notch is collapsed, AirDrop availability is indicated by a subtle icon:

- If AirDrop is available: small AirDrop icon appears in the notch status area (alongside other status indicators like now-playing).
- If AirDrop is unavailable: icon hidden (don't clutter with unavailable features).

This indicator is optional (controlled by settings).

### 7.4 Sharing Options Fallback

When the user long-presses the AirDrop zone (or right-clicks), show the full `NSSharingServicePicker` instead of direct AirDrop. This gives access to:

- AirDrop
- Messages
- Mail
- Notes
- Third-party sharing extensions

```swift
let picker = NSSharingServicePicker(items: shareableItems)
picker.delegate = self
picker.show(relativeTo: airdropZone.bounds, of: airdropZone, preferredEdge: .minY)
```

---

## 8. AirDrop Service Layer

### 8.1 Protocol

```swift
enum AirDropResult {
    case success
    case cancelled
    case failed(Error)
}

protocol AirDropServiceProtocol {
    var isAvailable: Bool { get }

    func send(items: [Any]) async -> AirDropResult
    func send(shelfItems: [ShelfItem]) async -> AirDropResult
    func send(clipboardEntry: ClipboardEntry) async -> AirDropResult
    func showSharingPicker(items: [Any], relativeTo: NSRect, of: NSView)
}
```

### 8.2 Implementation

```swift
final class AirDropService: NSObject, AirDropServiceProtocol, NSSharingServiceDelegate {
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol
    private var continuation: CheckedContinuation<AirDropResult, Never>?

    func send(items: [Any]) async -> AirDropResult {
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: items) else {
            return .failed(AirDropError.unavailable)
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            service.delegate = self
            service.perform(withItems: items)
        }
    }

    // NSSharingServiceDelegate
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        continuation?.resume(returning: .success)
        continuation = nil
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        continuation?.resume(returning: .failed(error))
        continuation = nil
    }
}
```

### 8.3 ShelfItem to Shareable Content Conversion

```swift
extension AirDropService {
    func resolveShareableItems(from shelfItems: [ShelfItem]) throws -> [Any] {
        try shelfItems.map { item in
            switch item.kind {
            case .file(let bookmark):
                let (url, _) = try bookmarkService.resolveBookmark(bookmark)
                return url as Any

            case .text(let string):
                return string as Any

            case .link(let url):
                return url as Any
            }
        }
    }

    func resolveShareableItems(from entry: ClipboardEntry) throws -> [Any] {
        switch entry.contentType {
        case .text, .richText:
            guard let text = entry.textContent else {
                throw AirDropError.noContent
            }
            return [text]

        case .image:
            guard let imageData = entry.imageData,
                  let image = NSImage(data: imageData) else {
                throw AirDropError.noContent
            }
            return [image]

        case .fileURL:
            guard let urls = entry.fileURLs, !urls.isEmpty else {
                throw AirDropError.noContent
            }
            return urls.map { $0 as Any }
        }
    }
}
```

### 8.4 Error Types

```swift
enum AirDropError: LocalizedError {
    case unavailable
    case noContent
    case bookmarkResolutionFailed(Error)
    case transferFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AirDrop is not available. Check that AirDrop is enabled in System Settings."
        case .noContent:
            return "No content to share."
        case .bookmarkResolutionFailed(let error):
            return "Could not access the file: \(error.localizedDescription)"
        case .transferFailed(let error):
            return "AirDrop transfer failed: \(error.localizedDescription)"
        }
    }
}
```

---

## 9. Settings

| Setting                          | Type    | Default          | Description                              |
|----------------------------------|---------|------------------|------------------------------------------|
| `airdrop.showZoneInShelf`        | Bool    | true             | Show AirDrop drop zone in file shelf.    |
| `airdrop.showStatusInNotch`      | Bool    | false            | Show AirDrop availability icon in collapsed notch. |
| `airdrop.keyboardShortcut`       | String  | "Ctrl+Option+A"  | Global shortcut for AirDrop current clipboard. |
| `airdrop.keyboardShortcutEnabled`| Bool    | true             | Enable/disable the global AirDrop shortcut. |

---

## 10. Error Handling

| Error                              | Handling                                         |
|------------------------------------|--------------------------------------------------|
| AirDrop unavailable on send        | Show unavailable state on AirDrop zone. Tooltip with System Settings path. |
| Bookmark resolution fails on send  | Show error toast: "Cannot access file: [name]". Offer to remove broken item from shelf. |
| No shareable content               | Show toast: "Nothing to AirDrop". No system picker shown. |
| User cancels AirDrop picker        | Return to idle state silently. No toast.         |
| Transfer fails after device select | Show error state on AirDrop zone for 3s with error message. Log full error. |
| Multiple items partially fail      | Show toast: "Some items could not be sent". Log per-item results. |
| NSSharingService init returns nil  | Hide AirDrop zone entirely (service not supported). Log as info. |
| NSSharingServicePicker dismissed   | Return to idle. No side effects.                 |

---

## 11. Testing Strategy

### 11.1 Unit Tests

| Test Area                    | Key Scenarios                                    |
|------------------------------|--------------------------------------------------|
| AirDropService               | Send success/failure/cancel via mock delegate callbacks. |
| Availability Checker         | Available, unavailable, nil service scenarios.   |
| ShelfItem Conversion         | Each ShelfItemKind -> shareable content. Bookmark resolution failure. |
| ClipboardEntry Conversion    | Each ClipboardContentType -> shareable content. Nil content fields. |
| Error Types                  | All `AirDropError` cases produce correct `errorDescription`. |

### 11.2 Integration Tests

| Test Area                    | Key Scenarios                                    |
|------------------------------|--------------------------------------------------|
| Shelf-to-AirDrop             | Drag file shelf item to AirDrop zone -> `NSSharingService.perform` called with resolved URL. |
| Clipboard-to-AirDrop         | Click AirDrop on clipboard entry -> service invoked with correct content. |
| Standalone AirDrop           | Keyboard shortcut -> current clipboard content sent via AirDrop service. |
| Multi-item Send              | Select 3 shelf items -> drag to AirDrop zone -> all 3 items in single `perform` call. |

### 11.3 UI Tests

| Test Area                    | Key Scenarios                                    |
|------------------------------|--------------------------------------------------|
| AirDrop Zone States          | Idle, drag-hover, unavailable, transferring, success, failure visual states. |
| Tooltip Display              | Unavailable state shows correct guidance tooltip. |
| Sharing Picker               | Long-press AirDrop zone -> `NSSharingServicePicker` appears. |
| Success/Failure Feedback     | Checkmark on success; error message on failure; auto-dismiss timing. |

### 11.4 Mock Strategy

Since AirDrop requires actual device proximity, tests use:

```swift
final class MockNSSharingService {
    var canPerformResult: Bool = true
    var performResult: AirDropResult = .success
    var performedItems: [Any] = []
}
```

All `AirDropServiceProtocol` consumers accept the protocol, enabling complete test isolation from the system sharing service.

---

## 12. Requirements

| ID       | Priority | Requirement                                              | Acceptance Criteria                              |
|----------|----------|----------------------------------------------------------|--------------------------------------------------|
| AD-001   | P0       | Send files from shelf to AirDrop via drag onto AirDrop zone. | Dragging a `.file` shelf item onto the AirDrop zone calls `NSSharingService(named: .sendViaAirDrop).perform(withItems:)` with the resolved file URL. Verified via integration test with mock sharing service. |
| AD-002   | P0       | Send text and URLs from shelf to AirDrop.                | `.text` and `.link` shelf items are correctly converted to shareable types and sent via AirDrop. Verified via unit test. |
| AD-003   | P0       | Display AirDrop availability status in shelf zone.       | AirDrop zone shows "available" or "unavailable" state based on `NSSharingService.canPerform`. State updates within 5s of system change. Verified via UI test with mock availability. |
| AD-004   | P0       | Show system AirDrop device picker on send.               | After `perform(withItems:)`, the system AirDrop picker appears for device selection. Verified manually (system UI cannot be automated). |
| AD-005   | P1       | Send clipboard entries via AirDrop from clipboard history. | Clicking AirDrop action on a clipboard entry sends the entry's content via AirDrop. All content types handled. Verified via integration test. |
| AD-006   | P1       | Multi-item AirDrop from shelf.                           | Selecting multiple shelf items and dragging to AirDrop zone sends all items in a single `perform` call. Verified via unit test. |
| AD-007   | P1       | Visual feedback for transfer states (idle, sending, success, failure). | AirDrop zone transitions through correct visual states during a transfer lifecycle. Success shows checkmark for 1.5s. Failure shows error for 3s. Verified via UI test. |
| AD-008   | P1       | Fall back to NSSharingServicePicker on long-press.       | Long-pressing the AirDrop zone shows the full sharing picker with all available services. Verified via UI test. |
| AD-009   | P1       | Handle bookmark resolution failure gracefully.           | If a shelf item's bookmark cannot be resolved for AirDrop, show an error toast and offer to remove the broken item. Do not crash. Verified via unit test with invalid bookmark data. |
| AD-010   | P2       | Standalone AirDrop via keyboard shortcut.                | Configurable global shortcut sends current clipboard content via AirDrop. Shortcut works from any app. Verified via integration test. |
| AD-011   | P2       | AirDrop status indicator in collapsed notch.             | When enabled in settings, a small AirDrop icon in the collapsed notch indicates availability. Hidden when unavailable. Verified via UI test. |
| AD-012   | P2       | Unavailable state tooltip with System Settings guidance. | When AirDrop is unavailable, the AirDrop zone tooltip reads "Enable AirDrop in System Settings > General > AirDrop & Handoff". Verified via UI test. |
| AD-013   | P3       | Configurable keyboard shortcut for standalone AirDrop.   | User can change the global AirDrop shortcut in settings. New shortcut takes effect immediately. Verified via integration test. |

---

## 13. Open Questions

1. Should we show nearby AirDrop devices inline in the notch (custom device discovery UI), or always defer to the system picker? Custom UI is more integrated but requires Multipeer Connectivity framework and is significantly more work.
2. Should standalone AirDrop auto-expand the notch to show transfer progress, or show a system notification instead?
3. Should we support AirDrop for items dragged directly onto the notch (without going through the shelf first)?
4. Rate limiting: if a user rapidly drags multiple items to AirDrop zone one after another, should we queue transfers or reject while a transfer is in progress?
