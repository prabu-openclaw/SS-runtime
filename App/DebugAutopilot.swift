#if DEBUG
import SurveillanceCore

/// DEBUG-only scripted pilot used to reach a named game state on demand.
///
/// It steers with nothing but normalized `PlayerCommand` movement — the same
/// interface a finger drives — so a scenario exercises the real input, physics,
/// encounter, and rendering path rather than reaching into authoritative state.
/// Never compiled into a release build, and never consulted while a human is
/// playing: `GameScene` only creates one when the launch argument is present.
///
/// Enable with `-SSAutopilot <scenario>`:
///
/// | Scenario | Walks to |
/// |---|---|
/// | `mobA` / `mobB` / `mobC` | that encounter trigger |
/// | `elite` | the Improper Search Daemon trigger |
/// | `boss` | the Algorithmic Moderate trigger |
/// | `extraction` | the Extraction zone |
/// | `tour` | every trigger in objective order, then Extraction |
struct DebugAutopilot {
    private var waypoints: [VecI]
    private var index = 0
    /// Ticks spent on the current waypoint, so a blocked path gives up instead
    /// of grinding into a wall forever.
    private var ticksOnWaypoint = 0
    private static let arrivalRadius = 48
    private static let waypointTimeoutTicks = 60 * 40

    static func fromLaunchArguments(_ arguments: [String], arena: ArenaManifest) -> DebugAutopilot? {
        guard let flag = arguments.firstIndex(of: "-SSAutopilot"),
              arguments.index(after: flag) < arguments.endIndex
        else { return nil }
        return DebugAutopilot(scenario: arguments[arguments.index(after: flag)], arena: arena)
    }

    init?(scenario: String, arena: ArenaManifest) {
        func trigger(_ encounterId: String) -> VecI? {
            arena.encounterTriggers.first { $0.id == "trigger-\(encounterId)" }?.center
        }
        let extraction = arena.extraction.center

        switch scenario {
        case "mobA": waypoints = [trigger("M-A")].compactMap { $0 }
        case "mobB": waypoints = [trigger("M-B")].compactMap { $0 }
        case "mobC": waypoints = [trigger("M-C")].compactMap { $0 }
        case "elite": waypoints = [trigger("elite")].compactMap { $0 }
        case "boss": waypoints = [trigger("boss")].compactMap { $0 }
        case "extraction": waypoints = [extraction]
        case "tour":
            waypoints = ["M-A", "M-B", "M-C", "elite", "boss"].compactMap(trigger) + [extraction]
        default:
            return nil
        }
        guard !waypoints.isEmpty else { return nil }
    }

    var finished: Bool { index >= waypoints.count }

    /// Normalized movement toward the active waypoint, or neutral when done.
    mutating func command(from position: VecI) -> (moveX: Int16, moveY: Int16) {
        guard index < waypoints.count else { return (0, 0) }
        let target = waypoints[index]
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distanceSquared = dx * dx + dy * dy

        ticksOnWaypoint += 1
        if distanceSquared <= Self.arrivalRadius * Self.arrivalRadius
            || ticksOnWaypoint >= Self.waypointTimeoutTicks
        {
            index += 1
            ticksOnWaypoint = 0
            return (0, 0)
        }

        // Full-magnitude unit vector; the controller re-normalizes and clamps.
        let magnitude = Double((distanceSquared as Int)).squareRoot()
        guard magnitude > 0 else { return (0, 0) }
        let scale = 32_767.0 / magnitude
        return (
            Int16(max(-32_767, min(32_767, (Double(dx) * scale).rounded()))),
            Int16(max(-32_767, min(32_767, (Double(dy) * scale).rounded())))
        )
    }
}
#endif
