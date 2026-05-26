import AppKit
import Combine

// MARK: - Now Playing Info

struct NowPlayingInfo: Equatable, Sendable {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artworkData: Data?
    var duration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var playbackRate: Double = 0

    var isPlaying: Bool { playbackRate > 0 }

    var artworkImage: NSImage? {
        guard let data = artworkData else { return nil }
        return NSImage(data: data)
    }
}

// MARK: - Playback Command

enum PlaybackCommand: Sendable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seek(TimeInterval)
}

// MARK: - Music Source

enum MusicSource: String, Codable, CaseIterable, Sendable {
    case nowPlaying
    case appleMusic
    case spotify
}

// MARK: - Playback State

struct PlaybackState: Equatable, Sendable {
    var isPlaying: Bool = false
    var shuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off
}

// MARK: - Repeat Mode

enum RepeatMode: Int, Codable, Sendable {
    case off = 0
    case all = 1
    case one = 2

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

// MARK: - Media Controller Error

enum MediaControllerError: Error, LocalizedError {
    case unsupported
    case connectionLost
    case appNotRunning(String)
    case frameworkNotAvailable

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "This control is not supported by the current media source."
        case .connectionLost:
            return "Lost connection to the media source."
        case .appNotRunning(let app):
            return "\(app) is not running."
        case .frameworkNotAvailable:
            return "MediaRemote framework is not available."
        }
    }
}
