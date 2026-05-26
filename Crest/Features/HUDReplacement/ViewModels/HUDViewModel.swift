import SwiftUI

@MainActor
@Observable
final class HUDViewModel {
    // MARK: - State

    private(set) var currentState: HUDState?
    private(set) var isVisible: Bool = false

    // MARK: - Private

    private let volumeController = VolumeController()
    private let brightnessController = BrightnessController()
    private let keyInterceptor = MediaKeyInterceptor()
    private var dismissTask: Task<Void, Never>?
    private var preMuteVolume: Float = 0.5
    private var isStarted = false

    // MARK: - Computed

    var iconName: String {
        guard let state = currentState else { return "" }
        switch state.type {
        case .volume, .mute:
            return VolumeIcon.forLevel(state.value, muted: state.isMuted).systemName
        case .brightness:
            return BrightnessIcon.forLevel(state.value).systemName
        case .keyboardBrightness:
            return "keyboard.badge.ellipsis"
        }
    }

    var displayPercentage: Int {
        guard let state = currentState else { return 0 }
        return Int(state.value * 100)
    }

    var barColor: Color {
        guard let state = currentState else { return .white }
        if state.isMuted { return .gray }
        return .white
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }
        isStarted = true

        keyInterceptor.onKeyEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyEvent(event)
            }
        }

        do {
            try keyInterceptor.start()
            Log.general.info("HUD interceptor started successfully")
        } catch {
            Log.general.error("Failed to start HUD interceptor: \(error.localizedDescription)")
        }

        // Monitor external volume changes
        volumeController.onVolumeChanged = { [weak self] newVolume in
            Task { @MainActor [weak self] in
                self?.showHUD(type: .volume, value: Double(newVolume), muted: false)
            }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        keyInterceptor.stop()
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: HIDKeyEvent) {
        switch event.keyCode {
        case .soundUp:
            handleVolumeChange(direction: .up, step: event.stepSize, isFine: event.isFineAdjustment)
        case .soundDown:
            handleVolumeChange(direction: .down, step: event.stepSize, isFine: event.isFineAdjustment)
        case .mute:
            handleMuteToggle()
        case .brightnessUp:
            handleBrightnessChange(direction: .up, step: event.stepSize)
        case .brightnessDown:
            handleBrightnessChange(direction: .down, step: event.stepSize)
        case .keyboardBrightnessUp:
            handleKeyboardBrightness(direction: .up, step: event.stepSize)
        case .keyboardBrightnessDown:
            handleKeyboardBrightness(direction: .down, step: event.stepSize)
        }
    }

    // MARK: - Volume

    private func handleVolumeChange(direction: HIDKeyEvent.Direction, step: Float, isFine: Bool) {
        // If muted, unmute on volume change
        if volumeController.isMuted {
            volumeController.isMuted = false
        }

        let actualStep = direction == .up ? step : -step
        volumeController.adjustVolume(by: actualStep)

        let newVolume = Double(volumeController.volume)
        showHUD(type: .volume, value: newVolume, muted: false)

        // Play tick sound (suppress during fine adjustment)
        if !isFine && newVolume > 0 {
            volumeController.playVolumeTick()
        }
    }

    private func handleMuteToggle() {
        let wasMuted = volumeController.isMuted

        if wasMuted {
            // Unmute: restore previous volume
            volumeController.isMuted = false
            volumeController.volume = preMuteVolume
            showHUD(type: .volume, value: Double(preMuteVolume), muted: false)
        } else {
            // Mute: save current volume
            preMuteVolume = volumeController.volume
            volumeController.isMuted = true
            showHUD(type: .mute, value: 0, muted: true)
        }
    }

    // MARK: - Brightness

    private func handleBrightnessChange(direction: HIDKeyEvent.Direction, step: Float) {
        guard brightnessController.isAvailable else { return }

        let actualStep = direction == .up ? Double(step) : -Double(step)
        brightnessController.adjustBrightness(by: actualStep)

        let newBrightness = brightnessController.brightness
        showHUD(type: .brightness, value: newBrightness, muted: false)
    }

    // MARK: - Keyboard Brightness

    private func handleKeyboardBrightness(direction: HIDKeyEvent.Direction, step: Float) {
        // Keyboard brightness via IOKit is complex and may not be available
        // Show the HUD with an estimated value for now
        let currentValue = currentState?.type == .keyboardBrightness ? currentState!.value : 0.5
        let actualStep = direction == .up ? Double(step) : -Double(step)
        let newValue = max(0, min(1, currentValue + actualStep))
        showHUD(type: .keyboardBrightness, value: newValue, muted: false)
    }

    // MARK: - HUD Display

    private func showHUD(type: HUDType, value: Double, muted: Bool) {
        currentState = HUDState(type: type, value: value, isMuted: muted, isVisible: true)
        isVisible = true
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        isVisible = false
        currentState?.isVisible = false
    }
}
