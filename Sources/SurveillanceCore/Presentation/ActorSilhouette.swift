/// Presentation-only grayscale blockouts. Collision, targeting, and Camera fields never use these contours.
public enum ActorSilhouette: String, Equatable, Sendable, CaseIterable {
    case playerRing
    case clusteredMass
    case longChassis
    case tallMast
    case forwardLean
    case broadTorso
    case queryApertures
    case officialInsignia

    public static func enemy(_ archetype: ArchetypeID) -> ActorSilhouette {
        switch archetype {
        case .fogAnalyticsCloud: .clusteredMass
        case .cableCarCorrelator: .longChassis
        case .sutroSignalWitch: .tallMast
        case .autonomousInformant: .forwardLean
        case .victorianVendor: .broadTorso
        case .improperSearchDaemon: .queryApertures
        case .algorithmicModerate: .officialInsignia
        }
    }

    public var spriteBox: AssetDimensions {
        switch self {
        case .queryApertures: AssetDimensions(width: 80, height: 80)
        case .officialInsignia: AssetDimensions(width: 96, height: 96)
        default: AssetDimensions(width: 64, height: 64)
        }
    }

    /// Closed polygon in world units relative to entity center. Thumbnail-scale distinctness only.
    public var contour: [VecI] {
        switch self {
        case .playerRing:
            return Self.ring(radius: 18, points: 8)
        case .clusteredMass:
            return [
                VecI(x: -16, y: 8), VecI(x: -6, y: 18), VecI(x: 8, y: 16), VecI(x: 18, y: 4),
                VecI(x: 14, y: -12), VecI(x: 0, y: -18), VecI(x: -14, y: -10), VecI(x: -18, y: 0)
            ]
        case .longChassis:
            return [
                VecI(x: -22, y: -8), VecI(x: 22, y: -8), VecI(x: 26, y: 0),
                VecI(x: 22, y: 8), VecI(x: -22, y: 8), VecI(x: -26, y: 0)
            ]
        case .tallMast:
            return [
                VecI(x: -6, y: -24), VecI(x: 6, y: -24), VecI(x: 8, y: 8),
                VecI(x: 0, y: 28), VecI(x: -8, y: 8)
            ]
        case .forwardLean:
            return [
                VecI(x: -10, y: -16), VecI(x: 18, y: -4), VecI(x: 18, y: 4),
                VecI(x: -10, y: 16), VecI(x: -16, y: 0)
            ]
        case .broadTorso:
            return [
                VecI(x: -20, y: -12), VecI(x: 20, y: -12), VecI(x: 16, y: 16),
                VecI(x: 0, y: 20), VecI(x: -16, y: 16)
            ]
        case .queryApertures:
            return [
                VecI(x: -18, y: -18), VecI(x: 18, y: -18), VecI(x: 24, y: 0),
                VecI(x: 18, y: 18), VecI(x: 0, y: 26), VecI(x: -18, y: 18), VecI(x: -24, y: 0)
            ]
        case .officialInsignia:
            return [
                VecI(x: -12, y: -28), VecI(x: 12, y: -28), VecI(x: 20, y: -8),
                VecI(x: 28, y: 8), VecI(x: 12, y: 28), VecI(x: -12, y: 28),
                VecI(x: -28, y: 8), VecI(x: -20, y: -8)
            ]
        }
    }

    private static func ring(radius: Int, points: Int) -> [VecI] {
        (0..<points).map { index in
            let milli = index * MilliDeg.circle / points
            let sc = Cordic.sinCos(milliDegrees: milli)
            return VecI(
                x: Int((Int64(sc.cos) * Int64(radius)) / Int64(Cordic.q15)),
                y: Int((Int64(sc.sin) * Int64(radius)) / Int64(Cordic.q15))
            )
        }
    }
}
