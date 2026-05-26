import Foundation

enum ClipboardContentType: String, Codable {
    case text
    case image
    case fileURL
    case richText
}

struct ClipboardEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let contentType: ClipboardContentType
    let textContent: String?
    let imageData: Data?
    let fileURLs: [URL]?
    let sourceAppBundleID: String?
    let sourceAppName: String?
    var isPinned: Bool
    var isTruncated: Bool

    var previewText: String {
        switch contentType {
        case .text, .richText:
            guard let text = textContent else { return "(empty)" }
            return String(text.prefix(200))
        case .image:
            return "Image"
        case .fileURL:
            guard let urls = fileURLs, !urls.isEmpty else { return "(no files)" }
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files: \(urls[0].lastPathComponent)..."
        }
    }

    var contentSizeDescription: String {
        switch contentType {
        case .text, .richText:
            guard let text = textContent else { return "0 B" }
            let bytes = text.utf8.count
            return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        case .image:
            guard let data = imageData else { return "Image" }
            return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory)
        case .fileURL:
            guard let urls = fileURLs else { return "0 files" }
            return "\(urls.count) file\(urls.count == 1 ? "" : "s")"
        }
    }
}

protocol ClipboardHistoryStoreProtocol {
    var entries: [ClipboardEntry] { get }
    var pinnedEntries: [ClipboardEntry] { get }
    var maxEntries: Int { get set }

    func add(_ entry: ClipboardEntry)
    func remove(id: UUID)
    func removeAll()
    func pin(id: UUID)
    func unpin(id: UUID)
    func copyToClipboard(id: UUID)
    func search(query: String) -> [ClipboardEntry]
}
