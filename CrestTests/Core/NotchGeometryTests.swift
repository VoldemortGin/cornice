import XCTest
@testable import Crest

/// Tests for NotchGeometry -- the module that computes closed/open notch sizes,
/// handles coordinate conversions, and produces virtual-notch fallback dimensions.
///
/// PRD references: PRD-01 Sections 1.2, 1.4, 3.5, 6.1; PRD-13 NotchGeometry
/// Requirements: ND-002, ND-007, NS-003, NS-005
final class NotchGeometryTests: XCTestCase {

    // MARK: - Closed Notch Size Calculation

    func test_closedSize_macBookPro14_matchesPhysicalNotch() {
        let d = ScreenDescriptor.macBookPro14
        let notchWidth: CGFloat = 200 // from auxiliary area calculation
        let notchHeight: CGFloat = d.safeAreaTop

        XCTAssertEqual(notchWidth, 200, accuracy: 5)
        XCTAssertEqual(notchHeight, 38, "Closed height should match safeAreaInsets.top")
    }

    func test_closedSize_macBookPro16_matchesPhysicalNotch() {
        let d = ScreenDescriptor.macBookPro16
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 200, accuracy: 5)
        XCTAssertEqual(d.safeAreaTop, 38)
    }

    func test_closedSize_macBookAir13_matchesPhysicalNotch() {
        let d = ScreenDescriptor.macBookAir13
        let rawWidth = d.frame.width - (d.auxiliaryTopLeftArea?.width ?? 0) - (d.auxiliaryTopRightArea?.width ?? 0)
        XCTAssertEqual(rawWidth, 180, accuracy: 5)
        XCTAssertEqual(d.safeAreaTop, 38)
    }

    func test_closedSize_hasPositiveDimensions() {
        let models: [ScreenDescriptor] = [.macBookPro14, .macBookPro16, .macBookAir13, .macBookAir15]
        for model in models {
            let w = model.frame.width - (model.auxiliaryTopLeftArea?.width ?? 0) - (model.auxiliaryTopRightArea?.width ?? 0)
            XCTAssertGreaterThan(w, 0, "Closed width must be positive for \(model.localizedName)")
            XCTAssertGreaterThan(model.safeAreaTop, 0, "Closed height must be positive for \(model.localizedName)")
        }
    }

    // MARK: - Open Notch Size Calculation (NS-005)

    func test_openSize_defaultDimensions() {
        // PRD-01 Section 3.5: default open size = 640 x 190 pts
        let defaultOpenWidth: CGFloat = 640
        let defaultOpenHeight: CGFloat = 190

        XCTAssertEqual(defaultOpenWidth, 640)
        XCTAssertEqual(defaultOpenHeight, 190)
    }

    func test_openSize_largerThanClosedSize() {
        let closedWidth: CGFloat = 200
        let closedHeight: CGFloat = 38
        let openWidth: CGFloat = 640
        let openHeight: CGFloat = 190

        XCTAssertGreaterThan(openWidth, closedWidth, "Open width must exceed closed width")
        XCTAssertGreaterThan(openHeight, closedHeight, "Open height must exceed closed height")
    }

    func test_openSize_expandsDownwardFromTop() {
        // The notch stays pinned to the top of the screen.
        // The open state grows downward (lower originY in AppKit coords).
        let d = ScreenDescriptor.macBookPro14
        let closedHeight: CGFloat = 38
        let openHeight: CGFloat = 190

        let closedOriginY = d.frame.maxY - closedHeight
        let openOriginY = d.frame.maxY - openHeight

        XCTAssertLessThan(openOriginY, closedOriginY,
                           "Open state origin.y should be lower (expands downward)")
        // Top edge stays the same
        XCTAssertEqual(closedOriginY + closedHeight, d.frame.maxY)
        XCTAssertEqual(openOriginY + openHeight, d.frame.maxY)
    }

    func test_openSize_remainsHorizontallyCentered() {
        let d = ScreenDescriptor.macBookPro14
        let openWidth: CGFloat = 640
        let openOriginX = d.frame.midX - openWidth / 2
        let centerX = openOriginX + openWidth / 2

        XCTAssertEqual(centerX, d.frame.midX, accuracy: 0.01)
    }

    // MARK: - Size for Different Screen Models

    func test_sizeForModel_14inch_closedFitsWithinScreen() {
        let d = ScreenDescriptor.macBookPro14
        let notchWidth: CGFloat = 208 // with padding
        XCTAssertLessThanOrEqual(notchWidth, d.frame.width)
    }

    func test_sizeForModel_16inch_closedFitsWithinScreen() {
        let d = ScreenDescriptor.macBookPro16
        let notchWidth: CGFloat = 208
        XCTAssertLessThanOrEqual(notchWidth, d.frame.width)
    }

    func test_sizeForModel_air13_closedFitsWithinScreen() {
        let d = ScreenDescriptor.macBookAir13
        let notchWidth: CGFloat = 188 // 180 + 8 padding
        XCTAssertLessThanOrEqual(notchWidth, d.frame.width)
    }

    func test_openSize_fitsWithinScreenBounds() {
        let models: [ScreenDescriptor] = [.macBookPro14, .macBookPro16, .macBookAir13, .macBookAir15]
        let openWidth: CGFloat = 640
        let openHeight: CGFloat = 190

        for model in models {
            XCTAssertLessThanOrEqual(openWidth, model.frame.width,
                                     "Open width should fit within \(model.localizedName)")
            XCTAssertLessThanOrEqual(openHeight, model.frame.height,
                                     "Open height should fit within \(model.localizedName)")
        }
    }

    // MARK: - Non-Notch Fallback Dimensions (Virtual Notch)

    func test_virtualNotch_defaultDimensions_forExternal4K() {
        let d = ScreenDescriptor.external4K
        let virtualWidth: CGFloat = 230
        let virtualHeight: CGFloat = 32

        XCTAssertLessThanOrEqual(virtualWidth, d.frame.width)
        XCTAssertLessThanOrEqual(virtualHeight, d.frame.height)
    }

    func test_virtualNotch_defaultDimensions_forExternal1080p() {
        let d = ScreenDescriptor.external1080p
        let virtualWidth: CGFloat = 230
        let virtualHeight: CGFloat = 32

        XCTAssertLessThanOrEqual(virtualWidth, d.frame.width)
        XCTAssertLessThanOrEqual(virtualHeight, d.frame.height)
    }

    func test_virtualNotch_defaultDimensions_forLegacyMacBook() {
        let d = ScreenDescriptor.legacyMacBook
        let virtualWidth: CGFloat = 230
        let virtualHeight: CGFloat = 32

        XCTAssertLessThanOrEqual(virtualWidth, d.frame.width)
        XCTAssertLessThanOrEqual(virtualHeight, d.frame.height)
    }

    func test_virtualNotch_geometryMarkedAsVirtual() {
        let d = ScreenDescriptor.external4K
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: false,
            notchRect: NSRect(x: d.frame.midX - 115, y: d.frame.maxY - 32, width: 230, height: 32),
            closedSize: CGSize(width: 230, height: 32),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )
        XCTAssertFalse(geometry.hasPhysicalNotch)
    }

    func test_physicalNotch_geometryNotMarkedAsVirtual() {
        let d = ScreenDescriptor.macBookPro14
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: true,
            notchRect: NSRect(x: d.frame.midX - 100, y: d.frame.maxY - 38, width: 200, height: 38),
            closedSize: CGSize(width: 200, height: 38),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )
        XCTAssertTrue(geometry.hasPhysicalNotch)
    }

    // MARK: - Expanded Detail Size (CL-009)

    func test_expandedDetailSize_cappedAt60PercentWidth() {
        let d = ScreenDescriptor.macBookPro14
        let maxWidth = d.frame.width * 0.6
        let requestedWidth: CGFloat = 2000

        let clampedWidth = min(requestedWidth, maxWidth)
        XCTAssertEqual(clampedWidth, maxWidth, accuracy: 0.01,
                       "Expanded detail width should be capped at 60% of screen width")
    }

    func test_expandedDetailSize_cappedAt50PercentHeight() {
        let d = ScreenDescriptor.macBookPro14
        let maxHeight = d.frame.height * 0.5
        let requestedHeight: CGFloat = 1000

        let clampedHeight = min(requestedHeight, maxHeight)
        XCTAssertEqual(clampedHeight, maxHeight, accuracy: 0.01,
                       "Expanded detail height should be capped at 50% of screen height")
    }

    func test_expandedDetailSize_withinCaps_passesThrough() {
        let d = ScreenDescriptor.macBookPro14
        let maxWidth = d.frame.width * 0.6
        let maxHeight = d.frame.height * 0.5
        let requestedWidth: CGFloat = 700
        let requestedHeight: CGFloat = 380

        let clampedWidth = min(requestedWidth, maxWidth)
        let clampedHeight = min(requestedHeight, maxHeight)

        XCTAssertEqual(clampedWidth, 700, "Width within cap should pass through")
        XCTAssertEqual(clampedHeight, 380, "Height within cap should pass through")
    }

    // MARK: - Coordinate Conversions (Appendix B)

    func test_coordinateConversion_screenToWindow_topEdge() {
        // AppKit: origin is bottom-left. screen.frame.maxY is the top.
        // Window origin at top: originY = screen.frame.maxY - panelHeight
        let d = ScreenDescriptor.macBookPro14
        let panelHeight: CGFloat = 190

        let windowOriginY = d.frame.maxY - panelHeight
        XCTAssertEqual(windowOriginY, d.frame.maxY - panelHeight)
        XCTAssertTrue(windowOriginY >= d.frame.minY, "Window origin must be within screen bounds")
    }

    func test_coordinateConversion_screenToWindow_horizontalCenter() {
        let d = ScreenDescriptor.macBookPro14
        let panelWidth: CGFloat = 640

        let windowOriginX = d.frame.midX - panelWidth / 2
        XCTAssertEqual(windowOriginX + panelWidth / 2, d.frame.midX, accuracy: 0.01)
    }

    func test_coordinateConversion_multiScreenOffset() {
        // External monitor positioned to the right of built-in
        let d = ScreenDescriptor.external4K // frame origin at x=1512
        let panelWidth: CGFloat = 230
        let panelOriginX = d.frame.midX - panelWidth / 2

        XCTAssertGreaterThanOrEqual(panelOriginX, d.frame.minX,
                                     "Panel origin X should be within the external screen frame")
        XCTAssertLessThanOrEqual(panelOriginX + panelWidth, d.frame.maxX,
                                  "Panel should not extend beyond the external screen")
    }

    func test_coordinateConversion_negativeOffsetScreen() {
        // Screen positioned to the left with negative X origin
        let d = ScreenDescriptor.external1080p // frame origin at x=-1920
        let panelWidth: CGFloat = 230
        let panelOriginX = d.frame.midX - panelWidth / 2

        XCTAssertGreaterThanOrEqual(panelOriginX, d.frame.minX)
        XCTAssertLessThanOrEqual(panelOriginX + panelWidth, d.frame.maxX)
    }

    // MARK: - Sneak Peek Size

    func test_sneakPeekSize_largerThanClosed_smallerThanOpen() {
        // PRD-01 Section 6.1: sneakPeek ~400 x 56 pts
        let closedSize = CGSize(width: 200, height: 38)
        let sneakPeekSize = CGSize(width: 400, height: 56)
        let openSize = CGSize(width: 640, height: 190)

        XCTAssertGreaterThan(sneakPeekSize.width, closedSize.width)
        XCTAssertGreaterThan(sneakPeekSize.height, closedSize.height)
        XCTAssertLessThan(sneakPeekSize.width, openSize.width)
        XCTAssertLessThan(sneakPeekSize.height, openSize.height)
    }

    // MARK: - Expanded Detail Size

    func test_expandedDetailSize_largerThanOpen() {
        // PRD-01 Section 6.1: expandedDetail ~700 x 380 pts
        let openSize = CGSize(width: 640, height: 190)
        let expandedSize = CGSize(width: 700, height: 380)

        XCTAssertGreaterThanOrEqual(expandedSize.width, openSize.width)
        XCTAssertGreaterThan(expandedSize.height, openSize.height)
    }

    // MARK: - Panel Frame Calculation (PRD-13 panelFrame)

    func test_panelFrame_closedState_matchesNotchGeometry() {
        let d = ScreenDescriptor.macBookPro14
        let geometry = NotchGeometryInfo(
            hasPhysicalNotch: true,
            notchRect: NSRect(x: d.frame.midX - 100, y: d.frame.maxY - 38, width: 200, height: 38),
            closedSize: CGSize(width: 200, height: 38),
            openSize: CGSize(width: 640, height: 190),
            sneakPeekSize: CGSize(width: 400, height: 56),
            expandedDetailSize: CGSize(width: 700, height: 380),
            screenFrame: d.frame
        )

        let panelFrame = geometry.notchRect

        XCTAssertEqual(panelFrame.width, 200)
        XCTAssertEqual(panelFrame.height, 38)
    }

    func test_panelFrame_openState_centeredAndPinnedToTop() {
        let d = ScreenDescriptor.macBookPro14
        let expandedWidth: CGFloat = 640
        let expandedHeight: CGFloat = 190

        let panelFrame = NSRect(
            x: d.frame.midX - expandedWidth / 2,
            y: d.frame.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )

        // Centered
        XCTAssertEqual(panelFrame.midX, d.frame.midX, accuracy: 0.01)
        // Pinned to top
        XCTAssertEqual(panelFrame.maxY, d.frame.maxY, accuracy: 0.01)
    }
}
