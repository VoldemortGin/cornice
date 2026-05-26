import AppKit
import SwiftUI

/// Manages the lifecycle of a single NotchPanel for one screen.
/// Creates the panel, positions it over the notch, hosts SwiftUI content,
/// and handles repositioning on screen/state changes.
@MainActor
final class NotchPanelController {

    /// The NSPanel instance for this screen.
    private(set) var panel: NotchPanel?

    /// The view model driving this screen's notch UI.
    let viewModel: NotchViewModel

    /// The screen this controller is associated with.
    private let screen: NSScreen

    /// The hosting view that bridges SwiftUI content into the panel.
    private var hostingView: NSHostingView<AnyView>?

    /// Geometry for this screen.
    private let geometry: NotchGeometry

    init(screen: NSScreen, viewModel: NotchViewModel) {
        self.screen = screen
        self.viewModel = viewModel
        self.geometry = NotchGeometry(screen: screen)
        createPanel()
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let initialFrame = geometry.frame(for: .closed)
        let newPanel = NotchPanel(contentRect: initialFrame)

        // Create SwiftUI content view
        let contentView = NotchContentWrapperView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(contentView))
        hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
        hosting.autoresizingMask = [.width, .height]

        newPanel.contentView = hosting
        self.hostingView = hosting
        self.panel = newPanel
    }

    // MARK: - Show / Hide

    /// Shows the panel, positioned over the notch area.
    func show() {
        guard let panel else { return }
        let frame = geometry.frame(for: viewModel.state)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        Log.ui.debug("NotchPanelController: showing panel for screen \(self.viewModel.screenUUID)")
    }

    /// Hides the panel.
    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Repositioning

    /// Recalculates and applies the panel frame based on the current notch state.
    func updateFrame() {
        guard let panel else { return }
        let frame = panelFrame(for: viewModel.state)
        panel.setFrame(frame, display: true)
    }

    /// Updates the panel frame for a new state (used during animation).
    func updateFrame(for state: NotchState) {
        guard let panel else { return }

        // Set the panel to the maximum frame needed so SwiftUI can animate within it.
        // We use the target state's frame directly.
        let frame = panelFrame(for: state)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.42
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    /// Called when screen parameters change (resolution, position, etc.).
    func handleScreenChange() {
        updateFrame()
    }

    // MARK: - Cleanup

    func tearDown() {
        viewModel.cancelAllTimers()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    // MARK: - Private

    /// Computes the panel frame for a given state.
    /// The panel is always centered on its screen, pinned to the top edge.
    private func panelFrame(for state: NotchState) -> NSRect {
        let size = geometry.size(for: state)
        let screenFrame = screen.frame
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.maxY - size.height
        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }
}

// MARK: - NotchContentWrapperView

/// A minimal SwiftUI wrapper that observes the NotchViewModel and renders the notch content.
private struct NotchContentWrapperView: View {
    let viewModel: NotchViewModel

    var body: some View {
        ZStack {
            // Background: black notch shape
            NotchShape(
                topCornerRadius: viewModel.topCornerRadius,
                bottomCornerRadius: viewModel.bottomCornerRadius
            )
            .fill(Color.black)

            // Content area (placeholder for features)
            if viewModel.state.isExpanded {
                VStack(spacing: 0) {
                    // Tab bar placeholder
                    HStack {
                        Spacer()
                        Text("Crest")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .frame(height: 32)

                    Spacer()
                }
                .transition(AnimationConstants.contentAppearTransition)
            }

            if case .sneakPeek(let event) = viewModel.state {
                sneakPeekContent(for: event)
                    .transition(AnimationConstants.contentAppearTransition)
            }
        }
        .frame(width: viewModel.notchSize.width, height: viewModel.notchSize.height)
        .clipShape(
            NotchShape(
                topCornerRadius: viewModel.topCornerRadius,
                bottomCornerRadius: viewModel.bottomCornerRadius
            )
        )
    }

    @ViewBuilder
    private func sneakPeekContent(for event: SneakPeekEvent) -> some View {
        HStack(spacing: 12) {
            sneakPeekIcon(for: event)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sneakPeekTitle(for: event))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = sneakPeekSubtitle(for: event) {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func sneakPeekIcon(for event: SneakPeekEvent) -> some View {
        switch event {
        case .trackChange:
            Image(systemName: "music.note")
                .foregroundColor(.white)
        case .volume:
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.white)
        case .brightness:
            Image(systemName: "sun.max.fill")
                .foregroundColor(.white)
        case .battery:
            Image(systemName: "battery.100")
                .foregroundColor(.white)
        case .calendarEvent:
            Image(systemName: "calendar")
                .foregroundColor(.white)
        case .timerCompleted:
            Image(systemName: "timer")
                .foregroundColor(.white)
        }
    }

    private func sneakPeekTitle(for event: SneakPeekEvent) -> String {
        switch event {
        case .trackChange(let title, _):
            return title
        case .volume(let level):
            return "Volume \(Int(level * 100))%"
        case .brightness(let level):
            return "Brightness \(Int(level * 100))%"
        case .battery(let pct, _):
            return "Battery \(pct)%"
        case .calendarEvent(let title, _):
            return title
        case .timerCompleted(let label):
            return label
        }
    }

    private func sneakPeekSubtitle(for event: SneakPeekEvent) -> String? {
        switch event {
        case .trackChange(_, let artist):
            return artist
        case .battery(_, let isCharging):
            return isCharging ? "Charging" : nil
        case .calendarEvent(_, let minutes):
            return "in \(minutes) min"
        default:
            return nil
        }
    }
}
