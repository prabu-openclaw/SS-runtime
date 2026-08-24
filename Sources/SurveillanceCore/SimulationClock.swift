public struct SimulationClock: Equatable, Sendable {
    public static let ticksPerSecond: UInt64 = 60

    public private(set) var tick: UInt64

    public init(tick: UInt64 = 0) {
        self.tick = tick
    }

    @discardableResult
    public mutating func advance() -> UInt64 {
        precondition(tick < .max, "Simulation tick overflow")
        tick += 1
        return tick
    }
}
