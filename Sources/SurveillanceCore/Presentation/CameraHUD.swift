public struct CameraHUDQuery: Equatable, Sendable {
    public var targetIntegrity: Int
    public var damageable: Bool
    public var targeted: Bool
    public var inRange: Bool
    public var damaged: Bool

    public init(
        targetIntegrity: Int = 0,
        damageable: Bool = false,
        targeted: Bool = false,
        inRange: Bool = false,
        damaged: Bool = false
    ) {
        self.targetIntegrity = targetIntegrity
        self.damageable = damageable
        self.targeted = targeted
        self.inRange = inRange
        self.damaged = damaged
    }

    public static let none = CameraHUDQuery()
}

public struct CameraHUDProjection: Equatable, Sendable {
    public var notchesVisible: Bool
    public var notchFilled: [Bool]
    public var tamperVisible: Bool
    public var tamperCopy: String

    /// The memberwise initializer is module-internal; the App layer seeds the
    /// initial projection before the first tick and needs a public one.
    public init(notchesVisible: Bool, notchFilled: [Bool], tamperVisible: Bool, tamperCopy: String) {
        self.notchesVisible = notchesVisible
        self.notchFilled = notchFilled
        self.tamperVisible = tamperVisible
        self.tamperCopy = tamperCopy
    }
}

/// Presentation-only Integrity notches and Tamper Spike. Does not enter the digest.
public struct CameraHUDProjector: Equatable, Sendable {
    public var lastHitTick: UInt64?
    public var lastDestroyTick: UInt64?
    public var persistedIntegrity: Int

    public init() {
        lastHitTick = nil
        lastDestroyTick = nil
        persistedIntegrity = 0
    }

    public mutating func reset() {
        self = CameraHUDProjector()
    }

    public mutating func project(
        tick: UInt64,
        events: [AuthoritativeEvent],
        query: CameraHUDQuery
    ) -> CameraHUDProjection {
        let hit = events.contains { $0.type == .cameraIntegrityChanged || $0.type == .cameraDestroyed }
        let destroyed = events.contains { $0.type == .cameraDestroyed }
        if hit {
            lastHitTick = tick
            persistedIntegrity = query.damageable ? query.targetIntegrity : 0
        }
        if destroyed {
            lastDestroyTick = tick
            persistedIntegrity = 0
        }
        if query.damageable {
            persistedIntegrity = query.targetIntegrity
        }
        let persistHit = within(lastHitTick, tick: tick, window: HUDLayout.integrityNotchPersistTicks)
        let persistTamper = within(lastDestroyTick, tick: tick, window: HUDLayout.integrityNotchPersistTicks)
        let live = query.damageable && (query.targeted || query.damaged || query.inRange)
        let notchesVisible = (live || persistHit) && persistedIntegrity > 0
        let integrity = notchesVisible ? persistedIntegrity : 0
        let filled = (0..<HUDLayout.integrityNotchCount).map {
            HUDLayout.integrityNotchFilled(integrity: integrity, index: $0)
        }
        return CameraHUDProjection(
            notchesVisible: notchesVisible,
            notchFilled: filled,
            tamperVisible: persistTamper,
            tamperCopy: persistTamper ? HUDLayout.tamperCopy : ""
        )
    }

    private func within(_ last: UInt64?, tick: UInt64, window: UInt64) -> Bool {
        guard let last, tick >= last else { return false }
        return tick - last < window
    }
}
