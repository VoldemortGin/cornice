import Foundation
import Defaults

struct QuickAppEntry: Identifiable, Codable, Hashable, Defaults.Serializable {
    let id: UUID
    let bundleIdentifier: String
    let name: String
    var order: Int

    init(id: UUID = UUID(), bundleIdentifier: String, name: String, order: Int) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.order = order
    }
}

extension Defaults.Keys {
    static let quickApps = Key<[QuickAppEntry]>("quickApps", default: [])
}
