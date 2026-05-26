import Testing
@testable import Niya

@Suite("Settings Tests")
struct SettingsTests {
    @Test("SettingsView initializes")
    func settingsViewInit() {
        _ = SettingsView()
    }
}
