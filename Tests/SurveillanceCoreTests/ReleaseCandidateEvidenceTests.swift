import Foundation
import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ReleaseCandidateEvidenceTests {
    @Test func evidenceT907CollectsReplayAndCompleteRunDigests() throws {
        let evidence = try ReleaseCandidateEvidenceCollector.collect()
        #expect(evidence.schemaVersion == "release-candidate-evidence-001")
        #expect(evidence.specificationCommit == ContractVersions.specificationCommit)
        #expect(evidence.replayMatrixDigests["RM-001"]?.count == 64)
        #expect(evidence.completeRunDigests.count == UpgradeID.allCases.count)
        #expect(evidence.linkedAutomatedGates.contains("B-001"))
        #expect(!evidence.pendingGateIds.isEmpty)
        #expect(evidence.peakDensityDigest.count == 64)
        #expect(evidence.d021Ceilings.status == .simulationMeasured)
        #expect(evidence.canonical().sha256Hex().count == 64)
    }

    @Test func evidenceT907DefaultExpansionGateIsNotComputable() throws {
        let evidence = try ReleaseCandidateEvidenceCollector.collect()
        #expect(evidence.expansionGateDecision == .notComputable)
        #expect(!evidence.d013Settled)
        #expect(!evidence.d021Settled)
    }

    @Test func evidenceT907DeviceEvidenceCanAdvanceGateC() throws {
        let device = DeviceRunEvidence(
            deviceClass: "iPhone 12",
            consecutiveCompleteRuns: 3,
            frameTimePassesGateC: true,
            memoryWarnings: 0,
            seriousOrCriticalThermalEvents: 0
        )
        let evidence = try ReleaseCandidateEvidenceCollector.collect(
            options: ReleaseCandidateEvidenceCollector.Options(deviceEvidence: [device])
        )
        #expect(device.gateResults().contains { $0.gateId == "C-001" && $0.passed })
        #expect(evidence.expansionGateDecision == .notComputable)
    }

    @Test func evidenceT907SettlesD021WhenDeviceProfilingProvided() throws {
        let report = try PeakDensityProfiler.profile()
        let settled = D021Ceilings.fromSimulation(report)
            .withDeviceProfiling(residentMemoryBytes: 100_000_000, atlasMemoryBytes: 50_000_000)
        let evidence = try ReleaseCandidateEvidenceCollector.collect(
            options: ReleaseCandidateEvidenceCollector.Options(d021DeviceProfiling: settled)
        )
        #expect(evidence.d021Settled)
        #expect(evidence.d021Ceilings.isSettled)
    }

    @Test func evidenceT907PlaytestEvidenceEvaluatesGates() {
        let playtest = PlaytestEvidence(
            taskId: "T903",
            sessions: (1...5).map { index in
                PlaytestSessionRecord(
                    participantId: "p\(index)",
                    completedOnboardingWithoutInstruction: index <= 4,
                    describedExposureCorrectly: index <= 4
                )
            }
        )
        let results = playtest.gateResults()
        #expect(results.contains { $0.gateId == "G-001" && $0.passed })
        #expect(results.contains { $0.gateId == "G-002" && $0.passed })
    }
}

@Suite(.serialized)
struct ExpansionGateDecisionTests {
    @Test func gateT908OpenDefectsFailExpansion() {
        let decision = ExpansionGateEvaluator.evaluate(
            ExpansionGateInputs(
                gateResults: [],
                d013Settled: true,
                d021Settled: true,
                openSeverityOneDefects: 1
            )
        )
        #expect(decision == .failed)
    }

    @Test func gateT908PendingDecisionsBlockComputation() {
        let decision = ExpansionGateEvaluator.evaluate(
            ExpansionGateInputs(
                gateResults: GateRegistry.evidence
                    .filter { $0.kind == .automatedTest }
                    .map { GatePassRecord(gateId: $0.gateId, passed: true, source: .automatedTest) },
                d013Settled: false,
                d021Settled: false
            )
        )
        #expect(decision == .notComputable)
    }

    @Test func gateT908AllRequiredGatesPassWhenFullyEvidenceLinked() {
        var results: [GatePassRecord] = GateRegistry.allGateIds.map {
            GatePassRecord(gateId: $0, passed: true, source: .automatedTest)
        }
        results.append(GatePassRecord(gateId: "G-001", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-002", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-003", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-004", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-005", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-006", passed: true, source: .playtest))
        results.append(GatePassRecord(gateId: "G-007", passed: true, source: .playtest))

        let unique = Dictionary(grouping: results, by: \.gateId).compactMapValues(\.first).values
        let decision = ExpansionGateEvaluator.evaluate(
            ExpansionGateInputs(
                gateResults: Array(unique),
                d013Settled: true,
                d021Settled: true
            )
        )
        #expect(decision == .passed)
    }
}

@Suite(.serialized)
struct ReceiptArchiveTests {
    @Test func receiptER006AtomicWriteAndRetention() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-archive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        final class ClockBox: @unchecked Sendable {
            var date = Date(timeIntervalSince1970: 1_735_689_600)
        }
        let clockBox = ClockBox()
        let archive = ReceiptArchive(
            directory: directory,
            clock: { clockBox.date }
        )

        for index in 0..<51 {
            clockBox.date = Date(timeIntervalSince1970: 1_735_689_600 + Double(index))
            var sim = try Simulation.make(seed: UInt64(index + 1))
            _ = sim.step(command: .neutral(tick: 1))
            let receipt = RunReceipt(sim.state)
            _ = try archive.store(receipt)
        }

        let entries = try archive.listEntries()
        #expect(entries.count == ReceiptArchive.retentionLimit)
        #expect(entries.allSatisfy { $0.filename.hasPrefix("run-") })
        #expect(entries.allSatisfy { $0.filename.hasSuffix(".json") })
    }

    @Test func receiptER006FilenameUsesDigestPrefix() throws {
        var sim = try Simulation.make(seed: 1)
        _ = sim.testing_completeRunSuccess(upgrade: .signalJammer)
        let receipt = RunReceipt(sim.state)
        let filename = ReceiptArchive.filename(for: receipt, at: Date(timeIntervalSince1970: 0))
        #expect(filename.hasPrefix("run-19700101T000000Z-"))
        #expect(filename.contains(String(receipt.finalDigest.prefix(12))))
    }
}
