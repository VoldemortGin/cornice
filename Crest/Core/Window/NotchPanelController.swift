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

        // Create SwiftUI content view using the full ContentView
        let contentView = ContentView(viewModel: viewModel)
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

