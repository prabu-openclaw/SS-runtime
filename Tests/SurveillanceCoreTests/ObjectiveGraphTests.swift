import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ObjectiveGraphTests {
    @Test func objectiveT703FreshRunStartsAtMobA() throws {
        let sim = try Simulation.make(seed: 1)
        let authority = EncounterDirector.combatAuthority(sim.state)
        let copy = HUDLayout.combatObjectiveCopy(
            node: authority.currentNode,
            extractionArmed: sim.state.extraction.armed,
            insideLockedExtraction: false
        )
        #expect(authority.currentNode == .mobA)
        #expect(authority.mobEncountersComplete == 0)
        #expect(!authority.complete)
        #expect(copy == "MOB ENCOUNTER A")
    }

    @Test func objectiveT703GraphAdvancesThroughMobEncounters() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeEncounter("M-A")
        let afterA = EncounterDirector.combatAuthority(sim.state)
        sim.testing_completeEncounter("M-B")
        let afterB = EncounterDirector.combatAuthority(sim.state)
        sim.testing_completeEncounter("M-C")
        let afterC = EncounterDirector.combatAuthority(sim.state)
        #expect(afterA.currentNode == .mobB)
        #expect(afterA.mobEncountersComplete == 1)
        #expect(afterB.currentNode == .mobC)
        #expect(afterB.mobEncountersComplete == 2)
        #expect(afterC.currentNode == .improperSearchDaemon)
        #expect(afterC.mobEncountersComplete == 3)
    }

    @Test func objectiveT703EliteAndBossNodesFollowMobs() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeMobAndEliteGraph()
        let afterElite = EncounterDirector.combatAuthority(sim.state)
        sim.testing_installBoss()
        let duringBoss = EncounterDirector.combatAuthority(sim.state)
        #expect(afterElite.currentNode == .algorithmicModerate)
        #expect(duringBoss.currentNode == .algorithmicModerate)
    }

    @Test func objectiveT703LockedExtractionContactShowsAuthorityCopy() throws {
        var sim = try Simulation.make(seed: 1)
        let extract = sim.state.arena.extraction.center
        sim.testing_setPlayerPosition(VecI(x: extract.x, y: extract.y))
        let snap = PresentationSnapshot(sim.state)
        #expect(snap.combatObjectiveCopy == HUDLayout.lockedExtractionCopy)
    }

    @Test func objectiveT703ReceiptIncludesCombatAuthorityLane() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeMobAndEliteGraph()
        sim.testing_installBoss(integrity: 10)
        let bossPosition = sim.state.enemies.first(where: { $0.archetype == .algorithmicModerate })!.position
        sim.testing_injectPulseHitting(position: bossPosition)
        _ = sim.step(command: .neutral(tick: 1))
        let receipt = RunReceipt(sim.state)
        let authority = receipt.combatAuthority
        #expect(authority.mobEncountersComplete == 3)
        #expect(authority.eliteDefeated)
        #expect(authority.bossDefeated)
        #expect(authority.complete)
        #expect(receipt.extractionArmed)
        #expect(receipt.canonical().serialize().contains("\"combatAuthority\""))
    }

    @Test func objectiveT703NetworkBlackoutDoesNotAdvanceCombatAuthority() throws {
        var sim = try Simulation.make(seed: 1)
        for index in 0..<8 {
            sim.testing_destroyCameraAtIndex(index)
            _ = sim.step(command: .neutral(tick: UInt64(index + 1)))
        }
        let authority = EncounterDirector.combatAuthority(sim.state)
        let armed = sim.state.extraction.armed
        #expect(sim.state.networkBlackout)
        #expect(authority.currentNode == .mobA)
        #expect(!armed)
    }
}
