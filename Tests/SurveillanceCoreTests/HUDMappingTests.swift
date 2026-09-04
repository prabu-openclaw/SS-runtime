import Testing
@testable import SurveillanceCore

/// `hud-tutorial-001` §Reference canvas: the 844 × 390 canvas scales uniformly
/// by `min(safeWidth / 844, safeHeight / 390)` and centres in the safe rect.
///
/// The existing `HUDLayout.validate` coverage could not catch a scaling fault,
/// because `mapControlRect` clamps a too-large rect down to the safe rectangle
/// and `validate` then checks the *clamped* result — which is inside the safe
/// area by construction. These tests assert the mapped geometry itself.
@Suite(.serialized)
struct HUDMappingTests {
    private static let safeWidth = 750
    private static let safeHeight = 382

    /// A mapped element keeps its share of the canvas: scaling is uniform and
    /// proportional, never a multiple of the permille factor.
    @Test func mappedElementsScaleProportionally() {
        let permille = HUDLayout.scale(safeWidth: Self.safeWidth, safeHeight: Self.safeHeight)
        let mapped = HUDLayout.mapReferenceRect(
            HUDLayout.stick(handedness: .right),
            safeWidth: Self.safeWidth,
            safeHeight: Self.safeHeight,
            hudScale: .standard,
            informational: false
        )

        #expect(permille > 0 && permille <= 1000)
        // 144 reference points at the canvas scale.
        #expect(mapped.width == Int(IntMath.mulDivHalfAway(144, Int64(permille), 1000)))
        #expect(mapped.height == mapped.width)
        // Sanity: a control cannot be most of the screen.
        #expect(mapped.width < Self.safeWidth / 2)
    }

    /// Every element fits inside the safe rectangle *before* any clamping.
    @Test func everyAnchoredElementFitsWithoutClamping() {
        let elements: [(String, HUDRect)] = [
            ("playerIntegrity", HUDLayout.playerIntegrity()),
            ("combatObjective", HUDLayout.combatObjective()),
            ("cameraObjective", HUDLayout.cameraObjective())
        ]
        for (name, rect) in elements {
            let mapped = HUDLayout.mapReferenceRect(
                rect,
                safeWidth: Self.safeWidth,
                safeHeight: Self.safeHeight,
                hudScale: .standard,
                informational: true
            )
            #expect(mapped.x >= 0, "\(name) x")
            #expect(mapped.y >= 0, "\(name) y")
            #expect(mapped.x + mapped.width <= Self.safeWidth, "\(name) width")
            #expect(mapped.y + mapped.height <= Self.safeHeight, "\(name) height")
        }
    }

    /// A control stays inside the safe rectangle, never scales below its
    /// authored baseline, and always meets the 44-point touch target.
    @Test(arguments: [Handedness.right, Handedness.left])
    func controlsStayInsideAndMeetTheTouchTarget(handedness: Handedness) {
        // Controls are centre-anchored, so resolve to a top-left rect first.
        func topLeft(_ rect: HUDRect) -> HUDRect {
            HUDRect(
                x: rect.x - rect.width / 2,
                y: rect.y - rect.height / 2,
                width: rect.width,
                height: rect.height
            )
        }
        let controls = [
            ("stick", topLeft(HUDLayout.stick(handedness: handedness))),
            ("dodge", topLeft(HUDLayout.dodge(handedness: handedness))),
            ("pause", topLeft(HUDLayout.pause()))
        ]
        for (name, rect) in controls {
            let mapped = HUDLayout.mapControlRect(
                rect,
                safeWidth: Self.safeWidth,
                safeHeight: Self.safeHeight
            )
            #expect(mapped.meetsTouchTarget, "\(name) touch target")
            #expect(mapped.width >= rect.width, "\(name) baseline width")
            #expect(mapped.height >= rect.height, "\(name) baseline height")
            #expect(mapped.x >= 0 && mapped.y >= 0, "\(name) origin")
            #expect(mapped.x + mapped.width <= Self.safeWidth, "\(name) width")
            #expect(mapped.y + mapped.height <= Self.safeHeight, "\(name) height")
        }
    }

    /// UI-003: 130% informational scale must not overflow the smallest target.
    @Test func extraLargeScaleFitsTheSEClassCanvas() {
        let safeW = HUDLayout.seClassSafeWidth
        let safeH = HUDLayout.seClassSafeHeight
        for rect in [
            HUDLayout.playerIntegrity(),
            HUDLayout.combatObjective(),
            HUDLayout.cameraObjective()
        ] {
            let mapped = HUDLayout.mapReferenceRect(
                rect,
                safeWidth: safeW,
                safeHeight: safeH,
                hudScale: .extraLarge,
                informational: true
            )
            #expect(mapped.x + mapped.width <= safeW)
            #expect(mapped.y + mapped.height <= safeH)
        }
    }

    /// The canvas is centred: equal slack on both axes.
    @Test func canvasIsCentredInTheSafeRectangle() {
        let permille = HUDLayout.scale(safeWidth: Self.safeWidth, safeHeight: Self.safeHeight)
        let canvasW = Int(IntMath.mulDivHalfAway(844, Int64(permille), 1000))
        let canvasH = Int(IntMath.mulDivHalfAway(390, Int64(permille), 1000))

        #expect(canvasW <= Self.safeWidth)
        #expect(canvasH <= Self.safeHeight)

        let origin = HUDLayout.mapReferenceRect(
            HUDRect(x: 0, y: 0, width: 0, height: 0),
            safeWidth: Self.safeWidth,
            safeHeight: Self.safeHeight,
            hudScale: .standard,
            informational: false
        )
        #expect(origin.x == (Self.safeWidth - canvasW) / 2)
        #expect(origin.y == (Self.safeHeight - canvasH) / 2)
    }

    /// A 1:1 safe rectangle maps the canvas onto itself unchanged.
    @Test func referenceSizedSafeRectIsIdentity() {
        let mapped = HUDLayout.mapReferenceRect(
            HUDLayout.exposureBar(),
            safeWidth: HUDLayout.referenceWidth,
            safeHeight: HUDLayout.referenceHeight,
            hudScale: .standard,
            informational: true
        )
        #expect(mapped == HUDLayout.exposureBar())
    }
}
