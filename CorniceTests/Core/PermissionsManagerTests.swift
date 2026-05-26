import XCTest
import AVFoundation
import EventKit
@testable import Cornice

/// Tests for PermissionsManager -- unified permissions manager for
/// Accessibility, Camera, and Calendar entitlements.
@MainActor
final class PermissionsManagerTests: XCTestCase {

    // MARK: - Singleton Access

    func test_shared_returnsSameInstance() {
        let a = PermissionsManager.shared
        let b = PermissionsManager.shared
        XCTAssertTrue(a === b,
                      "PermissionsManager.shared must always return the same instance")
    }

    func test_shared_isNotNil() {
        XCTAssertNotNil(PermissionsManager.shared)
    }

    // MARK: - Accessibility Permission

    func test_isAccessibilityGranted_returnsBool() {
        // In test/CI environments accessibility is typically not trusted.
        let granted = PermissionsManager.shared.isAccessibilityGranted
        // Just verify it returns a Bool without crashing.
        XCTAssertNotNil(granted as Bool)
    }

    // MARK: - Camera Authorization Status

    func test_cameraAuthorizationStatus_returnsValidStatus() {
        let status = PermissionsManager.shared.cameraAuthorizationStatus
        // The status should be one of the known AVAuthorizationStatus values.
        let validStatuses: [AVAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .authorized
        ]
        XCTAssertTrue(validStatuses.contains(status),
                      "Camera status should be a valid AVAuthorizationStatus")
    }

    func test_isCameraAuthorized_matchesAuthorizationStatus() {
        let manager = PermissionsManager.shared
        let isAuthorized = manager.isCameraAuthorized
        let status = manager.cameraAuthorizationStatus
        XCTAssertEqual(isAuthorized, status == .authorized,
                       "isCameraAuthorized should be true only when status is .authorized")
    }

    // MARK: - Calendar Authorization Status

    func test_calendarAuthorizationStatus_returnsValidStatus() {
        let status = PermissionsManager.shared.calendarAuthorizationStatus
        // The status should be one of the known EKAuthorizationStatus values.
        let validStatuses: [EKAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .fullAccess, .writeOnly
        ]
        XCTAssertTrue(validStatuses.contains(status),
                      "Calendar status should be a valid EKAuthorizationStatus")
    }

    func test_isCalendarAuthorized_matchesAuthorizationStatus() {
        let manager = PermissionsManager.shared
        let isAuthorized = manager.isCalendarAuthorized
        let status = manager.calendarAuthorizationStatus
        XCTAssertEqual(isAuthorized, status == .fullAccess,
                       "isCalendarAuthorized should be true only when status is .fullAccess")
    }

    // MARK: - PermissionStatus Struct

    func test_permissionStatus_allGranted_whenAllTrue() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .authorized,
            calendar: .fullAccess
        )
        XCTAssertTrue(status.allGranted,
                      "allGranted should be true when all permissions are granted")
    }

    func test_permissionStatus_allGranted_falseWhenAccessibilityDenied() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: false,
            camera: .authorized,
            calendar: .fullAccess
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when accessibility is denied")
    }

    func test_permissionStatus_allGranted_falseWhenCameraDenied() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .denied,
            calendar: .fullAccess
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when camera is denied")
    }

    func test_permissionStatus_allGranted_falseWhenCameraNotDetermined() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .notDetermined,
            calendar: .fullAccess
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when camera is notDetermined")
    }

    func test_permissionStatus_allGranted_falseWhenCalendarDenied() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .authorized,
            calendar: .denied
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when calendar is denied")
    }

    func test_permissionStatus_allGranted_falseWhenCalendarWriteOnly() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .authorized,
            calendar: .writeOnly
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when calendar is writeOnly (not fullAccess)")
    }

    func test_permissionStatus_allGranted_falseWhenAllDenied() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: false,
            camera: .denied,
            calendar: .denied
        )
        XCTAssertFalse(status.allGranted,
                       "allGranted should be false when all permissions are denied")
    }

    // MARK: - Minimum Granted (just accessibility)

    func test_permissionStatus_minimumGranted_trueWhenAccessibilityGranted() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .denied,
            calendar: .denied
        )
        XCTAssertTrue(status.minimumGranted,
                      "minimumGranted should be true when accessibility is granted, regardless of others")
    }

    func test_permissionStatus_minimumGranted_falseWhenAccessibilityDenied() {
        let status = PermissionsManager.PermissionStatus(
            accessibility: false,
            camera: .authorized,
            calendar: .fullAccess
        )
        XCTAssertFalse(status.minimumGranted,
                       "minimumGranted should be false when accessibility is denied")
    }

    func test_permissionStatus_minimumGranted_onlyDependsOnAccessibility() {
        let grantedStatus = PermissionsManager.PermissionStatus(
            accessibility: true,
            camera: .notDetermined,
            calendar: .notDetermined
        )
        XCTAssertTrue(grantedStatus.minimumGranted)

        let deniedStatus = PermissionsManager.PermissionStatus(
            accessibility: false,
            camera: .notDetermined,
            calendar: .notDetermined
        )
        XCTAssertFalse(deniedStatus.minimumGranted)
    }

    // MARK: - Combined Status Property

    func test_status_returnsPermissionStatusStruct() {
        let status = PermissionsManager.shared.status
        // Verify the struct has the expected fields.
        _ = status.accessibility
        _ = status.camera
        _ = status.calendar
        _ = status.allGranted
        _ = status.minimumGranted
        // If this compiles and runs, the struct shape is correct.
    }

    func test_status_accessibilityMatchesDirectProperty() {
        let manager = PermissionsManager.shared
        let status = manager.status
        XCTAssertEqual(status.accessibility, manager.isAccessibilityGranted,
                       "status.accessibility should match isAccessibilityGranted")
    }

    func test_status_cameraMatchesDirectProperty() {
        let manager = PermissionsManager.shared
        let status = manager.status
        XCTAssertEqual(status.camera, manager.cameraAuthorizationStatus,
                       "status.camera should match cameraAuthorizationStatus")
    }

    func test_status_calendarMatchesDirectProperty() {
        let manager = PermissionsManager.shared
        let status = manager.status
        XCTAssertEqual(status.calendar, manager.calendarAuthorizationStatus,
                       "status.calendar should match calendarAuthorizationStatus")
    }

    // MARK: - Check All (smoke test)

    func test_checkAll_doesNotCrash() {
        // checkAll just logs -- it should not throw or crash.
        PermissionsManager.shared.checkAll()
    }

    // MARK: - System Settings URL Construction (compile-time verification)

    func test_accessibilitySettingsURL_isValid() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        let url = URL(string: urlString)
        XCTAssertNotNil(url, "Accessibility settings URL should be valid")
        XCTAssertTrue(url!.absoluteString.contains("Privacy_Accessibility"))
    }

    func test_cameraSettingsURL_isValid() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        let url = URL(string: urlString)
        XCTAssertNotNil(url, "Camera settings URL should be valid")
        XCTAssertTrue(url!.absoluteString.contains("Privacy_Camera"))
    }

    func test_calendarSettingsURL_isValid() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        let url = URL(string: urlString)
        XCTAssertNotNil(url, "Calendar settings URL should be valid")
        XCTAssertTrue(url!.absoluteString.contains("Privacy_Calendars"))
    }

    func test_settingsURLs_useCorrectScheme() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
        ]
        for urlString in urls {
            let url = URL(string: urlString)!
            XCTAssertTrue(url.absoluteString.hasPrefix("x-apple.systempreferences:"),
                          "Settings URLs should use x-apple.systempreferences scheme")
        }
    }
}
