import XCTest
@testable import Cornice

final class ClipboardViewModelTests: XCTestCase {
    private var vm: ClipboardHistoryViewModel!
    private var tempDir: URL!

    @MainActor
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardViewModelTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        vm = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pollInterval: 999),
            persistenceDirectory: tempDir
        )
    }

    @MainActor
    override func tearDown() {
        vm = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Initial State

    @MainActor
    func test_initialState_entriesEmpty() {
        XCTAssertTrue(vm.entries.isEmpty)
    }

    @MainActor
    func test_initialState_searchQueryEmpty() {
        XCTAssertEqual(vm.searchQuery, "")
    }

    @MainActor
    func test_initialState_monitoringNotPaused() {
        XCTAssertFalse(vm.isMonitoringPaused)
    }

    @MainActor
    func test_initialState_copiedToastHidden() {
        XCTAssertFalse(vm.showCopiedToast)
    }

    @MainActor
    func test_initialState_maxEntries() {
        XCTAssertEqual(vm.maxEntries, 50)
    }

    // MARK: - Adding Entries

    @MainActor
    func test_addEntry_insertsAtFront() {
        let entry1 = ClipboardEntry.textStub(text: "First")
        let entry2 = ClipboardEntry.textStub(text: "Second")
        vm.addEntry(entry1)
        vm.addEntry(entry2)
        XCTAssertEqual(vm.entries.count, 2)
        XCTAssertEqual(vm.entries[0].textContent, "Second")
        XCTAssertEqual(vm.entries[1].textContent, "First")
    }

    @MainActor
    func test_addEntry_singleEntry() {
        let entry = ClipboardEntry.textStub(text: "Hello")
        vm.addEntry(entry)
        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertEqual(vm.entries[0].textContent, "Hello")
    }

    // MARK: - Max Entries Pruning

    @MainActor
    func test_pruning_removesOldestUnpinned() {
        vm.maxEntries = 3
        for i in 0..<5 {
            vm.addEntry(.textStub(text: "Entry \(i)"))
        }
        XCTAssertEqual(vm.entries.count, 3)
    }

    @MainActor
    func test_pruning_pinnedSurvive() {
        vm.maxEntries = 2
        let pinned = ClipboardEntry.textStub(text: "Pinned", isPinned: true)
        vm.addEntry(pinned)
        vm.addEntry(.textStub(text: "A"))
        vm.addEntry(.textStub(text: "B"))
        XCTAssertTrue(vm.entries.contains { $0.textContent == "Pinned" })
    }

    @MainActor
    func test_pruning_allPinned_doesNotCrash() {
        vm.maxEntries = 2
        let e1 = ClipboardEntry.textStub(text: "P1", isPinned: true)
        let e2 = ClipboardEntry.textStub(text: "P2", isPinned: true)
        let e3 = ClipboardEntry.textStub(text: "P3", isPinned: true)
        vm.addEntry(e1)
        vm.addEntry(e2)
        vm.addEntry(e3)
        // All pinned, so pruning cannot remove any, count exceeds max
        XCTAssertEqual(vm.entries.count, 3)
    }

    // MARK: - Pin / Unpin

    @MainActor
    func test_pinEntry() {
        let entry = ClipboardEntry.textStub(text: "Pin me")
        vm.addEntry(entry)
        let id = vm.entries[0].id
        vm.pinEntry(id: id)
        XCTAssertTrue(vm.entries[0].isPinned)
    }

    @MainActor
    func test_unpinEntry() {
        let entry = ClipboardEntry.textStub(text: "Unpin me", isPinned: true)
        vm.addEntry(entry)
        let id = vm.entries[0].id
        XCTAssertTrue(vm.entries[0].isPinned)
        vm.unpinEntry(id: id)
        XCTAssertFalse(vm.entries[0].isPinned)
    }

    @MainActor
    func test_pinEntry_invalidID_noChange() {
        vm.addEntry(.textStub(text: "X"))
        let bogusID = UUID()
        vm.pinEntry(id: bogusID)
        XCTAssertFalse(vm.entries[0].isPinned)
    }

    @MainActor
    func test_pinnedEntries_computed() {
        vm.addEntry(.textStub(text: "A", isPinned: true))
        vm.addEntry(.textStub(text: "B", isPinned: false))
        vm.addEntry(.textStub(text: "C", isPinned: true))
        XCTAssertEqual(vm.pinnedEntries.count, 2)
    }

    // MARK: - Remove Entry

    @MainActor
    func test_removeEntry() {
        let entry = ClipboardEntry.textStub(text: "Remove me")
        vm.addEntry(entry)
        let id = vm.entries[0].id
        vm.removeEntry(id: id)
        XCTAssertTrue(vm.entries.isEmpty)
    }

    @MainActor
    func test_removeEntry_invalidID_noChange() {
        vm.addEntry(.textStub(text: "Stay"))
        vm.removeEntry(id: UUID())
        XCTAssertEqual(vm.entries.count, 1)
    }

    // MARK: - Clear All

    @MainActor
    func test_clearAll_removesUnpinned() {
        vm.addEntry(.textStub(text: "Unpinned"))
        vm.addEntry(.textStub(text: "Also unpinned"))
        vm.clearAll()
        XCTAssertTrue(vm.entries.isEmpty)
    }

    @MainActor
    func test_clearAll_keepsPinned() {
        vm.addEntry(.textStub(text: "Important", isPinned: true))
        vm.addEntry(.textStub(text: "Disposable"))
        vm.clearAll()
        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertEqual(vm.entries[0].textContent, "Important")
    }

    @MainActor
    func test_clearAll_emptyList_doesNotCrash() {
        vm.clearAll()
        XCTAssertTrue(vm.entries.isEmpty)
    }

    // MARK: - Search Filtering

    @MainActor
    func test_filteredEntries_emptyQuery_returnsAll() {
        vm.addEntry(.textStub(text: "Hello"))
        vm.addEntry(.textStub(text: "World"))
        vm.searchQuery = ""
        XCTAssertEqual(vm.filteredEntries.count, 2)
    }

    @MainActor
    func test_filteredEntries_matchesTextContent() {
        vm.addEntry(.textStub(text: "Hello World"))
        vm.addEntry(.textStub(text: "Goodbye"))
        vm.searchQuery = "Hello"
        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertEqual(vm.filteredEntries[0].textContent, "Hello World")
    }

    @MainActor
    func test_searchEntries_caseInsensitive() {
        vm.addEntry(.textStub(text: "Hello"))
        let results = vm.searchEntries(query: "hello")
        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func test_searchEntries_bySourceAppName() {
        vm.addEntry(.textStub(text: "X", sourceAppName: "Safari"))
        vm.addEntry(.textStub(text: "Y", sourceAppName: "Notes"))
        let results = vm.searchEntries(query: "Safari")
        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func test_searchEntries_byFileName() {
        let entry = ClipboardEntry.fileURLStub(urls: [URL(fileURLWithPath: "/tmp/report.pdf")])
        vm.addEntry(entry)
        let results = vm.searchEntries(query: "report")
        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func test_searchEntries_emptyQuery_returnsAll() {
        vm.addEntry(.textStub(text: "A"))
        vm.addEntry(.textStub(text: "B"))
        let results = vm.searchEntries(query: "")
        XCTAssertEqual(results.count, 2)
    }

    @MainActor
    func test_searchEntries_noMatch_returnsEmpty() {
        vm.addEntry(.textStub(text: "Hello"))
        let results = vm.searchEntries(query: "zzzzz")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Monitor Control

    @MainActor
    func test_pauseMonitoring_setsFlag() {
        vm.pauseMonitoring()
        XCTAssertTrue(vm.isMonitoringPaused)
    }

    @MainActor
    func test_resumeMonitoring_clearsFlag() {
        vm.pauseMonitoring()
        vm.resumeMonitoring()
        XCTAssertFalse(vm.isMonitoringPaused)
    }

    // MARK: - Persistence

    @MainActor
    func test_saveAndReload() {
        vm.addEntry(.textStub(text: "Persistent"))
        vm.saveEntries()

        // Create a new ViewModel reading from the same directory
        let vm2 = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pollInterval: 999),
            persistenceDirectory: tempDir
        )
        XCTAssertEqual(vm2.entries.count, 1)
        XCTAssertEqual(vm2.entries[0].textContent, "Persistent")
    }

    @MainActor
    func test_persistence_emptyDirectory_loadsEmpty() {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let freshVM = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pollInterval: 999),
            persistenceDirectory: emptyDir
        )
        XCTAssertTrue(freshVM.entries.isEmpty)
    }
}
