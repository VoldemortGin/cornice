import XCTest
import UniformTypeIdentifiers
@testable import Cornice

final class TemporaryFileStorageTests: XCTestCase {
    private var sut: TemporaryFileStorageService!
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("niya-test-\(UUID().uuidString)")
        sut = TemporaryFileStorageService(baseDirectory: testDir)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: testDir); sut = nil; super.tearDown() }

    func test_storeData_createsFile() throws {
        let url = try sut.store(data: Data("Hi".utf8), suggestedName: "t.txt", utType: .plainText)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func test_storeData_contentsMatch() throws {
        let d = Data("Hello".utf8)
        let url = try sut.store(data: d, suggestedName: "c.txt", utType: .plainText)
        XCTAssertEqual(try Data(contentsOf: url), d)
    }
    func test_storeData_nilName_generates() throws {
        let url = try sut.store(data: Data([1]), suggestedName: nil, utType: .png)
        XCTAssertFalse(url.lastPathComponent.isEmpty)
    }
    func test_storeData_usesUTTypeExtension() throws {
        let url = try sut.store(data: Data([0x89]), suggestedName: nil, utType: .png)
        XCTAssertEqual(url.pathExtension, "png")
    }
    func test_storeText_creates() throws {
        let url = try sut.store(text: "Hello!", suggestedName: "s.txt")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "Hello!")
    }
    func test_uuidSubdirectory() throws {
        let url = try sut.store(data: Data("x".utf8), suggestedName: "x.txt", utType: .plainText)
        let parent = url.deletingLastPathComponent().lastPathComponent
        XCTAssertNotNil(UUID(uuidString: parent), "Parent should be UUID: \(parent)")
    }
    func test_separateSubdirs() throws {
        let u1 = try sut.store(data: Data("a".utf8), suggestedName: "a", utType: .plainText)
        let u2 = try sut.store(data: Data("b".utf8), suggestedName: "b", utType: .plainText)
        XCTAssertNotEqual(u1.deletingLastPathComponent(), u2.deletingLastPathComponent())
    }
    func test_cleanupAll() throws {
        _ = try sut.store(data: Data("1".utf8), suggestedName: "1", utType: .plainText)
        _ = try sut.store(data: Data("2".utf8), suggestedName: "2", utType: .plainText)
        sut.cleanupAll()
        let contents = try? FileManager.default.contentsOfDirectory(at: sut.storageDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(contents?.isEmpty ?? true)
    }
    func test_binaryBlob_preserves() throws {
        let d = Data((0..<256).map { UInt8($0) })
        let url = try sut.store(data: d, suggestedName: "b.bin", utType: nil)
        XCTAssertEqual(try Data(contentsOf: url), d)
    }
    func test_webloc_creates() throws {
        let url = try sut.createWebloc(for: URL(string: "https://example.com")!, name: "Ex")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "webloc")
    }
    func test_webloc_containsURL() throws {
        let wurl = try sut.createWebloc(for: URL(string: "https://swift.org")!, name: "Swift")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: wurl), format: nil) as? [String: Any]
        XCTAssertEqual(plist?["URL"] as? String, "https://swift.org")
    }
}
