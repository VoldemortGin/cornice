import SwiftUI

// MARK: - Compact Media View (Open State)

struct CompactMediaView: View {
    let viewModel: MediaPlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Album Art
            albumArt(size: 60)

            VStack(alignment: .leading, spacing: 4) {
                // Track Info
                Text(viewModel.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(viewModel.currentTrack?.artist ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                // Progress Bar
                ProgressBarView(
                    progress: viewModel.progress,
                    elapsedText: viewModel.elapsedFormatted,
                    durationText: viewModel.durationFormatted,
                    tintColor: viewModel.dominantColor,
                    onSeek: { viewModel.seekToProgress($0) }
                )

                // Controls
                HStack(spacing: 20) {
                    Button(action: { viewModel.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }

                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                    }

                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                }
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.dominantColor.opacity(0.15))
        )
    }

    @ViewBuilder
    private func albumArt(size: CGFloat) -> some View {
        if let image = viewModel.currentTrack?.artworkImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white.opacity(0.5))
                }
        }
    }
}

// MARK: - Expanded Media View

struct ExpandedMediaView: View {
    let viewModel: MediaPlayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Large Album Art
            expandedAlbumArt

            // Track Info
            VStack(spacing: 4) {
                Text(viewModel.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(trackSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            // Progress Bar
            ProgressBarView(
                progress: viewModel.progress,
                elapsedText: viewModel.elapsedFormatted,
                durationText: viewModel.durationFormatted,
                tintColor: viewModel.dominantColor,
                onSeek: { viewModel.seekToProgress($0) }
            )
            .padding(.horizontal, 16)

            // Transport Controls
            HStack(spacing: 32) {
                Button(action: { viewModel.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                }

                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                }

                Button(action: { viewModel.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                }
            }
            .foregroundStyle(.white)
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(viewModel.dominantColor.opacity(0.1))
        )
    }

    private var trackSubtitle: String {
        let artist = viewModel.currentTrack?.artist ?? ""
        let album = viewModel.currentTrack?.album ?? ""
        if artist.isEmpty && album.isEmpty { return "" }
        if album.isEmpty { return artist }
        return "\(artist) — \(album)"
    }

    @ViewBuilder
    private var expandedAlbumArt: some View {
        if let image = viewModel.currentTrack?.artworkImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }
}

// MARK: - Media Sneak Peek View

struct MediaSneakPeekView: View {
    let viewModel: MediaPlayerViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Small album art thumbnail
            if let image = viewModel.currentTrack?.artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }

            // Track name
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.currentTrack?.title ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(viewModel.currentTrack?.artist ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.85))
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Music Indicator View (Closed State)

struct MusicIndicatorView: View {
    let isPlaying: Bool

    @State private var animationPhase: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.8))
                    .frame(width: 2.5, height: barHeight(for: index))
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 0.4 + Double(index) * 0.15)
                                .repeatForever(autoreverses: true)
                            : .default,
                        value: isPlaying
                    )
            }
        }
        .frame(width: 14, height: 12)
        .onAppear {
            if isPlaying { animationPhase = 1 }
        }
        .onChange(of: isPlaying) { _, newValue in
            animationPhase = newValue ? 1 : 0
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return 4 }
        let heights: [CGFloat] = [10, 6, 8]
        let minHeights: [CGFloat] = [4, 3, 5]
        return animationPhase > 0 ? heights[index] : minHeights[index]
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    let progress: Double
    let elapsedText: String
    let durationText: String
    let tintColor: Color
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)

                    // Fill
                    Capsule()
                        .fill(tintColor)
                        .frame(width: max(0, geo.size.width * displayProgress), height: 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            onSeek(dragProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 4)

            HStack {
                Text(elapsedText)
                Spacer()
                Text(durationText)
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Main Media Player View (Entry Point)

struct MediaPlayerView: View {
    @State private var viewModel = MediaPlayerViewModel()
    @State private var isExpanded = false

    var body: some View {
        VStack {
            if isExpanded {
                ExpandedMediaView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                CompactMediaView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(AnimationConstants.openSpring, value: isExpanded)
        .onTapGesture(count: 2) {
            isExpanded.toggle()
        }
    }
}
