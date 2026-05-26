import XCTest
@testable import Crest

final class QuickAppsManagerTests: XCTestCase {
    private var apps: [QuickAppEntry]!
    private let maxApps = 12
    override func setUp() { super.setUp(); apps = [] }

    func test_addApp() { apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "com.apple.Safari", name: "Safari", order: 0)); XCTAssertEqual(apps.count, 1) }
    func test_multipleApps_order() {
        apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "A", name: "A", order: 0))
        apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "B", name: "B", order: 1))
        XCTAssertEqual(apps[0].bundleIdentifier, "A"); XCTAssertEqual(apps[1].bundleIdentifier, "B")
    }
    func test_removeApp() {
        let id = UUID(); apps.append(QuickAppEntry(id: id, bundleIdentifier: "X", name: "X", order: 0))
        apps.removeAll { $0.id == id }; XCTAssertTrue(apps.isEmpty)
    }
    func test_reorder_lastToFirst() {
        apps = ["A","B","C"].enumerated().map { QuickAppEntry(id: UUID(), bundleIdentifier: $0.element, name: $0.element, order: $0.offset) }
        apps.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(apps[0].bundleIdentifier, "C")
    }
    func test_reorder_firstToLast() {
        apps = ["A","B","C"].enumerated().map { QuickAppEntry(id: UUID(), bundleIdentifier: $0.element, name: $0.element, order: $0.offset) }
        apps.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(apps[2].bundleIdentifier, "A")
    }
    func test_bundleID_stored() { let e = QuickAppEntry(id: UUID(), bundleIdentifier: "com.co.App", name: "App", order: 0); XCTAssertEqual(e.bundleIdentifier, "com.co.App") }
    func test_codable_roundTrip() throws {
        let orig = QuickAppEntry(id: UUID(), bundleIdentifier: "com.apple.Safari", name: "Safari", order: 3)
        let dec = try JSONDecoder().decode(QuickAppEntry.self, from: JSONEncoder().encode(orig))
        XCTAssertEqual(dec.id, orig.id); XCTAssertEqual(dec.bundleIdentifier, orig.bundleIdentifier); XCTAssertEqual(dec.order, orig.order)
    }
    func test_maxApps_enforced() {
        for i in 0..<15 { if apps.count < maxApps { apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "app\(i)", name: "app\(i)", order: i)) } }
        XCTAssertEqual(apps.count, 12)
    }
    func test_addAtMax_rejected() {
        for i in 0..<maxApps { apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "app\(i)", name: "app\(i)", order: i)) }
        if apps.count < maxApps { apps.append(QuickAppEntry(id: UUID(), bundleIdentifier: "overflow", name: "overflow", order: maxApps)) }
        XCTAssertEqual(apps.count, maxApps)
    }
    func test_hashable_sameID() {
        let id = UUID()
        XCTAssertEqual(QuickAppEntry(id: id, bundleIdentifier: "A", name: "A", order: 0), QuickAppEntry(id: id, bundleIdentifier: "A", name: "A", order: 0))
    }
    func test_hashable_diffID() {
        XCTAssertNotEqual(QuickAppEntry(id: UUID(), bundleIdentifier: "A", name: "A", order: 0), QuickAppEntry(id: UUID(), bundleIdentifier: "A", name: "A", order: 0))
    }
    func test_defaultApps_filterInstalled() {
        let defaults = ["com.apple.finder", "com.apple.Safari", "com.apple.MobileSMS"]
        let installed: Set<String> = ["com.apple.finder", "com.apple.Safari"]
        let filtered = defaults.filter { installed.contains($0) }
        XCTAssertEqual(filtered.count, 2); XCTAssertFalse(filtered.contains("com.apple.MobileSMS"))
    }
}
