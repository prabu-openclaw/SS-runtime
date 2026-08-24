/// Signed fixed-point world quantity: 1/256 world unit.
public struct Q8: Equatable, Hashable, Comparable, Sendable {
    public static let scale: Int64 = 256

    public var raw: Int64

    public init(raw: Int64) {
        self.raw = raw
    }

    public init(units: Int) {
        self.raw = Int64(units) * Self.scale
    }

    public static var zero: Q8 { Q8(raw: 0) }

    public var unitsTruncated: Int {
        Int(raw / Self.scale)
    }

    public static func + (lhs: Q8, rhs: Q8) -> Q8 { Q8(raw: lhs.raw + rhs.raw) }
    public static func - (lhs: Q8, rhs: Q8) -> Q8 { Q8(raw: lhs.raw - rhs.raw) }
    public static func += (lhs: inout Q8, rhs: Q8) { lhs.raw += rhs.raw }
    public static func -= (lhs: inout Q8, rhs: Q8) { lhs.raw -= rhs.raw }

    public static func < (lhs: Q8, rhs: Q8) -> Bool { lhs.raw < rhs.raw }

    public func squared() -> Int64 {
        raw * raw
    }
}

public struct VecQ8: Equatable, Hashable, Sendable {
    public var x: Q8
    public var y: Q8

    public init(x: Q8, y: Q8) {
        self.x = x
        self.y = y
    }

    public init(unitsX: Int, unitsY: Int) {
        self.x = Q8(units: unitsX)
        self.y = Q8(units: unitsY)
    }

    public static var zero: VecQ8 { VecQ8(x: .zero, y: .zero) }

    public static func + (lhs: VecQ8, rhs: VecQ8) -> VecQ8 {
        VecQ8(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: VecQ8, rhs: VecQ8) -> VecQ8 {
        VecQ8(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public var lengthSquaredRaw: Int64 {
        x.raw * x.raw + y.raw * y.raw
    }

    public func distanceSquared(to other: VecQ8) -> Int64 {
        let dx = x.raw - other.x.raw
        let dy = y.raw - other.y.raw
        return dx * dx + dy * dy
    }

    public var clockwisePerpendicular: VecQ8 {
        VecQ8(x: y, y: Q8(raw: 0 &- x.raw))
    }

    public func offset(units: Int, along direction: VecQ8) -> VecQ8 {
        let mag = IntMath.isqrt(direction.lengthSquaredRaw)
        if mag == 0 { return self }
        let scale = Int64(units) * Q8.scale
        return VecQ8(
            x: Q8(raw: x.raw + IntMath.mulDivHalfAway(direction.x.raw, scale, mag)),
            y: Q8(raw: y.raw + IntMath.mulDivHalfAway(direction.y.raw, scale, mag))
        )
    }

    public func contains(_ point: VecQ8, radiusUnits: Int) -> Bool {
        let r = Int64(radiusUnits) * Q8.scale
        return distanceSquared(to: point) <= r * r
    }
}

public struct VecI: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var asQ8: VecQ8 { VecQ8(unitsX: x, unitsY: y) }
}
