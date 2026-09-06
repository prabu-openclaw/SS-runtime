public enum RunOutcome: String, Equatable, Sendable {
    case playing
    case upgradeSelectionPending
    case success
    case failure
    case invalid

    /// Whether the run is over.
    ///
    /// `upgradeSelectionPending` is deliberately **not** terminal: the run is
    /// paused for a choice, not finished. Treating "not playing" as "over" is
    /// how a tap at the upgrade gate came to restart the whole run, so the
    /// distinction lives here rather than at each call site.
    public var isTerminal: Bool {
        switch self {
        case .success, .failure, .invalid: return true
        case .playing, .upgradeSelectionPending: return false
        }
    }
}

public enum FailureReason: String, Equatable, Sendable {
    case playerDeath
    case contentInvalid
}

public enum DiagnosticCode: String, Equatable, Sendable {
    case incompatibleIdentity
    case duplicateCommandTick
    case lateOrFutureCommand
    case digestMismatch
    case arenaValidation
    case spawnFairnessTimeout
}

public struct UpgradeState: Equatable, Sendable {
    public var selected: UpgradeID?
    public var pending: Bool

    public init(selected: UpgradeID? = nil, pending: Bool = false) {
        self.selected = selected
        self.pending = pending
    }

    public var signalJammer: Bool { selected == .signalJammer }
    public var ricochetPulse: Bool { selected == .ricochetPulse }
    public var ghostStep: Bool { selected == .ghostStep }
}

public struct ExtractionState: Equatable, Sendable {
    public var armed: Bool
    public var remaining: Int
    public var wasInside: Bool

    public init(armed: Bool = false, remaining: Int = 300, wasInside: Bool = false) {
        self.armed = armed
        self.remaining = remaining
        self.wasInside = wasInside
    }
}

public struct CombatTotals: Equatable, Sendable {
    public var damageDealt: Int = 0
    public var defeatsByArchetype: [String: Int] = [:]
}

public struct CameraDestructionRecord: Equatable, Sendable {
    public var cameraId: EntityID
    public var tick: UInt64
    public var housingFamily: HousingFamily
    public var wasDetectingPlayer: Bool
    public var source: String
    public var exposureBefore: Int
    public var exposureAfter: Int
    public var triggeredLockdown: Bool
}

public struct GateState: Equatable, Sendable {
    public var id: String
    public var closed: Bool
    public var box: AABB
}

public struct TickResult: Equatable, Sendable {
    public var tick: UInt64
    public var events: [AuthoritativeEvent]
    public var digest: String
    public var outcome: RunOutcome
}
