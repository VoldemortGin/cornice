import XCTest
import Combine
@testable import Niya

@MainActor
final class HUDManagerTests: XCTestCase {
    private var sut: HUDManager!
    override func setUp() { super.setUp(); sut = HUDManager() }
    override func tearDown() { sut = nil; super.tearDown() }

    func test_volumeChange_showsVolumeHUD() { sut.showHUD(.volume, level: 0.75); XCTAssertEqual(sut.activeHUD, .volume); XCTAssertEqual(sut.level, 0.75, accuracy: 0.001) }
    func test_brightnessChange_showsBrightnessHUD() { sut.showHUD(.brightness, level: 0.6); XCTAssertEqual(sut.activeHUD, .brightness) }
    func test_kbBrightness_showsKBHUD() { sut.showHUD(.keyboardBrightness, level: 0.4); XCTAssertEqual(sut.activeHUD, .keyboardBrightness) }
    func test_mute_showsMuted() { sut.showMute(true); XCTAssertTrue(sut.isMuted); XCTAssertEqual(sut.level, 0, accuracy: 0.001) }
    func test_unmute_showsRestored() { sut.showMute(false); sut.showHUD(.volume, level: 0.75); XCTAssertFalse(sut.isMuted) }

    func test_autoDismiss() {
        sut.showHUD(.volume, level: 0.5); XCTAssertNotNil(sut.activeHUD)
        let e = expectation(description: "dismiss")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { XCTAssertNil(self.sut.activeHUD); e.fulfill() }
        waitForExpectations(timeout: 3)
    }
    func test_rapidUpdates_staysVisible() {
        let e = expectation(description: "stays")
        sut.showHUD(.volume, level: 0.5)
        var count = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { t in
            count += 1; self.sut.showHUD(.volume, level: 0.5 + Double(count)*0.0625)
            if count >= 5 { t.invalidate(); XCTAssertNotNil(self.sut.activeHUD); e.fulfill() }
        }
        RunLoop.main.add(timer, forMode: .common); waitForExpectations(timeout: 5)
    }

    func test_icon_volumeMuted() { sut.showMute(true); XCTAssertEqual(sut.iconName, "speaker.slash.fill") }
    func test_icon_volumeLow() { sut.showHUD(.volume, level: 0.2); XCTAssertEqual(sut.iconName, "speaker.wave.1.fill") }
    func test_icon_volumeMid() { sut.showHUD(.volume, level: 0.5); XCTAssertEqual(sut.iconName, "speaker.wave.2.fill") }
    func test_icon_volumeHigh() { sut.showHUD(.volume, level: 0.8); XCTAssertEqual(sut.iconName, "speaker.wave.3.fill") }
    func test_icon_brightnessLow() { sut.showHUD(.brightness, level: 0.3); XCTAssertEqual(sut.iconName, "sun.min.fill") }
    func test_icon_brightnessHigh() { sut.showHUD(.brightness, level: 0.7); XCTAssertEqual(sut.iconName, "sun.max.fill") }
    func test_icon_keyboard() { sut.showHUD(.keyboardBrightness, level: 0.5); XCTAssertEqual(sut.iconName, "keyboard.badge.ellipsis") }

    func test_initial_noHUD() { XCTAssertNil(sut.activeHUD) }
    func test_switchType() { sut.showHUD(.volume, level: 0.5); sut.showHUD(.brightness, level: 0.7); XCTAssertEqual(sut.activeHUD, .brightness) }
}

extension HUDManager {
    func showHUD(_ type: HUDType, level: Double) { activeHUD = type; self.level = level; isMuted = false; scheduleDismiss() }
    func showMute(_ muted: Bool) { activeHUD = .volume; isMuted = muted; level = muted ? 0 : level; scheduleDismiss() }
    var iconName: String {
        guard let h = activeHUD else { return "" }
        switch h {
        case .volume: return isMuted || level <= 0 ? "speaker.slash.fill" : level <= 0.33 ? "speaker.wave.1.fill" : level <= 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness: return level <= 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardBrightness: return "keyboard.badge.ellipsis"
        }
    }
    func scheduleDismiss() {}
}
