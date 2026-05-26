import Foundation

enum ShelfItemKind: Codable, Equatable, Hashable {
    case file(bookmark: Data)
    case text(string: String)
    case link(url: URL)
}

struct ShelfItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let kind: ShelfItemKind
    var createdAt: Date
    var name: String
    var identityKey: String
    var isPinned: Bool

    var typeLabel: String {
        switch kind {
        case .file:
            let ext = (name as NSString).pathExtension.uppercased()
            return ext.isEmpty ? "File" : ext
        case .text:
            return "Text"
        case .link:
            return "Link"
        }
    }

    var iconName: String {
        switch kind {
        case .file:
            return "doc.fill"
        case .text:
            return "doc.text.fill"
        case .link:
            return "link"
        }
    }
}
