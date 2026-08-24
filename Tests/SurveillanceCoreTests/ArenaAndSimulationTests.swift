import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ArenaAndSimulationTests {
    @Test func arenaManifestMatchesCivicSeamIdentity() throws {
        let arena = try ArenaManifest.bundled()
        #expect(arena.arenaVersion == ContractVersions.arena)
        #expect(arena.boundsUnits.maxX == 2304)
        #expect(arena.boundsUnits.maxY == 1536)
        #expect(arena.gridSizeCells.width == 36)
        #expect(arena.gridSizeCells.height == 24)
        #expect(arena.zones.count == 7)
        #expect(arena.permanentSolids.count == 14)
        #expect(arena.gates.count == 5)
        #expect(arena.cameraSockets.count == 18)
    }

    @Test func cameraPlacementSelectsEightWithZoneQuotas() throws {
        let arena = try ArenaManifest.bundled()
        var allocator = EntityAllocator()
        _ = allocator.next()
        let cameras = try #require(
            CameraPlacement.select(
                sockets: arena.cameraSockets,
                geometry: arena.standardCameraGeometry,
                runSeed: 1,
                allocator: &allocator
            )
        )
        #expect(cameras.count == 8)
        let counts = Dictionary(grouping: cameras, by: \.zoneId).mapValues(\.count)
        #expect(counts["Z-02"] == 2)
        #expect(counts["Z-03"] == 1)
        #expect(counts["Z-04"] == 2)
        #expect(counts["Z-05"] == 2)
        #expect(counts["Z-06"] == 1)
        #expect(Set(cameras.map(\.housingFamily)).count >= 4)
        #expect(cameras.filter(\.returnVisible).count >= 4)
        #expect(cameras.contains { $0.zoneId == "Z-02" && $0.tutorialEligible })

        var allocator2 = EntityAllocator()
        _ = allocator2.next()
        let again = CameraPlacement.select(
            sockets: arena.cameraSockets,
            geometry: arena.standardCameraGeometry,
            runSeed: 1,
            allocator: &allocator2
        )
        #expect(again?.map(\.socketId) == cameras.map(\.socketId))
        #expect(again?.map(\.housingFamily) == cameras.map(\.housingFamily))
    }

    @Test func simulationInitializesFailClosedAndStepsDeterministically() throws {
        var a = try Simulation.make(seed: 3)
        var b = try Simulation.make(seed: 3)
        #expect(a.state.digest() == b.state.digest())
        let command = PlayerCommand(tick: 1, moveX: 32767, moveY: 0, dodgePressed: false)
        let ra = a.step(command: command)
        let rb = b.step(command: command)
        #expect(ra.digest == rb.digest)
        #expect(ra.tick == 1)
        #expect(a.state.cameras.count == 8)
        #expect(PresentationSnapshot(a.state).player.radius == 18)
    }
}
