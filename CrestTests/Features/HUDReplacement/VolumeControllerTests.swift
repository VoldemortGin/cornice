import XCTest
@testable import Niya

final class MockVolumeCtrl {
    private var _vol: Float = 0.5; private var _muted = false; private var preMute: Float = 0.5
    var volume: Float { get { _muted ? 0 : _vol } set { _vol = min(max(newValue, 0), 1) } }
    var isMuted: Bool { _muted }; var restoredVolume: Float { preMute }
    func stepUp(by s: Float) { guard !_muted else { return }; volume = _vol + s }
    func stepDown(by s: Float) { guard !_muted else { return }; volume = _vol - s }
    func toggleMute() { if _muted { _muted = false; _vol = preMute } else { preMute = _vol; _muted = true } }
}

final class VolumeControllerTests: XCTestCase {
    private var sut: MockVolumeCtrl!
    override func setUp() { super.setUp(); sut = MockVolumeCtrl() }

    func test_defaultVolume() { XCTAssertEqual(sut.volume, 0.5, accuracy: 0.001) }
    func test_setWithinRange() { sut.volume = 0.75; XCTAssertEqual(sut.volume, 0.75, accuracy: 0.001) }
    func test_clampAbove() { sut.volume = 1.5; XCTAssertEqual(sut.volume, 1.0, accuracy: 0.001) }
    func test_clampBelow() { sut.volume = -0.5; XCTAssertEqual(sut.volume, 0.0, accuracy: 0.001) }
    func test_standardStep() { XCTAssertEqual(Float(1.0/16.0), 0.0625, accuracy: 0.0001) }
    func test_fineStep() { XCTAssertEqual(Float(1.0/64.0), 0.015625, accuracy: 0.00001) }
    func test_stepUp() { sut.volume = 0.5; sut.stepUp(by: 1.0/16.0); XCTAssertEqual(sut.volume, 0.5625, accuracy: 0.001) }
    func test_stepDown() { sut.volume = 0.5; sut.stepDown(by: 1.0/16.0); XCTAssertEqual(sut.volume, 0.4375, accuracy: 0.001) }
    func test_stepUp_atMax() { sut.volume = 1.0; sut.stepUp(by: 1.0/16.0); XCTAssertEqual(sut.volume, 1.0, accuracy: 0.001) }
    func test_stepDown_atZero() { sut.volume = 0.0; sut.stepDown(by: 1.0/16.0); XCTAssertEqual(sut.volume, 0.0, accuracy: 0.001) }
    func test_16StepsToMax() { sut.volume = 0; for _ in 0..<16 { sut.stepUp(by: 1.0/16.0) }; XCTAssertEqual(sut.volume, 1.0, accuracy: 0.001) }
    func test_mute_zerosVolume() { sut.volume = 0.75; sut.toggleMute(); XCTAssertTrue(sut.isMuted); XCTAssertEqual(sut.volume, 0, accuracy: 0.001) }
    func test_unmute_restores() { sut.volume = 0.75; sut.toggleMute(); sut.toggleMute(); XCTAssertFalse(sut.isMuted); XCTAssertEqual(sut.volume, 0.75, accuracy: 0.001) }
    func test_stepWhileMuted_noop() { sut.volume = 0.5; sut.toggleMute(); sut.stepUp(by: 1.0/16.0); XCTAssertEqual(sut.volume, 0, accuracy: 0.001) }

    func test_icon_muted() { XCTAssertEqual(volIcon(0, true), "speaker.slash.fill") }
    func test_icon_low() { XCTAssertEqual(volIcon(0.2, false), "speaker.wave.1.fill") }
    func test_icon_mid() { XCTAssertEqual(volIcon(0.5, false), "speaker.wave.2.fill") }
    func test_icon_high() { XCTAssertEqual(volIcon(0.8, false), "speaker.wave.3.fill") }
    func test_icon_zero() { XCTAssertEqual(volIcon(0, false), "speaker.slash.fill") }

    private func volIcon(_ level: Double, _ muted: Bool) -> String {
        if muted || level <= 0 { "speaker.slash.fill" } else if level <= 0.33 { "speaker.wave.1.fill" } else if level <= 0.66 { "speaker.wave.2.fill" } else { "speaker.wave.3.fill" }
    }
}
