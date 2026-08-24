import Testing
@testable import SurveillanceCore

private struct CameraLayout: Equatable {
    var sockets: [String]
    var housing: [HousingFamily]
    var ids: [UInt64]
    var integrity: [Int]
}

private func cameraLayout(_ cameras: [SelectedCamera]) -> CameraLayout {
    CameraLayout(
        sockets: cameras.map(\.socketId),
        housing: cameras.map(\.housingFamily),
        ids: cameras.map(\.entityId.raw),
        integrity: cameras.map(\.integrity)
    )
}

private func cameraLayout(from sim: Simulation) -> CameraLayout {
    cameraLayout(sim.state.cameras)
}

private func combatRngState(from sim: Simulation) -> (UInt64, UInt64, UInt64, UInt64) {
    let rng = sim.state.combatRng
    return (rng.s0, rng.s1, rng.s2, rng.s3)
}

private func placementReceipt(from sim: Simulation) -> (String, UInt64, [String]) {
    let receipt = RunReceipt(sim.state)
    return (
        receipt.cameraPlacementVersion,
        receipt.placementSeed,
        receipt.selectedSockets.map(\.socketId)
    )
}

@Suite(.serialized)
struct CameraPlacementTests {
    @Test func cameraCP001TenRestartsMatchSocketsHousingAndIds() throws {
        var sim = try Simulation.make(seed: 1)
        let first = cameraLayout(from: sim)
        let startOk = first.integrity == Array(repeating: 3, count: 8)
        #expect(startOk)
        for _ in 0..<10 {
            sim.restart()
            let next = cameraLayout(from: sim)
            let match = next == first
            #expect(match)
        }
    }

    @Test func cameraCP002ZoneQuotaTwoOneTwoTwoOne() throws {
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
        let counts = Dictionary(grouping: cameras, by: \.zoneId).mapValues(\.count)
        let z02 = counts["Z-02"] == 2
        let z03 = counts["Z-03"] == 1
        let z04 = counts["Z-04"] == 2
        let z05 = counts["Z-05"] == 2
        let z06 = counts["Z-06"] == 1
        let asserts = CameraPlacement.selectedSetPassesRuntimeAsserts(cameras)
        #expect(z02)
        #expect(z03)
        #expect(z04)
        #expect(z05)
        #expect(z06)
        #expect(cameras.count == 8)
        #expect(asserts)
    }

    @Test func cameraCP003TutorialFourFamiliesFourReturnVisible() throws {
        let arena = try ArenaManifest.bundled()
        var ok = true
        for seed: UInt64 in [1, 2, 3, 7, 11, 42] {
            var allocator = EntityAllocator()
            _ = allocator.next()
            guard let cameras = CameraPlacement.select(
                sockets: arena.cameraSockets,
                geometry: arena.standardCameraGeometry,
                runSeed: seed,
                allocator: &allocator
            ) else {
                ok = false
                break
            }
            let tutorial = cameras.contains { $0.zoneId == "Z-02" && $0.tutorialEligible }
            let families = Set(cameras.map(\.housingFamily)).count >= 4
            let visible = cameras.filter(\.returnVisible).count >= 4
            if !tutorial || !families || !visible { ok = false }
        }
        #expect(ok)
    }

    @Test func cameraCP004IncompatiblePairShuffledFirstYieldsNextLegal() throws {
        let arena = try ArenaManifest.bundled()
        let enabled = arena.cameraSockets.filter(\.enabled).sorted { $0.socketId.utf8LessThan($1.socketId) }
        var shuffledByZone = Dictionary(grouping: enabled, by: \.zoneId)
        shuffledByZone["Z-02"] = ["cam-z02-a", "cam-z02-d", "cam-z02-b", "cam-z02-c"].map { id in
            enabled.first { $0.socketId == id }!
        }
        var housing: [String: HousingFamily] = [:]
        for socket in enabled {
            housing[socket.socketId] = socket.allowedHousingFamilies[0]
        }
        let found = try #require(
            CameraPlacement.searchFirstLegal(shuffledByZone: shuffledByZone, housingBySocket: housing)
        )
        let z02 = Set(found.filter { $0.zoneId == "Z-02" }.map(\.socketId))
        let skippedPair = !z02.isSuperset(of: ["cam-z02-a", "cam-z02-d"])
        let choseAB = z02 == ["cam-z02-a", "cam-z02-b"]
        let visible = found.filter(\.returnVisible).count >= 4
        let tutorial = found.contains { $0.tutorialEligible }
        #expect(skippedPair)
        #expect(choseAB)
        #expect(visible)
        #expect(tutorial)
    }

    @Test func cameraCP005InsufficientZonePoolRejectedBeforeTickOne() throws {
        var arena = try ArenaManifest.bundled()
        for i in arena.cameraSockets.indices where arena.cameraSockets[i].zoneId == "Z-02" {
            if arena.cameraSockets[i].socketId != "cam-z02-a" {
                arena.cameraSockets[i].enabled = false
            }
        }
        let poolInvalid = !CameraPlacement.manifestPoolIsValid(arena.cameraSockets)
        var allocator = EntityAllocator()
        _ = allocator.next()
        let selected = CameraPlacement.select(
            sockets: arena.cameraSockets,
            geometry: arena.standardCameraGeometry,
            runSeed: 1,
            allocator: &allocator
        )
        var rejected = false
        do {
            _ = try Simulation(seed: 1, arena: arena, content: .bundled())
        } catch ArenaValidationError.cameraPlacement {
            rejected = true
        }
        #expect(poolInvalid)
        #expect(selected == nil)
        #expect(rejected)
    }

    @Test func cameraCP006NoCompatibleSetFailsArenaValidation() throws {
        var arena = try ArenaManifest.bundled()
        let z02 = arena.cameraSockets.filter { $0.zoneId == "Z-02" }.map(\.socketId)
        for i in arena.cameraSockets.indices where arena.cameraSockets[i].zoneId == "Z-02" {
            let id = arena.cameraSockets[i].socketId
            arena.cameraSockets[i].incompatibleSocketIds = z02.filter { $0 != id }
        }
        let poolValid = CameraPlacement.manifestPoolIsValid(arena.cameraSockets)
        let noSet = !CameraPlacement.hasCompleteCompatibleSet(arena.cameraSockets)
        var validateRejected = false
        do {
            try ArenaLoader.validate(arena)
        } catch ArenaValidationError.cameraPlacement {
            validateRejected = true
        }
        var allocator = EntityAllocator()
        _ = allocator.next()
        let selected = CameraPlacement.select(
            sockets: arena.cameraSockets,
            geometry: arena.standardCameraGeometry,
            runSeed: 1,
            allocator: &allocator
        )
        #expect(poolValid)
        #expect(noSet)
        #expect(validateRejected)
        #expect(selected == nil)
    }

    @Test func cameraCP007DifferentSeedsObserveMoreThanOneLayout() throws {
        let arena = try ArenaManifest.bundled()
        var layouts = Set<String>()
        var missing = false
        for seed: UInt64 in 1...48 {
            var allocator = EntityAllocator()
            _ = allocator.next()
            guard let cameras = CameraPlacement.select(
                sockets: arena.cameraSockets,
                geometry: arena.standardCameraGeometry,
                runSeed: seed,
                allocator: &allocator
            ) else {
                missing = true
                break
            }
            layouts.insert(CameraPlacement.setKey(cameras))
        }
        #expect(!missing)
        #expect(layouts.count > 1)
    }

    @Test func cameraCP008DestroyedThenSameSeedRestartRestoresOperational() throws {
        var sim = try Simulation.make(seed: 11)
        let original = cameraLayout(from: sim)
        sim.testing_destroyCameras()
        let destroyed = cameraLayout(from: sim)
        sim.restart()
        let restored = cameraLayout(from: sim)
        let receipt = placementReceipt(from: sim)
        let destroyedOk = destroyed.integrity == Array(repeating: 0, count: 8)
        let restoredOk = restored == original && restored.integrity == Array(repeating: 3, count: 8)
        let receiptOk = receipt.0 == ContractVersions.cameraPlacement
            && receipt.1 == CameraPlacement.placementSeed(runSeed: 11)
            && receipt.2 == original.sockets
        #expect(destroyedOk)
        #expect(restoredOk)
        #expect(receiptOk)
    }

    @Test func cameraCP009PlacementDoesNotPerturbCombatRng() throws {
        let combat = Xoshiro256StarStar.combat(runSeed: 19)
        let before = (combat.s0, combat.s1, combat.s2, combat.s3)
        let sim = try Simulation.make(seed: 19)
        let after = combatRngState(from: sim)
        var combatAgain = Xoshiro256StarStar.combat(runSeed: 19)
        var sequence: [UInt64] = []
        for _ in 0..<8 { sequence.append(combatAgain.next()) }
        var control = Xoshiro256StarStar.combat(runSeed: 19)
        _ = CameraPlacement.placementSeed(runSeed: 19)
        var afterPlacement: [UInt64] = []
        for _ in 0..<8 { afterPlacement.append(control.next()) }
        #expect(after.0 == before.0)
        #expect(after.1 == before.1)
        #expect(after.2 == before.2)
        #expect(after.3 == before.3)
        #expect(sequence == afterPlacement)
    }
}
