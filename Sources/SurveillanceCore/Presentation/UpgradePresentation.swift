/// hud-tutorial-001 / upgrades-001 protected selection presentation. Presentation-only.
public enum UpgradePresentation {
    public struct Card: Equatable, Sendable {
        public var upgrade: UpgradeID
        public var selectionIndex: UInt8
        public var name: String
        public var role: String
        public var numericSummary: String
        public var voiceOverLabel: String
    }

    public static let selectionOrder: [UpgradeID] = [.signalJammer, .ricochetPulse, .ghostStep]

    public static func selectionCards() -> [Card] {
        selectionOrder.map(card(for:))
    }

    public static func voiceOverLabels() -> [String] {
        selectionCards().map(\.voiceOverLabel)
    }

    public static func card(for upgrade: UpgradeID) -> Card {
        switch upgrade {
        case .signalJammer:
            Card(
                upgrade: .signalJammer,
                selectionIndex: 0,
                name: "Signal Jammer",
                role: "Surveillance control",
                numericSummary: "Contact delta −1 (min 1); pulses −25%",
                voiceOverLabel:
                    "Signal Jammer. Surveillance control. Reduces camera contact gain by one point per tick, minimum one. Reduces fog and boss observation pulses by twenty-five percent."
            )
        case .ricochetPulse:
            Card(
                upgrade: .ricochetPulse,
                selectionIndex: 1,
                name: "Ricochet Pulse",
                role: "Crowd control",
                numericSummary: "One continuation per hit; 160 unit range",
                voiceOverLabel:
                    "Ricochet Pulse. Crowd control. Each civic pulse hit may continue once to a second enemy or camera within one hundred sixty units, excluding the first target."
            )
        case .ghostStep:
            Card(
                upgrade: .ghostStep,
                selectionIndex: 2,
                name: "Ghost Step",
                role: "Mobility and surveillance evasion",
                numericSummary: "Dodge 540 u/s; 90 tick cooldown; 29 tick camera immunity",
                voiceOverLabel:
                    "Ghost Step. Mobility and surveillance evasion. Dodge speed five hundred forty units per second, ninety tick cooldown, camera immunity for twenty-nine ticks after dodge start. No damage immunity."
            )
        }
    }
}
