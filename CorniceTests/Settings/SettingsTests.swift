import Testing
@testable import Cornice

@Suite("Settings Tests")
struct SettingsTests {
    @Test("SettingsView initializes")
    func settingsViewInit() {
        _ = SettingsView()
    }
}
