import SwiftUI

struct AirDropView: View {
    let state: AirDropState
    let isAvailable: Bool
    var onDropItems: (([ShelfItem]) -> Void)?
    var onLongPress: (() -> Void)?

    @State private var isHovered = false
    @State private var showSuccessCheckmark = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            statusIcon
                .font(.system(size: 28))
                .scaleEffect(isHovered && isAvailable ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)

            statusLabel
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 80)
        .background(backgroundView)
        .overlay(borderView)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
        .help(tooltipText)
        .onChange(of: state) { _, newState in
            handleStateChange(newState)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle, .ready:
            if showSuccessCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if !isAvailable {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.gray)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(isHovered ? .blue : .secondary)
            }
        case .sending:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .idle, .ready:
            if !isAvailable {
                Text("AirDrop Off")
                    .foregroundStyle(.gray)
            } else if isHovered {
                Text("Drop to AirDrop")
                    .foregroundStyle(.blue)
            } else {
                Text("AirDrop")
                    .foregroundStyle(.secondary)
            }
        case .sending:
            Text("Sending...")
                .foregroundStyle(.primary)
        case .completed:
            Text("Sent!")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .lineLimit(2)
                .font(.system(size: 9))
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(backgroundColor)
    }

    private var borderView: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(borderColor, lineWidth: 1)
    }

    private var backgroundColor: Color {
        if !isAvailable { return Color.gray.opacity(0.05) }
        if isHovered { return Color.blue.opacity(0.1) }
        return Color.clear
    }

    private var borderColor: Color {
        if !isAvailable { return Color.gray.opacity(0.2) }
        if isHovered { return Color.blue.opacity(0.5) }
        return Color.secondary.opacity(0.2)
    }

    private var tooltipText: String {
        if !isAvailable {
            return "Enable AirDrop in System Settings > General > AirDrop & Handoff"
        }
        return "Drop items here to share via AirDrop"
    }

    private func handleStateChange(_ newState: AirDropState) {
        switch newState {
        case .completed:
            showSuccessCheckmark = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                showSuccessCheckmark = false
            }
        case .failed:
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                errorMessage = nil
            }
        default:
            break
        }
    }
}
