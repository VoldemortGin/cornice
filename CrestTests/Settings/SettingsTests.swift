import Testing
@testable import Crest

@Suite("Settings Tests")
struct SettingsTests {
    @Test("SettingsView initializes")
    func settingsViewInit() {
        _ = SettingsView()
    }
}
