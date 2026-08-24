public struct ProjectilePool: Equatable, Sendable {
    public static let civicPulseCapacity = Targeting.activeCeiling

    public var slots: [ProjectileBody?]
    public var doubleReturn: Bool

    public init(capacity: Int = ProjectilePool.civicPulseCapacity) {
        slots = Array(repeating: nil, count: capacity)
        doubleReturn = false
    }

    public var liveCount: Int { slots.compactMap { $0 }.filter(\.alive).count }

    public mutating func checkout(_ projectile: ProjectileBody) -> Bool {
        if let index = slots.firstIndex(where: { $0 == nil || $0?.alive == false }) {
            var fresh = projectile
            fresh.age = 1
            fresh.hitEntityIds = []
            fresh.alive = true
            slots[index] = fresh
            return true
        }
        return false
    }

    public mutating func release(id: EntityID) {
        guard let index = slots.firstIndex(where: { $0?.id == id }) else {
            doubleReturn = true
            return
        }
        guard slots[index]?.alive == true else {
            doubleReturn = true
            return
        }
        slots[index] = nil
    }

    public var live: [ProjectileBody] {
        slots.compactMap { slot in
            guard let projectile = slot, projectile.alive else { return nil }
            return projectile
        }
    }
}
