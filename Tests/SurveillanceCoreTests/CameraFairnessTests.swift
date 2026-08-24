import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CameraFairnessTests {
    @Test func cameraCP010EveryLegalSetFairness() throws {
        let arena = try ArenaManifest.bundled()
        let poolOk = CameraPlacement.manifestPoolIsValid(arena.cameraSockets)
        let legal = CameraPlacement.enumerateLegalSocketSets(arena.cameraSockets)
        let originKnownCount = legal.filter { $0.contains { $0.socketId == "cam-z02-d" } }.count
        let z01KnownCount = legal.filter { $0.contains { $0.socketId == "cam-z02-b" } }.count
        let report = CameraFairness.evaluate(arena)
        let originSockets = report.originInSolidSockets
        let unhittable = report.unhittableSockets
        let leaking = report.z01LeakingSockets
        let legalCount = report.legalSetCount
        let fieldOrigin = report.fieldOriginKeys.count
        let pulse = report.pulseStandKeys.count
        let access = report.accessibilityKeys.count
        let z01Keys = report.protectedZ01Keys.count
        let overlap = report.overlapKeys.count
        let extraction = report.extractionKeys.count
        let choke = report.chokeKeys.count
        let zeroContact = report.zeroContactRouteKeys.count
        let z04 = report.z04BranchKeys.count
        let captain = report.captainSafeKeys.count
        #expect(poolOk)
        #expect(legalCount == legal.count)
        #expect(!legal.isEmpty)
        // Pinned civic-seam-arena-001.json coordinates are authority; do not rewrite them.
        // cam-z02-d field origin sits in a solid (Civic Pulse stand empty).
        // cam-z02-b field leaks into walkable Z-01; spawn-point alley protection still holds.
        #expect(originSockets == ["cam-z02-d"])
        #expect(unhittable == ["cam-z02-d"])
        #expect(leaking == ["cam-z02-b"])
        #expect(fieldOrigin == originKnownCount)
        #expect(pulse == originKnownCount)
        #expect(access == originKnownCount)
        #expect(z01Keys == z01KnownCount)
        #expect(originKnownCount > 0)
        #expect(z01KnownCount > 0)
        #expect(overlap == 0)
        #expect(extraction == 0)
        #expect(choke == 0)
        #expect(zeroContact == 0)
        #expect(z04 == 0)
        #expect(captain == 0)
    }
}
