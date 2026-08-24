public enum IsolatedKernel {
    public static func moveFullRight(ticks: Int, start: VecI = VecI(x: 256, y: 256)) -> VecQ8 {
        var position = start.asQ8
        let command = PlayerCommand(tick: 1, moveX: PlayerCommand.axisMaximum, moveY: 0, dodgePressed: false)
        let delta = Movement.displacement(from: command, dodgeActive: false, ghostStep: false)
        let bounds = AABB(center: VecI(x: 1152, y: 768), halfSize: VecI(x: 1152, y: 768))
        for _ in 0..<ticks {
            position = Collision.slideCircle(from: position, delta: delta, radius: PlayerBody.radiusUnits, bounds: bounds, solids: [])
        }
        return position
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
}
