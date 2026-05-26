import AppKit

/// Owns global mouse event monitors and translates mouse positions
/// into hover-enter / hover-exit calls on per-screen ViewModels.
/// Also handles click-outside-to-dismiss logic.
@MainActor
final class HoverDetector {

    private let coordinator: ViewCoordinator
    private let panelControllers: () -> [String: NotchPanelController]

    /// Global mouse move event monitor.
    private var globalMouseMonitor: Any?

    /// Global mouse down event monitor (click-outside detection).
    private var globalMouseDownMonitor: Any?

    /// Local event monitor for interactions within panels.
    private var localEventMonitor: Any?

    init(coordinator: ViewCoordinator, panelControllers: @escaping () -> [String: NotchPanelController]) {
        self.coordinator = coordinator
        self.panelControllers = panelControllers
    }

    // MARK: - Setup / Teardown

    func start() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseMoved()
            }
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseDown()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .scrollWheel]
        ) { event in
            return event
        }
    }

    func stop() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Mouse Handling

    private func handleGlobalMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation
        coordinator.updateActiveScreen(mouseLocation: mouseLocation)

        let controllers = panelControllers()
        for (uuid, controller) in controllers {
            guard let viewModel = coordinator.viewModels[uuid] else { continue }
            let geometryInfo = viewModel.geometryInfo

            if viewModel.state.isExpanded {
                let expandedRect = geometryInfo.expandedRect(for: viewModel.state)
                if expandedRect.contains(mouseLocation) {
                    if !viewModel.isHovered {
                        viewModel.onHoverEnter()
                    }
                } else {
                    if viewModel.isHovered {
                        viewModel.onHoverExit()
                    }
                }
            } else {
                let activationRect = geometryInfo.activationRect
                if activationRect.contains(mouseLocation) {
                    if !viewModel.isHovered {
                        viewModel.onHoverEnter()
                    }
                } else if viewModel.isHovered {
                    viewModel.onHoverExit()
                }
            }

            controller.updateFrame()
        }
    }

    private func handleGlobalMouseDown() {
        let mouseLocation = NSEvent.mouseLocation

        let controllers = panelControllers()
        for (uuid, _) in controllers {
            guard let viewModel = coordinator.viewModels[uuid] else { continue }
            guard viewModel.state.isExpanded else { continue }

            let expandedRect = viewModel.geometryInfo.expandedRect(for: viewModel.state)
            if !expandedRect.contains(mouseLocation) {
                viewModel.close()
            }
        }
    }
}
