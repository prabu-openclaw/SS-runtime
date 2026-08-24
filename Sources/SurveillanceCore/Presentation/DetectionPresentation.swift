/// hud-tutorial-001 exposure presentation carriers. Non-color distinction for UI-008.
public enum DetectionPresentation {
    public struct Carrier: Equatable, Sendable {
        public var iconShape: String
        public var barPattern: String
    }

    public static let orderedStates: [DetectionState] = [
        .hidden, .observed, .tracked, .hunted, .lockdown
    ]

    public static func carrier(for state: DetectionState) -> Carrier {
        switch state {
        case .hidden:
            Carrier(iconShape: "openEye", barPattern: "slackDotted")
        case .observed:
            Carrier(iconShape: "halfEye", barPattern: "diagonalFill")
        case .tracked:
            Carrier(iconShape: "bracketEye", barPattern: "crossFill")
        case .hunted:
            Carrier(iconShape: "boxedEye", barPattern: "denseChevron")
        case .lockdown:
            Carrier(iconShape: "sealedEye", barPattern: "solidSegmented")
        }
    }

    public static func criticalStatesRemainDistinct() -> Bool {
        var seen: Set<String> = []
        for state in orderedStates {
            let carrier = carrier(for: state)
            let key = "\(carrier.iconShape)|\(carrier.barPattern)"
            if seen.contains(key) { return false }
            seen.insert(key)
        }
        return seen.count == orderedStates.count
    }

    public static func reducedPresentationCarriers() -> [DetectionState: Carrier] {
        Dictionary(uniqueKeysWithValues: orderedStates.map { ($0, carrier(for: $0)) })
    }
}
