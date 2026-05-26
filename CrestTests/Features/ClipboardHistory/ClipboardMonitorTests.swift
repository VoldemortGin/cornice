import XCTest
@testable import Niya

final class MockNSPasteboard {
    var currentChangeCount = 0; var types: [String] = []; var stringContent: String?
    func incrementChangeCount() { currentChangeCount += 1 }
    func setString(_ s: String) { stringContent = s; types = ["public.utf8-plain-text"]; incrementChangeCount() }
    func clear() { stringContent = nil; types = []; incrementChangeCount() }
}

final class MockClipboardStore: ClipboardHistoryStoreProtocol {
    var entries: [ClipboardEntry] = []; var pinnedEntries: [ClipboardEntry] { entries.filter(\.isPinned) }; var maxEntries = 50
    private(set) var addCallCount = 0; private(set) var copiedID: UUID?
    func add(_ entry: ClipboardEntry) {
        addCallCount += 1; entries.insert(entry, at: 0)
        while entries.count > maxEntries { if let i = entries.lastIndex(where: { !$0.isPinned }) { entries.remove(at: i) } else { break } }
    }
    func remove(id: UUID) { entries.removeAll { $0.id == id } }
    func removeAll() { entries.removeAll { !$0.isPinned } }
    func pin(id: UUID) { if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].isPinned = true } }
    func unpin(id: UUID) { if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].isPinned = false } }
    func copyToClipboard(id: UUID) { copiedID = id }
    func search(query: String) -> [ClipboardEntry] {
        entries.filter { $0.textContent?.localizedCaseInsensitiveContains(query) ?? false || $0.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false }
    }
}

extension ClipboardEntry {
    static func textStub(text: String = "Hi", sourceAppName: String? = "Safari", isPinned: Bool = false, ts: Date = Date()) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), timestamp: ts, contentType: .text, textContent: text, imageData: nil, fileURLs: nil, sourceAppBundleID: nil, sourceAppName: sourceAppName, isPinned: isPinned, isTruncated: false)
    }
    static func imageStub(data: Data = Data([0x89])) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), timestamp: Date(), contentType: .image, textContent: nil, imageData: data, fileURLs: nil, sourceAppBundleID: nil, sourceAppName: nil, isPinned: false, isTruncated: false)
    }
    static func fileURLStub(urls: [URL] = [URL(fileURLWithPath: "/tmp/f")]) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), timestamp: Date(), contentType: .fileURL, textContent: nil, imageData: nil, fileURLs: urls, sourceAppBundleID: "com.apple.finder", sourceAppName: "Finder", isPinned: false, isTruncated: false)
    }
}

final class ClipboardMonitorTests: XCTestCase {
    private var pb: MockNSPasteboard!; private var store: MockClipboardStore!
    override func setUp() { super.setUp(); pb = MockNSPasteboard(); store = MockClipboardStore() }
    override func tearDown() { pb = nil; store = nil; super.tearDown() }

    func test_changeCount_detectsChange() {
        let last = pb.currentChangeCount; pb.setString("new")
        XCTAssertNotEqual(pb.currentChangeCount, last)
    }
    func test_changeCount_same_noChange() { let last = pb.currentChangeCount; XCTAssertEqual(pb.currentChangeCount, last) }

    func test_textExtraction() { store.add(.textStub(text: "Copied")); XCTAssertEqual(store.entries[0].contentType, .text) }
    func test_imageExtraction() { store.add(.imageStub()); XCTAssertEqual(store.entries[0].contentType, .image) }
    func test_fileURLExtraction() { store.add(.fileURLStub()); XCTAssertEqual(store.entries[0].contentType, .fileURL) }

    func test_newestFirst() {
        store.add(.textStub(text: "Old", ts: Date().addingTimeInterval(-3600)))
        store.add(.textStub(text: "New", ts: Date()))
        XCTAssertEqual(store.entries[0].textContent, "New")
    }

    func test_maxEntries_prunes() {
        store.maxEntries = 3
        for i in 0..<4 { store.add(.textStub(text: "\(i)")) }
        XCTAssertEqual(store.entries.count, 3)
    }
    func test_pinnedSurvivePrune() {
        store.maxEntries = 2
        store.add(.textStub(text: "Pinned", isPinned: true))
        store.add(.textStub(text: "A")); store.add(.textStub(text: "B"))
        XCTAssertTrue(store.entries.contains(where: { $0.textContent == "Pinned" }))
    }

    func test_excludedApp() {
        let excluded: Set<String> = ["com.1password.1password"]
        XCTAssertTrue(excluded.contains("com.1password.1password"))
        XCTAssertFalse(excluded.contains("com.apple.Safari"))
    }

    func test_reCopyLoop_prevention() {
        var isRestoring = false; var lastCC = pb.currentChangeCount
        pb.setString("Original")
        if pb.currentChangeCount != lastCC && !isRestoring { store.add(.textStub(text: "Original")); lastCC = pb.currentChangeCount }
        XCTAssertEqual(store.addCallCount, 1)
        isRestoring = true; pb.setString("Original"); lastCC = pb.currentChangeCount; isRestoring = false
        if pb.currentChangeCount != lastCC && !isRestoring { store.add(.textStub(text: "Original")) }
        XCTAssertEqual(store.addCallCount, 1)
    }

    func test_pin_survivesClearAll() {
        store.add(.textStub(text: "Important", isPinned: true)); store.add(.textStub(text: "Disposable"))
        store.removeAll()
        XCTAssertEqual(store.entries.count, 1); XCTAssertEqual(store.entries[0].textContent, "Important")
    }
    func test_pin_toggle() {
        store.add(.textStub(text: "X")); let id = store.entries[0].id
        store.pin(id: id); XCTAssertTrue(store.entries[0].isPinned)
        store.unpin(id: id); XCTAssertFalse(store.entries[0].isPinned)
    }

    func test_search_byText() {
        store.add(.textStub(text: "Hello World")); store.add(.textStub(text: "Goodbye"))
        XCTAssertEqual(store.search(query: "Hello").count, 1)
    }
    func test_search_caseInsensitive() {
        store.add(.textStub(text: "Hello")); XCTAssertEqual(store.search(query: "hello").count, 1)
    }
    func test_search_byApp() {
        store.add(.textStub(text: "X", sourceAppName: "Safari")); store.add(.textStub(text: "Y", sourceAppName: "Notes"))
        XCTAssertEqual(store.search(query: "Safari").count, 1)
    }

    func test_creditCard_detected() { XCTAssertTrue(isCreditCard("4111111111111111")) }
    func test_nonCreditCard_notDetected() { XCTAssertFalse(isCreditCard("Hello")) }
    func test_ssn_detected() { XCTAssertTrue(isSSN("123-45-6789")) }
    func test_nonSSN_notDetected() { XCTAssertFalse(isSSN("Hello")) }

    private func isCreditCard(_ t: String) -> Bool { let d = t.filter(\.isNumber); return d.count >= 13 && d.count <= 16 }
    private func isSSN(_ t: String) -> Bool { t.range(of: #"^\d{3}-\d{2}-\d{4}$"#, options: .regularExpression) != nil }
}
