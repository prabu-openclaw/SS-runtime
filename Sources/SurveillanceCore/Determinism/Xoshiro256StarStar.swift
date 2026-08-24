/// xoshiro256** with rejection sampling for non-power-of-two ranges.
public struct Xoshiro256StarStar: Equatable, Sendable {
    public var s0: UInt64
    public var s1: UInt64
    public var s2: UInt64
    public var s3: UInt64

    public init(s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64) {
        precondition(!(s0 == 0 && s1 == 0 && s2 == 0 && s3 == 0), "xoshiro256** all-zero state is invalid")
        self.s0 = s0
        self.s1 = s1
        self.s2 = s2
        self.s3 = s3
    }

    public init(seed: UInt64) {
        let expanded = SplitMix64.expand(seed)
        self.init(s0: expanded.0, s1: expanded.1, s2: expanded.2, s3: expanded.3)
    }

    public static func combat(runSeed: UInt64) -> Xoshiro256StarStar {
        Xoshiro256StarStar(seed: runSeed)
    }

    /// Placement stream: `CAMERA01` ASCII constant, isolated from combat RNG.
    public static func cameraPlacement(runSeed: UInt64) -> Xoshiro256StarStar {
        let streamConstant: UInt64 = 0x4341_4D45_5241_3031
        let placementSeed = SplitMix64.mix(runSeed ^ streamConstant)
        return Xoshiro256StarStar(seed: placementSeed)
    }

    public static func cosmetic(runSeed: UInt64) -> Xoshiro256StarStar {
        let streamConstant: UInt64 = 0x434F_534D_4554_3031 // COSMET01
        let cosmeticSeed = SplitMix64.mix(runSeed ^ streamConstant)
        return Xoshiro256StarStar(seed: cosmeticSeed)
    }

    @discardableResult
    public mutating func next() -> UInt64 {
        let result = rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 45)
        return result
    }

    /// Uniform in `0 ..< n` via rejection sampling. Never uses modulo reduction of a biased sample.
    public mutating func next(below n: UInt64) -> UInt64 {
        precondition(n > 0)
        if n == 1 { return 0 }
        if n & (n &- 1) == 0 {
            return next() & (n &- 1)
        }
        let threshold = (0 &- n) % n
        while true {
            let value = next()
            if value >= threshold {
                return value % n
            }
        }
    }

    public mutating func nextIndex(_ count: Int) -> Int {
        precondition(count > 0)
        return Int(next(below: UInt64(count)))
    }

    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, through: 1, by: -1) {
            let j = nextIndex(i + 1)
            items.swapAt(i, j)
        }
    }

    private func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }
}
