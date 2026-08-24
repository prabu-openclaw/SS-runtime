/// T900: authoritative run telemetry sampled from simulation state.
/// Presentation-layer frame time, memory, and thermal sampling live in App/Instrumentation.
public struct RunTelemetrySnapshot: Equatable, Sendable {
    public var schemaVersion: String
    public var tick: UInt64
    public var outcome: RunOutcome
    public var entities: EntityCounts
    public var exposure: ExposureSample
    public var damage: DamageSample
    public var outcomeSummary: OutcomeSample

    public struct EntityCounts: Equatable, Sendable {
        public var camerasLive: Int
        public var enemiesLive: Int
        public var projectilesLive: Int
        public var minesLive: Int
        public var civicPoolLive: Int
        public var civicPoolCapacity: Int
        public var allocatorNext: UInt64

        public var totalLive: Int {
            camerasLive + enemiesLive + projectilesLive + minesLive + civicPoolLive
        }
    }

    public struct ExposureSample: Equatable, Sendable {
        public var value: Int
        public var peak: Int
        public var detectionState: DetectionState
        public var lockdownEntered: Bool
    }

    public struct DamageSample: Equatable, Sendable {
        public var playerIntegrity: Int
        public var damageTaken: Int
        public var damageDealt: Int
    }

    public struct OutcomeSample: Equatable, Sendable {
        public var camerasDestroyed: Int
        public var networkBlackout: Bool
        public var extractionArmed: Bool
        public var bossDefeated: Bool
        public var terminal: Bool
    }

    public init(_ state: WorldState) {
        schemaVersion = "run-telemetry-001"
        tick = state.tick
        outcome = state.outcome
        entities = EntityCounts(
            camerasLive: state.cameras.filter { $0.integrity > 0 }.count,
            enemiesLive: state.enemies.filter(\.alive).count,
            projectilesLive: state.projectiles.filter(\.alive).count,
            minesLive: state.mines.filter { $0.lifeRemaining > 0 }.count,
            civicPoolLive: state.civicPool.liveCount,
            civicPoolCapacity: state.civicPool.slots.count,
            allocatorNext: state.allocator.nextRaw
        )
        exposure = ExposureSample(
            value: state.exposure.exposure,
            peak: state.exposure.peak,
            detectionState: state.exposure.detectionState,
            lockdownEntered: state.exposure.lockdownEntered
        )
        damage = DamageSample(
            playerIntegrity: state.player.integrity,
            damageTaken: state.player.damageTaken,
            damageDealt: state.combat.damageDealt
        )
        outcomeSummary = OutcomeSample(
            camerasDestroyed: state.destructions.count,
            networkBlackout: state.networkBlackout,
            extractionArmed: state.extraction.armed,
            bossDefeated: state.bossDefeated,
            terminal: state.outcome != .playing
        )
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "tick": .unsigned(tick),
            "outcome": .string(outcome.rawValue),
            "entities": .object([
                "camerasLive": .integer(Int64(entities.camerasLive)),
                "enemiesLive": .integer(Int64(entities.enemiesLive)),
                "projectilesLive": .integer(Int64(entities.projectilesLive)),
                "minesLive": .integer(Int64(entities.minesLive)),
                "civicPoolLive": .integer(Int64(entities.civicPoolLive)),
                "civicPoolCapacity": .integer(Int64(entities.civicPoolCapacity)),
                "allocatorNext": .unsigned(entities.allocatorNext),
                "totalLive": .integer(Int64(entities.totalLive))
            ]),
            "exposure": .object([
                "value": .integer(Int64(exposure.value)),
                "peak": .integer(Int64(exposure.peak)),
                "detectionState": .string(exposure.detectionState.rawValue),
                "lockdownEntered": .bool(exposure.lockdownEntered)
            ]),
            "damage": .object([
                "playerIntegrity": .integer(Int64(damage.playerIntegrity)),
                "damageTaken": .integer(Int64(damage.damageTaken)),
                "damageDealt": .integer(Int64(damage.damageDealt))
            ]),
            "outcomeSummary": .object([
                "camerasDestroyed": .integer(Int64(outcomeSummary.camerasDestroyed)),
                "networkBlackout": .bool(outcomeSummary.networkBlackout),
                "extractionArmed": .bool(outcomeSummary.extractionArmed),
                "bossDefeated": .bool(outcomeSummary.bossDefeated),
                "terminal": .bool(outcomeSummary.terminal)
            ])
        ])
    }
}
