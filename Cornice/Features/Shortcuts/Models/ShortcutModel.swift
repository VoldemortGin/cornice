import Foundation
import Defaults

struct ShortcutEntry: Identifiable, Codable, Hashable, Defaults.Serializable {
    let id: UUID
    let name: String
    let iconSystemName: String?
    var order: Int

    init(id: UUID = UUID(), name: String, iconSystemName: String? = nil, order: Int) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.order = order
    }
}

extension Defaults.Keys {
    static let shortcuts = Key<[ShortcutEntry]>("shortcuts", default: [])
}
