import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CameraDestructionOrderTests {
    @Test func cameraCD003DestroyWhileDetectingOmitsContactDelta() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        let camera = sim.state.cameras[0]
        let px = camera.position.x
        let py = camera.position.y
        let ax = camera.targetAnchor.x.unitsTruncated
        let ay = camera.targetAnchor.y.unitsTruncated
        sim.testing_setPlayerPosition(
            VecI(x: px + (ax - px) * 3 / 2, y: py + (ay - py) * 3 / 2)
        )
        sim.testing_injectPulseHitting(camera: camera)
        _ = sim.step(command: .neutral(tick: 1))
        let integrity = sim.state.cameras[0].integrity
        let destroyed = sim.state.destructions.count
        let detecting = sim.state.destructions.first?.wasDetectingPlayer ?? false
        let exposure = sim.state.exposure.exposure
        let reason = sim.state.exposure.detectionState
        #expect(integrity == 0)
        #expect(destroyed == 1)
        #expect(detecting)
        // Contact from the destroyed Camera is stripped; only +100 Tamper remains (not 102).
        #expect(exposure == 100)
        #expect(reason == .hidden)
    }

    @Test func cameraCD004DestroyWhileNotDetectingStillTampers() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        let camera = sim.state.cameras[0]
        sim.testing_injectPulseHitting(camera: camera)
        _ = sim.step(command: .neutral(tick: 1))
        let integrity = sim.state.cameras[0].integrity
        let detecting = sim.state.destructions.first?.wasDetectingPlayer ?? true
        let exposure = sim.state.exposure.exposure
        let destroyed = sim.state.destructions.count
        #expect(integrity == 0)
        #expect(destroyed == 1)
        #expect(!detecting)
        #expect(exposure == 100)
    }

    @Test func cameraCD007DestroyAt950ClampsAndLockdown() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        sim.testing_setExposure(950)
        let camera = sim.state.cameras[0]
        sim.testing_injectPulseHitting(camera: camera)
        _ = sim.step(command: .neutral(tick: 1))
        let exposure = sim.state.exposure.exposure
        let lockdown = sim.state.exposure.lockdownEntered
        let state = sim.state.exposure.detectionState
        let destroyed = sim.state.destructions.count
        #expect(destroyed == 1)
        #expect(exposure == 1000)
        #expect(lockdown)
        #expect(state == .lockdown)
    }

    @Test func cameraCD010DeathTickStillRecordsTamper() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_keepOnlyCamera(at: 0, integrity: 1)
        sim.testing_setPlayerIntegrity(0)
        let camera = sim.state.cameras[0]
        sim.testing_injectPulseHitting(camera: camera)
        let result = sim.step(command: .neutral(tick: 1))
        let outcome = result.outcome
        let destroyed = sim.state.destructions.count
        let exposure = sim.state.exposure.exposure
        let reason = sim.state.failureReason
        #expect(outcome == .failure)
        #expect(reason == .playerDeath)
        #expect(destroyed == 1)
        #expect(exposure == 100)
    }

    @Test func cameraT410SurvivingContactThenTamperAddsBoth() {
        var state = ExposureState()
        let result = state.resolveTick(survivingContactCount: 1, tamperAmounts: [100], signalJammer: false)
        #expect(result.contactDelta == 2)
        #expect(result.tamperApplied == 100)
        #expect(state.exposure == 102)
        #expect(result.reason == .cameraTamper)
    }
}
