/// encounter-objectives-001 combat authority lane (required for Extraction).
public enum CombatAuthorityNode: String, Equatable, Sendable {
    case mobA = "M-A"
    case mobB = "M-B"
    case mobC = "M-C"
    case improperSearchDaemon
    case algorithmicModerate
    case extraction
}

public struct CombatAuthoritySnapshot: Equatable, Sendable {
    public var mobEncountersComplete: Int
    public var mobEncountersRequired: Int
    public var eliteDefeated: Bool
    public var bossDefeated: Bool
    public var bossPhasesReached: [String]
    public var complete: Bool
    public var currentNode: CombatAuthorityNode

    public static func project(_ state: WorldState) -> CombatAuthoritySnapshot {
        let mobA = state.encounters["M-A"]?.completed == true
        let mobB = state.encounters["M-B"]?.completed == true
        let mobC = state.encounters["M-C"]?.completed == true
        let mobComplete = [mobA, mobB, mobC].filter { $0 }.count

        let node: CombatAuthorityNode
        if state.extraction.armed {
            node = .extraction
        } else if !mobA {
            node = .mobA
        } else if !mobB {
            node = .mobB
        } else if !mobC {
            node = .mobC
        } else if !state.eliteDefeated {
            node = .improperSearchDaemon
        } else if !state.bossDefeated {
            node = .algorithmicModerate
        } else {
            node = .extraction
        }

        let complete = mobComplete == 3 && state.eliteDefeated && state.bossDefeated
        return CombatAuthoritySnapshot(
            mobEncountersComplete: mobComplete,
            mobEncountersRequired: EncounterDirector.mobEncounterCount,
            eliteDefeated: state.eliteDefeated,
            bossDefeated: state.bossDefeated,
            bossPhasesReached: BossPhase.canonicalPhasesReached(state.phasesReached),
            complete: complete,
            currentNode: node
        )
    }
}

extension EncounterDirector {
    public static let mobEncounterCount = 3
    public static let eliteReceiptId = "improper-search-daemon"
    public static let bossReceiptId = "algorithmic-moderate"

    public static func combatAuthority(_ state: WorldState) -> CombatAuthoritySnapshot {
        CombatAuthoritySnapshot.project(state)
    }
}
