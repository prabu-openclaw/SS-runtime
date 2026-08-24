public struct PlayerCommand: Equatable, Sendable {
    public static let axisMinimum: Int16 = -32_767
    public static let axisMaximum: Int16 = 32_767

    public let tick: UInt64
    public let moveX: Int16
    public let moveY: Int16
    public let dodgePressed: Bool
    public let upgradeChoiceIndex: UInt8?

    public init(
        tick: UInt64,
        moveX: Int16,
        moveY: Int16,
        dodgePressed: Bool,
        upgradeChoiceIndex: UInt8? = nil
    ) {
        self.tick = tick
        self.moveX = moveX
        self.moveY = moveY
        self.dodgePressed = dodgePressed
        self.upgradeChoiceIndex = upgradeChoiceIndex
    }

    public static func neutral(tick: UInt64) -> PlayerCommand {
        PlayerCommand(tick: tick, moveX: 0, moveY: 0, dodgePressed: false)
    }
}
