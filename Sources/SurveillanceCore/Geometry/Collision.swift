public struct AABB: Equatable, Sendable, Codable {
    public var center: VecI
    public var halfSize: VecI

    public init(center: VecI, halfSize: VecI) {
        self.center = center
        self.halfSize = halfSize
    }

    public var minX: Int { center.x - halfSize.x }
    public var maxX: Int { center.x + halfSize.x }
    public var minY: Int { center.y - halfSize.y }
    public var maxY: Int { center.y + halfSize.y }

    public func contains(_ point: VecI) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func contains(_ point: VecQ8) -> Bool {
        let x = point.x.raw
        let y = point.y.raw
        return x >= Int64(minX) * Q8.scale
            && x <= Int64(maxX) * Q8.scale
            && y >= Int64(minY) * Q8.scale
            && y <= Int64(maxY) * Q8.scale
    }
}

public struct Circle: Equatable, Sendable {
    public var center: VecQ8
    public var radiusUnits: Int

    public init(center: VecQ8, radiusUnits: Int) {
        self.center = center
        self.radiusUnits = radiusUnits
    }

    public var radiusQ8: Q8 { Q8(units: radiusUnits) }

    /// Penetration is exclusive of exact contact (`distance < radius`).
    public func penetrates(_ box: AABB) -> Bool {
        let cx = center.x.raw
        let cy = center.y.raw
        let minX = Int64(box.minX) * Q8.scale
        let maxX = Int64(box.maxX) * Q8.scale
        let minY = Int64(box.minY) * Q8.scale
        let maxY = Int64(box.maxY) * Q8.scale
        let closestX = min(max(cx, minX), maxX)
        let closestY = min(max(cy, minY), maxY)
        let dx = cx - closestX
        let dy = cy - closestY
        let r = Int64(radiusUnits) * Q8.scale
        return dx * dx + dy * dy < r * r
    }
}

public enum Collision {
    public static func clampCenter(_ point: VecQ8, radius: Int, bounds: AABB) -> VecQ8 {
        let r = Int64(radius) * Q8.scale
        let minX = Int64(bounds.minX) * Q8.scale + r
        let maxX = Int64(bounds.maxX) * Q8.scale - r
        let minY = Int64(bounds.minY) * Q8.scale + r
        let maxY = Int64(bounds.maxY) * Q8.scale - r
        return VecQ8(
            x: Q8(raw: min(max(point.x.raw, minX), maxX)),
            y: Q8(raw: min(max(point.y.raw, minY), maxY))
        )
    }

    /// X-then-Y slide against solids ordered by UTF-8 id.
    public static func slideCircle(
        from: VecQ8,
        delta: VecQ8,
        radius: Int,
        bounds: AABB,
        solids: [(id: String, box: AABB)]
    ) -> VecQ8 {
        let ordered = solids.sorted { $0.id.utf8LessThan($1.id) }
        var position = from
        var next = VecQ8(x: from.x + delta.x, y: from.y)
        next = clampCenter(next, radius: radius, bounds: bounds)
        let xProbe = Circle(center: next, radiusUnits: radius)
        if ordered.contains(where: { xProbe.penetrates($0.box) }) {
            next.x = position.x
        }
        position = next
        next = VecQ8(x: position.x, y: position.y + delta.y)
        next = clampCenter(next, radius: radius, bounds: bounds)
        let yProbe = Circle(center: next, radiusUnits: radius)
        if ordered.contains(where: { yProbe.penetrates($0.box) }) {
            next.y = position.y
        }
        return next
    }

    public static func segmentIntersects(_ a: VecQ8, _ b: VecQ8, box: AABB) -> Bool {
        let x0 = a.x.raw
        let y0 = a.y.raw
        let x1 = b.x.raw
        let y1 = b.y.raw
        let minX = Int64(box.minX) * Q8.scale
        let maxX = Int64(box.maxX) * Q8.scale
        let minY = Int64(box.minY) * Q8.scale
        let maxY = Int64(box.maxY) * Q8.scale

        var t0: Int64 = 0
        var t1: Int64 = Q8.scale
        func clip(_ p: Int64, _ q: Int64) -> Bool {
            if p == 0 {
                return q >= 0
            }
            let r = IntMath.mulDivHalfAway(q, Q8.scale, p)
            if p < 0 {
                if r > t1 { return false }
                if r > t0 { t0 = r }
            } else {
                if r < t0 { return false }
                if r < t1 { t1 = r }
            }
            return true
        }

        let dx = x1 - x0
        let dy = y1 - y0
        guard clip(-dx, x0 - minX),
              clip(dx, maxX - x0),
              clip(-dy, y0 - minY),
              clip(dy, maxY - y0)
        else { return false }
        return t0 <= t1
    }

    public static func lineOfFireClear(from: VecQ8, to: VecQ8, solids: [(id: String, box: AABB)]) -> Bool {
        !solids.contains { segmentIntersects(from, to, box: $0.box) }
    }

    /// Swept circle vs circle. Returns intersection time in [0, 256] Q8 of the move, or nil.
    public static func sweepCircleTime(
        from: VecQ8,
        to: VecQ8,
        radius: Int,
        target: VecQ8,
        targetRadius: Int
    ) -> Int64? {
        let mx = to.x.raw - from.x.raw
        let my = to.y.raw - from.y.raw
        let dx = from.x.raw - target.x.raw
        let dy = from.y.raw - target.y.raw
        let r = Int64(radius + targetRadius) * Q8.scale
        let a = mx * mx + my * my
        let b = 2 * (dx * mx + dy * my)
        let c = dx * dx + dy * dy - r * r
        if a == 0 {
            return c <= 0 ? 0 : nil
        }
        guard let disc = IntMath.quadraticDiscriminant(a: a, b: b, c: c) else { return nil }
        let sqrtDisc = IntMath.isqrt(disc)
        let tNum = -b - sqrtDisc
        if tNum < 0 {
            let tAlt = -b + sqrtDisc
            if tAlt < 0 { return c <= 0 ? 0 : nil }
            let t = IntMath.mulDivHalfAway(tAlt, Q8.scale, 2 * a)
            return (t >= 0 && t <= Q8.scale) ? t : (c <= 0 ? 0 : nil)
        }
        let t = IntMath.mulDivHalfAway(tNum, Q8.scale, 2 * a)
        if t < 0 { return c <= 0 ? 0 : nil }
        if t > Q8.scale { return nil }
        return t
    }

    public static func pointInCone(
        origin: VecQ8,
        point: VecQ8,
        headingMilli: Int,
        halfFieldMilli: Int,
        rangeUnits: Int
    ) -> Bool {
        let dx = point.x.raw - origin.x.raw
        let dy = point.y.raw - origin.y.raw
        let range = Int64(rangeUnits) * Q8.scale
        if dx * dx + dy * dy > range * range { return false }
        let angle = Cordic.atan2Milli(y: dy, x: dx)
        return MilliDeg.absDelta(angle, headingMilli) <= halfFieldMilli
    }
}

extension String {
    func utf8LessThan(_ other: String) -> Bool {
        let a = Array(self.utf8)
        let b = Array(other.utf8)
        for i in 0..<min(a.count, b.count) {
            if a[i] != b[i] { return a[i] < b[i] }
        }
        return a.count < b.count
    }
}

extension VecI: Codable {
    enum CodingKeys: String, CodingKey { case x, y }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
}
