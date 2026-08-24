import Testing
@testable import SurveillanceCore

private func mountExtents(_ sim: Simulation, socketId: String) -> (Int, Int, Int, Int)? {
    guard let box = sim.state.liveSolids.first(where: { $0.id == "mount-\(socketId)" })?.box else {
        return nil
    }
    return (box.minX, box.maxX, box.minY, box.maxY)
}

@Suite(.serialized)
struct CameraPermanenceTests {
    @Test func cameraCD008HitDestroyedCameraIsIgnored() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 0)
        let camera = sim.state.cameras[0]
        sim.testing_injectPulseHitting(camera: camera)
        _ = sim.step(command: .neutral(tick: 1))
        let integrity = sim.state.cameras[0].integrity
        let destroyed = sim.state.destructions.count
        let exposure = sim.state.exposure.exposure
        let events = sim.step(command: .neutral(tick: 2)).events.filter { $0.type == .cameraDestroyed }.count
        #expect(integrity == 0)
        #expect(destroyed == 0)
        #expect(exposure == 0)
        #expect(events == 0)
    }

    @Test func cameraCD009RestartRestoresOperationalAtFixedTransforms() throws {
        var sim = try Simulation.make(seed: 1)
        let sockets = sim.state.cameras.map(\.socketId)
        let ids = sim.state.cameras.map(\.entityId.raw)
        let headings = sim.state.cameras.map(\.headingMilliDegrees)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        sim.testing_injectPulseHitting(camera: sim.state.cameras[0])
        _ = sim.step(command: .neutral(tick: 1))
        let destroyedCount = sim.state.destructions.count
        let destroyedIntegrity = sim.state.cameras[0].integrity
        sim.restart()
        let restoredSockets = sim.state.cameras.map(\.socketId)
        let restoredIds = sim.state.cameras.map(\.entityId.raw)
        let restoredHeadings = sim.state.cameras.map(\.headingMilliDegrees)
        let restoredIntegrity = sim.state.cameras.map(\.integrity)
        let restoredDestructions = sim.state.destructions.count
        #expect(destroyedCount == 1)
        #expect(destroyedIntegrity == 0)
        #expect(restoredSockets == sockets)
        #expect(restoredIds == ids)
        #expect(restoredHeadings == headings)
        #expect(restoredIntegrity == Array(repeating: 3, count: 8))
        #expect(restoredDestructions == 0)
    }

    @Test func cameraT411DestroyedMountAndPoseStayFixedDuringRun() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        let socket = sim.state.cameras[0].socketId
        let x = sim.state.cameras[0].position.x
        let y = sim.state.cameras[0].position.y
        let heading = sim.state.cameras[0].headingMilliDegrees
        let range = sim.state.cameras[0].rangeUnits
        let mountBefore = mountExtents(sim, socketId: socket)
        sim.testing_injectPulseHitting(camera: sim.state.cameras[0])
        _ = sim.step(command: .neutral(tick: 1))
        for tick in 2...10 {
            _ = sim.step(command: .neutral(tick: UInt64(tick)))
        }
        let integrity = sim.state.cameras[0].integrity
        let xAfter = sim.state.cameras[0].position.x
        let yAfter = sim.state.cameras[0].position.y
        let headingAfter = sim.state.cameras[0].headingMilliDegrees
        let rangeAfter = sim.state.cameras[0].rangeUnits
        let detecting = sim.state.cameras[0].wasDetecting
        let damageable = sim.state.cameras[0].isDamageable
        let mountAfter = mountExtents(sim, socketId: socket)
        let stillPresent = sim.state.cameras.count
        let mountMatch = mountBefore?.0 == mountAfter?.0
            && mountBefore?.1 == mountAfter?.1
            && mountBefore?.2 == mountAfter?.2
            && mountBefore?.3 == mountAfter?.3
        #expect(integrity == 0)
        #expect(!damageable)
        #expect(!detecting)
        #expect(xAfter == x)
        #expect(yAfter == y)
        #expect(headingAfter == heading)
        #expect(rangeAfter == range)
        #expect(mountAfter != nil)
        #expect(mountMatch)
        #expect(stillPresent == 8)
    }
}
