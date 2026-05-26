import SwiftUI
import Combine
import AppKit

@MainActor
@Observable
final class MediaPlayerViewModel {
    // MARK: - Published State

    private(set) var currentTrack: NowPlayingInfo?
    private(set) var isPlaying: Bool = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var dominantColor: Color = .accentColor
    private(set) var playbackState: PlaybackState = PlaybackState()

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }

    var elapsedFormatted: String { formatTime(elapsed) }
    var durationFormatted: String { formatTime(duration) }

    // MARK: - Private

    private let controller: MediaControlling

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var elapsedTimer: Timer?

    @ObservationIgnored
    private var lastTrackTitle: String = ""

    @ObservationIgnored
    private var lastTrackArtist: String = ""

    // MARK: - Init

    init(controller: MediaControlling = NowPlayingController()) {
        self.controller = controller
        setupBindings()
        controller.startMonitoring()
    }

    // MARK: - Bindings

    private func setupBindings() {
        controller.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.handleInfoUpdate(info)
            }
            .store(in: &cancellables)
    }

    private func handleInfoUpdate(_ info: NowPlayingInfo) {
        let trackChanged = info.title != lastTrackTitle || info.artist != lastTrackArtist

        currentTrack = info
        isPlaying = info.isPlaying
        elapsed = info.elapsedTime
        duration = info.duration

        if trackChanged && !info.title.isEmpty {
            lastTrackTitle = info.title
            lastTrackArtist = info.artist
            extractDominantColor(from: info.artworkData)
            triggerSneakPeekForTrackChange(title: info.title, artist: info.artist)
        }

        updateElapsedTimer()
    }

    // MARK: - Timer

    private func updateElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        guard isPlaying else { return }

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.elapsed = min(self.elapsed + 1.0, self.duration)
            }
        }
    }

    // MARK: - Controls

    func togglePlayback() {
        Task {
            await controller.sendCommand(.togglePlayPause)
        }
    }

    func nextTrack() {
        Task {
            await controller.sendCommand(.nextTrack)
        }
    }

    func previousTrack() {
        Task {
            await controller.sendCommand(.previousTrack)
        }
    }

    func seek(to position: TimeInterval) {
        elapsed = position
        Task {
            await controller.sendCommand(.seek(position))
        }
    }

    func seekToProgress(_ progress: Double) {
        let position = progress * duration
        seek(to: position)
    }

    // MARK: - Color Extraction

    private func extractDominantColor(from imageData: Data?) {
        guard let imageData, let image = NSImage(data: imageData) else {
            dominantColor = .accentColor
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            dominantColor = .accentColor
            return
        }

        // Downscale to 40x40 for fast color sampling
        let sampleSize = 40
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            dominantColor = .accentColor
            return
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        guard let pixelBuffer = context.data else {
            dominantColor = .accentColor
            return
        }

        let pixels = pixelBuffer.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var totalWeight: Double = 0

        for i in 0..<(sampleSize * sampleSize) {
            let offset = i * 4
            let r = Double(pixels[offset]) / 255.0
            let g = Double(pixels[offset + 1]) / 255.0
            let b = Double(pixels[offset + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
            let brightness = maxC

            // Weight by saturation * brightness to favor vivid colors
            let weight = saturation * brightness
            guard weight > 0.1 else { continue }

            totalR += r * weight
            totalG += g * weight
            totalB += b * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            dominantColor = .accentColor
            return
        }

        let avgR = totalR / totalWeight
        let avgG = totalG / totalWeight
        let avgB = totalB / totalWeight

        // Ensure minimum luminance for visibility against dark background
        let luminance = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB
        let factor = luminance < 0.25 ? 1.3 : 1.0

        dominantColor = Color(
            nsColor: NSColor(
                red: min(avgR * factor, 1.0),
                green: min(avgG * factor, 1.0),
                blue: min(avgB * factor, 1.0),
                alpha: 1.0
            )
        )
    }

    // MARK: - Sneak Peek

    private func triggerSneakPeekForTrackChange(title: String, artist: String) {
        let event = SneakPeekEvent.trackChange(title: title, artist: artist)
        let coordinator = ViewCoordinator.shared
        for (_, vm) in coordinator.viewModels {
            vm.showSneakPeek(event)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    func cleanup() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        cancellables.removeAll()
        controller.stopMonitoring()
    }
}
