import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct PeakDensityProfilerTests {
    @Test func profileT406CompleteRunsStayWithinPoolCapacity() throws {
        for upgrade in UpgradeID.allCases {
            let metrics = try PeakDensityProfiler.profileCompleteRun(upgrade: upgrade)
            #expect(metrics.peakCivicPoolLive <= PerformanceThresholds.civicPoolCapacity)
            #expect(metrics.peakCamerasLive <= PerformanceThresholds.maxCameraCount)
        }
    }

    @Test func profileT406CivicPoolStressReachesCapacity() throws {
        let metrics = try PeakDensityProfiler.profileCivicPoolStress()
        #expect(metrics.peakCivicPoolLive == PerformanceThresholds.civicPoolCapacity)
    }

    @Test func profileT406AggregateReportIsStable() throws {
        let first = try PeakDensityProfiler.profile()
        let second = try PeakDensityProfiler.profile()
        #expect(first.canonical().sha256Hex() == second.canonical().sha256Hex())
        #expect(first.aggregate.peakTotalLive > 0)
    }

    @Test func profileT406GateC011SimulationBounds() throws {
        let report = try PeakDensityProfiler.profile()
        let ceilings = D021Ceilings.fromSimulation(report)
        #expect(D021CeilingEvaluator.gateC011PassesSimulationBounds(ceilings, report: report))
        #expect(ceilings.status == .simulationMeasured)
        #expect(!ceilings.isSettled)
    }
}

@Suite(.serialized)
struct D021CeilingsTests {
    @Test func d021T406DeviceProfilingSettlesCeilings() throws {
        let report = try PeakDensityProfiler.profile()
        var ceilings = D021Ceilings.fromSimulation(report)
        ceilings = ceilings.withDeviceProfiling(residentMemoryBytes: 128_000_000, atlasMemoryBytes: 64_000_000)
        #expect(ceilings.isSettled)
        #expect(ceilings.residentMemoryBytes == 128_000_000)
    }

    @Test func d021T406EvaluatorProfilesFromSimulation() throws {
        let ceilings = try D021CeilingEvaluator.profileAndMeasure()
        #expect(ceilings.peakCivicPoolLive <= PerformanceThresholds.civicPoolCapacity)
        #expect(ceilings.canonical().sha256Hex().count == 64)
    }
}

@Suite struct DefectRegistryTests {
    @Test func defectT906RegistryHasNoOpenSeverityOneOrTwo() {
        #expect(DefectRegistry.openSeverityOneDefects == 0)
        #expect(DefectRegistry.openSeverityTwoDefects == 0)
        #expect(DefectRegistry.openDefects.isEmpty)
    }

    @Test func defectT906RegistryCanonicalRoundTrip() {
        let serialized = DefectRegistry.canonical().serialize()
        #expect(serialized.contains("\"openSeverityOneDefects\":0"))
        #expect(serialized.contains("\"openSeverityTwoDefects\":0"))
    }
}
