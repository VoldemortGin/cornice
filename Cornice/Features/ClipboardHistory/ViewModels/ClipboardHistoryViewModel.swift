import AppKit
import os

private let log = Logger(subsystem: "com.cornice.app", category: "clipboardVM")

@MainActor
@Observable
final class ClipboardHistoryViewModel {
    var entries: [ClipboardEntry] = []
    var searchQuery: String = ""
    var isMonitoringPaused: Bool = false
    var showCopiedToast: Bool = false
    var maxEntries: Int = 50

    var filteredEntries: [ClipboardEntry] {
        if searchQuery.isEmpty {
            return entries
        }
        return searchEntries(query: searchQuery)
    }

    var pinnedEntries: [ClipboardEntry] {
        entries.filter(\.isPinned)
    }

    private let monitor: ClipboardMonitoring
    private let persistenceURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var saveTask: Task<Void, Never>?

    init(monitor: ClipboardMonitoring = ClipboardMonitor(), persistenceDirectory: URL? = nil) {
        self.monitor = monitor

        let dir = persistenceDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cornice")
        self.persistenceURL = dir.appendingPathComponent("clipboard-history.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        loadEntries()
        setupMonitor()
    }

    // MARK: - Monitor Control

    func startMonitoring() {
        monitor.startMonitoring()
        isMonitoringPaused = false
    }

    func stopMonitoring() {
        monitor.stopMonitoring()
    }

    func pauseMonitoring() {
        monitor.pauseMonitoring()
        isMonitoringPaused = true
    }

    func resumeMonitoring() {
        monitor.resumeMonitoring()
        isMonitoringPaused = false
    }

    // MARK: - Entry Management

    func addEntry(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        pruneIfNeeded()
        scheduleSave()
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        scheduleSave()
    }

    func clearAll() {
        entries.removeAll { !$0.isPinned }
        scheduleSave()
    }

    func pinEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isPinned = true
            scheduleSave()
        }
    }

    func unpinEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isPinned = false
            scheduleSave()
        }
    }

    // MARK: - Copy Back to Clipboard

    func copyToClipboard(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        copyToClipboard(entry: entry)
    }

    func copyToClipboard(entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general

        monitor.markAsRestoring()

        pasteboard.clearContents()

        switch entry.contentType {
        case .text, .richText:
            if let text = entry.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let imageData = entry.imageData {
                pasteboard.setData(imageData, forType: .tiff)
            }
        case .fileURL:
            if let urls = entry.fileURLs {
                let validURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
                if !validURLs.isEmpty {
                    pasteboard.writeObjects(validURLs.map { $0 as NSURL })
                }
            }
        }

        monitor.clearRestoringFlag()
        showCopiedToast = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            showCopiedToast = false
        }
    }

    // MARK: - Search

    func searchEntries(query: String) -> [ClipboardEntry] {
        guard !query.isEmpty else { return entries }
        let lowercased = query.lowercased()
        return entries.filter { entry in
            if let text = entry.textContent, text.localizedCaseInsensitiveContains(query) {
                return true
            }
            if let appName = entry.sourceAppName, appName.lowercased().hasPrefix(lowercased) {
                return true
            }
            if let urls = entry.fileURLs {
                return urls.contains { $0.lastPathComponent.localizedCaseInsensitiveContains(query) }
            }
            return false
        }
    }

    // MARK: - Persistence

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let wrapper = try decoder.decode(ClipboardPersistenceWrapper.self, from: data)
            entries = wrapper.entries
        } catch {
            log.warning("Failed to load clipboard history: \(error.localizedDescription)")
            // Back up corrupt file
            let backupURL = persistenceURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.moveItem(at: persistenceURL, to: backupURL)
            entries = []
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            saveEntries()
        }
    }

    func saveEntries() {
        do {
            let wrapper = ClipboardPersistenceWrapper(version: 1, entries: entries)
            let data = try encoder.encode(wrapper)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            log.error("Failed to save clipboard history: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func setupMonitor() {
        monitor.onClipboardChange = { [weak self] entry in
            Task { @MainActor [weak self] in
                self?.addEntry(entry)
            }
        }
    }

    private func pruneIfNeeded() {
        while entries.count > maxEntries {
            if let oldestUnpinnedIndex = entries.lastIndex(where: { !$0.isPinned }) {
                entries.remove(at: oldestUnpinnedIndex)
            } else {
                log.warning("All \(self.entries.count) clipboard entries are pinned, exceeding maxEntries (\(self.maxEntries))")
                break
            }
        }
    }
}

private struct ClipboardPersistenceWrapper: Codable {
    let version: Int
    let entries: [ClipboardEntry]
}
