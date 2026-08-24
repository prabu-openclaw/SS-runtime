import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct RunTelemetryTests {
    @Test func instrumentT900SnapshotCapturesEntitiesExposureAndDamage() throws {
        var sim = try Simulation.make(seed: 1)
        _ = sim.step(
            command: PlayerCommand(tick: 1, moveX: 32767, moveY: 0, dodgePressed: false)
        )
        let sample = RunTelemetrySnapshot(sim.state)
        #expect(sample.schemaVersion == "run-telemetry-001")
        #expect(sample.tick == 1)
        #expect(sample.entities.camerasLive == 8)
        #expect(sample.entities.civicPoolCapacity == PerformanceThresholds.civicPoolCapacity)
        #expect(sample.exposure.value >= 0)
        #expect(sample.damage.playerIntegrity == sim.state.player.integrity)
        #expect(!sample.outcomeSummary.terminal)
        #expect(sample.canonical().sha256Hex().count == 64)
    }

    @Test func instrumentT900PoolsRemainBounded() throws {
        var sim = try Simulation.make(seed: 1)
        for tick in 1...120 {
            _ = sim.step(
                command: PlayerCommand(
                    tick: UInt64(tick),
                    moveX: Int16(truncatingIfNeeded: tick % 3 == 0 ? 32767 : 0),
                    moveY: 0,
                    dodgePressed: tick % 7 == 0
                )
            )
            let sample = RunTelemetrySnapshot(sim.state)
            #expect(sample.entities.civicPoolLive <= PerformanceThresholds.civicPoolCapacity)
            #expect(sample.entities.projectilesLive <= PerformanceThresholds.civicPoolCapacity)
            #expect(sample.entities.camerasLive <= PerformanceThresholds.maxCameraCount)
        }
    }

    @Test func instrumentT900CompleteRunTerminalOutcome() throws {
        var sim = try Simulation.make(seed: 1)
        _ = sim.testing_completeRunSuccess(upgrade: .signalJammer)
        let sample = RunTelemetrySnapshot(sim.state)
        #expect(sample.outcome == .success)
        #expect(sample.outcomeSummary.terminal)
        #expect(sample.outcomeSummary.bossDefeated)
        #expect(sample.outcomeSummary.extractionArmed)
        #expect(sample.exposure.peak >= sample.exposure.value)
    }

    @Test func instrumentT900PerformanceThresholdsMatchGateC() {
        #expect(PerformanceThresholds.frameTimeP50Ms == 16.67)
        #expect(PerformanceThresholds.frameTimeP99Ms == 25.0)
        #expect(PerformanceThresholds.frameTimeWorstMs == 50.0)
        #expect(PerformanceThresholds.sustainedPresentationFloorFps == 55)
        #expect(PerformanceThresholds.targetPresentationFps == 60)
    }
}
