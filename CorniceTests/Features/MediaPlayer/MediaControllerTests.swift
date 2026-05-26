import XCTest
import Combine
@testable import Cornice

struct NowPlayingStreamState: Codable {
    let title: String; let artist: String; let album: String?; let artworkData: String?
    let duration: Double; let elapsedTime: Double; let playbackRate: Double; let timestamp: Double
}

final class NowPlayingControllerTests: XCTestCase {
    func test_parseJSON_valid() throws {
        let j = #"{"title":"S","artist":"A","album":"X","artworkData":null,"duration":482,"elapsedTime":123,"playbackRate":1,"timestamp":0}"#
        let s = try JSONDecoder().decode(NowPlayingStreamState.self, from: Data(j.utf8))
        XCTAssertEqual(s.title, "S"); XCTAssertEqual(s.duration, 482, accuracy: 0.01)
    }
    func test_parseJSON_nullOptionals() throws {
        let j = #"{"title":"X","artist":"Y","album":null,"artworkData":null,"duration":0,"elapsedTime":0,"playbackRate":0,"timestamp":0}"#
        let s = try JSONDecoder().decode(NowPlayingStreamState.self, from: Data(j.utf8))
        XCTAssertNil(s.album)
    }
    func test_parseJSON_invalid_throws() { XCTAssertThrowsError(try JSONDecoder().decode(NowPlayingStreamState.self, from: Data("bad".utf8))) }
    func test_parseJSON_missingField_throws() {
        let j = #"{"artist":"Y","album":null,"artworkData":null,"duration":0,"elapsedTime":0,"playbackRate":0,"timestamp":0}"#
        XCTAssertThrowsError(try JSONDecoder().decode(NowPlayingStreamState.self, from: Data(j.utf8)))
    }
    func test_playbackRate_0_notPlaying() {
        let info = NowPlayingInfo(title: "T", artist: "A", album: "Al", artworkData: nil, duration: 240, elapsedTime: 60, playbackRate: 0)
        XCTAssertFalse(info.isPlaying)
    }
    func test_playbackRate_1_playing() {
        let info = NowPlayingInfo(title: "T", artist: "A", album: "Al", artworkData: nil, duration: 240, elapsedTime: 60, playbackRate: 1)
        XCTAssertTrue(info.isPlaying)
    }
    func test_artworkDecode_valid() { XCTAssertNotNil(Data(base64Encoded: Data([0x89]).base64EncodedString())) }
    func test_artworkDecode_invalid() { XCTAssertNil(Data(base64Encoded: "!!!")) }
}

final class MediaControllerCommandTests: XCTestCase {
    private var m: MockMediaController!
    override func setUp() { super.setUp(); m = MockMediaController() }
    func test_play() async throws { try await m.play(); XCTAssertEqual(m.playCallCount, 1) }
    func test_pause() async throws { try await m.pause(); XCTAssertEqual(m.pauseCallCount, 1) }
    func test_toggle() async throws { try await m.togglePlay(); XCTAssertEqual(m.togglePlayCallCount, 1) }
    func test_next() async throws { try await m.nextTrack(); XCTAssertEqual(m.nextTrackCallCount, 1) }
    func test_prev() async throws { try await m.previousTrack(); XCTAssertEqual(m.previousTrackCallCount, 1) }
    func test_seek() async throws { try await m.seek(to: 90.5); XCTAssertEqual(m.seekPosition, 90.5) }
    func test_volume() async throws { try await m.setVolume(0.75); XCTAssertEqual(m.volumeLevel, 0.75) }
    func test_unsupported() async {
        m.shouldThrow = .unsupported
        do {
            try await m.play()
            XCTFail()
        } catch let e as MediaControllerError {
            switch e {
            case .unsupported: break // expected
            default: XCTFail("Expected .unsupported, got \(e)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

final class RepeatModeTests: XCTestCase {
    func test_rawValues() { XCTAssertEqual(RepeatMode.off.rawValue, 0); XCTAssertEqual(RepeatMode.all.rawValue, 1); XCTAssertEqual(RepeatMode.one.rawValue, 2) }
    func test_cycle() { XCTAssertEqual(RepeatMode.off.next, .all); XCTAssertEqual(RepeatMode.all.next, .one); XCTAssertEqual(RepeatMode.one.next, .off) }
}
