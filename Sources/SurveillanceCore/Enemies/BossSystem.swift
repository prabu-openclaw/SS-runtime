public enum BossPhase: String, Equatable, Sendable {
    case publicSafety
    case civilLiberties
    case temporarySafeguard
    case independentReview

    public static func from(hp: Int) -> BossPhase {
        switch hp {
        case 600...800: .publicSafety
        case 400..<600: .civilLiberties
        case 200..<400: .temporarySafeguard
        default: .independentReview
        }
    }

    public var sequence: [BossAttackID] {
        switch self {
        case .publicSafety: [.safetyRationale, .narrowTailoring]
        case .civilLiberties: [.narrowTailoring, .safetyRationale, .temporaryOrder]
        case .temporarySafeguard: [.temporaryOrder, .narrowTailoring, .safetyRationale]
        case .independentReview: [.independentReview, .narrowTailoring, .temporaryOrder]
        }
    }
}

public enum BossAttackID: String, Equatable, Sendable {
    case safetyRationale
    case narrowTailoring
    case temporaryOrder
    case independentReview
}

public struct BossRuntime: Equatable, Sendable {
    public var phase: BossPhase
    public var sequenceIndex: Int
    public var recoveryRemaining: Int
    public var telegraphRemaining: Int
    public var attackRemaining: Int
    public var cooldownRemaining: Int
    public var currentAttack: BossAttackID?
    public var emitterIndex: Int
    public var lockedHeadingMilli: Int?

    public var observationNumerator: Int {
        switch phase {
        case .publicSafety: 105
        case .civilLiberties: 108
        case .temporarySafeguard: 112
        case .independentReview: 116
        }
    }

    public init(phase: BossPhase = .publicSafety) {
        self.phase = phase
        sequenceIndex = 0
        recoveryRemaining = 90
        telegraphRemaining = 0
        attackRemaining = 0
        cooldownRemaining = 0
        currentAttack = nil
        emitterIndex = 0
        lockedHeadingMilli = nil
    }

    public mutating func syncPhase(hp: Int) -> BossPhase? {
        let next = BossPhase.from(hp: hp)
        if next != phase {
            phase = next
            sequenceIndex = 0
            recoveryRemaining = 45
            telegraphRemaining = 0
            attackRemaining = 0
            cooldownRemaining = 0
            currentAttack = nil
            lockedHeadingMilli = nil
            return next
        }
        return nil
    }
}

public enum BossSystem {
    public static func step(
        boss: inout EnemyBody,
        runtime: inout BossRuntime,
        player: PlayerBody,
        tick: UInt64,
        emitters: [CaptainEmitter],
        solids: [(id: String, box: AABB)],
        allocator: inout EntityAllocator,
        projectiles: inout [ProjectileBody],
        exposurePulse: inout Int?,
        playerDamage: inout Int,
        events: inout EventBuffer
    ) {
        if let changed = runtime.syncPhase(hp: boss.integrity), boss.alive {
            events.emit(
                tick: tick,
                phase: 16,
                type: .bossPhaseChanged,
                primary: boss.id,
                payload: [
                    "before": .null,
                    "after": .string(changed.rawValue),
                    "remainingIntegrity": .integer(Int64(boss.integrity))
                ]
            )
        }
        if runtime.recoveryRemaining > 0 {
            runtime.recoveryRemaining -= 1
            return
        }
        if runtime.attackRemaining > 0 {
            runtime.attackRemaining -= 1
            if runtime.currentAttack == .temporaryOrder, runtime.attackRemaining % 30 == 0 {
                exposurePulse = 10
            }
            if runtime.attackRemaining == 0 {
                runtime.currentAttack = nil
            }
        }
        if runtime.telegraphRemaining > 0 {
            runtime.telegraphRemaining -= 1
            if runtime.telegraphRemaining == 0, let attack = runtime.currentAttack {
                resolve(
                    attack,
                    boss: boss,
                    runtime: &runtime,
                    player: player,
                    emitters: emitters,
                    solids: solids,
                    allocator: &allocator,
                    projectiles: &projectiles,
                    exposurePulse: &exposurePulse,
                    playerDamage: &playerDamage
                )
                events.emit(
                    tick: tick,
                    phase: 16,
                    type: .bossAttackStarted,
                    primary: boss.id,
                    payload: [
                        "attackId": .string(attack.rawValue),
                        "phaseId": .string(runtime.phase.rawValue)
                    ]
                )
            }
            return
        }
        if runtime.cooldownRemaining > 0 {
            runtime.cooldownRemaining -= 1
            return
        }
        let sequence = runtime.phase.sequence
        let attack = sequence[runtime.sequenceIndex % sequence.count]
        runtime.currentAttack = attack
        runtime.sequenceIndex += 1
        switch attack {
        case .safetyRationale:
            runtime.telegraphRemaining = 45
        case .narrowTailoring:
            runtime.telegraphRemaining = 30
        case .temporaryOrder:
            runtime.telegraphRemaining = 48
            runtime.attackRemaining = 180
        case .independentReview:
            runtime.telegraphRemaining = 60
        }
    }

    private static func resolve(
        _ attack: BossAttackID,
        boss: EnemyBody,
        runtime: inout BossRuntime,
        player: PlayerBody,
        emitters: [CaptainEmitter],
        solids: [(id: String, box: AABB)],
        allocator: inout EntityAllocator,
        projectiles: inout [ProjectileBody],
        exposurePulse: inout Int?,
        playerDamage: inout Int
    ) {
        switch attack {
        case .safetyRationale:
            let heading = Cordic.atan2Milli(
                y: player.position.y.raw - boss.position.y.raw,
                x: player.position.x.raw - boss.position.x.raw
            )
            runtime.lockedHeadingMilli = heading
            runtime.cooldownRemaining = 90
            if Collision.pointInCone(
                origin: boss.position,
                point: player.position,
                headingMilli: heading,
                halfFieldMilli: 35_000,
                rangeUnits: 260
            ) && Collision.lineOfFireClear(from: boss.position, to: player.position, solids: solids) {
                playerDamage = 18
            }
        case .narrowTailoring:
            let heading = Cordic.atan2Milli(
                y: player.position.y.raw - boss.position.y.raw,
                x: player.position.x.raw - boss.position.x.raw
            )
            for offset in [-12_000, 0, 12_000] {
                fire(
                    from: boss.position,
                    headingMilli: MilliDeg.normalize(heading + offset),
                    speed: 420,
                    radius: 7,
                    lifetime: 72,
                    damage: 9,
                    owner: boss.id,
                    allocator: &allocator,
                    projectiles: &projectiles
                )
            }
            runtime.cooldownRemaining = 75
        case .temporaryOrder:
            if !emitters.isEmpty {
                runtime.emitterIndex = runtime.emitterIndex % emitters.count
                runtime.emitterIndex += 1
            }
            runtime.cooldownRemaining = 120
        case .independentReview:
            let toPlayer = Cordic.atan2Milli(
                y: player.position.y.raw - boss.position.y.raw,
                x: player.position.x.raw - boss.position.x.raw
            )
            var lanes = (0..<6).map { MilliDeg.normalize($0 * 60_000) }
            let nearest = lanes.enumerated().min { lhs, rhs in
                let ld = MilliDeg.absDelta(lhs.element, toPlayer)
                let rd = MilliDeg.absDelta(rhs.element, toPlayer)
                if ld != rd { return ld < rd }
                return lhs.offset < rhs.offset
            }!.offset
            lanes.remove(at: nearest)
            for lane in lanes {
                fire(
                    from: boss.position,
                    headingMilli: lane,
                    speed: 360,
                    radius: 7,
                    lifetime: 90,
                    damage: 8,
                    owner: boss.id,
                    allocator: &allocator,
                    projectiles: &projectiles
                )
            }
            runtime.cooldownRemaining = 105
        }
    }

    private static func fire(
        from: VecQ8,
        headingMilli: Int,
        speed: Int,
        radius: Int,
        lifetime: Int,
        damage: Int,
        owner: EntityID,
        allocator: inout EntityAllocator,
        projectiles: inout [ProjectileBody]
    ) {
        let unit = Cordic.headingUnit(milliDegrees: headingMilli)
        let speedQ8 = Steering.speedQ8(speed)
        let velocity = VecQ8(
            x: Q8(raw: IntMath.mulDivHalfAway(Int64(unit.x), speedQ8, Int64(Cordic.q15))),
            y: Q8(raw: IntMath.mulDivHalfAway(Int64(unit.y), speedQ8, Int64(Cordic.q15)))
        )
        projectiles.append(
            ProjectileBody(
                id: allocator.next(),
                ownerId: owner,
                kind: .bossBolt,
                position: from + velocity,
                previous: from,
                velocity: velocity,
                radius: radius,
                damage: damage,
                cameraDamage: 0,
                age: 1,
                lifetime: lifetime,
                distanceTravelledQ8: IntMath.isqrt(velocity.lengthSquaredRaw),
                maxTravelQ8: Int64(10_000) * Q8.scale,
                hitEntityIds: [],
                alive: true
            )
        )
    }
}
