import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CombatAuthorityReceiptTests {
    @Test func receiptT708BossPhasesCanonicalOrder() {
        let canonical = BossPhase.canonicalPhasesReached([
            "independentReview",
            "publicSafety",
            "temporarySafeguard"
        ])
        #expect(canonical == ["publicSafety", "temporarySafeguard", "independentReview"])
    }

    @Test func receiptT708ObjectivesMatchEncounterObjectivesContract() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeMobAndEliteGraph()
        sim.testing_installBoss(integrity: 800)
        sim.testing_setPhasesReached([
            BossPhase.civilLiberties.rawValue,
            BossPhase.publicSafety.rawValue
        ])
        let receipt = RunReceipt(sim.state)
        let serialized = receipt.canonical().serialize()
        #expect(serialized.contains("\"currentNode\":\"algorithmicModerate\""))
        #expect(serialized.contains("\"extractionArmed\":false"))
        #expect(serialized.contains("\"extraction\":{\"armed\"") == false)
        #expect(receipt.combatAuthority.bossPhasesReached == [
            BossPhase.publicSafety.rawValue,
            BossPhase.civilLiberties.rawValue
        ])
    }

    @Test func receiptT708RootBossMirrorsCombatAuthorityBoss() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeCombatGraph()
        _ = sim.step(command: .neutral(tick: 1))
        let receipt = RunReceipt(sim.state)
        #expect(receipt.bossDefeated == receipt.combatAuthority.bossDefeated)
        #expect(receipt.bossPhases == receipt.combatAuthority.bossPhasesReached)
        #expect(receipt.combatAuthority.complete)
        #expect(receipt.extractionArmed)
    }

    @Test func receiptT708DefeatedBossReceiptListsCanonicalPhases() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeMobAndEliteGraph()
        sim.testing_installBoss(integrity: 10)
        let bossPosition = sim.state.enemies.first(where: { $0.archetype == .algorithmicModerate })!.position
        sim.testing_injectPulseHitting(position: bossPosition)
        _ = sim.step(command: .neutral(tick: 1))
        let receipt = RunReceipt(sim.state)
        #expect(receipt.combatAuthority.bossDefeated)
        #expect(receipt.combatAuthority.bossPhasesReached.contains(BossPhase.publicSafety.rawValue))
    }
}
