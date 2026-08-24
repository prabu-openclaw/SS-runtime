/// T406: peak authoritative entity and pool counts observed during simulation scenarios.
public struct PeakDensityMetrics: Equatable, Sendable {
    public var peakCamerasLive: Int
    public var peakEnemiesLive: Int
    public var peakProjectilesLive: Int
    public var peakMinesLive: Int
    public var peakCivicPoolLive: Int
    public var peakAllocatorNext: UInt64
    public var peakTotalLive: Int

    public static let zero = PeakDensityMetrics(
        peakCamerasLive: 0,
        peakEnemiesLive: 0,
        peakProjectilesLive: 0,
        peakMinesLive: 0,
        peakCivicPoolLive: 0,
        peakAllocatorNext: 0,
        peakTotalLive: 0
    )

    public mutating func absorb(_ sample: RunTelemetrySnapshot) {
        peakCamerasLive = max(peakCamerasLive, sample.entities.camerasLive)
        peakEnemiesLive = max(peakEnemiesLive, sample.entities.enemiesLive)
        peakProjectilesLive = max(peakProjectilesLive, sample.entities.projectilesLive)
        peakMinesLive = max(peakMinesLive, sample.entities.minesLive)
        peakCivicPoolLive = max(peakCivicPoolLive, sample.entities.civicPoolLive)
        peakAllocatorNext = max(peakAllocatorNext, sample.entities.allocatorNext)
        peakTotalLive = max(peakTotalLive, sample.entities.totalLive)
    }

    public mutating func merge(_ other: PeakDensityMetrics) {
        peakCamerasLive = max(peakCamerasLive, other.peakCamerasLive)
        peakEnemiesLive = max(peakEnemiesLive, other.peakEnemiesLive)
        peakProjectilesLive = max(peakProjectilesLive, other.peakProjectilesLive)
        peakMinesLive = max(peakMinesLive, other.peakMinesLive)
        peakCivicPoolLive = max(peakCivicPoolLive, other.peakCivicPoolLive)
        peakAllocatorNext = max(peakAllocatorNext, other.peakAllocatorNext)
        peakTotalLive = max(peakTotalLive, other.peakTotalLive)
    }
}

public struct PeakDensityReport: Equatable, Sendable {
    public var schemaVersion: String
    public var scenarios: [String: PeakDensityMetrics]
    public var aggregate: PeakDensityMetrics

    public init(schemaVersion: String = "peak-density-001", scenarios: [String: PeakDensityMetrics], aggregate: PeakDensityMetrics) {
        self.schemaVersion = schemaVersion
        self.scenarios = scenarios
        self.aggregate = aggregate
    }

    public func canonical() -> CanonicalJSON {
        func metricsJSON(_ metrics: PeakDensityMetrics) -> CanonicalJSON {
            .object([
                "peakCamerasLive": .integer(Int64(metrics.peakCamerasLive)),
                "peakEnemiesLive": .integer(Int64(metrics.peakEnemiesLive)),
                "peakProjectilesLive": .integer(Int64(metrics.peakProjectilesLive)),
                "peakMinesLive": .integer(Int64(metrics.peakMinesLive)),
                "peakCivicPoolLive": .integer(Int64(metrics.peakCivicPoolLive)),
                "peakAllocatorNext": .unsigned(metrics.peakAllocatorNext),
                "peakTotalLive": .integer(Int64(metrics.peakTotalLive))
            ])
        }

        return .object([
            "schemaVersion": .string(schemaVersion),
            "scenarios": .object(
                scenarios
                    .sorted { $0.key < $1.key }
                    .reduce(into: [:]) { $0[$1.key] = metricsJSON($1.value) }
            ),
            "aggregate": metricsJSON(aggregate)
        ])
    }
}

public enum PeakDensityProfiler {
    public static func observe(_ state: WorldState, peak: inout PeakDensityMetrics) {
        peak.absorb(RunTelemetrySnapshot(state))
    }

    public static func profileCompleteRun(upgrade: UpgradeID) throws -> PeakDensityMetrics {
        var sim = try Simulation.make(seed: 1)
        var peak = PeakDensityMetrics.zero

        func track() {
            observe(sim.state, peak: &peak)
        }

        track()
        sim.testing_completeEncounter("M-A")
        track()
        sim.testing_armUpgradeSelection()
        track()
        _ = sim.step(
            command: PlayerCommand(
                tick: sim.state.tick + 1,
                moveX: 0,
                moveY: 0,
                dodgePressed: false,
                upgradeChoiceIndex: upgrade.selectionIndex
            )
        )
        track()
        sim.testing_completeCombatGraph()
        track()
        _ = sim.step(command: .neutral(tick: sim.state.tick + 1))
        track()
        let extract = sim.state.arena.extraction.center
        sim.testing_setPlayerPosition(VecI(x: extract.x, y: extract.y))
        while sim.state.outcome == .playing {
            _ = sim.step(command: .neutral(tick: sim.state.tick + 1))
            track()
        }
        return peak
    }

    public static func profileCivicPoolStress() throws -> PeakDensityMetrics {
        var sim = try Simulation.make(seed: 1)
        sim.testing_completeEncounter("M-A")
        sim.testing_selectUpgrade(.ricochetPulse)
        sim.testing_completeCombatGraph()
        sim.testing_fillCivicPool(count: PerformanceThresholds.civicPoolCapacity)

        var peak = PeakDensityMetrics.zero
        for _ in 0..<120 {
            _ = sim.step(
                command: PlayerCommand(
                    tick: sim.state.tick + 1,
                    moveX: 32767,
                    moveY: 0,
                    dodgePressed: false
                )
            )
            observe(sim.state, peak: &peak)
        }
        return peak
    }

    public static func profile() throws -> PeakDensityReport {
        var scenarios: [String: PeakDensityMetrics] = [:]
        var aggregate = PeakDensityMetrics.zero

        for upgrade in UpgradeID.allCases {
            let key = "complete-run-\(upgrade.rawValue)"
            let metrics = try profileCompleteRun(upgrade: upgrade)
            scenarios[key] = metrics
            aggregate.merge(metrics)
        }

        let stress = try profileCivicPoolStress()
        scenarios["civic-pool-stress"] = stress
        aggregate.merge(stress)

        return PeakDensityReport(scenarios: scenarios, aggregate: aggregate)
    }
}
