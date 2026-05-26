import AppKit
import os

private let log = Logger(subsystem: "com.crest.app", category: "airdrop")

protocol AirDropServiceProtocol {
    var isAvailable: Bool { get }
    func send(items: [Any]) async -> AirDropResult
    func send(shelfItems: [ShelfItem]) async -> AirDropResult
    func send(clipboardEntry: ClipboardEntry) async -> AirDropResult
    func showSharingPicker(items: [Any], relativeTo rect: NSRect, of view: NSView)
}

final class AirDropService: NSObject, AirDropServiceProtocol, NSSharingServiceDelegate {
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol
    private var continuation: CheckedContinuation<AirDropResult, Never>?
    private var monitorTimer: Timer?

    var isAvailable: Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        return service.canPerform(withItems: ["placeholder"])
    }

    init(bookmarkService: SecurityScopedBookmarkServiceProtocol = BookmarkService()) {
        self.bookmarkService = bookmarkService
        super.init()
    }

    func checkAvailability(for items: [Any]) -> Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        return service.canPerform(withItems: items)
    }

    func send(items: [Any]) async -> AirDropResult {
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            return .failed(AirDropError.unavailable)
        }
        guard service.canPerform(withItems: items) else {
            return .failed(AirDropError.unavailable)
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            service.delegate = self
            service.perform(withItems: items)
        }
    }

    func send(shelfItems: [ShelfItem]) async -> AirDropResult {
        do {
            let shareableItems = try resolveShareableItems(from: shelfItems)
            guard !shareableItems.isEmpty else {
                return .failed(AirDropError.noContent)
            }
            return await send(items: shareableItems)
        } catch {
            return .failed(error)
        }
    }

    func send(clipboardEntry: ClipboardEntry) async -> AirDropResult {
        do {
            let shareableItems = try resolveShareableItems(from: clipboardEntry)
            guard !shareableItems.isEmpty else {
                return .failed(AirDropError.noContent)
            }
            return await send(items: shareableItems)
        } catch {
            return .failed(error)
        }
    }

    func showSharingPicker(items: [Any], relativeTo rect: NSRect, of view: NSView) {
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    // MARK: - Item Conversion

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

    // MARK: - Availability Monitoring

    func startMonitoring(interval: TimeInterval = 5.0, onChange: @escaping (Bool) -> Void) {
        stopMonitoring()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            onChange(self.isAvailable)
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - NSSharingServiceDelegate

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        log.info("AirDrop transfer completed successfully")
        continuation?.resume(returning: .success)
        continuation = nil
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        log.error("AirDrop transfer failed: \(error.localizedDescription)")
        continuation?.resume(returning: .failed(error))
        continuation = nil
    }

    nonisolated func sharingService(
        _ sharingService: NSSharingService,
        sourceWindowForShareItems items: [Any],
        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>
    ) -> NSWindow? {
        nil
    }
}
