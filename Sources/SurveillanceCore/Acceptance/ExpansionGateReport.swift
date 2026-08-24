/// T908: canonical expansion gate decision artifact for release review.
public struct ExpansionGateReport: Equatable, Sendable {
    public var schemaVersion: String
    public var decision: ExpansionGateDecision
    public var openSeverityOneDefects: Int
    public var openSeverityTwoDefects: Int
    public var d013Settled: Bool
    public var d021Settled: Bool
    public var linkedAutomatedGateCount: Int
    public var pendingGateCount: Int
    public var releaseCandidateDigest: String

    public init(
        schemaVersion: String = "expansion-gate-report-001",
        decision: ExpansionGateDecision,
        openSeverityOneDefects: Int,
        openSeverityTwoDefects: Int,
        d013Settled: Bool,
        d021Settled: Bool,
        linkedAutomatedGateCount: Int,
        pendingGateCount: Int,
        releaseCandidateDigest: String
    ) {
        self.schemaVersion = schemaVersion
        self.decision = decision
        self.openSeverityOneDefects = openSeverityOneDefects
        self.openSeverityTwoDefects = openSeverityTwoDefects
        self.d013Settled = d013Settled
        self.d021Settled = d021Settled
        self.linkedAutomatedGateCount = linkedAutomatedGateCount
        self.pendingGateCount = pendingGateCount
        self.releaseCandidateDigest = releaseCandidateDigest
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "decision": .string(decision.rawValue),
            "openSeverityOneDefects": .integer(Int64(openSeverityOneDefects)),
            "openSeverityTwoDefects": .integer(Int64(openSeverityTwoDefects)),
            "d013Settled": .bool(d013Settled),
            "d021Settled": .bool(d021Settled),
            "linkedAutomatedGateCount": .integer(Int64(linkedAutomatedGateCount)),
            "pendingGateCount": .integer(Int64(pendingGateCount)),
            "releaseCandidateDigest": .string(releaseCandidateDigest)
        ])
    }
}

public enum ExpansionGateReporter {
    public static func evaluate(
        options: ReleaseCandidateEvidenceCollector.Options = ReleaseCandidateEvidenceCollector.Options()
    ) throws -> ExpansionGateReport {
        let evidence = try ReleaseCandidateEvidenceCollector.collect(options: options)
        return ExpansionGateReport(
            decision: evidence.expansionGateDecision,
            openSeverityOneDefects: evidence.openSeverityOneDefects,
            openSeverityTwoDefects: evidence.openSeverityTwoDefects,
            d013Settled: evidence.d013Settled,
            d021Settled: evidence.d021Settled,
            linkedAutomatedGateCount: evidence.linkedAutomatedGates.count,
            pendingGateCount: evidence.pendingGateIds.count,
            releaseCandidateDigest: evidence.canonical().sha256Hex()
        )
    }
}
