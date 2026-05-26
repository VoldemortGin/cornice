import XCTest
@testable import Cornice

/// Tests for AppConstants -- app-wide constant values for notch dimensions,
/// timing, virtual notch defaults, and URLs.
final class AppConstantsTests: XCTestCase {

    // MARK: - App Identity

    func test_bundleIdentifier_isNotEmpty() {
        XCTAssertFalse(AppConstants.bundleIdentifier.isEmpty,
                       "Bundle identifier should not be empty")
    }

    func test_appName_isCornice() {
        XCTAssertEqual(AppConstants.appName, "Cornice")
    }

    func test_version_isNotEmpty() {
        XCTAssertFalse(AppConstants.version.isEmpty,
                       "Version string should not be empty")
    }

    func test_version_hasDotSeparatedFormat() {
        // Version should look like "X.Y.Z" or at least "X.Y"
        let components = AppConstants.version.split(separator: ".")
        XCTAssertGreaterThanOrEqual(components.count, 2,
                                     "Version should have at least major.minor format")
    }

    func test_buildNumber_isNotEmpty() {
        XCTAssertFalse(AppConstants.buildNumber.isEmpty,
                       "Build number should not be empty")
    }

    // MARK: - NotchDefaults

    func test_notchDefaults_physicalWidth_isPositive() {
        XCTAssertGreaterThan(AppConstants.NotchDefaults.physicalWidth, 0,
                              "Physical notch width should be positive")
    }

    func test_notchDefaults_physicalWidth_isReasonable() {
        // Physical notch is approximately 200 points on MacBook Pro.
        let width = AppConstants.NotchDefaults.physicalWidth
        XCTAssertGreaterThanOrEqual(width, 100, "Physical width should be at least 100")
        XCTAssertLessThanOrEqual(width, 400, "Physical width should be at most 400")
    }

    func test_notchDefaults_physicalHeight_isPositive() {
        XCTAssertGreaterThan(AppConstants.NotchDefaults.physicalHeight, 0,
                              "Physical notch height should be positive")
    }

    func test_notchDefaults_physicalHeight_isReasonable() {
        let height = AppConstants.NotchDefaults.physicalHeight
        XCTAssertGreaterThanOrEqual(height, 20, "Physical height should be at least 20")
        XCTAssertLessThanOrEqual(height, 60, "Physical height should be at most 60")
    }

    func test_notchDefaults_closedTopRadius_isPositive() {
        XCTAssertGreaterThan(AppConstants.NotchDefaults.closedTopRadius, 0)
    }

    func test_notchDefaults_closedBottomRadius_isPositive() {
        XCTAssertGreaterThan(AppConstants.NotchDefaults.closedBottomRadius, 0)
    }

    func test_notchDefaults_bottomRadius_greaterThanTopRadius() {
        XCTAssertGreaterThan(
            AppConstants.NotchDefaults.closedBottomRadius,
            AppConstants.NotchDefaults.closedTopRadius,
            "Bottom radius should be larger than top radius for the closed state"
        )
    }

    // MARK: - VirtualNotch Defaults

    func test_virtualNotch_defaultWidth_isPositive() {
        XCTAssertGreaterThan(AppConstants.VirtualNotch.defaultWidth, 0)
    }

    func test_virtualNotch_defaultHeight_isPositive() {
        XCTAssertGreaterThan(AppConstants.VirtualNotch.defaultHeight, 0)
    }

    func test_virtualNotch_minWidth_lessOrEqualDefault() {
        XCTAssertLessThanOrEqual(
            AppConstants.VirtualNotch.minWidth,
            AppConstants.VirtualNotch.defaultWidth,
            "Minimum width should be less than or equal to default width"
        )
    }

    func test_virtualNotch_maxWidth_greaterOrEqualDefault() {
        XCTAssertGreaterThanOrEqual(
            AppConstants.VirtualNotch.maxWidth,
            AppConstants.VirtualNotch.defaultWidth,
            "Maximum width should be greater than or equal to default width"
        )
    }

    func test_virtualNotch_minWidth_lessThanMaxWidth() {
        XCTAssertLessThan(
            AppConstants.VirtualNotch.minWidth,
            AppConstants.VirtualNotch.maxWidth,
            "Minimum width must be less than maximum width"
        )
    }

    func test_virtualNotch_minHeight_lessOrEqualDefault() {
        XCTAssertLessThanOrEqual(
            AppConstants.VirtualNotch.minHeight,
            AppConstants.VirtualNotch.defaultHeight,
            "Minimum height should be less than or equal to default height"
        )
    }

    func test_virtualNotch_maxHeight_greaterOrEqualDefault() {
        XCTAssertGreaterThanOrEqual(
            AppConstants.VirtualNotch.maxHeight,
            AppConstants.VirtualNotch.defaultHeight,
            "Maximum height should be greater than or equal to default height"
        )
    }

    func test_virtualNotch_minHeight_lessThanMaxHeight() {
        XCTAssertLessThan(
            AppConstants.VirtualNotch.minHeight,
            AppConstants.VirtualNotch.maxHeight,
            "Minimum height must be less than maximum height"
        )
    }

    func test_virtualNotch_allDimensions_arePositive() {
        XCTAssertGreaterThan(AppConstants.VirtualNotch.minWidth, 0)
        XCTAssertGreaterThan(AppConstants.VirtualNotch.maxWidth, 0)
        XCTAssertGreaterThan(AppConstants.VirtualNotch.minHeight, 0)
        XCTAssertGreaterThan(AppConstants.VirtualNotch.maxHeight, 0)
    }

    // MARK: - Timing Constants

    func test_timing_hoverDelay_isPositive() {
        XCTAssertGreaterThan(AppConstants.Timing.hoverDelay, 0)
    }

    func test_timing_hoverDelay_isReasonable() {
        // Hover delay should be under 1 second for responsiveness.
        XCTAssertLessThanOrEqual(AppConstants.Timing.hoverDelay, 1.0,
                                  "Hover delay should be 1 second or less")
    }

    func test_timing_collapseDelay_isPositive() {
        XCTAssertGreaterThan(AppConstants.Timing.collapseDelay, 0)
    }

    func test_timing_collapseDelay_greaterThanHoverDelay() {
        XCTAssertGreaterThan(
            AppConstants.Timing.collapseDelay,
            AppConstants.Timing.hoverDelay,
            "Collapse delay should be longer than hover delay"
        )
    }

    func test_timing_sneakPeekDuration_isPositive() {
        XCTAssertGreaterThan(AppConstants.Timing.sneakPeekDuration, 0)
    }

    func test_timing_sneakPeekDuration_isReasonable() {
        let duration = AppConstants.Timing.sneakPeekDuration
        XCTAssertGreaterThanOrEqual(duration, 1.0, "Sneak peek should last at least 1 second")
        XCTAssertLessThanOrEqual(duration, 10.0, "Sneak peek should last no more than 10 seconds")
    }

    func test_timing_hudDuration_isPositive() {
        XCTAssertGreaterThan(AppConstants.Timing.hudDuration, 0)
    }

    func test_timing_hudDuration_isReasonable() {
        let duration = AppConstants.Timing.hudDuration
        XCTAssertGreaterThanOrEqual(duration, 0.5, "HUD should last at least 0.5 seconds")
        XCTAssertLessThanOrEqual(duration, 5.0, "HUD should last no more than 5 seconds")
    }

    func test_timing_hudDuration_lessThanOrEqualSneakPeek() {
        XCTAssertLessThanOrEqual(
            AppConstants.Timing.hudDuration,
            AppConstants.Timing.sneakPeekDuration,
            "HUD duration should be shorter than or equal to sneak peek duration"
        )
    }

    // MARK: - URLs

    func test_urls_websiteIsValid() {
        let url = AppConstants.URLs.website
        XCTAssertNotNil(url.scheme, "Website URL should have a scheme")
        XCTAssertEqual(url.scheme, "https", "Website URL should use https")
        XCTAssertNotNil(url.host, "Website URL should have a host")
    }

    func test_urls_supportIsValid() {
        let url = AppConstants.URLs.support
        XCTAssertNotNil(url.scheme, "Support URL should have a scheme")
        XCTAssertEqual(url.scheme, "https", "Support URL should use https")
        XCTAssertNotNil(url.host, "Support URL should have a host")
    }

    func test_urls_privacyIsValid() {
        let url = AppConstants.URLs.privacy
        XCTAssertNotNil(url.scheme, "Privacy URL should have a scheme")
        XCTAssertEqual(url.scheme, "https", "Privacy URL should use https")
        XCTAssertNotNil(url.host, "Privacy URL should have a host")
    }

    func test_urls_allShareSameHost() {
        let hosts = [
            AppConstants.URLs.website.host,
            AppConstants.URLs.support.host,
            AppConstants.URLs.privacy.host,
        ]
        let uniqueHosts = Set(hosts.compactMap { $0 })
        XCTAssertEqual(uniqueHosts.count, 1,
                       "All URLs should share the same host domain")
    }

    func test_urls_absoluteStringsAreNotEmpty() {
        XCTAssertFalse(AppConstants.URLs.website.absoluteString.isEmpty)
        XCTAssertFalse(AppConstants.URLs.support.absoluteString.isEmpty)
        XCTAssertFalse(AppConstants.URLs.privacy.absoluteString.isEmpty)
    }
}
