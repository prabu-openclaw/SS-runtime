/// D-021 / T406: profiled simulation and device ceilings for Gate C-011.
public enum D021Status: String, Equatable, Sendable {
    case pendingDeviceProfiling = "pendingDeviceProfiling"
    case simulationMeasured = "simulationMeasured"
    case settled = "settled"
}

public struct D021Ceilings: Equatable, Sendable {
    public var schemaVersion: String
    public var status: D021Status
    public var peakCamerasLive: Int
    public var peakEnemiesLive: Int
    public var peakProjectilesLive: Int
    public var peakMinesLive: Int
    public var peakCivicPoolLive: Int
    public var peakAllocatorNext: UInt64
    public var peakTotalLive: Int
    public var residentMemoryBytes: UInt64?
    public var atlasMemoryBytes: UInt64?

    public init(
        schemaVersion: String = "d021-ceilings-001",
        status: D021Status,
        peakCamerasLive: Int,
        peakEnemiesLive: Int,
        peakProjectilesLive: Int,
        peakMinesLive: Int,
        peakCivicPoolLive: Int,
        peakAllocatorNext: UInt64,
        peakTotalLive: Int,
        residentMemoryBytes: UInt64? = nil,
        atlasMemoryBytes: UInt64? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.peakCamerasLive = peakCamerasLive
        self.peakEnemiesLive = peakEnemiesLive
        self.peakProjectilesLive = peakProjectilesLive
        self.peakMinesLive = peakMinesLive
        self.peakCivicPoolLive = peakCivicPoolLive
        self.peakAllocatorNext = peakAllocatorNext
        self.peakTotalLive = peakTotalLive
        self.residentMemoryBytes = residentMemoryBytes
        self.atlasMemoryBytes = atlasMemoryBytes
    }

    public static func fromSimulation(_ report: PeakDensityReport) -> D021Ceilings {
        D021Ceilings(
            status: .simulationMeasured,
            peakCamerasLive: report.aggregate.peakCamerasLive,
            peakEnemiesLive: report.aggregate.peakEnemiesLive,
            peakProjectilesLive: report.aggregate.peakProjectilesLive,
            peakMinesLive: report.aggregate.peakMinesLive,
            peakCivicPoolLive: report.aggregate.peakCivicPoolLive,
            peakAllocatorNext: report.aggregate.peakAllocatorNext,
            peakTotalLive: report.aggregate.peakTotalLive
        )
    }

    public func withDeviceProfiling(residentMemoryBytes: UInt64, atlasMemoryBytes: UInt64) -> D021Ceilings {
        var copy = self
        copy.residentMemoryBytes = residentMemoryBytes
        copy.atlasMemoryBytes = atlasMemoryBytes
        copy.status = .settled
        return copy
    }

    public var isSettled: Bool { status == .settled }

    public func metricsWithinCeilings(_ metrics: PeakDensityMetrics) -> Bool {
        metrics.peakCamerasLive <= peakCamerasLive
            && metrics.peakEnemiesLive <= peakEnemiesLive
            && metrics.peakProjectilesLive <= peakProjectilesLive
            && metrics.peakMinesLive <= peakMinesLive
            && metrics.peakCivicPoolLive <= peakCivicPoolLive
            && metrics.peakAllocatorNext <= peakAllocatorNext
            && metrics.peakTotalLive <= peakTotalLive
    }

    public func sampleWithinSimulationCeilings(_ sample: RunTelemetrySnapshot) -> Bool {
        sample.entities.camerasLive <= peakCamerasLive
            && sample.entities.enemiesLive <= peakEnemiesLive
            && sample.entities.projectilesLive <= peakProjectilesLive
            && sample.entities.minesLive <= peakMinesLive
            && sample.entities.civicPoolLive <= peakCivicPoolLive
            && sample.entities.allocatorNext <= peakAllocatorNext
            && sample.entities.totalLive <= peakTotalLive
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "status": .string(status.rawValue),
            "simulation": .object([
                "peakCamerasLive": .integer(Int64(peakCamerasLive)),
                "peakEnemiesLive": .integer(Int64(peakEnemiesLive)),
                "peakProjectilesLive": .integer(Int64(peakProjectilesLive)),
                "peakMinesLive": .integer(Int64(peakMinesLive)),
                "peakCivicPoolLive": .integer(Int64(peakCivicPoolLive)),
                "peakAllocatorNext": .unsigned(peakAllocatorNext),
                "peakTotalLive": .integer(Int64(peakTotalLive))
            ]),
            "device": .object([
                "residentMemoryBytes": residentMemoryBytes.map { .unsigned($0) } ?? .null,
                "atlasMemoryBytes": atlasMemoryBytes.map { .unsigned($0) } ?? .null
            ])
        ])
    }
}

public enum D021CeilingEvaluator {
    public static func profileAndMeasure() throws -> D021Ceilings {
        D021Ceilings.fromSimulation(try PeakDensityProfiler.profile())
    }

    public static func gateC011PassesSimulationBounds(_ ceilings: D021Ceilings, report: PeakDensityReport) -> Bool {
        report.scenarios.values.allSatisfy { ceilings.metricsWithinCeilings($0) }
    }
}
