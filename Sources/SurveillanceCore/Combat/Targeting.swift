public enum ProjectileKind: Equatable, Sendable {
    case civicPulse
    case ricochet
    case sutroBolt
    case bossBolt
}

public struct ProjectileBody: Equatable, Sendable {
    public var id: EntityID
    public var ownerId: EntityID
    public var kind: ProjectileKind
    public var position: VecQ8
    public var previous: VecQ8
    public var velocity: VecQ8
    public var radius: Int
    public var damage: Int
    public var cameraDamage: Int
    public var age: Int
    public var lifetime: Int
    public var distanceTravelledQ8: Int64
    public var maxTravelQ8: Int64
    public var hitEntityIds: [EntityID]
    public var alive: Bool
}

public enum TargetClass: Int, Equatable, Sendable {
    case closeEnemy = 1
    case detectingCamera = 2
    case otherEnemy = 3
    case otherCamera = 4
}

public enum Targeting {
    public static let civicPulseRange = 512
    public static let closeEnemyRange = 96
    public static let cadence = 30
    public static let firstOpportunity: UInt64 = 30
    public static let projectileSpeedPerTick = 12
    public static let projectileRadius = 4
    public static let projectileLifetime = 45
    public static let maxTravel = 540
    public static let activeCeiling = 32
    public static let enemyDamage = 10
    public static let cameraDamage = 1
    public static let ricochetRange = 160

    public static func select(
        player: PlayerBody,
        enemies: [EnemyBody],
        cameras: [SelectedCamera],
        solids: [(id: String, box: AABB)]
    ) -> (EntityID, VecQ8)? {
        struct Candidate {
            var id: EntityID
            var `class`: TargetClass
            var distSq: Int64
            var anchor: VecQ8
        }
        var list: [Candidate] = []
        for enemy in enemies where enemy.alive {
            let distSq = player.position.distanceSquared(to: enemy.position)
            if !inRange(distSq) { continue }
            if !Collision.lineOfFireClear(from: player.position, to: enemy.position, solids: solids) { continue }
            let close = distSq <= Int64(closeEnemyRange) * Int64(closeEnemyRange) * Q8.scale * Q8.scale
            list.append(
                Candidate(
                    id: enemy.id,
                    class: close ? .closeEnemy : .otherEnemy,
                    distSq: distSq,
                    anchor: enemy.position
                )
            )
        }
        for camera in cameras where camera.isDamageable {
            let distSq = player.position.distanceSquared(to: camera.targetAnchor)
            if !inRange(distSq) { continue }
            if !Collision.lineOfFireClear(from: player.position, to: camera.targetAnchor, solids: solids) { continue }
            list.append(
                Candidate(
                    id: camera.entityId,
                    class: camera.wasDetecting ? .detectingCamera : .otherCamera,
                    distSq: distSq,
                    anchor: camera.targetAnchor
                )
            )
        }
        list.sort {
            if $0.class != $1.class { return $0.class.rawValue < $1.class.rawValue }
            if $0.distSq != $1.distSq { return $0.distSq < $1.distSq }
            return $0.id < $1.id
        }
        guard let best = list.first else { return nil }
        return (best.id, best.anchor)
    }

    public static func inRange(_ distSqQ8: Int64) -> Bool {
        let r = Int64(civicPulseRange) * Q8.scale
        return distSqQ8 <= r * r
    }

    public static func aimVelocity(from: VecQ8, to: VecQ8, targetVelocity: VecQ8) -> VecQ8 {
        let speed = Int64(projectileSpeedPerTick) * Q8.scale
        if let intercept = intercept(from: from, to: to, targetVelocity: targetVelocity, speed: speed) {
            return intercept
        }
        return direct(from: from, to: to, speed: speed)
    }

    public static func direct(from: VecQ8, to: VecQ8, speed: Int64) -> VecQ8 {
        let dx = to.x.raw - from.x.raw
        let dy = to.y.raw - from.y.raw
        let mag = IntMath.isqrt(dx * dx + dy * dy)
        if mag == 0 { return VecQ8(x: Q8(raw: speed), y: .zero) }
        return VecQ8(
            x: Q8(raw: IntMath.mulDivHalfAway(dx, speed, mag)),
            y: Q8(raw: IntMath.mulDivHalfAway(dy, speed, mag))
        )
    }

    private static func intercept(from: VecQ8, to: VecQ8, targetVelocity: VecQ8, speed: Int64) -> VecQ8? {
        let rx = to.x.raw - from.x.raw
        let ry = to.y.raw - from.y.raw
        let vx = targetVelocity.x.raw
        let vy = targetVelocity.y.raw
        let a = vx * vx + vy * vy - speed * speed
        let b = 2 * (rx * vx + ry * vy)
        let c = rx * rx + ry * ry
        if a == 0 {
            if b == 0 { return nil }
            let t = IntMath.divHalfAway(-c, b)
            if t <= 0 { return nil }
            let aim = VecQ8(x: Q8(raw: rx + vx * t / Q8.scale), y: Q8(raw: ry + vy * t / Q8.scale))
            return direct(from: .zero, to: aim, speed: speed)
        }
        guard let disc = IntMath.quadraticDiscriminant(a: a, b: b, c: c) else { return nil }
        let s = IntMath.isqrt(disc)
        let t1 = IntMath.divHalfAway(-b - s, 2 * a)
        let t2 = IntMath.divHalfAway(-b + s, 2 * a)
        let t = [t1, t2].filter { $0 > 0 }.min()
        guard let t else { return nil }
        let aim = VecQ8(x: Q8(raw: rx + vx * t / Q8.scale), y: Q8(raw: ry + vy * t / Q8.scale))
        return direct(from: .zero, to: aim, speed: speed)
    }
}
