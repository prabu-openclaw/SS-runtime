public enum IsolatedKernel {
    public static let openBounds = AABB(center: VecI(x: 1152, y: 768), halfSize: VecI(x: 1152, y: 768))

    public static func move(
        ticks: Int,
        moveX: Int16,
        moveY: Int16,
        start: VecI = VecI(x: 256, y: 256),
        dodge: Bool = false
    ) -> VecQ8 {
        var player = PlayerBody(id: EntityID(1), spawn: start)
        var events = EventBuffer()
        for tick in 1...UInt64(ticks) {
            let command = PlayerCommand(
                tick: tick,
                moveX: moveX,
                moveY: moveY,
                dodgePressed: dodge && tick == 1
            )
            Movement.apply(
                player: &player,
                command: command,
                tick: tick,
                ghostStep: false,
                bounds: openBounds,
                solids: [],
                events: &events
            )
        }
        return player.position
    }

    public static func moveFullRight(ticks: Int, start: VecI = VecI(x: 256, y: 256)) -> VecQ8 {
        move(ticks: ticks, moveX: PlayerCommand.axisMaximum, moveY: 0, start: start)
    }

    public static func dodgeOnce(ticks: Int = 12, moveX: Int16 = PlayerCommand.axisMaximum) -> (PlayerBody, EventBuffer) {
        var player = PlayerBody(id: EntityID(1), spawn: VecI(x: 256, y: 256))
        var events = EventBuffer()
        for tick in 1...UInt64(ticks) {
            Movement.apply(
                player: &player,
                command: PlayerCommand(tick: tick, moveX: moveX, moveY: 0, dodgePressed: tick == 1),
                tick: tick,
                ghostStep: false,
                bounds: openBounds,
                solids: [],
                events: &events
            )
        }
        return (player, events)
    }

    public static func rejectedDodgeDuringCooldown() -> Int {
        var player = PlayerBody(id: EntityID(1), spawn: VecI(x: 256, y: 256))
        var events = EventBuffer()
        Movement.apply(
            player: &player,
            command: PlayerCommand(tick: 1, moveX: PlayerCommand.axisMaximum, moveY: 0, dodgePressed: true),
            tick: 1,
            ghostStep: false,
            bounds: openBounds,
            solids: [],
            events: &events
        )
        Movement.apply(
            player: &player,
            command: PlayerCommand(tick: 2, moveX: 0, moveY: 0, dodgePressed: false),
            tick: 2,
            ghostStep: false,
            bounds: openBounds,
            solids: [],
            events: &events
        )
        Movement.apply(
            player: &player,
            command: PlayerCommand(tick: 3, moveX: 0, moveY: 0, dodgePressed: true),
            tick: 3,
            ghostStep: false,
            bounds: openBounds,
            solids: [],
            events: &events
        )
        return player.rejectedDodges
    }

    public static func cameraIntegrity(impacts: Int) -> (integrity: Int, tamper: Int, destructions: Int) {
        var integrity = 3
        var tamper = 0
        var destructions = 0
        for _ in 0..<impacts {
            guard integrity > 0 else { break }
            integrity -= 1
            if integrity == 0 {
                tamper += 100
                destructions += 1
            }
        }
        return (integrity, tamper, destructions)
    }

    public static func lowestTarget(candidates: [(id: UInt64, distSq: Int64)]) -> UInt64 {
        candidates.min { lhs, rhs in
            if lhs.distSq != rhs.distSq { return lhs.distSq < rhs.distSq }
            return lhs.id < rhs.id
        }!.id
    }

    public static func extractCycle(insideTicks: Int, leave: Bool, reenter: Bool) -> (afterLeave: Int, afterReenter: Int) {
        var remaining = 300
        var inside = true
        for _ in 0..<insideTicks {
            if inside { remaining -= 1 }
        }
        var afterLeave = remaining
        if leave {
            inside = false
            remaining = 300
            afterLeave = remaining
        }
        var afterReenter = remaining
        if reenter {
            inside = true
            remaining -= 1
            afterReenter = remaining
            _ = inside
        }
        return (afterLeave, afterReenter)
    }

    public static func distanceUnits(_ a: VecQ8, _ b: VecQ8) -> Int {
        Int(IntMath.isqrt(a.distanceSquared(to: b)) / Q8.scale)
    }
}
