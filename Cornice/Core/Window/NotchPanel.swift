import AppKit

// MARK: - Private API Declarations (CGSSpace)

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> UInt32

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ connection: UInt32, _ flags: Int, _ options: CFDictionary?) -> UInt64

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ connection: UInt32, _ space: UInt64, _ level: Int32)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ connection: UInt32, _ windows: CFArray, _ spaces: CFArray)

// MARK: - NotchPanel

/// NSPanel subclass that renders the notch overlay.
/// Configured as non-activating, borderless, and always-on-top.
/// Never steals focus from the user's current application.
final class NotchPanel: NSPanel {

    /// Whether CGSSpace private API integration is available and enabled.
    private var cgsSpaceEnabled = false
    private var cgsSpaceID: UInt64 = 0

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: flag
        )
        configurePanel()
    }

    private func configurePanel() {
        // Window level: above menu bar
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Always visible, never steals focus
        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Visible on all spaces, fullscreen apps, doesn't appear in app switcher
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        // Accept mouse events (for hover and clicks within the notch shape)
        ignoresMouseEvents = false

        // Try to set up CGSSpace for maximum z-level
        setupCGSSpace()
    }

    // MARK: - CGSSpace Integration

    /// Attempts to use private CGSSpace API for elevated window level.
    /// Falls back gracefully if unavailable.
    private func setupCGSSpace() {
        // Only attempt if we can resolve the function (sanity check via dlsym)
        guard let _ = dlsym(dlopen(nil, RTLD_NOW), "_CGSDefaultConnection") else {
            Log.ui.info("CGSSpace API unavailable, using standard window level")
            return
        }

        let connection = _CGSDefaultConnection()
        guard connection != 0 else {
            Log.ui.info("CGS connection failed, using standard window level")
            return
        }

        cgsSpaceEnabled = true
    }

    /// Elevates this panel to the maximum possible z-level using CGSSpace.
    /// Call this after the panel is ordered on screen.
    func elevateToMaxLevel() {
        guard cgsSpaceEnabled, windowNumber > 0 else { return }

        let connection = _CGSDefaultConnection()
        let space = CGSSpaceCreate(connection, 0, nil)
        guard space != 0 else { return }

        cgsSpaceID = space
        CGSSpaceSetAbsoluteLevel(connection, space, Int32.max)

        let windows = [NSNumber(value: windowNumber)] as CFArray
        let spaces = [NSNumber(value: space)] as CFArray
        CGSAddWindowsToSpaces(connection, windows, spaces)

        Log.ui.debug("Panel elevated to max z-level via CGSSpace")
    }

    /// Reverts to standard window level.
    func revertToStandardLevel() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
    }
}
