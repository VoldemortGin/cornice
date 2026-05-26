import XCTest
import Combine
@testable import Niya

final class MockMediaController: MediaControllerProtocol, @unchecked Sendable {
    private let stateSubject = PassthroughSubject<PlaybackState, Never>()
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { stateSubject.eraseToAnyPublisher() }
    private(set) var playCallCount = 0; private(set) var pauseCallCount = 0; private(set) var togglePlayCallCount = 0
    private(set) var nextTrackCallCount = 0; private(set) var previousTrackCallCount = 0
    private(set) var seekPosition: TimeInterval?; private(set) var volumeLevel: Float?
    private(set) var shuffleState: Bool?; private(set) var repeatModeSet: RepeatMode?
    var shouldThrow: MediaControllerError?
    func play() async throws { if let e = shouldThrow { throw e }; playCallCount += 1 }
    func pause() async throws { if let e = shouldThrow { throw e }; pauseCallCount += 1 }
    func togglePlay() async throws { if let e = shouldThrow { throw e }; togglePlayCallCount += 1 }
    func nextTrack() async throws { if let e = shouldThrow { throw e }; nextTrackCallCount += 1 }
    func previousTrack() async throws { if let e = shouldThrow { throw e }; previousTrackCallCount += 1 }
    func seek(to position: TimeInterval) async throws { if let e = shouldThrow { throw e }; seekPosition = position }
    func setVolume(_ level: Float) async throws { if let e = shouldThrow { throw e }; volumeLevel = level }
    func setShuffle(_ enabled: Bool) async throws { if let e = shouldThrow { throw e }; shuffleState = enabled }
    func setRepeatMode(_ mode: RepeatMode) async throws { if let e = shouldThrow { throw e }; repeatModeSet = mode }
    func emit(_ state: PlaybackState) { stateSubject.send(state) }
}

extension PlaybackState {
    static func stub(title: String = "Song", artist: String = "Artist", album: String? = "Album", artworkData: Data? = nil, duration: TimeInterval = 240, elapsedTime: TimeInterval = 60, playbackRate: Double = 1.0, shuffleEnabled: Bool? = nil, repeatMode: RepeatMode? = nil) -> PlaybackState {
        PlaybackState(title: title, artist: artist, album: album, artworkData: artworkData, duration: duration, elapsedTime: elapsedTime, playbackRate: playbackRate, shuffleEnabled: shuffleEnabled, repeatMode: repeatMode)
    }
}

@MainActor
final class MusicManagerTests: XCTestCase {
    private var sut: MusicManager!
    private var mock: MockMediaController!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() { super.setUp(); mock = MockMediaController(); sut = MusicManager(); cancellables = [] }
    override func tearDown() { cancellables = nil; sut = nil; mock = nil; super.tearDown() }

    func test_setController_updatesSongTitle() {
        sut.setController(mock); let e = expectation(description: "t")
        sut.$songTitle.dropFirst().sink { XCTAssertEqual($0, "Bohemian Rhapsody"); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(title: "Bohemian Rhapsody")); waitForExpectations(timeout: 2)
    }
    func test_setController_updatesArtist() {
        sut.setController(mock); let e = expectation(description: "a")
        sut.$artistName.dropFirst().sink { XCTAssertEqual($0, "Queen"); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(artist: "Queen")); waitForExpectations(timeout: 2)
    }
    func test_setController_updatesAlbum() {
        sut.setController(mock); let e = expectation(description: "al")
        sut.$albumName.dropFirst().sink { XCTAssertEqual($0, "IV"); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(album: "IV")); waitForExpectations(timeout: 2)
    }
    func test_setController_updatesDuration() {
        sut.setController(mock); let e = expectation(description: "d")
        sut.$duration.dropFirst().sink { XCTAssertEqual($0, 355, accuracy: 0.01); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(duration: 355)); waitForExpectations(timeout: 2)
    }
    func test_setController_updatesElapsed() {
        sut.setController(mock); let e = expectation(description: "el")
        sut.$elapsed.dropFirst().sink { XCTAssertEqual($0, 120, accuracy: 0.01); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(elapsedTime: 120)); waitForExpectations(timeout: 2)
    }
    func test_playbackRate0_isPlayingFalse() {
        sut.setController(mock); let e = expectation(description: "p")
        sut.$isPlaying.dropFirst().sink { XCTAssertFalse($0); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(playbackRate: 0)); waitForExpectations(timeout: 2)
    }
    func test_playbackRate1_isPlayingTrue() {
        sut.setController(mock); let e = expectation(description: "p")
        sut.$isPlaying.dropFirst().sink { XCTAssertTrue($0); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(playbackRate: 1)); waitForExpectations(timeout: 2)
    }
    func test_shuffle_updates() {
        sut.setController(mock); let e = expectation(description: "s")
        sut.$shuffleEnabled.dropFirst().sink { XCTAssertTrue($0); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(shuffleEnabled: true)); waitForExpectations(timeout: 2)
    }
    func test_repeatMode_updates() {
        sut.setController(mock); let e = expectation(description: "r")
        sut.$repeatMode.dropFirst().sink { XCTAssertEqual($0, .one); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(repeatMode: .one)); waitForExpectations(timeout: 2)
    }
    func test_artwork_loadsImage() {
        sut.setController(mock); let png = makeMinPNG(); let e = expectation(description: "img")
        sut.$albumArt.dropFirst().sink { XCTAssertNotNil($0); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(artworkData: png)); waitForExpectations(timeout: 2)
    }
    func test_nilArtwork_albumArtNil() {
        sut.setController(mock); let e = expectation(description: "nil")
        sut.$albumArt.dropFirst().sink { XCTAssertNil($0); e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(artworkData: nil)); waitForExpectations(timeout: 2)
    }
    func test_artworkColor_extracted() {
        sut.setController(mock); let e = expectation(description: "c")
        sut.$dominantColor.dropFirst().sink { _ in e.fulfill() }.store(in: &cancellables)
        mock.emit(.stub(artworkData: makeMinPNG())); waitForExpectations(timeout: 2)
    }
    func test_trackChange_sneakPeek() {
        sut.setController(mock); mock.emit(.stub(title: "A", artist: "X"))
        let e = expectation(description: "sp")
        NotificationCenter.default.addObserver(forName: .niyaSneakPeekTriggered, object: nil, queue: .main) { _ in e.fulfill() }
        mock.emit(.stub(title: "B", artist: "Y")); waitForExpectations(timeout: 3)
    }
    func test_sameTrack_noSneakPeek() {
        sut.setController(mock); mock.emit(.stub(title: "A", artist: "X"))
        let e = expectation(description: "no sp"); e.isInverted = true
        NotificationCenter.default.addObserver(forName: .niyaSneakPeekTriggered, object: nil, queue: .main) { _ in e.fulfill() }
        mock.emit(.stub(title: "A", artist: "X", elapsedTime: 90)); waitForExpectations(timeout: 1)
    }
    func test_switchController_usesNew() {
        let c1 = MockMediaController(); let c2 = MockMediaController()
        sut.setController(c1); let e1 = expectation(description: "c1")
        sut.$songTitle.dropFirst().first().sink { XCTAssertEqual($0, "C1"); e1.fulfill() }.store(in: &cancellables)
        c1.emit(.stub(title: "C1")); waitForExpectations(timeout: 2)
        sut.setController(c2); let e2 = expectation(description: "c2")
        sut.$songTitle.dropFirst().first().sink { XCTAssertEqual($0, "C2"); e2.fulfill() }.store(in: &cancellables)
        c2.emit(.stub(title: "C2")); waitForExpectations(timeout: 2)
    }
    func test_oldController_ignored() {
        let c1 = MockMediaController(); let c2 = MockMediaController()
        sut.setController(c1); sut.setController(c2)
        let e = expectation(description: "ign"); e.isInverted = true
        sut.$songTitle.dropFirst().filter { $0 == "Ghost" }.sink { _ in e.fulfill() }.store(in: &cancellables)
        c1.emit(.stub(title: "Ghost")); waitForExpectations(timeout: 1)
    }
    private func makeMinPNG() -> Data {
        let img = NSImage(size: NSSize(width: 2, height: 2)); img.lockFocus(); NSColor.red.setFill(); NSRect(origin: .zero, size: img.size).fill(); img.unlockFocus()
        guard let t = img.tiffRepresentation, let b = NSBitmapImageRep(data: t), let p = b.representation(using: .png, properties: [:]) else { return Data() }; return p
    }
}

extension Notification.Name { static let niyaSneakPeekTriggered = Notification.Name("niyaSneakPeekTriggered") }
