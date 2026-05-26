import AppKit
import CoreAudio
import AudioToolbox

// MARK: - Media Key Interceptor

final class MediaKeyInterceptor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onKeyEvent: (@Sendable (HIDKeyEvent) -> Void)?

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HUDError.accessibilityPermissionDenied
        }

        // NX_SYSDEFINED events have CGEventType raw value 14
        let systemDefinedType: CGEventType = CGEventType(rawValue: 14)!
        let mask: CGEventMask = 1 << systemDefinedType.rawValue

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passRetained(event)
            }

            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            return interceptor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HUDError.eventTapCreationFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        Log.general.info("Media key interceptor started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        Log.general.info("Media key interceptor stopped")
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled by the system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // NX_SYSDEFINED = raw value 14
        guard type.rawValue == 14 else {
            return Unmanaged.passRetained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        // Only handle NX_SUBTYPE_AUX_CONTROL_BUTTONS (subtype 8)
        guard nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = UInt16((data1 & 0xFFFF0000) >> 16)
        let keyFlags = (data1 & 0x0000FFFF)
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) & 0x0A != 0
        let isRepeat = (keyFlags & 0x02) != 0

        // Only handle known key codes
        guard let code = HIDKeyEvent.KeyCode(rawValue: keyCode) else {
            return Unmanaged.passRetained(event)
        }

        // Only process key down events (not key up)
        guard isKeyDown else {
            // Swallow key up for intercepted keys too
            return nil
        }

        let modifiers = nsEvent.modifierFlags
        let hasOption = modifiers.contains(.option)
        let hasShift = modifiers.contains(.shift)

        let keyEvent = HIDKeyEvent(
            keyCode: code,
            isKeyDown: isKeyDown,
            isRepeat: isRepeat,
            hasOption: hasOption,
            hasShift: hasShift
        )

        // If Option alone (no shift), open System Settings instead
        if keyEvent.shouldOpenSettings {
            openSystemSettings(for: code)
            return nil
        }

        onKeyEvent?(keyEvent)
        return nil  // Swallow the event to prevent system HUD
    }

    private func openSystemSettings(for keyCode: HIDKeyEvent.KeyCode) {
        let urlString: String
        switch keyCode {
        case .soundUp, .soundDown, .mute:
            urlString = "x-apple.systempreferences:com.apple.preference.sound"
        case .brightnessUp, .brightnessDown:
            urlString = "x-apple.systempreferences:com.apple.preference.displays"
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Volume Controller

final class VolumeController: @unchecked Sendable {
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentDeviceID: AudioDeviceID = 0
    var onVolumeChanged: ((Float) -> Void)?

    // Use kAudioHardwareServiceDeviceProperty_VirtualMainVolume (FourCC 'vmvc')
    private static let virtualMainVolumeSelector: AudioObjectPropertySelector = 0x766D7663 // 'vmvc'

    init() {
        currentDeviceID = Self.defaultOutputDeviceID
        registerVolumeListener()
        registerDeviceChangeListener()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Volume Get/Set

    var volume: Float {
        get {
            var vol: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: Self.virtualMainVolumeSelector,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &vol)
            if status != noErr {
                Log.general.warning("Failed to get volume: \(status)")
                return 0.5
            }
            return vol
        }
        set {
            var vol = newValue.clamped(to: 0.0...1.0)
            let size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: Self.virtualMainVolumeSelector,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &vol)
        }
    }

    // MARK: - Mute Get/Set

    var isMuted: Bool {
        get {
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &muted)
            if status != noErr {
                return false
            }
            return muted != 0
        }
        set {
            var muted: UInt32 = newValue ? 1 : 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &muted)
        }
    }

    // MARK: - Step Volume

    func adjustVolume(by step: Float) {
        let newVol = (volume + step).clamped(to: 0.0...1.0)
        volume = newVol
    }

    // MARK: - Volume Tick Sound

    func playVolumeTick() {
        let tickPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        guard let sound = NSSound(contentsOfFile: tickPath, byReference: true) else { return }
        sound.play()
    }

    // MARK: - Listeners

    private func registerVolumeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: Self.virtualMainVolumeSelector,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.onVolumeChanged?(self.volume)
        }
        listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func registerDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.removeVolumeListener()
            self.currentDeviceID = Self.defaultOutputDeviceID
            self.registerVolumeListener()
        }
        deviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func removeVolumeListener() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: Self.virtualMainVolumeSelector,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(currentDeviceID, &address, DispatchQueue.main, block)
        listenerBlock = nil
    }

    private func removeListeners() {
        removeVolumeListener()
        if let block = deviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
            deviceListenerBlock = nil
        }
    }

    // MARK: - Default Device

    static var defaultOutputDeviceID: AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return deviceID
    }
}

// MARK: - Brightness Controller

final class BrightnessController: @unchecked Sendable {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID) -> Double
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Double) -> Void

    private var getBrightnessFn: GetBrightnessFn?
    private var setBrightnessFn: SetBrightnessFn?
    private var frameworkHandle: UnsafeMutableRawPointer?
    private(set) var isAvailable: Bool = false

    init() {
        loadFramework()
    }

    private func loadFramework() {
        let path = "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            Log.general.warning("Failed to load CoreDisplay framework")
            return
        }
        frameworkHandle = handle

        guard let getPtr = dlsym(handle, "CoreDisplay_Display_GetUserBrightness"),
              let setPtr = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else {
            Log.general.warning("CoreDisplay brightness symbols not found")
            return
        }

        getBrightnessFn = unsafeBitCast(getPtr, to: GetBrightnessFn.self)
        setBrightnessFn = unsafeBitCast(setPtr, to: SetBrightnessFn.self)
        isAvailable = true
        Log.general.info("CoreDisplay framework loaded successfully")
    }

    var brightness: Double {
        get {
            guard let fn = getBrightnessFn else { return 0.5 }
            return fn(CGMainDisplayID())
        }
        set {
            guard let fn = setBrightnessFn else { return }
            fn(CGMainDisplayID(), newValue.clamped(to: 0.0...1.0))
        }
    }

    func adjustBrightness(by step: Double) {
        let newValue = (brightness + step).clamped(to: 0.0...1.0)
        brightness = newValue
    }
}

// MARK: - Comparable Clamping Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
