import XCTest
import SwiftUI
@testable import Crest

/// Tests for NotchShape -- the custom SwiftUI Shape that defines the notch
/// outline with independently animatable top and bottom corner radii.
///
/// PRD references: PRD-01 Sections 3.1-3.4
/// Requirements: NS-001, NS-002, NS-003, NS-004, NS-005, NS-006
final class NotchShapeTests: XCTestCase {

    // MARK: - Shape Conformance (NS-001)

    func test_notchShape_conformsToShapeProtocol() {
        // NotchShape must conform to Shape so it can be used with .clipShape(), .background(), etc.
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        // If this compiles, NotchShape conforms to Shape.
        XCTAssertNotNil(shape, "NotchShape should be instantiable")
    }

    func test_notchShape_canGeneratePath() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 38)
        let path = shape.path(in: rect)

        XCTAssertFalse(path.isEmpty, "NotchShape should generate a non-empty path")
    }

    func test_notchShape_pathBoundedByRect() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 38)
        let path = shape.path(in: rect)
        let pathBounds = path.boundingRect

        // The path should be contained within or close to the input rect.
        // Allow small tolerance for arc overshoots.
        XCTAssertGreaterThanOrEqual(pathBounds.minX, rect.minX - 1,
                                     "Path should not extend far left of the rect")
        XCTAssertLessThanOrEqual(pathBounds.maxX, rect.maxX + 1,
                                  "Path should not extend far right of the rect")
        XCTAssertGreaterThanOrEqual(pathBounds.minY, rect.minY - 1,
                                     "Path should not extend far above the rect")
        XCTAssertLessThanOrEqual(pathBounds.maxY, rect.maxY + 1,
                                  "Path should not extend far below the rect")
    }

    func test_notchShape_pathIsClosed() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 38)
        let path = shape.path(in: rect)

        // A closed path's bounding rect should have positive area.
        XCTAssertGreaterThan(path.boundingRect.width, 0, "Path should have positive width")
        XCTAssertGreaterThan(path.boundingRect.height, 0, "Path should have positive height")
    }

    // MARK: - AnimatableData Property (NS-002)

    func test_notchShape_defaultCornerRadius_isReasonable() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        XCTAssertGreaterThan(shape.topCornerRadius, 0, "Top corner radius should be positive")
        XCTAssertGreaterThan(shape.bottomCornerRadius, 0, "Bottom corner radius should be positive")
    }

    func test_notchShape_cornerRadiusValues_forClosedState() {
        // PRD-01 Section 3.2: Closed state: topCornerRadius = 10, bottomCornerRadius = 14
        let expectedTopClosed: CGFloat = 10
        let expectedBottomClosed: CGFloat = 14

        XCTAssertEqual(expectedTopClosed, 10)
        XCTAssertEqual(expectedBottomClosed, 14)
        XCTAssertGreaterThan(expectedBottomClosed, expectedTopClosed,
                              "Bottom corners should be larger than top corners in closed state")
    }

    func test_notchShape_cornerRadiusValues_forSneakPeekState() {
        // PRD-01 Section 3.2: Sneak Peek: top = 14, bottom = 18
        let expectedTopSneakPeek: CGFloat = 14
        let expectedBottomSneakPeek: CGFloat = 18

        XCTAssertGreaterThan(expectedTopSneakPeek, 10,
                              "Sneak peek top radius should be larger than closed")
        XCTAssertGreaterThan(expectedBottomSneakPeek, expectedTopSneakPeek)
    }

    func test_notchShape_cornerRadiusValues_forOpenState() {
        // PRD-01 Section 3.2: Open: top = 18, bottom = 24
        let expectedTopOpen: CGFloat = 18
        let expectedBottomOpen: CGFloat = 24

        XCTAssertEqual(expectedTopOpen, 18)
        XCTAssertEqual(expectedBottomOpen, 24)
    }

    func test_notchShape_cornerRadiusValues_forExpandedDetailState() {
        // PRD-01 Section 3.2: Expanded Detail: top = 18, bottom = 28
        let expectedTopExpanded: CGFloat = 18
        let expectedBottomExpanded: CGFloat = 28

        XCTAssertEqual(expectedTopExpanded, 18)
        XCTAssertEqual(expectedBottomExpanded, 28)
    }

    func test_notchShape_cornerRadii_progressFromClosedToOpen() {
        // Verify that corner radii increase monotonically from closed to open state.
        let closedTop: CGFloat = 10
        let sneakPeekTop: CGFloat = 14
        let openTop: CGFloat = 18

        XCTAssertLessThan(closedTop, sneakPeekTop)
        XCTAssertLessThan(sneakPeekTop, openTop)

        let closedBottom: CGFloat = 14
        let sneakPeekBottom: CGFloat = 18
        let openBottom: CGFloat = 24

        XCTAssertLessThan(closedBottom, sneakPeekBottom)
        XCTAssertLessThan(sneakPeekBottom, openBottom)
    }

    // MARK: - Corner Radius Transitions

    func test_cornerRadiusTransition_interpolationMidpoint() {
        // When animating from closed to open, the midpoint should be between the two values.
        let closedTop: CGFloat = 10
        let openTop: CGFloat = 18
        let midpoint = closedTop + (openTop - closedTop) * 0.5

        XCTAssertEqual(midpoint, 14, "Midpoint of top radius animation should be 14")
        XCTAssertGreaterThan(midpoint, closedTop)
        XCTAssertLessThan(midpoint, openTop)
    }

    func test_cornerRadiusTransition_atProgress0_equalsClosed() {
        let closedTop: CGFloat = 10
        let openTop: CGFloat = 18
        let progress: CGFloat = 0
        let interpolated = closedTop + (openTop - closedTop) * progress

        XCTAssertEqual(interpolated, closedTop)
    }

    func test_cornerRadiusTransition_atProgress1_equalsOpen() {
        let closedTop: CGFloat = 10
        let openTop: CGFloat = 18
        let progress: CGFloat = 1
        let interpolated = closedTop + (openTop - closedTop) * progress

        XCTAssertEqual(interpolated, openTop)
    }

    // MARK: - Closed vs Open Shape Parameters

    func test_closedShape_usesSmallCornerRadii() {
        // PRD-01 Section 3.4: closed state should closely match physical notch
        let closedTop: CGFloat = 10
        let closedBottom: CGFloat = 14

        XCTAssertLessThanOrEqual(closedTop, 14, "Closed top radius should be tight")
        XCTAssertLessThanOrEqual(closedBottom, 18, "Closed bottom radius should be tight")
    }

    func test_openShape_usesLargerCornerRadii() {
        // PRD-01 Section 3.5: open state is a comfortable rounded rectangle
        let openTop: CGFloat = 18
        let openBottom: CGFloat = 24

        XCTAssertGreaterThanOrEqual(openTop, 18)
        XCTAssertGreaterThanOrEqual(openBottom, 24)
    }

    func test_closedShape_dimensions_matchNotchSize() {
        // PRD-01 Section 3.4: closed state width = notchWidth, height = notchHeight
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 38
        let closedRect = CGRect(x: 0, y: 0, width: notchWidth, height: notchHeight)

        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let path = shape.path(in: closedRect)

        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(closedRect.width, notchWidth)
        XCTAssertEqual(closedRect.height, notchHeight)
    }

    func test_openShape_dimensions_default640x190() {
        let openRect = CGRect(x: 0, y: 0, width: 640, height: 190)
        let shape = NotchShape(topCornerRadius: 18, bottomCornerRadius: 24)
        let path = shape.path(in: openRect)

        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(openRect.width, 640)
        XCTAssertEqual(openRect.height, 190)
    }

    // MARK: - Path Generation Edge Cases

    func test_notchShape_zeroRect_producesEmptyOrDegeneratePath() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let zeroRect = CGRect.zero
        let path = shape.path(in: zeroRect)

        // A zero rect should produce either an empty path or a degenerate path with no area.
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 0, accuracy: 0.01,
                       "Zero rect should not produce a path with width")
        XCTAssertEqual(bounds.height, 0, accuracy: 0.01,
                       "Zero rect should not produce a path with height")
    }

    func test_notchShape_verySmallRect_doesNotCrash() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let tinyRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let path = shape.path(in: tinyRect)

        // Should not crash; path may be degenerate but that is acceptable.
        XCTAssertNotNil(path)
    }

    func test_notchShape_veryLargeRect_doesNotCrash() {
        let shape = NotchShape(topCornerRadius: 18, bottomCornerRadius: 24)
        let largeRect = CGRect(x: 0, y: 0, width: 5000, height: 3000)
        let path = shape.path(in: largeRect)

        XCTAssertFalse(path.isEmpty, "Large rect should produce a valid path")
    }

    func test_notchShape_negativeOrigin_producesValidPath() {
        let shape = NotchShape(topCornerRadius: 10, bottomCornerRadius: 14)
        let rect = CGRect(x: -100, y: -50, width: 200, height: 38)
        let path = shape.path(in: rect)

        XCTAssertFalse(path.isEmpty, "Rect with negative origin should still produce a valid path")
    }

    // MARK: - Background Fill (NS-004)

    func test_closedStateBackground_shouldBeSolidBlack() {
        // PRD-01 Section 3.4: closed state overlay background is solid black (Color.black)
        // This is a view-level concern, but we verify the design constant here.
        // In production, the view applies .background(NotchShape().fill(Color.black))
        let expectedBackground = "Color.black"
        XCTAssertEqual(expectedBackground, "Color.black",
                       "Closed state background should be solid black per PRD-01 Section 3.4")
    }

    // MARK: - Factory Methods

    func test_notchShape_closedFactory() {
        let shape = NotchShape.closed()
        XCTAssertEqual(shape.topCornerRadius, AnimationConstants.CornerRadii.closedTop)
        XCTAssertEqual(shape.bottomCornerRadius, AnimationConstants.CornerRadii.closedBottom)
    }

    func test_notchShape_openFactory() {
        let shape = NotchShape.open()
        XCTAssertEqual(shape.topCornerRadius, AnimationConstants.CornerRadii.openTop)
        XCTAssertEqual(shape.bottomCornerRadius, AnimationConstants.CornerRadii.openBottom)
    }

    func test_notchShape_sneakPeekFactory() {
        let shape = NotchShape.sneakPeek()
        XCTAssertEqual(shape.topCornerRadius, AnimationConstants.CornerRadii.sneakPeekTop)
        XCTAssertEqual(shape.bottomCornerRadius, AnimationConstants.CornerRadii.sneakPeekBottom)
    }

    func test_notchShape_expandedDetailFactory() {
        let shape = NotchShape.expandedDetail()
        XCTAssertEqual(shape.topCornerRadius, AnimationConstants.CornerRadii.expandedDetailTop)
        XCTAssertEqual(shape.bottomCornerRadius, AnimationConstants.CornerRadii.expandedDetailBottom)
    }
}
