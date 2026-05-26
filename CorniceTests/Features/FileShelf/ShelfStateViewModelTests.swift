import XCTest
import Combine
@testable import Cornice

final class MockShelfPersistence: ShelfPersistenceServiceProtocol {
    var savedItems: [ShelfItem]?
    var loadResult: Result<[ShelfItem], Error> = .success([])
    var clearCallCount = 0
    func load() throws -> [ShelfItem] { try loadResult.get() }
    func save(_ items: [ShelfItem]) throws { savedItems = items }
    func clear() throws { clearCallCount += 1; savedItems = [] }
}

final class MockBookmarkService: SecurityScopedBookmarkServiceProtocol {
    var createResult: Result<Data, Error> = .success(Data([0x01]))
    var resolveResult: Result<(url: URL, isStale: Bool), Error> = .success((URL(fileURLWithPath: "/tmp/t"), false))
    var validateResult: [UUID] = []
    func createBookmark(for url: URL) throws -> Data { try createResult.get() }
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) { try resolveResult.get() }
    func accessResource<T>(bookmark: Data, operation: (URL) throws -> T) throws -> T { try operation(resolveBookmark(bookmark).url) }
    func validateBookmarks(_ items: [ShelfItem]) -> [UUID] { validateResult }
}

extension ShelfItem {
    static func fileStub(id: UUID = UUID(), name: String = "test.txt", identityKey: String? = nil, isPinned: Bool = false) -> ShelfItem {
        ShelfItem(id: id, kind: .file(bookmark: Data([0x01])), createdAt: Date(), name: name, identityKey: identityKey ?? "/tmp/\(name)", isPinned: isPinned)
    }
    static func textStub(id: UUID = UUID(), text: String = "Hello", isPinned: Bool = false) -> ShelfItem {
        ShelfItem(id: id, kind: .text(string: text), createdAt: Date(), name: "Text", identityKey: "hash_\(text.hashValue)", isPinned: isPinned)
    }
    static func linkStub(id: UUID = UUID(), urlString: String = "https://example.com", isPinned: Bool = false) -> ShelfItem {
        ShelfItem(id: id, kind: .link(url: URL(string: urlString)!), createdAt: Date(), name: "Link", identityKey: urlString.lowercased(), isPinned: isPinned)
    }
}

@MainActor
final class ShelfStateViewModelTests: XCTestCase {
    private var sut: ShelfStore!
    private var mockPersistence: MockShelfPersistence!
    private var mockBookmarks: MockBookmarkService!

    override func setUp() {
        super.setUp()
        mockPersistence = MockShelfPersistence()
        mockBookmarks = MockBookmarkService()
        sut = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 20)
    }
    override func tearDown() { sut = nil; mockPersistence = nil; mockBookmarks = nil; super.tearDown() }

    func test_addFileItem() throws { try sut.add(.fileStub(name: "doc.pdf")); XCTAssertEqual(sut.items.count, 1) }
    func test_addTextItem() throws { try sut.add(.textStub(text: "Hi")); XCTAssertEqual(sut.items.count, 1); if case .text(let s) = sut.items[0].kind { XCTAssertEqual(s, "Hi") } else { XCTFail() } }
    func test_addLinkItem() throws { try sut.add(.linkStub(urlString: "https://swift.org")); if case .link(let u) = sut.items[0].kind { XCTAssertEqual(u.host, "swift.org") } else { XCTFail() } }

    func test_dedup_sameKey_noSecondEntry() throws {
        try sut.add(.fileStub(identityKey: "/k")); try sut.add(.fileStub(identityKey: "/k"))
        XCTAssertEqual(sut.items.count, 1)
    }
    func test_dedup_bumpsCreatedAt() throws {
        var item = ShelfItem.fileStub(identityKey: "/k"); item.createdAt = .distantPast
        try sut.add(item); try sut.add(.fileStub(identityKey: "/k"))
        XCTAssertGreaterThan(sut.items[0].createdAt, .distantPast)
    }
    func test_differentKeys_bothKept() throws {
        try sut.add(.fileStub(identityKey: "/a")); try sut.add(.fileStub(identityKey: "/b"))
        XCTAssertEqual(sut.items.count, 2)
    }

    func test_removeById() throws { let id = UUID(); try sut.add(.fileStub(id: id, identityKey: "/r")); sut.remove(id: id); XCTAssertTrue(sut.items.isEmpty) }
    func test_removeAll() throws { try sut.add(.fileStub(identityKey: "/a")); try sut.add(.fileStub(identityKey: "/b")); sut.removeAll(); XCTAssertTrue(sut.items.isEmpty) }

    func test_maxItems_prunesOldest() throws {
        sut = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 3)
        for i in 0..<4 { try sut.add(.fileStub(name: "\(i)", identityKey: "/\(i)")) }
        XCTAssertEqual(sut.items.count, 3)
        XCTAssertNil(sut.items.first(where: { $0.name == "0" }))
    }
    func test_maxItems_pinnedSurvive() throws {
        sut = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 2)
        try sut.add(.fileStub(name: "pin", identityKey: "/pin", isPinned: true))
        try sut.add(.fileStub(name: "old", identityKey: "/old"))
        try sut.add(.fileStub(name: "new", identityKey: "/new"))
        XCTAssertNotNil(sut.items.first(where: { $0.name == "pin" }))
    }

    func test_loadOnInit_restores() throws {
        mockPersistence.loadResult = .success([.fileStub(name: "saved", identityKey: "/saved")])
        let store = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 20)
        XCTAssertEqual(store.items.first?.name, "saved")
    }
    func test_loadCorrupt_startsEmpty() throws {
        mockPersistence.loadResult = .failure(NSError(domain: "", code: -1))
        let store = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 20)
        XCTAssertTrue(store.items.isEmpty)
    }

    func test_pin() throws { let id = UUID(); try sut.add(.fileStub(id: id, identityKey: "/p")); sut.pin(id: id); XCTAssertTrue(sut.items[0].isPinned) }
    func test_unpin() throws { let id = UUID(); try sut.add(.fileStub(id: id, identityKey: "/u", isPinned: true)); sut.unpin(id: id); XCTAssertFalse(sut.items[0].isPinned) }

    func test_move() throws {
        try sut.add(.fileStub(name: "A", identityKey: "/A")); try sut.add(.fileStub(name: "B", identityKey: "/B")); try sut.add(.fileStub(name: "C", identityKey: "/C"))
        sut.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(sut.items[0].name, "C")
    }

    func test_itemForKey_found() throws { try sut.add(.fileStub(identityKey: "/find")); XCTAssertNotNil(sut.item(for: "/find")) }
    func test_itemForKey_notFound() { XCTAssertNil(sut.item(for: "/nope")) }
}
