import XCTest
@testable import Cornice

final class ShortcutModelTests: XCTestCase {

    // MARK: - Creation

    func test_creation_withAllFields() {
        let id = UUID()
        let entry = ShortcutEntry(id: id, name: "Toggle", iconSystemName: "star", order: 0)
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.name, "Toggle")
        XCTAssertEqual(entry.iconSystemName, "star")
        XCTAssertEqual(entry.order, 0)
    }

    func test_creation_withDefaultID() {
        let entry = ShortcutEntry(name: "Test", iconSystemName: nil, order: 1)
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.name, "Test")
    }

    func test_creation_withNilIcon() {
        let entry = ShortcutEntry(name: "No Icon", iconSystemName: nil, order: 2)
        XCTAssertNil(entry.iconSystemName)
    }

    func test_creation_withIcon() {
        let entry = ShortcutEntry(name: "With Icon", iconSystemName: "gear", order: 3)
        XCTAssertEqual(entry.iconSystemName, "gear")
    }

    func test_order_isMutable() {
        var entry = ShortcutEntry(name: "Mutable", order: 0)
        entry.order = 5
        XCTAssertEqual(entry.order, 5)
    }

    // MARK: - Identifiable

    func test_identifiable_uniqueIDs() {
        let a = ShortcutEntry(name: "A", order: 0)
        let b = ShortcutEntry(name: "B", order: 1)
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_identifiable_explicitID() {
        let id = UUID()
        let entry = ShortcutEntry(id: id, name: "X", order: 0)
        XCTAssertEqual(entry.id, id)
    }

    // MARK: - Codable Round-trip

    func test_codable_roundTrip() throws {
        let original = ShortcutEntry(name: "Calendar", iconSystemName: "calendar", order: 2)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ShortcutEntry.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.iconSystemName, original.iconSystemName)
        XCTAssertEqual(decoded.order, original.order)
    }

    func test_codable_roundTrip_nilIcon() throws {
        let original = ShortcutEntry(name: "No Icon", iconSystemName: nil, order: 0)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ShortcutEntry.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertNil(decoded.iconSystemName)
    }

    func test_codable_arrayRoundTrip() throws {
        let entries = [
            ShortcutEntry(name: "A", iconSystemName: "star", order: 0),
            ShortcutEntry(name: "B", iconSystemName: nil, order: 1),
            ShortcutEntry(name: "C", iconSystemName: "gear", order: 2),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(entries)
        let decoded = try decoder.decode([ShortcutEntry].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        for i in 0..<entries.count {
            XCTAssertEqual(decoded[i].id, entries[i].id)
            XCTAssertEqual(decoded[i].name, entries[i].name)
            XCTAssertEqual(decoded[i].order, entries[i].order)
        }
    }

    // MARK: - Hashable

    func test_hashable_sameIDsSameHash() {
        let id = UUID()
        let a = ShortcutEntry(id: id, name: "A", iconSystemName: nil, order: 0)
        let b = ShortcutEntry(id: id, name: "A", iconSystemName: nil, order: 0)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_hashable_differentIDs_notEqual() {
        let a = ShortcutEntry(name: "A", order: 0)
        let b = ShortcutEntry(name: "A", order: 0)
        // Different UUIDs so they should not be equal
        XCTAssertNotEqual(a, b)
    }

    func test_hashable_setDeduplication() {
        let id = UUID()
        let a = ShortcutEntry(id: id, name: "Same", iconSystemName: nil, order: 0)
        let b = ShortcutEntry(id: id, name: "Same", iconSystemName: nil, order: 0)
        let set: Set<ShortcutEntry> = [a, b]
        XCTAssertEqual(set.count, 1)
    }

    func test_hashable_differentEntries_inSet() {
        let a = ShortcutEntry(name: "A", order: 0)
        let b = ShortcutEntry(name: "B", order: 1)
        let set: Set<ShortcutEntry> = [a, b]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Equatable

    func test_equatable_sameValues() {
        let id = UUID()
        let a = ShortcutEntry(id: id, name: "X", iconSystemName: "star", order: 0)
        let b = ShortcutEntry(id: id, name: "X", iconSystemName: "star", order: 0)
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentName() {
        let id = UUID()
        let a = ShortcutEntry(id: id, name: "X", iconSystemName: nil, order: 0)
        let b = ShortcutEntry(id: id, name: "Y", iconSystemName: nil, order: 0)
        // ShortcutEntry uses synthesized Equatable, so different name means not equal
        XCTAssertNotEqual(a, b)
    }

    func test_equatable_differentOrder() {
        let id = UUID()
        let a = ShortcutEntry(id: id, name: "X", iconSystemName: nil, order: 0)
        let b = ShortcutEntry(id: id, name: "X", iconSystemName: nil, order: 5)
        XCTAssertNotEqual(a, b)
    }
}
