import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct GateVerificationTests {
    @Test func gateT902RegistryCoversPhaseNineAutomatedGates() {
        #expect(GateRegistry.automatedGateIds.contains("B-001"))
        #expect(GateRegistry.automatedGateIds.contains("B-016"))
        #expect(GateRegistry.automatedGateIds.contains("C-008"))
        #expect(GateRegistry.automatedGateIds.contains("C-009"))
        #expect(GateRegistry.automatedGateIds.contains("A-008"))
        #expect(GateRegistry.automatedGateIds.contains("F-017"))
        #expect(!GateRegistry.automatedGateIds.isEmpty)
    }

    @Test func gateT902AllGateFamiliesEnumerated() {
        #expect(GateRegistry.functional.count == 22)
        #expect(GateRegistry.determinism.count == 17)
        #expect(GateRegistry.stability.count == 11)
        #expect(GateRegistry.visual.count == 21)
        #expect(GateRegistry.arena.count == 20)
        #expect(GateRegistry.accessibility.count == 17)
        #expect(GateRegistry.playtest.count == 7)
        #expect(GateRegistry.allGateIds.count == 115)
    }

    @Test func gateT902DeviceGatesRequirePhysicalEvidence() {
        #expect(GateRegistry.deviceGateIds.contains("C-001"))
        #expect(GateRegistry.deviceGateIds.contains("C-002"))
        #expect(GateRegistry.deviceGateIds.contains("C-011"))
        #expect(GateRegistry.evidence(for: "C-001")?.kind == .deviceCapture)
    }

    @Test func gateT902PlaytestGatesMapToT903T904() {
        #expect(GateRegistry.playtestGateIds.contains("G-001"))
        #expect(GateRegistry.evidence(for: "G-001")?.note?.contains("T903") == true)
    }

    @Test func gateT902UnmappedGatesTrackedForT907() {
        let unmapped = GateRegistry.unmappedGateIds()
        #expect(unmapped.count > 0)
        #expect(unmapped.contains("A-001"))
        #expect(!unmapped.contains("B-001"))
    }

    @Test func gateC009TenConsecutiveCompleteRunsPass() throws {
        for upgrade in UpgradeID.allCases {
            for _ in 0..<10 {
                var sim = try Simulation.make(seed: 1)
                let result = sim.testing_completeRunSuccess(upgrade: upgrade)
                #expect(result.outcome == .success)
                #expect(sim.state.destructions.count == 0)
                let telemetry = RunTelemetrySnapshot(sim.state)
                #expect(telemetry.outcomeSummary.terminal)
                #expect(telemetry.entities.civicPoolLive <= PerformanceThresholds.civicPoolCapacity)
            }
        }
    }

    @Test func gateB003RestartRestoresInitialAuthoritativeState() throws {
        var sim = try Simulation.make(seed: 7)
        let initial = sim.state.digest()
        _ = sim.step(command: PlayerCommand(tick: 1, moveX: 32767, moveY: 0, dodgePressed: false))
        #expect(sim.state.digest() != initial)
        sim.restart()
        #expect(sim.state.digest() == initial)
    }

    @Test func gateF017ReceiptCanonicalRoundTrip() throws {
        var sim = try Simulation.make(seed: 1)
        _ = sim.testing_completeRunSuccess(upgrade: .ricochetPulse)
        let receipt = RunReceipt(sim.state)
        let first = receipt.canonical().serialize()
        let second = receipt.canonical().serialize()
        #expect(first == second)
        #expect(receipt.canonical().sha256Hex().count == 64)
    }
}
