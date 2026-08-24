import Foundation
import Testing
@testable import SurveillanceCore

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

@Test func arenaAR006CriticalPathAndSpawnAlley() throws {
    let arena = try ArenaManifest.bundled()
    #expect(ArenaReachability.geometryInBounds(arena))
    #expect(ArenaReachability.viewportMatchesContract(arena))
    #expect(ArenaReachability.spawnAlleyProtected(arena))
    #expect(ArenaReachability.consecutiveZonesConnected(arena))
    #expect(ArenaReachability.diagonalSpine(arena))
    // Pinned civic-seam-arena-001.json; do not rewrite coordinates (SS-specs authority).
    #expect(
        ArenaReachability.authoredSolidOverlaps(arena) == [
            "gate gate-mb-forward overlaps mb-05",
            "socket:ma-02 in solid-04-civic-west",
            "socket:mb-02 in solid-06-service-yard-a",
            "socket:mc-08 in solid-09-grid-island-a"
        ]
    )
    #expect(ArenaReachability.fieldOriginsInsideSolids(arena) == ["cam-z02-d"])
}

@Test func arenaAR005ClosedMAGateLeavesEscapeAperture() throws {
    let arena = try ArenaManifest.bundled()
    #expect(ArenaReachability.maEscapeOpen(arena))
}

@Test func arenaAR007BossCorridorRemainsOneHundredNinetyTwoWide() throws {
    let arena = try ArenaManifest.bundled()
    #expect(ArenaReachability.bossCorridorClear(arena))
}

@Test func arenaLayoutDocumentsBossGateSidestep() throws {
    let arena = try ArenaManifest.bundled()
    #expect(ArenaReachability.extractionReachable(arena, bossGateClosed: false))
    // Pinned civic-seam-arena-001.json leaves a 64-unit gap beside gate-boss-extraction
    // (2048,384) half (96,16) vs phoenix solids. SS-specs is authority; do not widen the gate.
    #expect(ArenaReachability.extractionReachable(arena, bossGateClosed: true))
}

@Test func arenaAR010ManifestJSONRoundTrip() throws {
    let data = SpecBundle.contract("civic-seam-arena-001")
    let object = try JSONSerialization.jsonObject(with: data)
    let first = try #require(CanonicalJSON.parse(object))
    let encoded = first.serialize()
    let secondObject = try JSONSerialization.jsonObject(with: Data(encoded.utf8))
    let second = try #require(CanonicalJSON.parse(secondObject))
    #expect(first.serialize() == second.serialize())
    #expect(first.sha256Hex() == second.sha256Hex())

    let arena = try ArenaLoader.decodeAndValidate(data)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let roundTrip = try encoder.encode(arena)
    let again = try ArenaLoader.decodeAndValidate(roundTrip)
    #expect(again == arena)
}

@Test func arenaAR009LethalDamageBeatsExtractionSuccess() {
    #expect(IsolatedKernel.extractionVersusDeath(integrity: 0, remainingAfterTick: 0) == .failure)
    #expect(IsolatedKernel.extractionVersusDeath(integrity: 1, remainingAfterTick: 0) == .success)
    #expect(IsolatedKernel.extractionVersusDeath(integrity: 1, remainingAfterTick: 1) == .playing)
}
