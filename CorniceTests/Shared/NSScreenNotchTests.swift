import XCTest
import AppKit
@testable import Cornice

/// Tests for NSScreen+Notch extension -- computed properties for notch detection,
/// notch dimensions, and display UUID generation.
///
/// Since NSScreen depends on actual display hardware, these tests verify the
/// logic and consistency of the extension methods on the screens available
/// in the test environment, as well as value range correctness.
final class NSScreenNotchTests: XCTestCase {

    // MARK: - hasNotch Property

    func test_hasNotch_returnsConsistentValue() {
        guard let screen = NSScreen.main else {
            // No screen available (headless CI) -- skip gracefully.
            return
        }
        let first = screen.hasNotch
        let second = screen.hasNotch
        XCTAssertEqual(first, second,
                       "hasNotch should return the same value on consecutive calls")
    }

    func test_hasNotch_matchesSafeAreaInsetsLogic() {
        guard let screen = NSScreen.main else { return }
        let expected = screen.safeAreaInsets.top > 0
        XCTAssertEqual(screen.hasNotch, expected,
                       "hasNotch should be true iff safeAreaInsets.top > 0")
    }

    func test_hasNotch_allScreensReportBool() {
        for screen in NSScreen.screens {
            // Just verify it returns without crashing.
            _ = screen.hasNotch
        }
    }

    // MARK: - notchWidth Property

    func test_notchWidth_isNilForNonNotchScreen() {
        guard let screen = NSScreen.main else { return }
        if !screen.hasNotch {
            XCTAssertNil(screen.notchWidth,
                         "notchWidth should be nil for screens without a notch")
        }
    }

    func test_notchWidth_isPositiveForNotchScreen() {
        guard let screen = NSScreen.main, screen.hasNotch else { return }
        let width = screen.notchWidth
        XCTAssertNotNil(width, "notchWidth should not be nil for notch screens")
        if let width {
            XCTAssertGreaterThan(width, 0, "notchWidth should be positive")
        }
    }

    func test_notchWidth_includesHorizontalPadding() {
        guard let screen = NSScreen.main, screen.hasNotch else { return }
        guard let width = screen.notchWidth else { return }
        // The width formula adds 2 * horizontalPadding to the raw width.
        // So notchWidth should be at least 2 * padding.
        let minPaddedWidth = 2 * NotchDetector.horizontalPadding
        XCTAssertGreaterThanOrEqual(width, minPaddedWidth,
                                     "notchWidth should include horizontal padding on both sides")
    }

    func test_notchWidth_lessOrEqualToScreenWidth() {
        guard let screen = NSScreen.main, screen.hasNotch else { return }
        guard let width = screen.notchWidth else { return }
        XCTAssertLessThanOrEqual(width, screen.frame.width,
                                  "notchWidth should not exceed screen width")
    }

    func test_notchWidth_consistentAcrossCalls() {
        guard let screen = NSScreen.main, screen.hasNotch else { return }
        let width1 = screen.notchWidth
        let width2 = screen.notchWidth
        XCTAssertEqual(width1, width2,
                       "notchWidth should return the same value on consecutive calls")
    }

    // MARK: - notchHeight Property

    func test_notchHeight_isZeroForNonNotchScreen() {
        guard let screen = NSScreen.main else { return }
        if !screen.hasNotch {
            XCTAssertEqual(screen.notchHeight, 0,
                           "notchHeight should be 0 for screens without a notch")
        }
    }

    func test_notchHeight_isPositiveForNotchScreen() {
        guard let screen = NSScreen.main, screen.hasNotch else { return }
        XCTAssertGreaterThan(screen.notchHeight, 0,
                              "notchHeight should be positive for notch screens")
    }

    func test_notchHeight_matchesSafeAreaTop() {
        guard let screen = NSScreen.main else { return }
        XCTAssertEqual(screen.notchHeight, screen.safeAreaInsets.top,
                       "notchHeight should equal safeAreaInsets.top")
    }

    func test_notchHeight_nonNegativeForAllScreens() {
        for screen in NSScreen.screens {
            XCTAssertGreaterThanOrEqual(screen.notchHeight, 0,
                                        "notchHeight should never be negative")
        }
    }

    func test_notchHeight_consistentAcrossCalls() {
        guard let screen = NSScreen.main else { return }
        let height1 = screen.notchHeight
        let height2 = screen.notchHeight
        XCTAssertEqual(height1, height2,
                       "notchHeight should return the same value on consecutive calls")
    }

    // MARK: - displayUUID Property

    func test_displayUUID_isNotEmpty() {
        guard let screen = NSScreen.main else { return }
        XCTAssertFalse(screen.displayUUID.isEmpty,
                       "displayUUID should not be an empty string")
    }

    func test_displayUUID_consistentAcrossCalls() {
        guard let screen = NSScreen.main else { return }
        let uuid1 = screen.displayUUID
        let uuid2 = screen.displayUUID
        XCTAssertEqual(uuid1, uuid2,
                       "displayUUID should return the same value on consecutive calls")
    }

    func test_displayUUID_uniquePerScreen() {
        let screens = NSScreen.screens
        guard screens.count >= 2 else { return }
        let uuids = screens.map { $0.displayUUID }
        let uniqueUUIDs = Set(uuids)
        XCTAssertEqual(uuids.count, uniqueUUIDs.count,
                       "Each screen should have a unique displayUUID")
    }

    func test_displayUUID_allScreensReturnNonEmpty() {
        for screen in NSScreen.screens {
            XCTAssertFalse(screen.displayUUID.isEmpty,
                           "Every screen's displayUUID should be non-empty")
        }
    }

    // MARK: - Consistency Between Properties

    func test_hasNotch_false_impliesNotchWidthNil() {
        for screen in NSScreen.screens where !screen.hasNotch {
            XCTAssertNil(screen.notchWidth,
                         "Non-notch screen should have nil notchWidth")
        }
    }

    func test_hasNotch_false_impliesNotchHeightZero() {
        for screen in NSScreen.screens where !screen.hasNotch {
            XCTAssertEqual(screen.notchHeight, 0,
                           "Non-notch screen should have notchHeight == 0")
        }
    }

    func test_hasNotch_true_impliesNotchWidthNotNil() {
        for screen in NSScreen.screens where screen.hasNotch {
            XCTAssertNotNil(screen.notchWidth,
                            "Notch screen should have non-nil notchWidth")
        }
    }

    func test_hasNotch_true_impliesNotchHeightPositive() {
        for screen in NSScreen.screens where screen.hasNotch {
            XCTAssertGreaterThan(screen.notchHeight, 0,
                                  "Notch screen should have positive notchHeight")
        }
    }

    // MARK: - NotchDetector.displayUUID Consistency

    func test_displayUUID_matchesNotchDetectorMethod() {
        guard let screen = NSScreen.main else { return }
        let extensionUUID = screen.displayUUID
        let detectorUUID = NotchDetector.displayUUID(for: screen.screenDisplayID)
        XCTAssertEqual(extensionUUID, detectorUUID,
                       "NSScreen.displayUUID should match NotchDetector.displayUUID")
    }
}
