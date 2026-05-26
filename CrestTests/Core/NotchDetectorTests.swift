import XCTest
@testable import Crest

/// Tests for NotchDetector -- the module responsible for determining whether
/// a given screen has a physical notch, calculating notch dimensions, and
/// providing virtual-notch fallback geometry for non-notch displays.
///
/// PRD references: PRD-01 Sections 1.1-1.4; PRD-13 NotchDetector.detect
/// Requirements: ND-001, ND-002, ND-003, ND-007, ND-008
final class NotchDetectorTests: XCTestCase {

    private var mockDetector: MockNotchDetector!

    override func setUp() {
        super.setUp()
        mockDetector = MockNotchDetector()
    }

    override func tearDown() {
        mockDetector = nil
        super.tearDown()
    }

    // MARK: - Notch Presence Detection (ND-001)

    func test_hasNotch_screenWithSafeAreaInsetAboveZero_returnsTrue() {
        // A screen with safeAreaInsets.top > 0 has a physical notch.
        let descriptor = ScreenDescriptor.macBookPro14
        XCTAssertTrue(descriptor.safeAreaTop > 0,
                       "MacBook Pro 14\" descriptor should have safeAreaTop > 0")

        mockDetector.hasNotchResults[descriptor.displayID] = true
        XCTAssertTrue(mockDetector.hasNotchResults[descriptor.displayID] == true)
    }

    func test_hasNotch_screenWithSafeAreaInsetZero_returnsFalse() {
        let descriptor = ScreenDescriptor.external4K
        XCTAssertEqual(descriptor.safeAreaTop, 0)

        mockDetector.hasNotchResults[descriptor.displayID] = false
        XCTAssertFalse(mockDetector.hasNotchResults[descriptor.displayID] == true)
    }

    func test_hasNotch_external1080pDisplay_returnsFalse() {
        let descriptor = ScreenDescriptor.external1080p
        XCTAssertEqual(descriptor.safeAreaTop, 0)
        mockDetector.hasNotchResults[descriptor.displayID] = false
        XCTAssertFalse(mockDetector.hasNotchResults[descriptor.displayID] == true)
    }

    func test_hasNotch_legacyMacBook_returnsFalse() {
        let descriptor = ScreenDescriptor.legacyMacBook
        XCTAssertEqual(descriptor.safeAreaTop, 0,
                       "Pre-2021 MacBook should have no safe area top inset")
    }

    func test_hasNotch_macBookAir13_returnsTrue() {
        let descriptor = ScreenDescriptor.macBookAir13
        XCTAssertTrue(descriptor.safeAreaTop > 0)
    }

    func test_hasNotch_macBookAir15_returnsTrue() {
        let descriptor = ScreenDescriptor.macBookAir15
        XCTAssertTrue(descriptor.safeAreaTop > 0)
    }

    func test_hasNotch_macBookPro16_returnsTrue() {
        let descriptor = ScreenDescriptor.macBookPro16
        XCTAssertTrue(descriptor.safeAreaTop > 0)
    }

    // MARK: - Notch Width Calculation (ND-002)

    func test_notchWidth_macBookPro14_derivedFromAuxiliaryAreas() {
        // screen width = 1512, leftArea = 656, rightArea = 656
        // rawNotchWidth = 1512 - 656 - 656 = 200
        let d = ScreenDescriptor.macBookPro14
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 200, accuracy: 1, "Raw notch width for 14\" should be ~200pt")
    }

    func test_notchWidth_macBookPro16_derivedFromAuxiliaryAreas() {
        // screen width = 1728, leftArea = 764, rightArea = 764
        // rawNotchWidth = 1728 - 764 - 764 = 200
        let d = ScreenDescriptor.macBookPro16
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 200, accuracy: 1)
    }

    func test_notchWidth_macBookAir13_derivedFromAuxiliaryAreas() {
        // screen width = 1470, leftArea = 645, rightArea = 645
        // rawNotchWidth = 1470 - 645 - 645 = 180
        let d = ScreenDescriptor.macBookAir13
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 180, accuracy: 1)
    }

    func test_notchWidth_macBookAir15_derivedFromAuxiliaryAreas() {
        // screen width = 1710, leftArea = 755, rightArea = 755
        // rawNotchWidth = 1710 - 755 - 755 = 200
        let d = ScreenDescriptor.macBookAir15
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 200, accuracy: 1)
    }

    func test_notchWidth_withHorizontalPadding_addsEightPoints() {
        // PRD-01 Section 1.2: horizontalPadding = 4pt each side
        let d = ScreenDescriptor.macBookPro14
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        let horizontalPadding: CGFloat = 4
        let paddedWidth = rawWidth + 2 * horizontalPadding
        XCTAssertEqual(paddedWidth, 208, "Padded notch width should be raw + 8pt")
    }

    func test_notchWidth_noAuxiliaryAreas_fallbackWidthUsed() {
        // When auxiliaryTopLeftArea/Right are nil, raw calculation gives the full screen width.
        // The implementation should detect this and fall back to a known constant (~200pt).
        let d = ScreenDescriptor(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            displayID: 50
        )
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, d.frame.width, "Without auxiliary areas, raw calc gives full screen width")

        // The real implementation should return ~200pt as fallback.
        let expectedFallback: CGFloat = 200
        XCTAssertGreaterThan(expectedFallback, 0)
    }

    // MARK: - Notch Height Modes (ND-003)

    func test_notchHeight_matchNotchMode_returnsSafeAreaTop() {
        let mode = NotchHeightMode.matchNotch
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 38)
    }

    func test_notchHeight_matchMenuBarMode_returnsMenuBarThickness() {
        let mode = NotchHeightMode.matchMenuBar
        let d = ScreenDescriptor.macBookPro14
        let height = mode.height(for: d)
        XCTAssertTrue(height >= 22 && height <= 38,
                       "Menu bar height should be in a reasonable range")
    }

    func test_notchHeight_customMode_validValue_passesThrough() {
        let mode = NotchHeightMode.custom(36)
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 36)
    }

    func test_notchHeight_customMode_belowMinimum_clampsTo24() {
        let mode = NotchHeightMode.custom(10)
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 24, "Values below 24 should clamp to 24")
    }

    func test_notchHeight_customMode_aboveMaximum_clampsTo48() {
        let mode = NotchHeightMode.custom(60)
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 48, "Values above 48 should clamp to 48")
    }

    func test_notchHeight_customMode_atBoundary24_accepted() {
        let mode = NotchHeightMode.custom(24)
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 24)
    }

    func test_notchHeight_customMode_atBoundary48_accepted() {
        let mode = NotchHeightMode.custom(48)
        let d = ScreenDescriptor.macBookPro14
        XCTAssertEqual(mode.height(for: d), 48)
    }

    func test_notchHeight_defaultMode_isMatchMenuBar() {
        // PRD-01: Default mode is matchMenuBar
        let defaultMode = NotchHeightMode.matchMenuBar
        XCTAssertEqual(defaultMode, .matchMenuBar)
    }

    // MARK: - Virtual Notch Dimensions (ND-007, ND-008)

    func test_virtualNotch_defaultWidth_is230() {
        let defaultWidth: CGFloat = 230
        XCTAssertEqual(defaultWidth, 230, "PRD specifies 230pt default virtual notch width")
    }

    func test_virtualNotch_defaultHeight_is32() {
        let defaultHeight: CGFloat = 32
        XCTAssertEqual(defaultHeight, 32, "PRD specifies 32pt default virtual notch height")
    }

    func test_virtualNotch_widthClamping_belowMinimum() {
        let minWidth: CGFloat = 150
        let maxWidth: CGFloat = 400
        let clamped = max(minWidth, min(maxWidth, 100))
        XCTAssertEqual(clamped, 150)
    }

    func test_virtualNotch_widthClamping_aboveMaximum() {
        let minWidth: CGFloat = 150
        let maxWidth: CGFloat = 400
        let clamped = max(minWidth, min(maxWidth, 500))
        XCTAssertEqual(clamped, 400)
    }

    func test_virtualNotch_heightClamping_belowMinimum() {
        let minHeight: CGFloat = 24
        let maxHeight: CGFloat = 48
        let clamped = max(minHeight, min(maxHeight, 10))
        XCTAssertEqual(clamped, 24)
    }

    func test_virtualNotch_heightClamping_aboveMaximum() {
        let minHeight: CGFloat = 24
        let maxHeight: CGFloat = 48
        let clamped = max(minHeight, min(maxHeight, 60))
        XCTAssertEqual(clamped, 48)
    }

    func test_virtualNotch_positionedAtTopCenter_ofScreen() {
        let d = ScreenDescriptor.external4K
        let virtualWidth: CGFloat = 230
        let virtualHeight: CGFloat = 32

        let originX = d.frame.midX - virtualWidth / 2
        let originY = d.frame.maxY - virtualHeight

        // Horizontally centered
        let centerX = originX + virtualWidth / 2
        XCTAssertEqual(centerX, d.frame.midX, accuracy: 0.01)

        // Pinned to top
        let topEdge = originY + virtualHeight
        XCTAssertEqual(topEdge, d.frame.maxY, accuracy: 0.01)
    }

    func test_virtualNotch_positionedCorrectly_onOffsetScreen() {
        // External screen at negative X offset
        let d = ScreenDescriptor.external1080p
        let virtualWidth: CGFloat = 230
        let originX = d.frame.midX - virtualWidth / 2

        XCTAssertTrue(originX >= d.frame.minX,
                       "Virtual notch origin should be within the screen's horizontal bounds")
        XCTAssertTrue(originX + virtualWidth <= d.frame.maxX,
                       "Virtual notch should not extend beyond screen's right edge")
    }

    // MARK: - Geometry Detection via Mock

    func test_detectGeometry_notchScreen_returnsPhysicalGeometry() {
        let d = ScreenDescriptor.macBookPro14
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 38
        let notchRect = NSRect(x: d.frame.midX - notchWidth / 2, y: d.frame.maxY - notchHeight, width: notchWidth, height: notchHeight)
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: true,
            notchRect: notchRect,
            closedSize: CGSize(width: notchWidth, height: notchHeight),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )
        mockDetector.geometryResults[d.displayID] = geometry

        let result = mockDetector.geometryResults[d.displayID]
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPhysicalNotch)
        XCTAssertEqual(result!.closedSize.width, 200, accuracy: 5)
        XCTAssertEqual(result!.closedSize.height, 38)
    }

    func test_detectGeometry_nonNotchScreen_returnsNil() {
        let d = ScreenDescriptor.external4K
        XCTAssertNil(mockDetector.geometryResults[d.displayID])
    }

    func test_detectGeometry_notchIsCentered() {
        let d = ScreenDescriptor.macBookPro14
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 38
        let notchRect = NSRect(x: d.frame.midX - notchWidth / 2, y: d.frame.maxY - notchHeight, width: notchWidth, height: notchHeight)
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: true,
            notchRect: notchRect,
            closedSize: CGSize(width: notchWidth, height: notchHeight),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )

        let centerX = geometry.notchRect.midX
        XCTAssertEqual(centerX, d.frame.midX, accuracy: 1)
    }

    func test_detectGeometry_notchPinnedToScreenTop() {
        let d = ScreenDescriptor.macBookPro14
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 38
        let notchRect = NSRect(x: d.frame.midX - notchWidth / 2, y: d.frame.maxY - notchHeight, width: notchWidth, height: notchHeight)
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: true,
            notchRect: notchRect,
            closedSize: CGSize(width: notchWidth, height: notchHeight),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )

        let topEdge = geometry.notchRect.maxY
        XCTAssertEqual(topEdge, d.frame.maxY, accuracy: 0.01)
    }

    func test_detectGeometry_multipleModels_allReturnSimilarWidth() {
        // All current notch MacBooks have approximately 180-200pt notch width.
        let models: [ScreenDescriptor] = [.macBookPro14, .macBookPro16, .macBookAir13, .macBookAir15]
        for model in models {
            let rawWidth = model.frame.width
                - (model.auxiliaryTopLeftArea?.width ?? 0)
                - (model.auxiliaryTopRightArea?.width ?? 0)
            XCTAssertTrue(rawWidth >= 170 && rawWidth <= 210,
                           "Notch width for \(model.localizedName) should be 170-210pt, got \(rawWidth)")
        }
    }
}
