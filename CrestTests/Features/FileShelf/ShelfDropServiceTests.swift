import XCTest
import UniformTypeIdentifiers
@testable import Crest

final class MockTemporaryFileStorage: TemporaryFileStorageServiceProtocol {
    var storedData: [(Data, String?)] = []
    var storedTexts: [(String, String?)] = []
    var createdWeblocs: [(URL, String?)] = []
    var cleanupAllCallCount = 0
    var storageDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("niya-test")
    func store(data: Data, suggestedName: String?, utType: UTType?) throws -> URL {
        storedData.append((data, suggestedName))
        return storageDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent(suggestedName ?? "f")
    }
    func store(text: String, suggestedName: String?) throws -> URL {
        storedTexts.append((text, suggestedName))
        return storageDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent(suggestedName ?? "t.txt")
    }
    func createWebloc(for url: URL, name: String?) throws -> URL {
        createdWeblocs.append((url, name))
        return storageDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("\(name ?? "l").webloc")
    }
    func cleanup(olderThan: TimeInterval) {}
    func cleanupAll() { cleanupAllCallCount += 1 }
}

final class MockDropPasteboard: DropPasteboardProviding {
    var fileURLs: [URL] = []; var urls: [URL] = []; var strings: [String] = []
    var rawDataByType: [String: Data] = [:]; var availableTypes: [String] = []
}

final class ShelfDropServiceTests: XCTestCase {
    private var sut: DropProcessor!
    private var mockBookmarks: MockBookmarkService!
    private var mockTemp: MockTemporaryFileStorage!
    private var mockStore: ShelfStore!
    private var mockPersistence: MockShelfPersistence!

    override func setUp() {
        super.setUp()
        mockBookmarks = MockBookmarkService(); mockTemp = MockTemporaryFileStorage(); mockPersistence = MockShelfPersistence()
        mockStore = ShelfStore(persistence: mockPersistence, bookmarkService: mockBookmarks, maxItems: 20)
        sut = DropProcessor(bookmarkService: mockBookmarks, tempStorage: mockTemp, shelfStore: mockStore)
    }
    override func tearDown() { sut = nil; super.tearDown() }

    func test_fileURL_highestPriority() async throws {
        let pb = MockDropPasteboard()
        pb.fileURLs = [URL(fileURLWithPath: "/tmp/doc.pdf")]; pb.urls = [URL(string: "https://x.com")!]; pb.strings = ["text"]
        pb.availableTypes = ["public.file-url", "public.url", "public.utf8-plain-text"]
        let r = try await sut.process(pasteboard: pb)
        if case .file = r.item.kind {} else { XCTFail("Expected .file") }
    }

    func test_webURL_whenNoFile() async throws {
        let pb = MockDropPasteboard(); pb.urls = [URL(string: "https://swift.org")!]; pb.availableTypes = ["public.url"]
        let r = try await sut.process(pasteboard: pb)
        if case .link(let u) = r.item.kind { XCTAssertEqual(u.host, "swift.org") } else { XCTFail() }
    }

    func test_text_whenNoURLs() async throws {
        let pb = MockDropPasteboard(); pb.strings = ["hello"]; pb.availableTypes = ["public.utf8-plain-text"]
        let r = try await sut.process(pasteboard: pb)
        if case .text(let s) = r.item.kind { XCTAssertEqual(s, "hello") } else { XCTFail() }
    }

    func test_dataFallback_savesTemp() async throws {
        let pb = MockDropPasteboard(); pb.rawDataByType = ["public.png": Data([0x89])]; pb.availableTypes = ["public.png"]
        let r = try await sut.process(pasteboard: pb)
        if case .file = r.item.kind { XCTAssertEqual(mockTemp.storedData.count, 1) } else { XCTFail() }
    }

    func test_textTruncation_10000chars() async throws {
        let pb = MockDropPasteboard(); pb.strings = [String(repeating: "a", count: 15_000)]; pb.availableTypes = ["public.utf8-plain-text"]
        let r = try await sut.process(pasteboard: pb)
        if case .text(let s) = r.item.kind { XCTAssertLessThanOrEqual(s.count, 10_000) } else { XCTFail() }
    }

    func test_emptyPasteboard_throws() async {
        let pb = MockDropPasteboard(); pb.availableTypes = []
        do { _ = try await sut.process(pasteboard: pb); XCTFail() } catch {}
    }

    func test_duplicateDrop_deduped() async throws {
        let pb = MockDropPasteboard(); pb.fileURLs = [URL(fileURLWithPath: "/tmp/same.txt")]; pb.availableTypes = ["public.file-url"]
        let r1 = try await sut.process(pasteboard: pb); XCTAssertFalse(r1.wasDeduped)
        let r2 = try await sut.process(pasteboard: pb); XCTAssertTrue(r2.wasDeduped)
    }
}
