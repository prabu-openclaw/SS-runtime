import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct AudioProjectorSmokeTests {
    @Test func audioProjectorProjectsEmptyDisabledCues() {
        var projector = AudioProjector()
        let world = AudioWorldQuery(
            playerId: EntityID(1),
            playerPosition: .zero,
            outcome: .playing,
            extractionArmed: false,
            hasAlgorithmicModerate: false,
            lockdownEntered: false,
            detectionState: .hidden,
            viewport: ViewportSpec(
                baselineWorldWidth: 1920,
                baselineWorldHeight: 1080,
                deadZoneWidth: 64,
                deadZoneHeight: 64,
                maximumLookAheadUnits: 48
            )
        )
        let projection = projector.project(
            tick: 0,
            events: [],
            world: world,
            settings: .disabled
        )
        #expect(projection.cues.isEmpty)
        #expect(projection.musicState == .explore)
    }
}
