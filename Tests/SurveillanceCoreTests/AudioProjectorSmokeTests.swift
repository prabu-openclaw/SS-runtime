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

    @Test func audioAHNetworkBlackoutAccoladeCaption() {
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
        let event = AuthoritativeEvent(
            tick: 8,
            phase: 10,
            type: .allCamerasDestroyed,
            payload: ["destroyedCount": .integer(8), "totalCount": .integer(8)],
            insertion: 0
        )
        let projection = projector.project(tick: 8, events: [event], world: world)
        let cue = projection.cues.first { $0.audioId == "network_blackout" }
        let audioId = cue?.audioId
        let caption = cue?.caption
        let haptic = cue?.haptic
        #expect(audioId == "network_blackout")
        #expect(caption == "Network Blackout 8/8")
        #expect(haptic == .success)
    }
}
