import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ExpansionGateReportTests {
    @Test func gateT908DefaultReportIsNotComputable() throws {
        let report = try ExpansionGateReporter.evaluate()
        #expect(report.decision == .notComputable)
        #expect(report.openSeverityOneDefects == 0)
        #expect(report.openSeverityTwoDefects == 0)
        #expect(!report.d013Settled)
        #expect(!report.d021Settled)
        #expect(report.pendingGateCount > 0)
        #expect(report.canonical().sha256Hex().count == 64)
    }

    @Test func gateT908OpenDefectsFailReport() throws {
        let report = try ExpansionGateReporter.evaluate(
            options: ReleaseCandidateEvidenceCollector.Options(openSeverityOneDefects: 1)
        )
        #expect(report.decision == .failed)
    }

    @Test func gateT908SettledD021StillNotComputableWithoutFullGates() throws {
        let simulation = try D021CeilingEvaluator.profileAndMeasure()
        let settled = simulation.withDeviceProfiling(
            residentMemoryBytes: 100_000_000,
            atlasMemoryBytes: 50_000_000
        )
        let report = try ExpansionGateReporter.evaluate(
            options: ReleaseCandidateEvidenceCollector.Options(
                d021DeviceProfiling: settled
            )
        )
        #expect(report.d021Settled)
        #expect(report.decision == .notComputable)
    }
}
