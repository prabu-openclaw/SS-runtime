import Testing
@testable import SurveillanceCore

@Suite struct DeviceRunEvidenceTests {
    @Test func deviceT905PerformanceFloorBuildsEvidence() {
        let evidence = DeviceRunEvidence.performanceFloor(
            consecutiveCompleteRuns: 3,
            frameTimePassesGateC: true,
            memoryWarnings: 0,
            thermalState: "nominal",
            residentMemoryBytes: 120_000_000,
            atlasMemoryBytes: 48_000_000
        )
        #expect(evidence.consecutiveCompleteRuns == 3)
        #expect(evidence.frameTimePassesGateC)
        #expect(evidence.seriousOrCriticalThermalEvents == 0)
        #expect(evidence.residentMemoryBytes == 120_000_000)
    }

    @Test func deviceT905SettlesD021FromSimulationCeilings() throws {
        let simulation = try D021CeilingEvaluator.profileAndMeasure()
        let evidence = DeviceRunEvidence.performanceFloor(
            consecutiveCompleteRuns: 3,
            frameTimePassesGateC: true,
            memoryWarnings: 0,
            thermalState: "nominal",
            residentMemoryBytes: 120_000_000,
            atlasMemoryBytes: 48_000_000
        )
        let settled = try #require(evidence.settledD021Ceilings(from: simulation))
        #expect(settled.isSettled)
        #expect(settled.peakCivicPoolLive == simulation.peakCivicPoolLive)
    }

    @Test func deviceT905GateResultsPassWhenPerformanceFloorMet() {
        let evidence = DeviceRunEvidence.performanceFloor(
            consecutiveCompleteRuns: 3,
            frameTimePassesGateC: true,
            memoryWarnings: 0,
            thermalState: "nominal",
            residentMemoryBytes: 120_000_000,
            atlasMemoryBytes: 48_000_000
        )
        let results = evidence.gateResults()
        #expect(results.contains { $0.gateId == "C-001" && $0.passed })
        #expect(results.allSatisfy { $0.passed })
    }

    @Test func evidenceT907CollectsWithDeviceProfilingAndSettledD021() throws {
        let simulation = try D021CeilingEvaluator.profileAndMeasure()
        let device = DeviceRunEvidence.performanceFloor(
            consecutiveCompleteRuns: 3,
            frameTimePassesGateC: true,
            memoryWarnings: 0,
            thermalState: "nominal",
            residentMemoryBytes: 120_000_000,
            atlasMemoryBytes: 48_000_000
        )
        let settled = try #require(device.settledD021Ceilings(from: simulation))
        let evidence = try ReleaseCandidateEvidenceCollector.collect(
            options: ReleaseCandidateEvidenceCollector.Options(
                deviceEvidence: [device],
                d021DeviceProfiling: settled
            )
        )
        #expect(evidence.d021Settled)
        #expect(evidence.expansionGateDecision == .notComputable)
    }
}
