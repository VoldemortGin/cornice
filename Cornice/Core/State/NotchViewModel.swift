import SwiftUI
import Combine
import Defaults

/// The user-chosen method for activating the notch.
enum ActivationMethod: String, Codable, CaseIterable, Sendable {
    case hover
    case click
    case swipe
}

/// Per-screen view model that drives the notch UI state and animations.
@MainActor
@Observable
final class NotchViewModel {
    // MARK: - State

    /// Current notch state.
    private(set) var state: NotchState = .closed

    /// Current size of the notch overlay (animated).
    var notchSize: CGSize

    /// Current top corner radius (animated).
    var topCornerRadius: CGFloat = AnimationConstants.CornerRadii.closedTop

    /// Current bottom corner radius (animated).
    var bottomCornerRadius: CGFloat = AnimationConstants.CornerRadii.closedBottom

    /// Whether the mouse is currently hovering over the notch region.
    var isHovered: Bool = false

    /// The activation method for this screen. Synced from user settings.
    var activationMethod: ActivationMethod = Defaults[.activationMethod]

    /// Hover activation delay. Synced from user settings.
    var hoverDelay: TimeInterval = Defaults[.hoverDelay]

    /// Collapse delay after mouse leaves expanded area. Synced from user settings.
    var closeDelay: TimeInterval = Defaults[.closeDelay]

    /// Sneak peek auto-dismiss duration. Synced from user settings.
    var sneakPeekDuration: TimeInterval = Defaults[.sneakPeekDuration]

    /// The screen UUID for multi-monitor identity.
    let screenUUID: String

    /// Geometry info for this screen's notch.
    let geometryInfo: NotchGeometryInfo

    // MARK: - Private

    @ObservationIgnored
    private var hoverTimer: Task<Void, Never>?

    @ObservationIgnored
    private var closeTimer: Task<Void, Never>?

    @ObservationIgnored
    private var sneakPeekTimer: Task<Void, Never>?

    @ObservationIgnored
    private var settingsCancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(screenUUID: String, geometryInfo: NotchGeometryInfo) {
        self.screenUUID = screenUUID
        self.geometryInfo = geometryInfo
        self.notchSize = geometryInfo.closedSize
        observeSettingsChanges()
    }

    // MARK: - Settings Observation

    private func observeSettingsChanges() {
        Defaults.publisher(.activationMethod)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.activationMethod = change.newValue
            }
            .store(in: &settingsCancellables)

        Defaults.publisher(.hoverDelay)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.hoverDelay = change.newValue
            }
            .store(in: &settingsCancellables)

        Defaults.publisher(.closeDelay)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.closeDelay = change.newValue
            }
            .store(in: &settingsCancellables)

        Defaults.publisher(.sneakPeekDuration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.sneakPeekDuration = change.newValue
            }
            .store(in: &settingsCancellables)
    }

    // MARK: - State Transitions

    /// Attempts to transition to a new state. Returns false if the transition is invalid.
    @discardableResult
    func transition(to newState: NotchState) -> Bool {
        guard state.canTransition(to: newState) else {
            Log.ui.debug("Invalid transition from \(String(describing: self.state)) to \(String(describing: newState))")
            return false
        }

        let animation: Animation
        switch newState {
        case .closed:
            animation = AnimationConstants.closeSpring
        case .sneakPeek, .open, .expandedDetail:
            animation = AnimationConstants.openSpring
        }

        state = newState
        withAnimation(animation) {
            applyStateVisuals(for: newState)
        }

        // Start sneak peek dismiss timer if entering sneakPeek state.
        if case .sneakPeek = newState {
            startSneakPeekTimer()
        } else {
            cancelSneakPeekTimer()
        }

        return true
    }

    /// Opens the notch (from closed or sneak peek).
    func open() {
        transition(to: .open)
    }

    /// Closes the notch.
    func close() {
        transition(to: .closed)
    }

    /// Shows a sneak peek with the given event.
    func showSneakPeek(_ event: SneakPeekEvent) {
        if state.isSneakPeek {
            // Replace current sneak peek: update state directly, restart timer.
            state = .sneakPeek(event)
            withAnimation(AnimationConstants.openSpring) {
                applyStateVisuals(for: .sneakPeek(event))
            }
            startSneakPeekTimer()
        } else if state.isClosed {
            transition(to: .sneakPeek(event))
        }
        // If open or expandedDetail, ignore sneak peek (user is already interacting).
    }

    /// Expands to detail view (from open state).
    func expandToDetail() {
        transition(to: .expandedDetail)
    }

    /// Collapses from expanded detail back to open.
    func collapseFromDetail() {
        transition(to: .open)
    }

    // MARK: - Hover Handling

    /// Called when the mouse enters the notch region.
    func onHoverEnter() {
        isHovered = true
        cancelCloseTimer()

        guard activationMethod == .hover else { return }
        guard state.isClosed else { return }

        hoverTimer?.cancel()
        hoverTimer = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(self.hoverDelay * 1000)))
            guard !Task.isCancelled, self.isHovered else { return }
            self.open()
        }
    }

    /// Called when the mouse exits the notch/expanded region.
    func onHoverExit() {
        isHovered = false
        cancelHoverTimer()

        guard state.isExpanded else { return }
        startCloseTimer()
    }

    // MARK: - Gesture Handling

    /// Updates notch size during an interactive swipe gesture.
    /// Progress is 0 (closed) to 1 (fully open).
    func updateGestureProgress(_ progress: CGFloat) {
        let clamped = max(0, min(1, progress))
        let closedSize = geometryInfo.closedSize
        let openSize = geometryInfo.openSize

        let width = closedSize.width + (openSize.width - closedSize.width) * clamped
        let height = closedSize.height + (openSize.height - closedSize.height) * clamped

        notchSize = CGSize(width: width, height: height)

        // Interpolate corner radii
        let closedTopR = AnimationConstants.CornerRadii.closedTop
        let openTopR = AnimationConstants.CornerRadii.openTop
        let closedBottomR = AnimationConstants.CornerRadii.closedBottom
        let openBottomR = AnimationConstants.CornerRadii.openBottom

        topCornerRadius = closedTopR + (openTopR - closedTopR) * clamped
        bottomCornerRadius = closedBottomR + (openBottomR - closedBottomR) * clamped
    }

    /// Completes a swipe gesture. If committed, opens; otherwise snaps back to closed.
    func endGesture(translation: CGFloat) {
        let committed = translation >= AnimationConstants.swipeCommitThreshold
        let animation = AnimationConstants.interactiveSpring

        withAnimation(animation) {
            if committed {
                state = .open
                applyStateVisuals(for: .open)
            } else {
                state = .closed
                applyStateVisuals(for: .closed)
            }
        }
    }

    // MARK: - Private Helpers

    private func applyStateVisuals(for state: NotchState) {
        notchSize = geometryInfo.size(for: state)

        switch state {
        case .closed:
            topCornerRadius = AnimationConstants.CornerRadii.closedTop
            bottomCornerRadius = AnimationConstants.CornerRadii.closedBottom
        case .sneakPeek:
            topCornerRadius = AnimationConstants.CornerRadii.sneakPeekTop
            bottomCornerRadius = AnimationConstants.CornerRadii.sneakPeekBottom
        case .open:
            topCornerRadius = AnimationConstants.CornerRadii.openTop
            bottomCornerRadius = AnimationConstants.CornerRadii.openBottom
        case .expandedDetail:
            topCornerRadius = AnimationConstants.CornerRadii.expandedDetailTop
            bottomCornerRadius = AnimationConstants.CornerRadii.expandedDetailBottom
        }
    }

    // MARK: - Timers

    private func startSneakPeekTimer() {
        cancelSneakPeekTimer()
        sneakPeekTimer = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(self.sneakPeekDuration * 1000)))
            guard !Task.isCancelled else { return }
            if self.state.isSneakPeek {
                self.transition(to: .closed)
            }
        }
    }

    private func cancelSneakPeekTimer() {
        sneakPeekTimer?.cancel()
        sneakPeekTimer = nil
    }

    private func startCloseTimer() {
        cancelCloseTimer()
        closeTimer = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(self.closeDelay * 1000)))
            guard !Task.isCancelled else { return }
            if !self.isHovered && self.state.isExpanded {
                self.close()
            }
        }
    }

    private func cancelCloseTimer() {
        closeTimer?.cancel()
        closeTimer = nil
    }

    private func cancelHoverTimer() {
        hoverTimer?.cancel()
        hoverTimer = nil
    }

    /// Cancels all timers (for cleanup).
    func cancelAllTimers() {
        cancelHoverTimer()
        cancelCloseTimer()
        cancelSneakPeekTimer()
    }
}
