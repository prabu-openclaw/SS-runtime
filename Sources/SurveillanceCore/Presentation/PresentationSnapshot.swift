/// Immutable presentation projection of authoritative state. Does not own rules.
public struct PresentationSnapshot: Equatable, Sendable {
    public struct CircleSprite: Equatable, Sendable {
        public var id: EntityID
        public var x: Int
        public var y: Int
        public var radius: Int
        public var role: String
    }

    public struct CameraSprite: Equatable, Sendable {
        public var id: EntityID
        public var x: Int
        public var y: Int
        public var headingMilli: Int
        public var range: Int
        public var fieldAngleMilli: Int
        public var integrity: Int
        public var detecting: Bool
    }

    public var tick: UInt64
    public var outcome: RunOutcome
    public var player: CircleSprite
    public var playerIntegrity: Int
    public var exposure: Int
    public var detection: DetectionState
    public var solids: [AABB]
    public var cameras: [CameraSprite]
    public var enemies: [CircleSprite]
    public var extraction: AABB
    public var extractionArmed: Bool
    public var extractionRemaining: Int
    public var camerasDestroyed: Int
    public var upgrade: UpgradeID?
    public var upgradePending: Bool
    public var tutorialCopy: String?

    public init(_ state: WorldState) {
        tick = state.tick
        outcome = state.outcome
        player = CircleSprite(
            id: state.player.id,
            x: state.player.position.x.unitsTruncated,
            y: state.player.position.y.unitsTruncated,
            radius: PlayerBody.radiusUnits,
            role: "player"
        )
        playerIntegrity = state.player.integrity
        exposure = state.exposure.exposure
        detection = state.exposure.detectionState
        solids = state.liveSolids.map(\.box)
        cameras = state.cameras.map {
            CameraSprite(
                id: $0.entityId,
                x: $0.position.x,
                y: $0.position.y,
                headingMilli: $0.headingMilliDegrees,
                range: $0.rangeUnits,
                fieldAngleMilli: $0.fieldAngleMilliDegrees,
                integrity: $0.integrity,
                detecting: $0.wasDetecting
            )
        }
        enemies = state.enemies.filter(\.alive).map {
            CircleSprite(
                id: $0.id,
                x: $0.position.x.unitsTruncated,
                y: $0.position.y.unitsTruncated,
                radius: $0.radius,
                role: $0.archetype.rawValue
            )
        }
        extraction = state.arena.extraction.aabb
        extractionArmed = state.extraction.armed
        extractionRemaining = state.extraction.remaining
        camerasDestroyed = state.destructions.count
        upgrade = state.upgrade.selected
        upgradePending = state.upgrade.pending
        tutorialCopy = nil
    }
}

public enum HUDLayout {
    public static let referenceWidth = 844
    public static let referenceHeight = 390
}
