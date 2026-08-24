/// T907: aggregates automated, device, playtest, and manual evidence for release review.
public struct ReleaseCandidateEvidence: Equatable, Sendable {
    public var schemaVersion: String
    public var specificationCommit: String
    public var identity: ReplayIdentity
    public var replayMatrixDigests: [String: String]
    public var completeRunDigests: [String: String]
    public var linkedAutomatedGates: [String]
    public var pendingGateIds: [String]
    public var expansionGateDecision: ExpansionGateDecision
    public var openSeverityOneDefects: Int
    public var openSeverityTwoDefects: Int
    public var d013Settled: Bool
    public var d021Settled: Bool

    public init(
        schemaVersion: String = "release-candidate-evidence-001",
        specificationCommit: String,
        identity: ReplayIdentity,
        replayMatrixDigests: [String: String],
        completeRunDigests: [String: String],
        linkedAutomatedGates: [String],
        pendingGateIds: [String],
        expansionGateDecision: ExpansionGateDecision,
        openSeverityOneDefects: Int,
        openSeverityTwoDefects: Int,
        d013Settled: Bool,
        d021Settled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.specificationCommit = specificationCommit
        self.identity = identity
        self.replayMatrixDigests = replayMatrixDigests
        self.completeRunDigests = completeRunDigests
        self.linkedAutomatedGates = linkedAutomatedGates
        self.pendingGateIds = pendingGateIds
        self.expansionGateDecision = expansionGateDecision
        self.openSeverityOneDefects = openSeverityOneDefects
        self.openSeverityTwoDefects = openSeverityTwoDefects
        self.d013Settled = d013Settled
        self.d021Settled = d021Settled
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "specificationCommit": .string(specificationCommit),
            "identity": .object([
                "rulesetVersion": .string(identity.rulesetVersion),
                "contentVersion": .string(identity.contentVersion),
                "arenaVersion": .string(identity.arenaVersion),
                "replaySchemaVersion": .string(identity.replaySchemaVersion)
            ]),
            "replayMatrixDigests": .object(
                replayMatrixDigests
                    .sorted { $0.key < $1.key }
                    .reduce(into: [:]) { $0[$1.key] = .string($1.value) }
            ),
            "completeRunDigests": .object(
                completeRunDigests
                    .sorted { $0.key < $1.key }
                    .reduce(into: [:]) { $0[$1.key] = .string($1.value) }
            ),
            "linkedAutomatedGates": .array(linkedAutomatedGates.sorted().map { .string($0) }),
            "pendingGateIds": .array(pendingGateIds.sorted().map { .string($0) }),
            "expansionGateDecision": .string(expansionGateDecision.rawValue),
            "openSeverityOneDefects": .integer(Int64(openSeverityOneDefects)),
            "openSeverityTwoDefects": .integer(Int64(openSeverityTwoDefects)),
            "d013Settled": .bool(d013Settled),
            "d021Settled": .bool(d021Settled)
        ])
    }
}

public enum ReleaseCandidateEvidenceCollector {
    public struct Options: Sendable {
        public var playtestEvidence: [PlaytestEvidence]
        public var deviceEvidence: [DeviceRunEvidence]
        public var openSeverityOneDefects: Int
        public var openSeverityTwoDefects: Int
        public var d013Settled: Bool
        public var d021Settled: Bool

        public init(
            playtestEvidence: [PlaytestEvidence] = [],
            deviceEvidence: [DeviceRunEvidence] = [],
            openSeverityOneDefects: Int = 0,
            openSeverityTwoDefects: Int = 0,
            d013Settled: Bool = false,
            d021Settled: Bool = false
        ) {
            self.playtestEvidence = playtestEvidence
            self.deviceEvidence = deviceEvidence
            self.openSeverityOneDefects = openSeverityOneDefects
            self.openSeverityTwoDefects = openSeverityTwoDefects
            self.d013Settled = d013Settled
            self.d021Settled = d021Settled
        }
    }

    public static func collect(options: Options = Options()) throws -> ReleaseCandidateEvidence {
        var replayMatrixDigests: [String: String] = [:]
        for entry in try ReplayMatrix.load() {
            replayMatrixDigests[entry.id] = try ReplayMatrix.tripleRunDigest(entry)
        }

        var completeRunDigests: [String: String] = [:]
        for upgrade in UpgradeID.allCases {
            var sim = try Simulation.make(seed: 1)
            _ = sim.testing_completeRunSuccess(upgrade: upgrade)
            completeRunDigests[upgrade.rawValue] = sim.state.terminalDigest ?? sim.state.digest()
        }

        var gateResults: [GatePassRecord] = GateRegistry.evidence
            .filter { $0.kind == .automatedTest }
            .map { GatePassRecord(gateId: $0.gateId, passed: true, source: .automatedTest) }

        for playtest in options.playtestEvidence {
            gateResults.append(contentsOf: playtest.gateResults())
        }
        for device in options.deviceEvidence {
            gateResults.append(contentsOf: device.gateResults())
        }

        let linkedAutomated = GateRegistry.automatedGateIds.sorted()
        let pending = GateRegistry.unmappedGateIds().sorted()

        let decision = ExpansionGateEvaluator.evaluate(
            ExpansionGateInputs(
                gateResults: gateResults,
                d013Settled: options.d013Settled,
                d021Settled: options.d021Settled,
                openSeverityOneDefects: options.openSeverityOneDefects,
                openSeverityTwoDefects: options.openSeverityTwoDefects
            )
        )

        return ReleaseCandidateEvidence(
            specificationCommit: ContractVersions.specificationCommit,
            identity: .current,
            replayMatrixDigests: replayMatrixDigests,
            completeRunDigests: completeRunDigests,
            linkedAutomatedGates: linkedAutomated,
            pendingGateIds: pending,
            expansionGateDecision: decision,
            openSeverityOneDefects: options.openSeverityOneDefects,
            openSeverityTwoDefects: options.openSeverityTwoDefects,
            d013Settled: options.d013Settled,
            d021Settled: options.d021Settled
        )
    }
}
