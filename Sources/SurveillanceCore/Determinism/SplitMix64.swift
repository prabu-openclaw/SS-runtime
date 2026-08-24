/// SplitMix64 as specified by D-044 / simulation-order-001.
public struct SplitMix64: Equatable, Sendable {
    public var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    @discardableResult
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// One mixing step used to derive stream seeds.
    public static func mix(_ seed: UInt64) -> UInt64 {
        var rng = SplitMix64(seed: seed)
        return rng.next()
    }

    /// Expand a 64-bit seed into four xoshiro256** state words.
    public static func expand(_ seed: UInt64) -> (UInt64, UInt64, UInt64, UInt64) {
        var rng = SplitMix64(seed: seed)
        return (rng.next(), rng.next(), rng.next(), rng.next())
    }
}
