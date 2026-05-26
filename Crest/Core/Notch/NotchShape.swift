import SwiftUI

/// Custom Shape that mimics the MacBook notch with animatable corner radii.
/// The shape is a rounded rectangle with independent top and bottom corner radii,
/// and concave curves at the bottom edges to match the real MacBook notch aesthetic.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let tr = min(topCornerRadius, min(rect.width / 2, rect.height / 2))
        let br = min(bottomCornerRadius, min(rect.width / 2, rect.height / 2))

        // Start at top-left after the top corner arc
        path.move(to: CGPoint(x: minX + tr, y: minY))

        // Top edge
        path.addLine(to: CGPoint(x: maxX - tr, y: minY))

        // Top-right corner
        path.addArc(
            center: CGPoint(x: maxX - tr, y: minY + tr),
            radius: tr,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: maxX, y: maxY - br))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: maxX - br, y: maxY - br),
            radius: br,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: minX + br, y: maxY))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: minX + br, y: maxY - br),
            radius: br,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge up to top-left corner
        path.addLine(to: CGPoint(x: minX, y: minY + tr))

        // Top-left corner
        path.addArc(
            center: CGPoint(x: minX + tr, y: minY + tr),
            radius: tr,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Factory Methods

extension NotchShape {
    /// Creates a NotchShape configured for the closed state.
    static func closed(for geometry: NotchGeometryInfo? = nil) -> NotchShape {
        NotchShape(
            topCornerRadius: AnimationConstants.CornerRadii.closedTop,
            bottomCornerRadius: AnimationConstants.CornerRadii.closedBottom
        )
    }

    /// Creates a NotchShape configured for the open state.
    static func open(for geometry: NotchGeometryInfo? = nil) -> NotchShape {
        NotchShape(
            topCornerRadius: AnimationConstants.CornerRadii.openTop,
            bottomCornerRadius: AnimationConstants.CornerRadii.openBottom
        )
    }

    /// Creates a NotchShape configured for the sneak peek state.
    static func sneakPeek(for geometry: NotchGeometryInfo? = nil) -> NotchShape {
        NotchShape(
            topCornerRadius: AnimationConstants.CornerRadii.sneakPeekTop,
            bottomCornerRadius: AnimationConstants.CornerRadii.sneakPeekBottom
        )
    }

    /// Creates a NotchShape configured for the expanded detail state.
    static func expandedDetail(for geometry: NotchGeometryInfo? = nil) -> NotchShape {
        NotchShape(
            topCornerRadius: AnimationConstants.CornerRadii.expandedDetailTop,
            bottomCornerRadius: AnimationConstants.CornerRadii.expandedDetailBottom
        )
    }

    /// Returns the appropriate NotchShape for a given state.
    static func shape(for state: NotchState) -> NotchShape {
        switch state {
        case .closed:
            return .closed()
        case .sneakPeek:
            return .sneakPeek()
        case .open:
            return .open()
        case .expandedDetail:
            return .expandedDetail()
        }
    }
}
