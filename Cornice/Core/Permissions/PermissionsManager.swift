import AppKit
import AVFoundation
import EventKit

/// Unified permissions manager for all system entitlements Niya requires.
/// Provides check and request methods for Accessibility, Camera, and Calendar.
@MainActor
final class PermissionsManager {
    static let shared = PermissionsManager()

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Accessibility

    /// Whether accessibility permission is currently granted.
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for accessibility permission.
    /// Shows the system dialog if not already trusted.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        Log.permissions.info("Accessibility permission requested")
    }

    /// Opens System Settings to the Accessibility pane.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Camera

    /// Current camera authorization status.
    var cameraAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Whether camera access is currently authorized.
    var isCameraAuthorized: Bool {
        cameraAuthorizationStatus == .authorized
    }

    /// Requests camera access. Returns true if granted.
    func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        Log.permissions.info("Camera permission \(granted ? "granted" : "denied")")
        return granted
    }

    /// Opens System Settings to the Camera pane.
    func openCameraSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Calendar

    /// Current calendar authorization status.
    var calendarAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Whether calendar access is currently authorized.
    var isCalendarAuthorized: Bool {
        calendarAuthorizationStatus == .fullAccess
    }

    /// Requests full calendar access. Returns true if granted.
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            Log.permissions.info("Calendar permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            Log.permissions.error("Calendar permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Opens System Settings to the Calendar pane.
    func openCalendarSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Combined Status

    /// Summary of all permission states.
    struct PermissionStatus {
        let accessibility: Bool
        let camera: AVAuthorizationStatus
        let calendar: EKAuthorizationStatus

        /// Whether all required permissions are granted.
        var allGranted: Bool {
            accessibility && camera == .authorized && calendar == .fullAccess
        }

        /// Whether the minimum required permissions are granted (just accessibility).
        var minimumGranted: Bool {
            accessibility
        }
    }

    /// Returns the current status of all permissions.
    var status: PermissionStatus {
        PermissionStatus(
            accessibility: isAccessibilityGranted,
            camera: cameraAuthorizationStatus,
            calendar: calendarAuthorizationStatus
        )
    }

    /// Checks all permissions and logs their status.
    func checkAll() {
        let s = status
        Log.permissions.info("""
        Permission status:
          Accessibility: \(s.accessibility)
          Camera: \(String(describing: s.camera))
          Calendar: \(String(describing: s.calendar))
        """)
    }
}
