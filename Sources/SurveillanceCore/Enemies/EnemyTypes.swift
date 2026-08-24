public enum EnemyAIState: Equatable, Sendable {
    case pursue
    case orbit
    case telegraph
    case resolve
    case cooldown
    case charge
    case recover
    case keepRange
    case fire
    case throwMine
    case queryTelegraph
    case queryResolve
    case dashTelegraph
    case dash
}

public struct EnemyBody: Equatable, Sendable {
    public var id: EntityID
    public var archetype: ArchetypeID
    public var position: VecQ8
    public var velocity: VecQ8
    public var integrity: Int
    public var radius: Int
    public var speedUnitsPerSecond: Int
    public var contactDps: Int
    public var state: EnemyAIState
    public var stateTicks: Int
    public var spawnTick: UInt64
    public var nextSpecialTick: UInt64
    public var lockPosition: VecQ8?
    public var encounterId: String
    public var alive: Bool { integrity > 0 }
}

public struct MineBody: Equatable, Sendable {
    public var id: EntityID
    public var ownerId: EntityID
    public var position: VecQ8
    public var armRemaining: Int
    public var lifeRemaining: Int
    public var radius: Int
    public var damage: Int
    public var armed: Bool { armRemaining <= 0 }
}

public struct EncounterRuntime: Equatable, Sendable {
    public var id: String
    public var activated: Bool
    public var completed: Bool
    public var waveIndex: Int
    public var spawnQueue: [ArchetypeID]
    public var nextSpawnTick: UInt64
    public var deferTicks: Int
    public var living: Int
    public var spawned: Int
    public var cleanupTick: UInt64?
}

public enum EncounterDirector {
    public static let encounterOrder = ["M-A", "M-B", "M-C"]
}
