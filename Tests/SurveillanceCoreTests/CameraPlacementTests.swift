import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CameraPlacementTests {
    @Test func cameraCP001TenRestartsMatchSocketsHousingAndIds() throws {
        let seed: UInt64 = 1
        var firstSockets: [String] = []
        var firstHousing: [HousingFamily] = []
        var firstIds: [UInt64] = []
        for i in 0..<10 {
            var sim = try Simulation.make(seed: seed)
            let sockets = sim.state.cameras.map(\.socketId)
            let housing = sim.state.cameras.map(\.housingFamily)
            let ids = sim.state.cameras.map(\.entityId.raw)
            if i == 0 {
                firstSockets = sockets
                firstHousing = housing
                firstIds = ids
            } else {
                #expect(sockets == firstSockets)
                #expect(housing == firstHousing)
                #expect(ids == firstIds)
            }
            let initialIntegrity = sim.state.cameras.map(\.integrity)
            #expect(initialIntegrity.allSatisfy { $0 == 3 })
            sim.restart()
            let restarted = sim.state.cameras
            let restartedSockets = restarted.map(\.socketId)
            let restartedHousing = restarted.map(\.housingFamily)
            let restartedIds = restarted.map(\.entityId.raw)
            #expect(restartedSockets == firstSockets)
            #expect(restartedHousing == firstHousing)
            #expect(restartedIds == firstIds)
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
        #expect(counts["Z-02"] == 2)
        #expect(counts["Z-03"] == 1)
        #expect(counts["Z-04"] == 2)
        #expect(counts["Z-05"] == 2)
        #expect(counts["Z-06"] == 1)
        #expect(cameras.count == 8)
        #expect(CameraPlacement.selectedSetPassesRuntimeAsserts(cameras))
    }

    @Test func cameraCP003TutorialFourFamiliesFourReturnVisible() throws {
        let arena = try ArenaManifest.bundled()
        for seed: UInt64 in [1, 2, 3, 7, 11, 42] {
            var allocator = EntityAllocator()
            _ = allocator.next()
            let cameras = try #require(
                CameraPlacement.select(
                    sockets: arena.cameraSockets,
                    geometry: arena.standardCameraGeometry,
                    runSeed: seed,
                    allocator: &allocator
                )
            )
            #expect(cameras.contains { $0.zoneId == "Z-02" && $0.tutorialEligible })
            #expect(Set(cameras.map(\.housingFamily)).count >= 4)
            #expect(cameras.filter(\.returnVisible).count >= 4)
        }
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
        #expect(!z02.isSuperset(of: ["cam-z02-a", "cam-z02-d"]))
        #expect(z02 == ["cam-z02-a", "cam-z02-b"])
        #expect(found.filter(\.returnVisible).count >= 4)
        #expect(found.contains { $0.tutorialEligible })
    }

    @Test func cameraCP005InsufficientZonePoolRejectedBeforeTickOne() throws {
        var arena = try ArenaManifest.bundled()
        for i in arena.cameraSockets.indices where arena.cameraSockets[i].zoneId == "Z-02" {
            if arena.cameraSockets[i].socketId != "cam-z02-a" {
                arena.cameraSockets[i].enabled = false
            }
        }
        #expect(!CameraPlacement.manifestPoolIsValid(arena.cameraSockets))
        var allocator = EntityAllocator()
        _ = allocator.next()
        #expect(
            CameraPlacement.select(
                sockets: arena.cameraSockets,
                geometry: arena.standardCameraGeometry,
                runSeed: 1,
                allocator: &allocator
            ) == nil
        )
        #expect(throws: ArenaValidationError.cameraPlacement) {
            _ = try Simulation(seed: 1, arena: arena, content: .bundled())
        }
    }

    @Test func cameraCP006NoCompatibleSetFailsArenaValidation() throws {
        var arena = try ArenaManifest.bundled()
        let z02 = arena.cameraSockets.filter { $0.zoneId == "Z-02" }.map(\.socketId)
        for i in arena.cameraSockets.indices where arena.cameraSockets[i].zoneId == "Z-02" {
            let id = arena.cameraSockets[i].socketId
            arena.cameraSockets[i].incompatibleSocketIds = z02.filter { $0 != id }
        }
        #expect(CameraPlacement.manifestPoolIsValid(arena.cameraSockets))
        #expect(!CameraPlacement.hasCompleteCompatibleSet(arena.cameraSockets))
        #expect(throws: ArenaValidationError.cameraPlacement) {
            try ArenaLoader.validate(arena)
        }
        var allocator = EntityAllocator()
        _ = allocator.next()
        #expect(
            CameraPlacement.select(
                sockets: arena.cameraSockets,
                geometry: arena.standardCameraGeometry,
                runSeed: 1,
                allocator: &allocator
            ) == nil
        )
    }

    @Test func cameraCP007DifferentSeedsObserveMoreThanOneLayout() throws {
        let arena = try ArenaManifest.bundled()
        var layouts = Set<String>()
        for seed: UInt64 in 1...48 {
            var allocator = EntityAllocator()
            _ = allocator.next()
            let cameras = try #require(
                CameraPlacement.select(
                    sockets: arena.cameraSockets,
                    geometry: arena.standardCameraGeometry,
                    runSeed: seed,
                    allocator: &allocator
                )
            )
            layouts.insert(CameraPlacement.setKey(cameras))
        }
        #expect(layouts.count > 1)
    }

    @Test func cameraCP008DestroyedThenSameSeedRestartRestoresOperational() throws {
        var sim = try Simulation.make(seed: 11)
        let sockets = sim.state.cameras.map(\.socketId)
        let housing = sim.state.cameras.map(\.housingFamily)
        let ids = sim.state.cameras.map(\.entityId.raw)
        sim.testing_destroyCameras()
        let destroyedIntegrity = sim.state.cameras.map(\.integrity)
        #expect(destroyedIntegrity.allSatisfy { $0 == 0 })
        sim.restart()
        let restored = sim.state.cameras
        let restoredSockets = restored.map(\.socketId)
        let restoredHousing = restored.map(\.housingFamily)
        let restoredIds = restored.map(\.entityId.raw)
        let restoredIntegrity = restored.map(\.integrity)
        #expect(restoredSockets == sockets)
        #expect(restoredHousing == housing)
        #expect(restoredIds == ids)
        #expect(restoredIntegrity.allSatisfy { $0 == 3 })
        let receipt = RunReceipt(sim.state)
        let receiptVersion = receipt.cameraPlacementVersion
        let receiptSeed = receipt.placementSeed
        let receiptSockets = receipt.selectedSockets.map(\.socketId)
        #expect(receiptVersion == ContractVersions.cameraPlacement)
        #expect(receiptSeed == CameraPlacement.placementSeed(runSeed: 11))
        #expect(receiptSockets == sockets)
    }

    @Test func cameraCP009PlacementDoesNotPerturbCombatRng() throws {
        let combat = Xoshiro256StarStar.combat(runSeed: 19)
        let before = (combat.s0, combat.s1, combat.s2, combat.s3)
        let sim = try Simulation.make(seed: 19)
        let after = sim.state.combatRng
        #expect(after.s0 == before.0)
        #expect(after.s1 == before.1)
        #expect(after.s2 == before.2)
        #expect(after.s3 == before.3)
        var combatAgain = Xoshiro256StarStar.combat(runSeed: 19)
        var sequence: [UInt64] = []
        for _ in 0..<8 { sequence.append(combatAgain.next()) }
        var control = Xoshiro256StarStar.combat(runSeed: 19)
        _ = CameraPlacement.placementSeed(runSeed: 19)
        var afterPlacement: [UInt64] = []
        for _ in 0..<8 { afterPlacement.append(control.next()) }
        #expect(sequence == afterPlacement)
    }

    @Test func cameraCP010EveryLegalSetFairness() throws {
        let arena = try ArenaManifest.bundled()
        #expect(CameraPlacement.manifestPoolIsValid(arena.cameraSockets))
        let legal = CameraPlacement.enumerateLegalSocketSets(arena.cameraSockets)
        #expect(!legal.isEmpty)
        let originKnownCount = legal.filter { $0.contains { $0.socketId == "cam-z02-d" } }.count
        let z01KnownCount = legal.filter { $0.contains { $0.socketId == "cam-z02-b" } }.count
        let report = CameraFairness.evaluate(arena)
        #expect(report.legalSetCount == legal.count)
        // Pinned civic-seam-arena-001.json coordinates are authority; do not rewrite them.
        // cam-z02-d field origin sits in a solid (Civic Pulse stand empty).
        // cam-z02-b field leaks into walkable Z-01; spawn-point alley protection still holds.
        #expect(report.originInSolidSockets == ["cam-z02-d"])
        #expect(report.unhittableSockets == ["cam-z02-d"])
        #expect(report.z01LeakingSockets == ["cam-z02-b"])
        #expect(report.fieldOriginKeys.count == originKnownCount)
        #expect(report.pulseStandKeys.count == originKnownCount)
        #expect(report.accessibilityKeys.count == originKnownCount)
        #expect(report.protectedZ01Keys.count == z01KnownCount)
        #expect(originKnownCount > 0)
        #expect(z01KnownCount > 0)
        #expect(report.overlapKeys.isEmpty)
        #expect(report.extractionKeys.isEmpty)
        #expect(report.chokeKeys.isEmpty)
        #expect(report.zeroContactRouteKeys.isEmpty)
        #expect(report.z04BranchKeys.isEmpty)
        #expect(report.captainSafeKeys.isEmpty)
    }
}
