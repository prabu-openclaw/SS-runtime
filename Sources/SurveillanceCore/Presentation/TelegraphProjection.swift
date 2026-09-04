/// Presentation projection of authoritative telegraph geometry.
///
/// bosses.md §Attack vocabulary and §Elite give every telegraph an exact shape,
/// duration, and origin. The renderer must not re-derive them from sprites, so
/// the shapes are projected here from authoritative state only.
///
/// A telegraph is a *preview* of the resolve that will run when
/// `remainingTicks` reaches zero. Safety Rationale locks its heading on the
/// final telegraph tick, so the projected cone tracks the Player until then and
/// reports `locked` on that tick.
public enum TelegraphKind: String, Equatable, Sendable {
    /// Bounded arc: Safety Rationale.
    case cone
    /// Straight corridor: Narrow Tailoring, Independent Review, Redaction Dash.
    case lane
    /// Fixed Captain Camera field about to activate: Temporary Order.
    case emitterField
}

public struct TelegraphShape: Equatable, Sendable {
    public var kind: TelegraphKind
    public var ownerId: EntityID
    /// Telegraph origin in world units.
    public var x: Int
    public var y: Int
    public var headingMilli: Int
    /// Half-angle for `cone` and `emitterField`; zero for `lane`.
    public var halfAngleMilli: Int
    public var rangeUnits: Int
    /// Full corridor width for `lane`; zero otherwise.
    public var widthUnits: Int
    public var remainingTicks: Int
    public var totalTicks: Int
    /// True on the tick the heading stops tracking the Player.
    public var locked: Bool
    /// Stable identity for renderer node reuse.
    public var key: String

    public init(
        kind: TelegraphKind,
        ownerId: EntityID,
        x: Int,
        y: Int,
        headingMilli: Int,
        halfAngleMilli: Int,
        rangeUnits: Int,
        widthUnits: Int,
        remainingTicks: Int,
        totalTicks: Int,
        locked: Bool,
        key: String
    ) {
        self.kind = kind
        self.ownerId = ownerId
        self.x = x
        self.y = y
        self.headingMilli = headingMilli
        self.halfAngleMilli = halfAngleMilli
        self.rangeUnits = rangeUnits
        self.widthUnits = widthUnits
        self.remainingTicks = remainingTicks
        self.totalTicks = totalTicks
        self.locked = locked
        self.key = key
    }

    /// 0…1000 progress toward resolve, for wind-up presentation only.
    public var progressPermille: Int {
        guard totalTicks > 0 else { return 1000 }
        let elapsed = max(0, totalTicks - remainingTicks)
        return Int(IntMath.mulDivHalfAway(Int64(elapsed), 1000, Int64(totalTicks)))
    }
}

public enum TelegraphProjection {
    // bosses.md §Safety Rationale.
    public static let safetyRationaleTicks = 45
    public static let safetyRationaleHalfAngleMilli = 35_000
    public static let safetyRationaleRange = 260

    // bosses.md §Narrow Tailoring.
    public static let narrowTailoringTicks = 30
    public static let narrowTailoringOffsetsMilli = [-12_000, 0, 12_000]
    public static let narrowTailoringSpeed = 420
    public static let narrowTailoringLifetime = 72
    public static let narrowTailoringRadius = 7

    // bosses.md §Temporary Order.
    public static let temporaryOrderTicks = 48

    // bosses.md §Independent Review.
    public static let independentReviewTicks = 60
    public static let independentReviewSpeed = 360
    public static let independentReviewLifetime = 90
    public static let independentReviewRadius = 7

    // bosses.md §Elite Redaction Dash.
    public static let dashTelegraphTicks = 36
    public static let dashLaneWidth = 72
    public static let dashSpeed = 288
    public static let dashTicks = 30

    /// Reach of a projectile fired at `speed` world units/second for
    /// `lifetime` ticks at the authoritative 60 Hz rate.
    static func projectileReach(speed: Int, lifetimeTicks: Int) -> Int {
        Int(IntMath.mulDivHalfAway(Int64(speed), Int64(lifetimeTicks), 60))
    }

    static func headingToPlayer(from origin: VecQ8, player: VecQ8) -> Int {
        Cordic.atan2Milli(
            y: player.y.raw - origin.y.raw,
            x: player.x.raw - origin.x.raw
        )
    }

    /// Every telegraph currently winding up, ordered by owner entity ID then
    /// lane index so the renderer sees a stable sequence.
    public static func project(_ state: WorldState) -> [TelegraphShape] {
        var shapes: [TelegraphShape] = []
        shapes.append(contentsOf: bossTelegraphs(state))
        shapes.append(contentsOf: eliteTelegraphs(state))
        return shapes
    }

    static func bossTelegraphs(_ state: WorldState) -> [TelegraphShape] {
        guard let runtime = state.bossRuntime,
              let attack = runtime.currentAttack,
              runtime.telegraphRemaining > 0,
              let boss = state.enemies.first(where: { $0.archetype == .algorithmicModerate && $0.alive })
        else { return [] }

        let origin = boss.position
        let originUnits = VecI(x: origin.x.unitsTruncated, y: origin.y.unitsTruncated)
        let heading = headingToPlayer(from: origin, player: state.player.position)
        // The resolve samples the heading on the tick the telegraph expires.
        let locked = runtime.telegraphRemaining == 1

        switch attack {
        case .safetyRationale:
            return [
                TelegraphShape(
                    kind: .cone,
                    ownerId: boss.id,
                    x: originUnits.x,
                    y: originUnits.y,
                    headingMilli: heading,
                    halfAngleMilli: safetyRationaleHalfAngleMilli,
                    rangeUnits: safetyRationaleRange,
                    widthUnits: 0,
                    remainingTicks: runtime.telegraphRemaining,
                    totalTicks: safetyRationaleTicks,
                    locked: locked,
                    key: "boss-safetyRationale"
                )
            ]

        case .narrowTailoring:
            let reach = projectileReach(speed: narrowTailoringSpeed, lifetimeTicks: narrowTailoringLifetime)
            return narrowTailoringOffsetsMilli.enumerated().map { index, offset in
                TelegraphShape(
                    kind: .lane,
                    ownerId: boss.id,
                    x: originUnits.x,
                    y: originUnits.y,
                    headingMilli: MilliDeg.normalize(heading + offset),
                    halfAngleMilli: 0,
                    rangeUnits: reach,
                    widthUnits: narrowTailoringRadius * 2,
                    remainingTicks: runtime.telegraphRemaining,
                    totalTicks: narrowTailoringTicks,
                    locked: locked,
                    key: "boss-narrowTailoring-\(index)"
                )
            }

        case .temporaryOrder:
            // resolve() takes emitters[emitterIndex % count] and does not
            // advance the index until it fires, so the pending emitter is known.
            let emitters = state.arena.captainCameraEmitters
            guard !emitters.isEmpty else { return [] }
            let emitter = emitters[runtime.emitterIndex % emitters.count]
            return [
                TelegraphShape(
                    kind: .emitterField,
                    ownerId: boss.id,
                    x: emitter.x,
                    y: emitter.y,
                    headingMilli: emitter.headingMilliDegrees,
                    halfAngleMilli: emitter.fieldAngleMilliDegrees / 2,
                    rangeUnits: emitter.rangeUnits,
                    widthUnits: 0,
                    remainingTicks: runtime.telegraphRemaining,
                    totalTicks: temporaryOrderTicks,
                    locked: true,
                    key: "boss-temporaryOrder-\(emitter.id)"
                )
            ]

        case .independentReview:
            let reach = projectileReach(speed: independentReviewSpeed, lifetimeTicks: independentReviewLifetime)
            // The omitted lane is the deterministic safe gap; showing the five
            // that will actually fire is what makes the gap readable.
            return BossSystem.independentReviewLanes(toPlayerMilli: heading)
                .enumerated()
                .map { index, lane in
                    TelegraphShape(
                        kind: .lane,
                        ownerId: boss.id,
                        x: originUnits.x,
                        y: originUnits.y,
                        headingMilli: lane,
                        halfAngleMilli: 0,
                        rangeUnits: reach,
                        widthUnits: independentReviewRadius * 2,
                        remainingTicks: runtime.telegraphRemaining,
                        totalTicks: independentReviewTicks,
                        locked: locked,
                        key: "boss-independentReview-\(index)"
                    )
                }
        }
    }

    static func eliteTelegraphs(_ state: WorldState) -> [TelegraphShape] {
        state.enemies
            .filter { $0.alive && $0.state == .dashTelegraph }
            .sorted { $0.id.raw < $1.id.raw }
            .map { enemy in
                TelegraphShape(
                    kind: .lane,
                    ownerId: enemy.id,
                    x: enemy.position.x.unitsTruncated,
                    y: enemy.position.y.unitsTruncated,
                    headingMilli: headingToPlayer(from: enemy.position, player: state.player.position),
                    halfAngleMilli: 0,
                    rangeUnits: projectileReach(speed: dashSpeed, lifetimeTicks: dashTicks),
                    widthUnits: dashLaneWidth,
                    remainingTicks: enemy.stateTicks,
                    totalTicks: dashTelegraphTicks,
                    locked: enemy.stateTicks <= 1,
                    key: "elite-dash-\(enemy.id.raw)"
                )
            }
    }
}
