import XCTest
import Combine
@testable import Crest

/// Tests for HUD display logic using the production model types directly.
/// Since HUDViewModel relies on hardware interceptors, we test the model/icon logic.
final class HUDManagerTests: XCTestCase {

    // MARK: - HUDState Tests

    func test_volumeState_creation() {
        let state = HUDState(type: .volume, value: 0.75, isMuted: false, isVisible: true)
        XCTAssertEqual(state.type, .volume)
        XCTAssertEqual(state.value, 0.75, accuracy: 0.001)
        XCTAssertFalse(state.isMuted)
    }

    func test_brightnessState_creation() {
        let state = HUDState(type: .brightness, value: 0.6, isMuted: false, isVisible: true)
        XCTAssertEqual(state.type, .brightness)
    }

    func test_keyboardBrightness_creation() {
        let state = HUDState(type: .keyboardBrightness, value: 0.4, isMuted: false, isVisible: true)
        XCTAssertEqual(state.type, .keyboardBrightness)
    }

    func test_muteState_creation() {
        let state = HUDState(type: .mute, value: 0, isMuted: true, isVisible: true)
        XCTAssertTrue(state.isMuted)
        XCTAssertEqual(state.value, 0, accuracy: 0.001)
    }

    // MARK: - VolumeIcon Tests

    func test_icon_volumeMuted() {
        XCTAssertEqual(VolumeIcon.forLevel(0, muted: true).systemName, "speaker.slash.fill")
    }
    func test_icon_volumeLow() {
        XCTAssertEqual(VolumeIcon.forLevel(0.2, muted: false).systemName, "speaker.wave.1.fill")
    }
    func test_icon_volumeMid() {
        XCTAssertEqual(VolumeIcon.forLevel(0.5, muted: false).systemName, "speaker.wave.2.fill")
    }
    func test_icon_volumeHigh() {
        XCTAssertEqual(VolumeIcon.forLevel(0.8, muted: false).systemName, "speaker.wave.3.fill")
    }
    func test_icon_volumeZero_showsMuted() {
        XCTAssertEqual(VolumeIcon.forLevel(0, muted: false).systemName, "speaker.slash.fill")
    }

    // MARK: - BrightnessIcon Tests

    func test_icon_brightnessLow() {
        XCTAssertEqual(BrightnessIcon.forLevel(0.3).systemName, "sun.min.fill")
    }
    func test_icon_brightnessHigh() {
        XCTAssertEqual(BrightnessIcon.forLevel(0.7).systemName, "sun.max.fill")
    }
    func test_icon_brightnessBoundary() {
        XCTAssertEqual(BrightnessIcon.forLevel(0.5).systemName, "sun.min.fill")
        XCTAssertEqual(BrightnessIcon.forLevel(0.51).systemName, "sun.max.fill")
    }

    // MARK: - HUDType Equality

    func test_hudType_equality() {
        XCTAssertEqual(HUDType.volume, HUDType.volume)
        XCTAssertNotEqual(HUDType.volume, HUDType.brightness)
        XCTAssertNotEqual(HUDType.brightness, HUDType.keyboardBrightness)
    }

    func test_switchType() {
        var state = HUDState(type: .volume, value: 0.5, isMuted: false, isVisible: true)
        state = HUDState(type: .brightness, value: 0.7, isMuted: false, isVisible: true)
        XCTAssertEqual(state.type, .brightness)
    }

    // MARK: - HIDKeyEvent Tests

    func test_stepSize_normal() {
        let event = HIDKeyEvent(keyCode: .soundUp, isKeyDown: true, isRepeat: false, hasOption: false, hasShift: false)
        XCTAssertEqual(event.stepSize, 1.0 / 16.0, accuracy: 0.001)
    }

    func test_stepSize_fineAdjustment() {
        let event = HIDKeyEvent(keyCode: .soundUp, isKeyDown: true, isRepeat: false, hasOption: true, hasShift: true)
        XCTAssertEqual(event.stepSize, 1.0 / 64.0, accuracy: 0.001)
        XCTAssertTrue(event.isFineAdjustment)
    }

    func test_shouldOpenSettings() {
        let event = HIDKeyEvent(keyCode: .soundUp, isKeyDown: true, isRepeat: false, hasOption: true, hasShift: false)
        XCTAssertTrue(event.shouldOpenSettings)
    }
}
