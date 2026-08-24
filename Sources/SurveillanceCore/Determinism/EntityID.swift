public struct EntityID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let raw: UInt64

    public init(_ raw: UInt64) {
        self.raw = raw
    }

    public var description: String { String(raw) }
    public var decimalString: String { String(raw) }

    public static func < (lhs: EntityID, rhs: EntityID) -> Bool {
        lhs.raw < rhs.raw
    }
}

public struct EntityAllocator: Equatable, Sendable {
    public private(set) var nextRaw: UInt64

    public init(start: UInt64 = 1) {
        precondition(start >= 1)
        self.nextRaw = start
    }

    public mutating func next() -> EntityID {
        precondition(nextRaw < .max, "Entity ID overflow")
        let id = EntityID(nextRaw)
        nextRaw += 1
        return id
    }
}
