import SwiftUI

// MARK: - Inline HUD View

struct InlineHUDView: View {
    let viewModel: HUDViewModel

    var body: some View {
        if viewModel.isVisible, let state = viewModel.currentState {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: viewModel.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .contentTransition(.symbolEffect(.replace))

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        Capsule()
                            .fill(barFillColor(for: state))
                            .frame(width: max(0, geo.size.width * state.value))
                            .animation(.spring(duration: 0.1), value: state.value)
                    }
                }
                .frame(height: 4)

                // Percentage Label
                Text("\(viewModel.displayPercentage)%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.black.opacity(0.85))
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
    }

    private func barFillColor(for state: HUDState) -> Color {
        if state.isMuted {
            return .gray
        }
        switch state.type {
        case .volume:
            return .white
        case .brightness:
            return .yellow.opacity(0.9)
        case .keyboardBrightness:
            return .white.opacity(0.9)
        case .mute:
            return .gray
        }
    }
}

// MARK: - HUD View (Entry Point)

struct HUDView: View {
    @State private var viewModel = HUDViewModel()

    var body: some View {
        InlineHUDView(viewModel: viewModel)
            .animation(.easeOut(duration: 0.2), value: viewModel.isVisible)
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
    }
}
