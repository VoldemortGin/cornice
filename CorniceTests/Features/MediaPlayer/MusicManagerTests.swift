import XCTest
import Combine
@testable import Cornice

/// Mock implementation of MediaControlling for testing.
final class MockMediaController: MediaControlling, @unchecked Sendable {
    private let infoSubject = PassthroughSubject<NowPlayingInfo, Never>()
    var nowPlayingInfo: NowPlayingInfo?
    var playbackStatePublisher: AnyPublisher<NowPlayingInfo, Never> { infoSubject.eraseToAnyPublisher() }
    private(set) var playCallCount = 0; private(set) var pauseCallCount = 0; private(set) var togglePlayCallCount = 0
    private(set) var nextTrackCallCount = 0; private(set) var previousTrackCallCount = 0
    private(set) var seekPosition: TimeInterval?; private(set) var volumeLevel: Float?
    private(set) var shuffleState: Bool?; private(set) var repeatModeSet: RepeatMode?
    var shouldThrow: MediaControllerError?
    private var isMonitoring = false

    func play() async throws { if let e = shouldThrow { throw e }; playCallCount += 1 }
    func pause() async throws { if let e = shouldThrow { throw e }; pauseCallCount += 1 }
    func togglePlay() async throws { if let e = shouldThrow { throw e }; togglePlayCallCount += 1 }
    func nextTrack() async throws { if let e = shouldThrow { throw e }; nextTrackCallCount += 1 }
    func previousTrack() async throws { if let e = shouldThrow { throw e }; previousTrackCallCount += 1 }
    func seek(to position: TimeInterval) async throws { if let e = shouldThrow { throw e }; seekPosition = position }
    func setVolume(_ level: Float) async throws { if let e = shouldThrow { throw e }; volumeLevel = level }
    func setShuffle(_ enabled: Bool) async throws { if let e = shouldThrow { throw e }; shuffleState = enabled }
    func setRepeatMode(_ mode: RepeatMode) async throws { if let e = shouldThrow { throw e }; repeatModeSet = mode }

    func sendCommand(_ command: PlaybackCommand) async {
        switch command {
        case .play: playCallCount += 1
        case .pause: pauseCallCount += 1
        case .togglePlayPause: togglePlayCallCount += 1
        case .nextTrack: nextTrackCallCount += 1
        case .previousTrack: previousTrackCallCount += 1
        case .seek(let pos): seekPosition = pos
        }
    }

    func startMonitoring() { isMonitoring = true }
    func stopMonitoring() { isMonitoring = false }

    func emit(_ info: NowPlayingInfo) { infoSubject.send(info) }
}

extension NowPlayingInfo {
    static func stub(title: String = "Song", artist: String = "Artist", album: String = "Album", artworkData: Data? = nil, duration: TimeInterval = 240, elapsedTime: TimeInterval = 60, playbackRate: Double = 1.0) -> NowPlayingInfo {
        NowPlayingInfo(title: title, artist: artist, album: album, artworkData: artworkData, duration: duration, elapsedTime: elapsedTime, playbackRate: playbackRate)
    }
}

@MainActor
final class MediaPlayerViewModelTests: XCTestCase {
    private var sut: MediaPlayerViewModel!
    private var mock: MockMediaController!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() { super.setUp(); mock = MockMediaController(); sut = MediaPlayerViewModel(controller: mock); cancellables = [] }
    override func tearDown() { cancellables = nil; sut?.cleanup(); sut = nil; mock = nil; super.tearDown() }

    func test_setController_updatesDuration() {
        let e = expectation(description: "d")
        e.isInverted = false
        // Emit and check duration updates
        mock.emit(.stub(duration: 355))
        // Give the main run loop a tick to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.sut.duration, 355, accuracy: 0.01)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_setController_updatesElapsed() {
        let e = expectation(description: "el")
        mock.emit(.stub(elapsedTime: 120))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.sut.elapsed, 120, accuracy: 0.01)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_playbackRate0_isPlayingFalse() {
        let e = expectation(description: "p")
        mock.emit(.stub(playbackRate: 0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(self.sut.isPlaying)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_playbackRate1_isPlayingTrue() {
        let e = expectation(description: "p")
        mock.emit(.stub(playbackRate: 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.sut.isPlaying)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_nilArtwork_currentTrackHasNilArtwork() {
        let e = expectation(description: "nil")
        mock.emit(.stub(artworkData: nil))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNil(self.sut.currentTrack?.artworkData)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_progress_computedCorrectly() {
        let e = expectation(description: "progress")
        mock.emit(.stub(duration: 200, elapsedTime: 100, playbackRate: 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.sut.progress, 0.5, accuracy: 0.01)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_formatTime() {
        mock.emit(.stub(duration: 185, elapsedTime: 65, playbackRate: 1))
        let e = expectation(description: "fmt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.sut.elapsedFormatted, "1:05")
            XCTAssertEqual(self.sut.durationFormatted, "3:05")
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }
}
