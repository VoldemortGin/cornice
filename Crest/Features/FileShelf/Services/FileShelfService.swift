import AppKit
import UniformTypeIdentifiers
import os

private let log = Logger(subsystem: "com.crest.app", category: "fileShelf")

// MARK: - Protocols

protocol SecurityScopedBookmarkServiceProtocol {
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
    func accessResource<T>(bookmark: Data, operation: (URL) throws -> T) throws -> T
    func validateBookmarks(_ items: [ShelfItem]) -> [UUID]
}

protocol TemporaryFileStorageServiceProtocol {
    func store(data: Data, suggestedName: String?, utType: UTType?) throws -> URL
    func store(text: String, suggestedName: String?) throws -> URL
    func createWebloc(for url: URL, name: String?) throws -> URL
    func cleanup(olderThan: TimeInterval)
    func cleanupAll()
    var storageDirectory: URL { get }
}

protocol ShelfPersistenceServiceProtocol {
    func load() throws -> [ShelfItem]
    func save(_ items: [ShelfItem]) throws
    func clear() throws
}

protocol DragDetectorDelegate: AnyObject {
    func dragDetector(_ detector: DragDetector, didDetectDragEnteringNotch event: NSEvent)
    func dragDetector(_ detector: DragDetector, didDetectDropInNotch event: NSEvent, pasteboard: NSPasteboard)
    func dragDetector(_ detector: DragDetector, didDetectDragLeavingNotch event: NSEvent)
}

// MARK: - BookmarkService

final class BookmarkService: SecurityScopedBookmarkServiceProtocol {
    func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    func accessResource<T>(bookmark: Data, operation: (URL) throws -> T) throws -> T {
        let (url, _) = try resolveBookmark(bookmark)
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try operation(url)
    }

    func validateBookmarks(_ items: [ShelfItem]) -> [UUID] {
        items.compactMap { item in
            guard case .file(let bookmark) = item.kind else { return nil }
            do {
                _ = try resolveBookmark(bookmark)
                return nil
            } catch {
                return item.id
            }
        }
    }
}

enum BookmarkError: LocalizedError {
    case accessDenied
    case staleBookmark
    case resolutionFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Access to the security-scoped resource was denied."
        case .staleBookmark: return "The bookmark is stale and needs to be recreated."
        case .resolutionFailed: return "Failed to resolve the bookmark data."
        }
    }
}

// MARK: - TemporaryFileStorageService

final class TemporaryFileStorageService: TemporaryFileStorageServiceProtocol {
    let storageDirectory: URL

    init(baseDirectory: URL? = nil) {
        self.storageDirectory = baseDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("crest-shelf")
    }

    func store(data: Data, suggestedName: String?, utType: UTType?) throws -> URL {
        let subDir = storageDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let fileName: String
        if let name = suggestedName, !name.isEmpty {
            fileName = name
        } else if let ext = utType?.preferredFilenameExtension {
            fileName = "data.\(ext)"
        } else {
            fileName = "data.bin"
        }

        let fileURL = subDir.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func store(text: String, suggestedName: String?) throws -> URL {
        let subDir = storageDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let fileName = suggestedName ?? "snippet.txt"
        let fileURL = subDir.appendingPathComponent(fileName)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func createWebloc(for url: URL, name: String?) throws -> URL {
        let subDir = storageDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let fileName = "\(name ?? "link").webloc"
        let fileURL = subDir.appendingPathComponent(fileName)
        let plist: [String: Any] = ["URL": url.absoluteString]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func cleanup(olderThan interval: TimeInterval) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-interval)
        for dir in contents {
            guard let values = try? dir.resourceValues(forKeys: [.creationDateKey]),
                  let created = values.creationDate,
                  created < cutoff else { continue }
            try? fm.removeItem(at: dir)
        }
    }

    func cleanupAll() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in contents {
            try? fm.removeItem(at: item)
        }
    }
}

// MARK: - ShelfPersistenceService

final class ShelfPersistenceService: ShelfPersistenceServiceProtocol {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Crest")
        self.fileURL = dir.appendingPathComponent("shelf-items.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func load() throws -> [ShelfItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let wrapper = try decoder.decode(PersistenceWrapper.self, from: data)
        return wrapper.items
    }

    func save(_ items: [ShelfItem]) throws {
        let wrapper = PersistenceWrapper(version: 1, items: items)
        let data = try encoder.encode(wrapper)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        try save([])
    }

    private struct PersistenceWrapper: Codable {
        let version: Int
        let items: [ShelfItem]
    }
}

// MARK: - ShelfStore

final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    var maxItems: Int
    private let persistence: ShelfPersistenceServiceProtocol
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol

    init(persistence: ShelfPersistenceServiceProtocol, bookmarkService: SecurityScopedBookmarkServiceProtocol, maxItems: Int = 20) {
        self.persistence = persistence
        self.bookmarkService = bookmarkService
        self.maxItems = maxItems

        do {
            self.items = try persistence.load()
        } catch {
            log.warning("Failed to load shelf items: \(error.localizedDescription)")
            self.items = []
        }
    }

    func add(_ item: ShelfItem) throws {
        if let existingIndex = items.firstIndex(where: { $0.identityKey == item.identityKey }) {
            items[existingIndex].createdAt = Date()
        } else {
            items.append(item)
            pruneIfNeeded()
        }
        try persistence.save(items)
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        try? persistence.save(items)
    }

    func removeAll() {
        items.removeAll()
        try? persistence.save(items)
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        try? persistence.save(items)
    }

    func pin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned = true
            try? persistence.save(items)
        }
    }

    func unpin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned = false
            try? persistence.save(items)
        }
    }

    func item(for identityKey: String) -> ShelfItem? {
        items.first { $0.identityKey == identityKey }
    }

    private func pruneIfNeeded() {
        while items.count > maxItems {
            if let oldestUnpinnedIndex = items.enumerated()
                .filter({ !$0.element.isPinned })
                .min(by: { $0.element.createdAt < $1.element.createdAt })?
                .offset {
                items.remove(at: oldestUnpinnedIndex)
            } else {
                break
            }
        }
    }
}

// MARK: - DropProcessor

enum DropProcessorError: LocalizedError {
    case emptyPasteboard
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .emptyPasteboard: return "The pasteboard is empty."
        case .processingFailed: return "Failed to process the dropped content."
        }
    }
}

struct DropResult {
    let item: ShelfItem
    let wasDeduped: Bool
}

protocol DropPasteboardProviding {
    var availableTypes: [String] { get }
    var fileURLs: [URL] { get }
    var urls: [URL] { get }
    var strings: [String] { get }
    var rawDataByType: [String: Data] { get }
}

final class DropProcessor {
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol
    private let tempStorage: TemporaryFileStorageServiceProtocol
    private let shelfStore: ShelfStore

    init(bookmarkService: SecurityScopedBookmarkServiceProtocol, tempStorage: TemporaryFileStorageServiceProtocol, shelfStore: ShelfStore) {
        self.bookmarkService = bookmarkService
        self.tempStorage = tempStorage
        self.shelfStore = shelfStore
    }

    func process(pasteboard: some DropPasteboardProviding) async throws -> DropResult {
        guard !pasteboard.availableTypes.isEmpty else {
            throw DropProcessorError.emptyPasteboard
        }

        let item: ShelfItem

        if pasteboard.availableTypes.contains("public.file-url"), let fileURL = pasteboard.fileURLs.first {
            let bookmark = try bookmarkService.createBookmark(for: fileURL)
            let identityKey = fileURL.standardizedFileURL.path
            if let existing = shelfStore.item(for: identityKey) {
                try shelfStore.add(existing)
                return DropResult(item: existing, wasDeduped: true)
            }
            item = ShelfItem(
                id: UUID(),
                kind: .file(bookmark: bookmark),
                createdAt: Date(),
                name: fileURL.lastPathComponent,
                identityKey: identityKey,
                isPinned: false
            )
        } else if pasteboard.availableTypes.contains("public.url"), let url = pasteboard.urls.first {
            if url.isFileURL {
                let bookmark = try bookmarkService.createBookmark(for: url)
                let identityKey = url.standardizedFileURL.path
                if let existing = shelfStore.item(for: identityKey) {
                    try shelfStore.add(existing)
                    return DropResult(item: existing, wasDeduped: true)
                }
                item = ShelfItem(
                    id: UUID(),
                    kind: .file(bookmark: bookmark),
                    createdAt: Date(),
                    name: url.lastPathComponent,
                    identityKey: identityKey,
                    isPinned: false
                )
            } else {
                let identityKey = url.absoluteString.lowercased()
                if let existing = shelfStore.item(for: identityKey) {
                    try shelfStore.add(existing)
                    return DropResult(item: existing, wasDeduped: true)
                }
                item = ShelfItem(
                    id: UUID(),
                    kind: .link(url: url),
                    createdAt: Date(),
                    name: url.host ?? url.absoluteString,
                    identityKey: identityKey,
                    isPinned: false
                )
            }
        } else if pasteboard.availableTypes.contains("public.utf8-plain-text"), let text = pasteboard.strings.first {
            let truncated = String(text.prefix(10_000))
            let identityKey = "text_\(truncated.hashValue)"
            if let existing = shelfStore.item(for: identityKey) {
                try shelfStore.add(existing)
                return DropResult(item: existing, wasDeduped: true)
            }
            item = ShelfItem(
                id: UUID(),
                kind: .text(string: truncated),
                createdAt: Date(),
                name: String(truncated.prefix(50)),
                identityKey: identityKey,
                isPinned: false
            )
        } else if let (typeKey, data) = pasteboard.rawDataByType.first {
            let utType = UTType(typeKey)
            let tempURL = try tempStorage.store(data: data, suggestedName: nil, utType: utType)
            let bookmark = try bookmarkService.createBookmark(for: tempURL)
            let identityKey = tempURL.standardizedFileURL.path
            item = ShelfItem(
                id: UUID(),
                kind: .file(bookmark: bookmark),
                createdAt: Date(),
                name: tempURL.lastPathComponent,
                identityKey: identityKey,
                isPinned: false
            )
        } else {
            throw DropProcessorError.emptyPasteboard
        }

        try shelfStore.add(item)
        return DropResult(item: item, wasDeduped: false)
    }

    func process(pasteboard: NSPasteboard) async throws -> DropResult {
        let types = pasteboard.types ?? []

        if types.contains(.fileURL), let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let fileURL = urls.first, fileURL.isFileURL {
            let bookmark = try bookmarkService.createBookmark(for: fileURL)
            let identityKey = fileURL.standardizedFileURL.path
            if let existing = shelfStore.item(for: identityKey) {
                try shelfStore.add(existing)
                return DropResult(item: existing, wasDeduped: true)
            }
            let item = ShelfItem(
                id: UUID(),
                kind: .file(bookmark: bookmark),
                createdAt: Date(),
                name: fileURL.lastPathComponent,
                identityKey: identityKey,
                isPinned: false
            )
            try shelfStore.add(item)
            return DropResult(item: item, wasDeduped: false)
        }

        if types.contains(.URL), let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            if url.isFileURL {
                let bookmark = try bookmarkService.createBookmark(for: url)
                let identityKey = url.standardizedFileURL.path
                if let existing = shelfStore.item(for: identityKey) {
                    try shelfStore.add(existing)
                    return DropResult(item: existing, wasDeduped: true)
                }
                let item = ShelfItem(
                    id: UUID(),
                    kind: .file(bookmark: bookmark),
                    createdAt: Date(),
                    name: url.lastPathComponent,
                    identityKey: identityKey,
                    isPinned: false
                )
                try shelfStore.add(item)
                return DropResult(item: item, wasDeduped: false)
            } else {
                let identityKey = url.absoluteString.lowercased()
                if let existing = shelfStore.item(for: identityKey) {
                    try shelfStore.add(existing)
                    return DropResult(item: existing, wasDeduped: true)
                }
                let item = ShelfItem(
                    id: UUID(),
                    kind: .link(url: url),
                    createdAt: Date(),
                    name: url.host ?? url.absoluteString,
                    identityKey: identityKey,
                    isPinned: false
                )
                try shelfStore.add(item)
                return DropResult(item: item, wasDeduped: false)
            }
        }

        if types.contains(.string), let text = pasteboard.string(forType: .string) {
            let truncated = String(text.prefix(10_000))
            let identityKey = "text_\(truncated.hashValue)"
            if let existing = shelfStore.item(for: identityKey) {
                try shelfStore.add(existing)
                return DropResult(item: existing, wasDeduped: true)
            }
            let item = ShelfItem(
                id: UUID(),
                kind: .text(string: truncated),
                createdAt: Date(),
                name: String(truncated.prefix(50)),
                identityKey: identityKey,
                isPinned: false
            )
            try shelfStore.add(item)
            return DropResult(item: item, wasDeduped: false)
        }

        if let firstItem = pasteboard.pasteboardItems?.first, let firstType = firstItem.types.first,
           let data = firstItem.data(forType: firstType) {
            let utType = UTType(firstType.rawValue)
            let tempURL = try tempStorage.store(data: data, suggestedName: nil, utType: utType)
            let bookmark = try bookmarkService.createBookmark(for: tempURL)
            let identityKey = tempURL.standardizedFileURL.path
            let item = ShelfItem(
                id: UUID(),
                kind: .file(bookmark: bookmark),
                createdAt: Date(),
                name: tempURL.lastPathComponent,
                identityKey: identityKey,
                isPinned: false
            )
            try shelfStore.add(item)
            return DropResult(item: item, wasDeduped: false)
        }

        throw DropProcessorError.emptyPasteboard
    }
}

// MARK: - DragDetector

final class DragDetector {
    let screen: NSScreen
    weak var delegate: DragDetectorDelegate?

    private var lastChangeCount: Int
    private var isDragActive: Bool = false
    private var monitors: [Any] = []
    private var dragStartPoint: NSPoint?
    private let dragThreshold: CGFloat = 8

    init(screen: NSScreen) {
        self.screen = screen
        self.lastChangeCount = NSPasteboard(name: .drag).changeCount
    }

    func startMonitoring() {
        let mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event)
        }
        let mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
        }
        let mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp(event)
        }
        if let m1 = mouseDownMonitor { monitors.append(m1) }
        if let m2 = mouseDragMonitor { monitors.append(m2) }
        if let m3 = mouseUpMonitor { monitors.append(m3) }
    }

    func stopMonitoring() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        isDragActive = false
        dragStartPoint = nil
    }

    private func handleMouseDown(_ event: NSEvent) {
        dragStartPoint = NSEvent.mouseLocation
        isDragActive = false
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let start = dragStartPoint else { return }
        let current = NSEvent.mouseLocation
        let distance = hypot(current.x - start.x, current.y - start.y)

        if distance > dragThreshold && !isDragActive {
            let currentChangeCount = NSPasteboard(name: .drag).changeCount
            if currentChangeCount != lastChangeCount {
                lastChangeCount = currentChangeCount
                isDragActive = true
            }
        }

        if isDragActive && isPointInNotchRegion(current) {
            delegate?.dragDetector(self, didDetectDragEnteringNotch: event)
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        if isDragActive {
            let location = NSEvent.mouseLocation
            if isPointInNotchRegion(location) {
                delegate?.dragDetector(self, didDetectDropInNotch: event, pasteboard: NSPasteboard(name: .drag))
            } else {
                delegate?.dragDetector(self, didDetectDragLeavingNotch: event)
            }
        }
        isDragActive = false
        dragStartPoint = nil
    }

    private func isPointInNotchRegion(_ point: NSPoint) -> Bool {
        let frame = screen.frame
        let notchWidth: CGFloat = 190
        let notchHeight: CGFloat = 32
        let padding: CGFloat = 12

        let notchCenterX = frame.midX
        let notchTop = frame.maxY

        let hitRect = NSRect(
            x: notchCenterX - (notchWidth / 2) - padding,
            y: notchTop - notchHeight - padding,
            width: notchWidth + (padding * 2),
            height: notchHeight + (padding * 2)
        )
        return hitRect.contains(point)
    }
}
