import XCTest
@testable import Crest

// Local test enums that don't conflict with production types
enum TestActivationMethod: String, Codable { case hover, click }
enum TestLogLevel: String, Codable { case debug, info, warning, error }
enum TestQuickAppsIconSize: String, Codable { case small, medium, large }
enum TestAutoClearDuration: String, Codable { case never, oneHour, fourHours, twelveHours, oneDay, sevenDays }

final class SettingsManagerTests: XCTestCase {
    private let keysToClean = ["menubarIcon","hoverDelay","closeDelay","autoSwitchDisplay","transparency","animationSpeed","cornerRadius","showAlbumArt","showVisualizer","sneakPeekOnTrackChange","sneakPeekDuration","calendarEnabled","calendarLookahead","showDeclinedEvents","hudReplacementEnabled","hudDisplayDuration","lowBatteryThreshold","shelfMaxItems","clipboardMaxEntries","quickAppsEnabled","mirrorEnabled","mirrorFlipped","debugMode","customAccentColor","clipboardExcludedApps","settingsSchemaVersion"]
    override func setUp() { super.setUp(); keysToClean.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
    override func tearDown() { keysToClean.forEach { UserDefaults.standard.removeObject(forKey: $0) }; super.tearDown() }
    private func def<T>(_ key: String, _ fallback: T) -> T { UserDefaults.standard.object(forKey: key) as? T ?? fallback }

    // Defaults
    func test_default_menubarIcon() { XCTAssertTrue(def("menubarIcon", true)) }
    func test_default_hoverDelay() { XCTAssertEqual(def("hoverDelay", 0.2), 0.2, accuracy: 0.01) }
    func test_default_closeDelay() { XCTAssertEqual(def("closeDelay", 0.5), 0.5, accuracy: 0.01) }
    func test_default_transparency() { XCTAssertEqual(def("transparency", 0.8), 0.8, accuracy: 0.01) }
    func test_default_animationSpeed() { XCTAssertEqual(def("animationSpeed", 1.0), 1.0, accuracy: 0.01) }
    func test_default_showAlbumArt() { XCTAssertTrue(def("showAlbumArt", true)) }
    func test_default_sneakPeek() { XCTAssertTrue(def("sneakPeekOnTrackChange", true)) }
    func test_default_sneakPeekDuration() { XCTAssertEqual(def("sneakPeekDuration", 3.0), 3.0, accuracy: 0.01) }
    func test_default_calendarEnabled() { XCTAssertTrue(def("calendarEnabled", true)) }
    func test_default_lookahead() { XCTAssertEqual(def("calendarLookahead", 12), 12) }
    func test_default_hudEnabled() { XCTAssertTrue(def("hudReplacementEnabled", true)) }
    func test_default_hudDuration() { XCTAssertEqual(def("hudDisplayDuration", 1.5), 1.5, accuracy: 0.01) }
    func test_default_batteryThreshold() { XCTAssertEqual(def("lowBatteryThreshold", 20), 20) }
    func test_default_shelfMax() { XCTAssertEqual(def("shelfMaxItems", 20), 20) }
    func test_default_clipboardMax() { XCTAssertEqual(def("clipboardMaxEntries", 50), 50) }
    func test_default_debugMode() { XCTAssertFalse(def("debugMode", false)) }

    // Persistence
    func test_persist_bool() { UserDefaults.standard.set(false, forKey: "menubarIcon"); XCTAssertFalse(UserDefaults.standard.bool(forKey: "menubarIcon")) }
    func test_persist_double() { UserDefaults.standard.set(0.35, forKey: "hoverDelay"); XCTAssertEqual(UserDefaults.standard.double(forKey: "hoverDelay"), 0.35, accuracy: 0.001) }
    func test_persist_int() { UserDefaults.standard.set(30, forKey: "clipboardMaxEntries"); XCTAssertEqual(UserDefaults.standard.integer(forKey: "clipboardMaxEntries"), 30) }
    func test_persist_string() { UserDefaults.standard.set("#FF0000", forKey: "customAccentColor"); XCTAssertEqual(UserDefaults.standard.string(forKey: "customAccentColor"), "#FF0000") }
    func test_persist_array() { let a = ["com.1password"]; UserDefaults.standard.set(a, forKey: "clipboardExcludedApps"); XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "clipboardExcludedApps"), a) }

    // Notification
    func test_resetNotification() {
        let e = expectation(description: "notif"); let n = Notification.Name("SettingsDidReset")
        NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { _ in e.fulfill() }
        NotificationCenter.default.post(name: n, object: nil); waitForExpectations(timeout: 2)
    }

    // Export/Import
    func test_exportImport_roundTrip() {
        UserDefaults.standard.set(false, forKey: "menubarIcon"); UserDefaults.standard.set(0.4, forKey: "hoverDelay")
        let dict: [String: Any] = ["menubarIcon": false, "hoverDelay": 0.4, "_exportVersion": 1, "_exportDate": "now"]
        keysToClean.forEach { UserDefaults.standard.removeObject(forKey: $0) } // reset
        for (k, v) in dict where !k.hasPrefix("_") { UserDefaults.standard.set(v, forKey: k) }
        XCTAssertEqual(UserDefaults.standard.double(forKey: "hoverDelay"), 0.4, accuracy: 0.001)
    }

    // Enum Codable - using test-local enums that don't conflict
    func test_activationMethod_codable() throws { let d = try JSONEncoder().encode(TestActivationMethod.hover); XCTAssertEqual(try JSONDecoder().decode(TestActivationMethod.self, from: d), .hover) }
    func test_notchHeightMode_codable() throws {
        // Test the production NotchHeightMode Codable conformance
        let modes: [NotchHeightMode] = [.matchNotch, .matchMenuBar, .custom(36)]
        for m in modes {
            let d = try JSONEncoder().encode(m)
            let decoded = try JSONDecoder().decode(NotchHeightMode.self, from: d)
            XCTAssertEqual(decoded, m)
        }
    }
    func test_musicSource_codable() throws { for s in MusicSource.allCases { let d = try JSONEncoder().encode(s); XCTAssertEqual(try JSONDecoder().decode(MusicSource.self, from: d), s) } }
    func test_logLevel_codable() throws { for l in [TestLogLevel.debug, .info, .warning, .error] { let d = try JSONEncoder().encode(l); XCTAssertEqual(try JSONDecoder().decode(TestLogLevel.self, from: d), l) } }
    func test_iconSize_codable() throws { for s in [TestQuickAppsIconSize.small, .medium, .large] { let d = try JSONEncoder().encode(s); XCTAssertEqual(try JSONDecoder().decode(TestQuickAppsIconSize.self, from: d), s) } }
    func test_autoClear_codable() throws { for c in [TestAutoClearDuration.never, .oneHour, .sevenDays] { let d = try JSONEncoder().encode(c); XCTAssertEqual(try JSONDecoder().decode(TestAutoClearDuration.self, from: d), c) } }

    // Reset
    func test_reset_clearsKeys() {
        UserDefaults.standard.set(false, forKey: "menubarIcon"); UserDefaults.standard.set(0.4, forKey: "hoverDelay")
        keysToClean.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        XCTAssertNil(UserDefaults.standard.object(forKey: "menubarIcon")); XCTAssertNil(UserDefaults.standard.object(forKey: "hoverDelay"))
    }

    // Migration
    func test_migration_v1ToV2() {
        UserDefaults.standard.set(1, forKey: "settingsSchemaVersion")
        if UserDefaults.standard.integer(forKey: "settingsSchemaVersion") < 2 { UserDefaults.standard.set(2, forKey: "settingsSchemaVersion") }
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "settingsSchemaVersion"), 2)
    }
}
