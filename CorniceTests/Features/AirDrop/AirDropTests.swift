import XCTest
@testable import Cornice

// MARK: - Mock Bookmark Service for AirDrop

private final class AirDropMockBookmarkService: SecurityScopedBookmarkServiceProtocol {
    var bookmarkToReturn: Data = Data([0x01, 0x02])
    var resolvedURL: URL = URL(fileURLWithPath: "/tmp/resolved-file.txt")
    var resolvedIsStale: Bool = false
    var shouldThrow: Bool = false
    var staleIDs: [UUID] = []

    func createBookmark(for url: URL) throws -> Data {
        if shouldThrow { throw BookmarkError.resolutionFailed }
        return bookmarkToReturn
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        if shouldThrow { throw BookmarkError.resolutionFailed }
        return (resolvedURL, resolvedIsStale)
    }

    func accessResource<T>(bookmark: Data, operation: (URL) throws -> T) throws -> T {
        if shouldThrow { throw BookmarkError.accessDenied }
        return try operation(resolvedURL)
    }

    func validateBookmarks(_ items: [ShelfItem]) -> [UUID] {
        staleIDs
    }
}

// MARK: - AirDropState Tests

final class AirDropStateTests: XCTestCase {

    func test_idle_equalsIdle() {
        XCTAssertEqual(AirDropState.idle, AirDropState.idle)
    }

    func test_ready_equalsReady() {
        XCTAssertEqual(AirDropState.ready, AirDropState.ready)
    }

    func test_sending_equalsSending() {
        XCTAssertEqual(AirDropState.sending, AirDropState.sending)
    }

    func test_completed_equalsCompleted() {
        XCTAssertEqual(AirDropState.completed, AirDropState.completed)
    }

    func test_failed_equalsSameMessage() {
        XCTAssertEqual(AirDropState.failed("error"), AirDropState.failed("error"))
    }

    func test_failed_notEqualDifferentMessage() {
        XCTAssertNotEqual(AirDropState.failed("a"), AirDropState.failed("b"))
    }

    func test_idle_notEqualReady() {
        XCTAssertNotEqual(AirDropState.idle, AirDropState.ready)
    }

    func test_idle_notEqualSending() {
        XCTAssertNotEqual(AirDropState.idle, AirDropState.sending)
    }

    func test_idle_notEqualCompleted() {
        XCTAssertNotEqual(AirDropState.idle, AirDropState.completed)
    }

    func test_idle_notEqualFailed() {
        XCTAssertNotEqual(AirDropState.idle, AirDropState.failed("x"))
    }

    func test_sending_notEqualCompleted() {
        XCTAssertNotEqual(AirDropState.sending, AirDropState.completed)
    }

    func test_completed_notEqualFailed() {
        XCTAssertNotEqual(AirDropState.completed, AirDropState.failed("done"))
    }

    func test_allCasesExist() {
        let states: [AirDropState] = [.idle, .ready, .sending, .completed, .failed("msg")]
        XCTAssertEqual(states.count, 5)
    }
}

// MARK: - AirDropResult Tests

final class AirDropResultTests: XCTestCase {

    func test_successCase_exists() {
        let result: AirDropResult = .success
        if case .success = result {
            // pass
        } else {
            XCTFail("Expected .success")
        }
    }

    func test_cancelledCase_exists() {
        let result: AirDropResult = .cancelled
        if case .cancelled = result {
            // pass
        } else {
            XCTFail("Expected .cancelled")
        }
    }

    func test_failedCase_carriesError() {
        let error = AirDropError.noContent
        let result: AirDropResult = .failed(error)
        if case .failed(let e) = result {
            XCTAssertTrue(e is AirDropError)
        } else {
            XCTFail("Expected .failed")
        }
    }
}

// MARK: - AirDropError Tests

final class AirDropErrorTests: XCTestCase {

    func test_unavailable_description() {
        let error = AirDropError.unavailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("AirDrop"))
        XCTAssertTrue(error.errorDescription!.contains("not available"))
    }

    func test_noContent_description() {
        let error = AirDropError.noContent
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("No content"))
    }

    func test_bookmarkResolutionFailed_description() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad bookmark"])
        let error = AirDropError.bookmarkResolutionFailed(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Could not access"))
        XCTAssertTrue(error.errorDescription!.contains("bad bookmark"))
    }

    func test_transferFailed_description() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = AirDropError.transferFailed(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("transfer failed"))
        XCTAssertTrue(error.errorDescription!.contains("timeout"))
    }

    func test_conformsToLocalizedError() {
        let error: LocalizedError = AirDropError.unavailable
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - AirDropService Protocol Tests

final class AirDropServiceProtocolTests: XCTestCase {

    func test_protocolConformance() {
        // AirDropService conforms to AirDropServiceProtocol
        let mockBookmark = AirDropMockBookmarkService()
        let service = AirDropService(bookmarkService: mockBookmark)
        let proto: any AirDropServiceProtocol = service
        XCTAssertNotNil(proto)
    }

    func test_serviceCreation() {
        let mockBookmark = AirDropMockBookmarkService()
        let service = AirDropService(bookmarkService: mockBookmark)
        XCTAssertNotNil(service)
    }
}

// MARK: - AirDropService Item Conversion Tests

final class AirDropItemConversionTests: XCTestCase {
    private var service: AirDropService!
    private var mockBookmark: AirDropMockBookmarkService!

    override func setUp() {
        super.setUp()
        mockBookmark = AirDropMockBookmarkService()
        mockBookmark.resolvedURL = URL(fileURLWithPath: "/tmp/test-file.pdf")
        service = AirDropService(bookmarkService: mockBookmark)
    }

    override func tearDown() {
        service = nil
        mockBookmark = nil
        super.tearDown()
    }

    // MARK: - ShelfItem conversion

    func test_resolveShareableItems_fileItem_resolvesBookmark() throws {
        let bookmark = Data([0xAA, 0xBB])
        let item = ShelfItem(
            id: UUID(),
            kind: .file(bookmark: bookmark),
            createdAt: Date(),
            name: "document.pdf",
            identityKey: "/tmp/document.pdf",
            isPinned: false
        )
        let result = try service.resolveShareableItems(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is URL)
    }

    func test_resolveShareableItems_textItem_returnsString() throws {
        let item = ShelfItem(
            id: UUID(),
            kind: .text(string: "Hello World"),
            createdAt: Date(),
            name: "Hello World",
            identityKey: "text_hello",
            isPinned: false
        )
        let result = try service.resolveShareableItems(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0] as? String, "Hello World")
    }

    func test_resolveShareableItems_linkItem_returnsURL() throws {
        let url = URL(string: "https://example.com")!
        let item = ShelfItem(
            id: UUID(),
            kind: .link(url: url),
            createdAt: Date(),
            name: "example.com",
            identityKey: "https://example.com",
            isPinned: false
        )
        let result = try service.resolveShareableItems(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0] as? URL, url)
    }

    func test_resolveShareableItems_multipleItems_returnsAll() throws {
        let items: [ShelfItem] = [
            ShelfItem(id: UUID(), kind: .text(string: "A"), createdAt: Date(), name: "A", identityKey: "a", isPinned: false),
            ShelfItem(id: UUID(), kind: .text(string: "B"), createdAt: Date(), name: "B", identityKey: "b", isPinned: false),
        ]
        let result = try service.resolveShareableItems(from: items)
        XCTAssertEqual(result.count, 2)
    }

    func test_resolveShareableItems_emptyArray_returnsEmpty() throws {
        let result = try service.resolveShareableItems(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func test_resolveShareableItems_bookmarkThrows_propagatesError() {
        mockBookmark.shouldThrow = true
        let item = ShelfItem(
            id: UUID(),
            kind: .file(bookmark: Data([0x01])),
            createdAt: Date(),
            name: "bad.pdf",
            identityKey: "/tmp/bad.pdf",
            isPinned: false
        )
        XCTAssertThrowsError(try service.resolveShareableItems(from: [item]))
    }

    // MARK: - ClipboardEntry conversion

    func test_resolveShareableItems_textEntry_returnsText() throws {
        let entry = ClipboardEntry.textStub(text: "clipboard text")
        let result = try service.resolveShareableItems(from: entry)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0] as? String, "clipboard text")
    }

    func test_resolveShareableItems_richTextEntry_returnsText() throws {
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .richText,
            textContent: "rich content", imageData: nil, fileURLs: nil,
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        let result = try service.resolveShareableItems(from: entry)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0] as? String, "rich content")
    }

    func test_resolveShareableItems_textEntry_nilContent_throws() {
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .text,
            textContent: nil, imageData: nil, fileURLs: nil,
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        XCTAssertThrowsError(try service.resolveShareableItems(from: entry)) { error in
            XCTAssertTrue(error is AirDropError)
        }
    }

    func test_resolveShareableItems_imageEntry_nilData_throws() {
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .image,
            textContent: nil, imageData: nil, fileURLs: nil,
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        XCTAssertThrowsError(try service.resolveShareableItems(from: entry)) { error in
            XCTAssertTrue(error is AirDropError)
        }
    }

    func test_resolveShareableItems_fileURLEntry_returnsURLs() throws {
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .fileURL,
            textContent: nil, imageData: nil, fileURLs: urls,
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        let result = try service.resolveShareableItems(from: entry)
        XCTAssertEqual(result.count, 2)
    }

    func test_resolveShareableItems_fileURLEntry_nilURLs_throws() {
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .fileURL,
            textContent: nil, imageData: nil, fileURLs: nil,
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        XCTAssertThrowsError(try service.resolveShareableItems(from: entry)) { error in
            XCTAssertTrue(error is AirDropError)
        }
    }

    func test_resolveShareableItems_fileURLEntry_emptyURLs_throws() {
        let entry = ClipboardEntry(
            id: UUID(), timestamp: Date(), contentType: .fileURL,
            textContent: nil, imageData: nil, fileURLs: [],
            sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false
        )
        XCTAssertThrowsError(try service.resolveShareableItems(from: entry)) { error in
            XCTAssertTrue(error is AirDropError)
        }
    }
}

// MARK: - AirDropService Monitoring Tests

final class AirDropMonitoringTests: XCTestCase {
    private var service: AirDropService!

    override func setUp() {
        super.setUp()
        service = AirDropService(bookmarkService: AirDropMockBookmarkService())
    }

    override func tearDown() {
        service.stopMonitoring()
        service = nil
        super.tearDown()
    }

    func test_stopMonitoring_doesNotCrashWhenNotStarted() {
        // Should be safe to call without starting first
        service.stopMonitoring()
    }

    func test_stopMonitoring_calledTwice_doesNotCrash() {
        service.startMonitoring(interval: 10.0) { _ in }
        service.stopMonitoring()
        service.stopMonitoring()
    }

    func test_startMonitoring_replacesExistingMonitor() {
        var callCount = 0
        service.startMonitoring(interval: 10.0) { _ in callCount += 1 }
        service.startMonitoring(interval: 10.0) { _ in callCount += 1 }
        // No crash means the old timer was properly invalidated
        service.stopMonitoring()
    }
}
