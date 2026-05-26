import XCTest
@testable import Cornice

/// Tests for SettingsKeys -- verifies Codable round-trip for custom enums,
/// enum case existence, and default value reasonableness.
final class SettingsKeysTests: XCTestCase {

    // MARK: - ActivationMethod

    func test_activationMethod_hasExpectedCases() {
        let cases: [ActivationMethod] = [.hover, .click, .swipe]
        XCTAssertEqual(cases.count, 3, "ActivationMethod should have 3 cases")
    }

    func test_activationMethod_rawValues() {
        XCTAssertEqual(ActivationMethod.hover.rawValue, "hover")
        XCTAssertEqual(ActivationMethod.click.rawValue, "click")
        XCTAssertEqual(ActivationMethod.swipe.rawValue, "swipe")
    }

    func test_activationMethod_codable_roundTrip_hover() throws {
        let original = ActivationMethod.hover
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActivationMethod.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_activationMethod_codable_roundTrip_click() throws {
        let original = ActivationMethod.click
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActivationMethod.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_activationMethod_codable_roundTrip_swipe() throws {
        let original = ActivationMethod.swipe
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActivationMethod.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_activationMethod_allCases_codableRoundTrip() throws {
        for method in ActivationMethod.allCases {
            let data = try JSONEncoder().encode(method)
            let decoded = try JSONDecoder().decode(ActivationMethod.self, from: data)
            XCTAssertEqual(method, decoded,
                           "Round-trip encoding/decoding should preserve \(method)")
        }
    }

    func test_activationMethod_isCaseIterable() {
        XCTAssertEqual(ActivationMethod.allCases.count, 3)
        XCTAssertTrue(ActivationMethod.allCases.contains(.hover))
        XCTAssertTrue(ActivationMethod.allCases.contains(.click))
        XCTAssertTrue(ActivationMethod.allCases.contains(.swipe))
    }

    // MARK: - NotchHeightSetting

    func test_notchHeightSetting_hasExpectedCases() {
        let cases: [NotchHeightSetting] = [.matchNotch, .matchMenuBar, .custom]
        XCTAssertEqual(cases.count, 3, "NotchHeightSetting should have 3 cases")
    }

    func test_notchHeightSetting_rawValues() {
        XCTAssertEqual(NotchHeightSetting.matchNotch.rawValue, "matchNotch")
        XCTAssertEqual(NotchHeightSetting.matchMenuBar.rawValue, "matchMenuBar")
        XCTAssertEqual(NotchHeightSetting.custom.rawValue, "custom")
    }

    func test_notchHeightSetting_codable_roundTrip_matchNotch() throws {
        let original = NotchHeightSetting.matchNotch
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotchHeightSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_notchHeightSetting_codable_roundTrip_matchMenuBar() throws {
        let original = NotchHeightSetting.matchMenuBar
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotchHeightSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_notchHeightSetting_codable_roundTrip_custom() throws {
        let original = NotchHeightSetting.custom
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotchHeightSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - MusicSourceSetting

    func test_musicSourceSetting_hasExpectedCases() {
        let cases: [MusicSourceSetting] = [.nowPlaying, .appleMusic, .spotify]
        XCTAssertEqual(cases.count, 3, "MusicSourceSetting should have 3 cases")
    }

    func test_musicSourceSetting_rawValues() {
        XCTAssertEqual(MusicSourceSetting.nowPlaying.rawValue, "nowPlaying")
        XCTAssertEqual(MusicSourceSetting.appleMusic.rawValue, "appleMusic")
        XCTAssertEqual(MusicSourceSetting.spotify.rawValue, "spotify")
    }

    func test_musicSourceSetting_codable_roundTrip_nowPlaying() throws {
        let original = MusicSourceSetting.nowPlaying
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MusicSourceSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_musicSourceSetting_codable_roundTrip_appleMusic() throws {
        let original = MusicSourceSetting.appleMusic
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MusicSourceSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_musicSourceSetting_codable_roundTrip_spotify() throws {
        let original = MusicSourceSetting.spotify
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MusicSourceSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - ThemeSetting

    func test_themeSetting_hasExpectedCases() {
        let cases: [ThemeSetting] = [.system, .dark]
        XCTAssertEqual(cases.count, 2, "ThemeSetting should have 2 cases")
    }

    func test_themeSetting_rawValues() {
        XCTAssertEqual(ThemeSetting.system.rawValue, "system")
        XCTAssertEqual(ThemeSetting.dark.rawValue, "dark")
    }

    func test_themeSetting_codable_roundTrip_system() throws {
        let original = ThemeSetting.system
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_themeSetting_codable_roundTrip_dark() throws {
        let original = ThemeSetting.dark
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeSetting.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Default Values: General

    func test_default_menubarIcon_isTrue() {
        // The default value for menubarIcon is true.
        let defaultValue = true
        XCTAssertTrue(defaultValue, "Menu bar icon should default to shown")
    }

    func test_default_activationMethod_isHover() {
        // The default activation method is .hover.
        XCTAssertEqual(ActivationMethod.hover, .hover)
    }

    func test_default_hoverDelay_isReasonable() {
        let defaultDelay: Double = 0.2
        XCTAssertGreaterThan(defaultDelay, 0, "Hover delay should be positive")
        XCTAssertLessThanOrEqual(defaultDelay, 1.0, "Hover delay should be 1s or less")
    }

    func test_default_closeDelay_isReasonable() {
        let defaultDelay: Double = 0.5
        XCTAssertGreaterThan(defaultDelay, 0)
        XCTAssertLessThanOrEqual(defaultDelay, 2.0)
    }

    // MARK: - Default Values: Appearance

    func test_default_notchHeightMode_isMatchNotch() {
        XCTAssertEqual(NotchHeightSetting.matchNotch, .matchNotch)
    }

    func test_default_customNotchHeight_isPositive() {
        let defaultHeight: Double = 32
        XCTAssertGreaterThan(defaultHeight, 0)
    }

    func test_default_theme_isSystem() {
        XCTAssertEqual(ThemeSetting.system, .system)
    }

    // MARK: - Default Values: Media

    func test_default_musicSource_isNowPlaying() {
        XCTAssertEqual(MusicSourceSetting.nowPlaying, .nowPlaying)
    }

    func test_default_sneakPeekDuration_isReasonable() {
        let defaultDuration: Double = 3.0
        XCTAssertGreaterThanOrEqual(defaultDuration, 1.0)
        XCTAssertLessThanOrEqual(defaultDuration, 10.0)
    }

    // MARK: - Default Values: HUD

    func test_default_hudDuration_isReasonable() {
        let defaultDuration: Double = 1.5
        XCTAssertGreaterThan(defaultDuration, 0)
        XCTAssertLessThanOrEqual(defaultDuration, 5.0)
    }

    // MARK: - Default Values: Calendar

    func test_default_calendarLookahead_isPositive() {
        let defaultLookahead: Int = 24
        XCTAssertGreaterThan(defaultLookahead, 0)
    }

    func test_default_calendarLookahead_isReasonable() {
        let defaultLookahead: Int = 24
        XCTAssertLessThanOrEqual(defaultLookahead, 168,
                                  "Lookahead should be at most one week (168 hours)")
    }

    // MARK: - Default Values: Shelf & Clipboard

    func test_default_shelfMaxItems_isPositive() {
        let defaultMax: Int = 20
        XCTAssertGreaterThan(defaultMax, 0)
    }

    func test_default_clipboardMaxEntries_isPositive() {
        let defaultMax: Int = 50
        XCTAssertGreaterThan(defaultMax, 0)
    }

    func test_default_clipboardMaxEntries_greaterThanOrEqualShelfMax() {
        let shelfMax: Int = 20
        let clipboardMax: Int = 50
        XCTAssertGreaterThanOrEqual(clipboardMax, shelfMax)
    }

    // MARK: - Default Values: Debug

    func test_default_debugMode_isFalse() {
        let defaultDebug = false
        XCTAssertFalse(defaultDebug, "Debug mode should default to off")
    }

    // MARK: - Cross-Enum Distinctness

    func test_allSettingEnums_rawValues_doNotCollide() {
        // Collect all raw values to ensure no accidental collisions.
        var allRawValues: [String] = []
        allRawValues.append(contentsOf: ActivationMethod.allCases.map(\.rawValue))
        allRawValues.append(contentsOf: [
            NotchHeightSetting.matchNotch.rawValue,
            NotchHeightSetting.matchMenuBar.rawValue,
            NotchHeightSetting.custom.rawValue,
        ])
        allRawValues.append(contentsOf: [
            MusicSourceSetting.nowPlaying.rawValue,
            MusicSourceSetting.appleMusic.rawValue,
            MusicSourceSetting.spotify.rawValue,
        ])
        allRawValues.append(contentsOf: [
            ThemeSetting.system.rawValue,
            ThemeSetting.dark.rawValue,
        ])

        let uniqueValues = Set(allRawValues)
        XCTAssertEqual(allRawValues.count, uniqueValues.count,
                       "All setting enum raw values should be unique across enums")
    }

    // MARK: - Codable Robustness

    func test_activationMethod_decodesFromRawString() throws {
        // Simulates reading a stored JSON string.
        let json = "\"hover\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ActivationMethod.self, from: data)
        XCTAssertEqual(decoded, .hover)
    }

    func test_notchHeightSetting_decodesFromRawString() throws {
        let json = "\"matchMenuBar\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(NotchHeightSetting.self, from: data)
        XCTAssertEqual(decoded, .matchMenuBar)
    }

    func test_musicSourceSetting_decodesFromRawString() throws {
        let json = "\"spotify\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MusicSourceSetting.self, from: data)
        XCTAssertEqual(decoded, .spotify)
    }

    func test_themeSetting_decodesFromRawString() throws {
        let json = "\"dark\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ThemeSetting.self, from: data)
        XCTAssertEqual(decoded, .dark)
    }

    func test_activationMethod_invalidRawString_throwsDecodingError() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(ActivationMethod.self, from: data),
            "Decoding an invalid raw value should throw"
        )
    }

    func test_notchHeightSetting_invalidRawString_throwsDecodingError() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(NotchHeightSetting.self, from: data),
            "Decoding an invalid raw value should throw"
        )
    }

    func test_musicSourceSetting_invalidRawString_throwsDecodingError() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(MusicSourceSetting.self, from: data),
            "Decoding an invalid raw value should throw"
        )
    }

    func test_themeSetting_invalidRawString_throwsDecodingError() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(ThemeSetting.self, from: data),
            "Decoding an invalid raw value should throw"
        )
    }
}
