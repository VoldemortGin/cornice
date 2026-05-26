import AppKit
import Combine

// MARK: - Media Controlling Protocol

protocol MediaControlling: AnyObject, Sendable {
    var nowPlayingInfo: NowPlayingInfo? { get }
    var playbackStatePublisher: AnyPublisher<NowPlayingInfo, Never> { get }
    func sendCommand(_ command: PlaybackCommand) async
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - MediaRemote Function Types

private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
) -> Void

private typealias MRMediaRemoteSendCommandFn = @convention(c) (
    UInt32,
    UnsafeRawPointer?
) -> Bool

private typealias MRMediaRemoteRegisterNotificationsFn = @convention(c) (
    DispatchQueue
) -> Void

// MARK: - MediaRemote Command Codes

private enum MRCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
}

// MARK: - MediaRemote Info Keys

private enum MRInfoKey {
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
}

// MARK: - Now Playing Controller

final class NowPlayingController: MediaControlling, @unchecked Sendable {
    private let playbackSubject = PassthroughSubject<NowPlayingInfo, Never>()
    private var _nowPlayingInfo: NowPlayingInfo?
    private let lock = NSLock()

    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFn?
    private var sendCommandFn: MRMediaRemoteSendCommandFn?
    private var registerNotifications: MRMediaRemoteRegisterNotificationsFn?
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var isMonitoring = false

    var nowPlayingInfo: NowPlayingInfo? {
        lock.lock()
        defer { lock.unlock() }
        return _nowPlayingInfo
    }

    var playbackStatePublisher: AnyPublisher<NowPlayingInfo, Never> {
        playbackSubject.eraseToAnyPublisher()
    }

    init() {
        loadFramework()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Framework Loading

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            Log.media.warning("Failed to load MediaRemote framework")
            return
        }
        frameworkHandle = handle

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFn.self)
        }

        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommandFn = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFn.self)
        }

        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerNotifications = unsafeBitCast(sym, to: MRMediaRemoteRegisterNotificationsFn.self)
        }

        Log.media.info("MediaRemote framework loaded successfully")
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        registerNotifications?(DispatchQueue.main)

        let notificationNames = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ]

        for name in notificationNames {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(nowPlayingInfoDidChange),
                name: Notification.Name(name),
                object: nil
            )
        }

        // Also observe via DistributedNotificationCenter for cross-process notifications
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(nowPlayingInfoDidChange),
            name: Notification.Name("com.apple.nowPlayingInfoDidChange"),
            object: nil
        )

        // Fetch initial state
        fetchNowPlayingInfo()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Commands

    func sendCommand(_ command: PlaybackCommand) async {
        guard let sendFn = sendCommandFn else {
            Log.media.warning("MRMediaRemoteSendCommand not available")
            return
        }

        let mrCommand: MRCommand
        switch command {
        case .play:
            mrCommand = .play
        case .pause:
            mrCommand = .pause
        case .togglePlayPause:
            mrCommand = .togglePlayPause
        case .nextTrack:
            mrCommand = .nextTrack
        case .previousTrack:
            mrCommand = .previousTrack
        case .seek:
            // Seek requires a different API path; not directly supported via basic send command
            Log.media.info("Seek command not supported via MRMediaRemoteSendCommand")
            return
        }

        _ = sendFn(mrCommand.rawValue, nil)

        // Refresh state after command
        try? await Task.sleep(for: .milliseconds(300))
        fetchNowPlayingInfo()
    }

    // MARK: - Info Fetching

    @objc private func nowPlayingInfoDidChange(_ notification: Notification? = nil) {
        fetchNowPlayingInfo()
    }

    private func fetchNowPlayingInfo() {
        guard let getInfo = getNowPlayingInfo else { return }

        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            let parsed = self.parseInfo(info)

            self.lock.lock()
            self._nowPlayingInfo = parsed
            self.lock.unlock()

            self.playbackSubject.send(parsed)
        }
    }

    private func parseInfo(_ dict: [String: Any]) -> NowPlayingInfo {
        NowPlayingInfo(
            title: dict[MRInfoKey.title] as? String ?? "",
            artist: dict[MRInfoKey.artist] as? String ?? "",
            album: dict[MRInfoKey.album] as? String ?? "",
            artworkData: dict[MRInfoKey.artworkData] as? Data,
            duration: dict[MRInfoKey.duration] as? TimeInterval ?? 0,
            elapsedTime: dict[MRInfoKey.elapsedTime] as? TimeInterval ?? 0,
            playbackRate: dict[MRInfoKey.playbackRate] as? Double ?? 0
        )
    }
}
