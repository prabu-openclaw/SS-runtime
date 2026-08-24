import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct AudioProjectorSmokeTests {
    @Test func audioAH004DisabledSettingsLeaveDigestUnchanged() throws {
        var sim = try Simulation.make(seed: 3)
        let before = sim.state.digest()
        var projector = AudioProjector()
        _ = projector.project(
            tick: sim.state.tick,
            events: [],
            state: sim.state,
            settings: .disabled
        )
        #expect(sim.state.digest() == before)
        _ = sim.step(command: PlayerCommand(tick: 1, moveX: 0, moveY: 0, dodgePressed: false))
        #expect(sim.state.digest() != before)
    }
}
