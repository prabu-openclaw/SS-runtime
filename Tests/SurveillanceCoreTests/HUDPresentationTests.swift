import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct HUDPresentationTests {
    @Test func hudUI003ExtraLargeScaleOnSmallestTarget() {
        let safeW = HUDLayout.seClassSafeWidth
        let safeH = HUDLayout.seClassSafeHeight
        let validation = HUDLayout.validate(
            safeWidth: safeW,
            safeHeight: safeH,
            handedness: .right,
            hudScale: .extraLarge
        )
        let left = HUDLayout.validate(
            safeWidth: safeW,
            safeHeight: safeH,
            handedness: .left,
            hudScale: .extraLarge
        )
        #expect(validation.allInsideSafeCanvas)
        #expect(validation.controlsMeetTouchTarget)
        #expect(validation.clippedElements.isEmpty)
        #expect(left.allInsideSafeCanvas)
        #expect(left.controlsMeetTouchTarget)
        let standardInfo = HUDLayout.informationalScalePermille(
            safeWidth: safeW,
            safeHeight: safeH,
            hudScale: .standard
        )
        let extraInfo = HUDLayout.informationalScalePermille(
            safeWidth: safeW,
            safeHeight: safeH,
            hudScale: .extraLarge
        )
        let stick = HUDLayout.mapControlRect(HUDLayout.stick(handedness: .right), safeWidth: safeW, safeHeight: safeH)
        let dodge = HUDLayout.mapControlRect(HUDLayout.dodge(handedness: .right), safeWidth: safeW, safeHeight: safeH)
        #expect(stick.meetsTouchTarget)
        #expect(dodge.meetsTouchTarget)
        #expect(extraInfo > standardInfo)
        #expect(extraInfo == Int(IntMath.mulDivHalfAway(Int64(standardInfo), 1300, 1000)))
    }

    @Test func hudUI007VoiceOverUpgradeSelectionOrderedLabels() {
        let labels = UpgradePresentation.voiceOverLabels()
        let cards = UpgradePresentation.selectionCards()
        #expect(labels.count == 3)
        #expect(cards.map(\.upgrade) == UpgradePresentation.selectionOrder)
        #expect(cards.map(\.selectionIndex) == [0, 1, 2])
        #expect(labels[0].hasPrefix("Signal Jammer."))
        #expect(labels[1].hasPrefix("Ricochet Pulse."))
        #expect(labels[2].hasPrefix("Ghost Step."))
        #expect(Set(labels).count == 3)
    }

    @Test func hudUI008GrayscaleReducedPresentationStatesDistinct() {
        #expect(DetectionPresentation.criticalStatesRemainDistinct())
        let carriers = DetectionPresentation.reducedPresentationCarriers()
        #expect(carriers.count == 5)
        let patterns = carriers.values.map(\.barPattern)
        let shapes = carriers.values.map(\.iconShape)
        #expect(Set(patterns).count == 5)
        #expect(Set(shapes).count == 5)
        #expect(DetectionPresentation.carrier(for: .lockdown).barPattern == "solidSegmented")
        #expect(DetectionPresentation.carrier(for: .hidden).iconShape == "openEye")
    }
}
