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

    public static func slideIntoVerticalWall() -> VecQ8 {
        let wall = AABB(center: VecI(x: 400, y: 256), halfSize: VecI(x: 8, y: 400))
        var player = PlayerBody(id: EntityID(1), spawn: VecI(x: 256, y: 256))
        var events = EventBuffer()
        for tick in 1...UInt64(60) {
            Movement.apply(
                player: &player,
                command: PlayerCommand(
                    tick: tick,
                    moveX: PlayerCommand.axisMaximum,
                    moveY: PlayerCommand.axisMaximum,
                    dodgePressed: false
                ),
                tick: tick,
                ghostStep: false,
                bounds: openBounds,
                solids: [("wall-v", wall)],
                events: &events
            )
        }
        return player.position
    }

    public static func daemonCycle(ticks: Int, playerMoves: Bool = false) -> (
        states: [EnemyAIState],
        damage: Int,
        markers: [VecQ8]
    ) {
        var enemy = EnemyBody(
            id: EntityID(2),
            archetype: .improperSearchDaemon,
            position: VecI(x: 400, y: 256).asQ8,
            velocity: .zero,
            integrity: 300,
            radius: 26,
            speedUnitsPerSecond: 108,
            contactDps: 14,
            state: .pursue,
            stateTicks: 120,
            spawnTick: 0,
            nextSpecialTick: 0,
            lockPosition: nil,
            encounterId: "elite"
        )
        var player = PlayerBody(id: EntityID(1), spawn: VecI(x: 256, y: 256))
        var allocator = EntityAllocator()
        _ = allocator.next()
        _ = allocator.next()
        var projectiles: [ProjectileBody] = []
        var mines: [MineBody] = []
        var pulses: [Int] = []
        var states: [EnemyAIState] = []
        var totalDamage = 0
        let content = CombatContent.bundled()
        for tick in 1...UInt64(ticks) {
            if playerMoves {
                player.position = player.position.offset(units: 1, along: VecQ8(unitsX: 1, unitsY: 0))
            }
            var enemies = [enemy]
            var damage: [(EntityID, Int)] = []
            EnemySystem.step(
                enemies: &enemies,
                player: player,
                tick: tick,
                content: content,
                bounds: openBounds,
                solids: [],
                allocator: &allocator,
                projectiles: &projectiles,
                mines: &mines,
                exposurePulses: &pulses,
                playerDamage: &damage
            )
            enemy = enemies[0]
            states.append(enemy.state)
            totalDamage += damage.reduce(0) { $0 + $1.1 }
        }
        return (states, totalDamage, enemy.queryMarkers)
    }

    public static func ghostStepImmunityTick() -> UInt64 {
        var player = PlayerBody(id: EntityID(1), spawn: VecI(x: 256, y: 256))
        var events = EventBuffer()
        Movement.apply(
            player: &player,
            command: PlayerCommand(tick: 100, moveX: PlayerCommand.axisMaximum, moveY: 0, dodgePressed: true),
            tick: 100,
            ghostStep: true,
            bounds: openBounds,
            solids: [],
            events: &events
        )
        return player.cameraInvisibleUntilTick
    }
}
