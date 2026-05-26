import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class FileShelfViewModel {
    var items: [ShelfItem] = []
    var maxItems: Int { didSet { store.maxItems = maxItems } }

    private let store: ShelfStore
    private let bookmarkService: SecurityScopedBookmarkServiceProtocol
    private let tempStorage: TemporaryFileStorageServiceProtocol
    private let dropProcessor: DropProcessor

    init(
        persistence: ShelfPersistenceServiceProtocol? = nil,
        bookmarkService: SecurityScopedBookmarkServiceProtocol? = nil,
        tempStorage: TemporaryFileStorageServiceProtocol? = nil,
        maxItems: Int = 20
    ) {
        let bm = bookmarkService ?? BookmarkService()
        let ts = tempStorage ?? TemporaryFileStorageService()
        let ps = persistence ?? ShelfPersistenceService()

        self.bookmarkService = bm
        self.tempStorage = ts
        self.maxItems = maxItems
        self.store = ShelfStore(persistence: ps, bookmarkService: bm, maxItems: maxItems)
        self.dropProcessor = DropProcessor(bookmarkService: bm, tempStorage: ts, shelfStore: store)
        self.items = store.items
    }

    // MARK: - Drop handling

    func handleDrop(providers: [NSItemProvider]) async {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                await loadFileURL(from: provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                await loadURL(from: provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                await loadText(from: provider)
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
              let data = item as? Data,
              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

        do {
            let bookmark = try bookmarkService.createBookmark(for: url)
            let identityKey = url.standardizedFileURL.path
            let shelfItem = ShelfItem(
                id: UUID(),
                kind: .file(bookmark: bookmark),
                createdAt: Date(),
                name: url.lastPathComponent,
                identityKey: identityKey,
                isPinned: false
            )
            try store.add(shelfItem)
            syncItems()
        } catch {
            // Silently ignore failed drops
        }
    }

    private func loadURL(from provider: NSItemProvider) async {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
              let url = item as? URL ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) }) else { return }

        do {
            if url.isFileURL {
                let bookmark = try bookmarkService.createBookmark(for: url)
                let identityKey = url.standardizedFileURL.path
                let shelfItem = ShelfItem(
                    id: UUID(),
                    kind: .file(bookmark: bookmark),
                    createdAt: Date(),
                    name: url.lastPathComponent,
                    identityKey: identityKey,
                    isPinned: false
                )
                try store.add(shelfItem)
            } else {
                let identityKey = url.absoluteString.lowercased()
                let shelfItem = ShelfItem(
                    id: UUID(),
                    kind: .link(url: url),
                    createdAt: Date(),
                    name: url.host ?? url.absoluteString,
                    identityKey: identityKey,
                    isPinned: false
                )
                try store.add(shelfItem)
            }
            syncItems()
        } catch {}
    }

    private func loadText(from provider: NSItemProvider) async {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier),
              let text = item as? String ?? (item as? Data).flatMap({ String(data: $0, encoding: .utf8) }) else { return }

        let truncated = String(text.prefix(10_000))
        let identityKey = "text_\(truncated.hashValue)"
        let shelfItem = ShelfItem(
            id: UUID(),
            kind: .text(string: truncated),
            createdAt: Date(),
            name: String(truncated.prefix(50)),
            identityKey: identityKey,
            isPinned: false
        )
        do {
            try store.add(shelfItem)
            syncItems()
        } catch {}
    }

    // MARK: - Item management

    func addItem(_ item: ShelfItem) {
        try? store.add(item)
        syncItems()
    }

    func removeItem(_ item: ShelfItem) {
        store.remove(id: item.id)
        syncItems()
    }

    func removeItem(id: UUID) {
        store.remove(id: id)
        syncItems()
    }

    func removeAll() {
        store.removeAll()
        syncItems()
    }

    func moveItems(fromOffsets: IndexSet, toOffset: Int) {
        store.move(fromOffsets: fromOffsets, toOffset: toOffset)
        syncItems()
    }

    func pinItem(id: UUID) {
        store.pin(id: id)
        syncItems()
    }

    func unpinItem(id: UUID) {
        store.unpin(id: id)
        syncItems()
    }

    // MARK: - Drag out

    func itemProvider(for item: ShelfItem) -> NSItemProvider {
        let provider = NSItemProvider()
        switch item.kind {
        case .file(let bookmark):
            if let (url, _) = try? bookmarkService.resolveBookmark(bookmark) {
                provider.registerFileRepresentation(
                    forTypeIdentifier: UTType.fileURL.identifier,
                    visibility: .all
                ) { completion in
                    completion(url, true, nil)
                    return nil
                }
            }
        case .text(let string):
            provider.registerItem(forTypeIdentifier: UTType.utf8PlainText.identifier) { completion, _, _ in
                completion?(string as NSString, nil)
            }
        case .link(let url):
            provider.registerItem(forTypeIdentifier: UTType.url.identifier) { completion, _, _ in
                completion?(url as NSURL, nil)
            }
        }
        return provider
    }

    // MARK: - Private

    private func syncItems() {
        items = store.items
    }
}
