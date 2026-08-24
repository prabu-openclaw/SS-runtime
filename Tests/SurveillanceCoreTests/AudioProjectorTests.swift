import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct AudioProjectorTests {
    @Test func audioAH001NineEffectsStealToEight() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 1)
        let world = AudioWorldQuery.from(sim.state)
        var events: [AuthoritativeEvent] = []
        for i in 0..<9 {
            events.append(
                AuthoritativeEvent(
                    tick: 10,
                    phase: 10,
                    type: .cameraDestroyed,
                    primary: EntityID(UInt64(i + 2)),
                    payload: [
                        "cameraId": .string("\(i + 2)"),
                        "socketId": .string("S"),
                        "projectileId": .string("1"),
                        "wasDetecting": .bool(false)
                    ],
                    insertion: i
                )
            )
        }
        let projection = projector.project(tick: 10, events: events, world: world)
        let cueCount = projection.cues.count
        let hasTamper = projection.cues.contains { $0.audioId == "camera_network_tamper" && $0.variant == 3 }
        #expect(cueCount == 8)
        #expect(hasTamper)
    }

    @Test func audioAH002ThreeCameraDestructionsOneTamper() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 1)
        let world = AudioWorldQuery.from(sim.state)
        let events: [AuthoritativeEvent] = (0..<3).map { i in
            AuthoritativeEvent(
                tick: 4,
                phase: 10,
                type: .cameraDestroyed,
                primary: EntityID(UInt64(i + 2)),
                payload: [
                    "cameraId": .string("\(i + 2)"),
                    "socketId": .string("S"),
                    "projectileId": .string("1"),
                    "wasDetecting": .bool(false)
                ],
                insertion: i
            )
        }
        let projection = projector.project(tick: 4, events: events, world: world)
        let destroyCount = projection.cues.filter { $0.audioId == "camera_destroy" }.count
        let fieldOffCount = projection.cues.filter { $0.audioId == "camera_field_off" }.count
        #expect(destroyCount == 3)
        #expect(fieldOffCount == 3)
        let tamper = try #require(projection.cues.first { $0.audioId == "camera_network_tamper" })
        #expect(tamper.variant == 3)
    }

    @Test func audioAH003PlayerDamageCoalescesPerFifteenTicks() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 1)
        let world = AudioWorldQuery.from(sim.state)
        let damage = AuthoritativeEvent(
            tick: 20,
            phase: 12,
            type: .playerDamaged,
            primary: sim.state.player.id,
            payload: [
                "amount": .integer(4),
                "remainingIntegrity": .integer(96),
                "sourceEntityId": .string("9")
            ],
            insertion: 0
        )
        let first = projector.project(tick: 20, events: [damage], world: world)
        #expect(first.cues.contains { $0.audioId == "player_damage" })
        var later = damage
        later.tick = 30
        let coalesced = projector.project(tick: 30, events: [later], world: world)
        #expect(coalesced.cues.contains { $0.audioId == "player_damage" } == false)
        later.tick = 35
        let allowed = projector.project(tick: 35, events: [later], world: world)
        #expect(allowed.cues.contains { $0.audioId == "player_damage" })
    }

    @Test func audioAH004DisabledSettingsLeaveCuesEmpty() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 3)
        let world = AudioWorldQuery.from(sim.state)
        let projection = projector.project(
            tick: 0,
            events: [],
            world: world,
            settings: .disabled
        )
        #expect(projection.cues.isEmpty)
        #expect(projection.musicState == .explore)
    }

    @Test func audioProjectsCameraHitAlternationAndUpgradeIds() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 1)
        let hit = AuthoritativeEvent(
            tick: 8,
            phase: 9,
            type: .cameraIntegrityChanged,
            primary: EntityID(4),
            payload: ["cameraId": .string("4"), "before": .integer(3), "after": .integer(2)],
            insertion: 0
        )
        let upgrade = AuthoritativeEvent(
            tick: 8,
            phase: 2,
            type: .upgradeSelected,
            payload: ["upgradeId": .string("ghostStep"), "selectionIndex": .integer(2)],
            insertion: 1
        )
        let world = AudioWorldQuery.from(sim.state)
        let projection = projector.project(tick: 8, events: [hit, upgrade], world: world)
        #expect(projection.cues.contains { $0.audioId == "camera_hit_01" })
        #expect(projection.cues.contains { $0.audioId == "upgrade_selected_ghostStep" })
        #expect(AudioProjector.musicState(world) == .explore)
    }

    @Test func extractionTickFiresOnDisplayedSecondChange() throws {
        var projector = AudioProjector()
        let sim = try Simulation.make(seed: 1)
        let first = AuthoritativeEvent(
            tick: 50,
            phase: 17,
            type: .extractionCountdownChanged,
            payload: ["remainingTicks": .integer(300)],
            insertion: 0
        )
        let sameSecond = AuthoritativeEvent(
            tick: 51,
            phase: 17,
            type: .extractionCountdownChanged,
            payload: ["remainingTicks": .integer(299)],
            insertion: 0
        )
        let world = AudioWorldQuery.from(sim.state)
        let firstProjection = projector.project(tick: 50, events: [first], world: world)
        let sameProjection = projector.project(tick: 51, events: [sameSecond], world: world)
        #expect(firstProjection.cues.contains { $0.audioId == "extraction_tick" })
        #expect(sameProjection.cues.contains { $0.audioId == "extraction_tick" } == false)
    }
}
