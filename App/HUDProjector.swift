import CoreGraphics
import SurveillanceCore

/// Maps the `hud-tutorial-001` reference canvas onto the device.
///
/// The contract authors the HUD on an 844 × 390-point landscape canvas *after*
/// safe-area insets, scaled uniformly by `min(safeWidth / 844, safeHeight / 390)`
/// and centred in the safe rectangle. `HUDLayout` owns that arithmetic; this
/// type only carries the result between point space and SpriteKit scene units
/// so the two conversions cannot drift apart.
///
/// Point space here is "points from the top-left of the safe rectangle", y
/// down — exactly what `HUDLayout.mapReferenceRect` returns. Scene space is
/// camera-relative units, y up.
struct HUDProjector {
    /// Points per scene unit under the scene's aspect-fit scale.
    let pointsPerSceneUnit: CGFloat
    let safeWidth: Int
    let safeHeight: Int
    /// Offset of the safe rectangle's centre from the view centre, in points, y down.
    let safeCentreOffset: CGPoint

    init(viewSize: CGSize, safeInsets: EdgeInsetsPoints, sceneSize: CGSize) {
        let fit = min(viewSize.width / sceneSize.width, viewSize.height / sceneSize.height)
        pointsPerSceneUnit = fit > 0 ? fit : 1

        let width = viewSize.width - safeInsets.left - safeInsets.right
        let height = viewSize.height - safeInsets.top - safeInsets.bottom
        safeWidth = Int(max(0, width.rounded(.down)))
        safeHeight = Int(max(0, height.rounded(.down)))

        let centreX = safeInsets.left + width / 2
        let centreY = safeInsets.top + height / 2
        safeCentreOffset = CGPoint(
            x: centreX - viewSize.width / 2,
            y: centreY - viewSize.height / 2
        )
    }

    /// A point in safe-rectangle space to camera-relative scene units.
    func scenePoint(fromPoints point: CGPoint) -> CGPoint {
        let viewX = point.x - CGFloat(safeWidth) / 2 + safeCentreOffset.x
        let viewY = point.y - CGFloat(safeHeight) / 2 + safeCentreOffset.y
        return CGPoint(x: viewX / pointsPerSceneUnit, y: -viewY / pointsPerSceneUnit)
    }

    /// The inverse, for hit-testing a touch taken in camera-relative space.
    func points(fromScenePoint point: CGPoint) -> CGPoint {
        let viewX = point.x * pointsPerSceneUnit
        let viewY = -point.y * pointsPerSceneUnit
        return CGPoint(
            x: viewX - safeCentreOffset.x + CGFloat(safeWidth) / 2,
            y: viewY - safeCentreOffset.y + CGFloat(safeHeight) / 2
        )
    }

    /// Scene-unit length of a HUD measurement given in points.
    func sceneLength(points: Int) -> CGFloat {
        CGFloat(points) / pointsPerSceneUnit
    }

    /// The mapped rect for a reference-canvas anchor.
    func mapped(_ rect: HUDRect, hudScale: HUDScaleSetting, informational: Bool) -> HUDRect {
        HUDLayout.mapReferenceRect(
            rect,
            safeWidth: safeWidth,
            safeHeight: safeHeight,
            hudScale: hudScale,
            informational: informational
        )
    }

    /// Controls never shrink below their baseline and stay inside the safe rect.
    func mappedControl(_ rect: HUDRect) -> HUDRect {
        HUDLayout.mapControlRect(rect, safeWidth: safeWidth, safeHeight: safeHeight)
    }

    /// Centre of a mapped rect, in scene units. Anchors are top-left in the
    /// contract, so the centre is half a size away on each axis.
    func sceneCentre(of rect: HUDRect) -> CGPoint {
        scenePoint(
            fromPoints: CGPoint(
                x: CGFloat(rect.x) + CGFloat(rect.width) / 2,
                y: CGFloat(rect.y) + CGFloat(rect.height) / 2
            )
        )
    }

    func contains(_ rect: HUDRect, points point: CGPoint) -> Bool {
        point.x >= CGFloat(rect.x)
            && point.x <= CGFloat(rect.x + rect.width)
            && point.y >= CGFloat(rect.y)
            && point.y <= CGFloat(rect.y + rect.height)
    }
}

/// Safe-area insets in points, kept free of UIKit so this file stays testable.
struct EdgeInsetsPoints {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    static let zero = EdgeInsetsPoints(top: 0, left: 0, bottom: 0, right: 0)
}
