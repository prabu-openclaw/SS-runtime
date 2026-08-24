/// T908: expansion gate outcomes from acceptance.md.
public enum ExpansionGateDecision: String, Equatable, Sendable, Codable {
    case passed = "EXPANSION_GATE_PASSED"
    case failed = "EXPANSION_GATE_FAILED"
    case notComputable = "EXPANSION_GATE_NOT_COMPUTABLE"
}

public struct GatePassRecord: Equatable, Sendable {
    public var gateId: String
    public var passed: Bool
    public var source: GateEvidenceKind

    public init(gateId: String, passed: Bool, source: GateEvidenceKind) {
        self.gateId = gateId
        self.passed = passed
        self.source = source
    }
}

public struct ExpansionGateInputs: Equatable, Sendable {
    public var gateResults: [GatePassRecord]
    public var d013Settled: Bool
    public var d021Settled: Bool
    public var openSeverityOneDefects: Int
    public var openSeverityTwoDefects: Int

    public init(
        gateResults: [GatePassRecord] = [],
        d013Settled: Bool = false,
        d021Settled: Bool = false,
        openSeverityOneDefects: Int = 0,
        openSeverityTwoDefects: Int = 0
    ) {
        self.gateResults = gateResults
        self.d013Settled = d013Settled
        self.d021Settled = d021Settled
        self.openSeverityOneDefects = openSeverityOneDefects
        self.openSeverityTwoDefects = openSeverityTwoDefects
    }
}

public enum ExpansionGateEvaluator {
    public static let requiredGateFamilies: [[String]] = [
        GateRegistry.functional,
        GateRegistry.determinism,
        GateRegistry.stability,
        GateRegistry.visual,
        GateRegistry.arena,
        GateRegistry.accessibility,
        GateRegistry.playtest
    ]

    public static func evaluate(_ inputs: ExpansionGateInputs) -> ExpansionGateDecision {
        if inputs.openSeverityOneDefects > 0 || inputs.openSeverityTwoDefects > 0 {
            return .failed
        }

        if !inputs.d013Settled || !inputs.d021Settled {
            return .notComputable
        }

        let requiredIds = Set(requiredGateFamilies.joined())
        let resultsByGate = Dictionary(uniqueKeysWithValues: inputs.gateResults.map { ($0.gateId, $0) })

        if requiredIds.contains(where: { resultsByGate[$0] == nil }) {
            return .notComputable
        }

        if requiredIds.contains(where: { resultsByGate[$0]?.passed == false }) {
            return .failed
        }

        if requiredIds.allSatisfy({ resultsByGate[$0]?.passed == true }) {
            return .passed
        }

        return .notComputable
    }

    public static func defaultInputsFromRegistry() -> ExpansionGateInputs {
        var results: [GatePassRecord] = []
        for entry in GateRegistry.evidence where entry.kind == .automatedTest {
            results.append(GatePassRecord(gateId: entry.gateId, passed: true, source: .automatedTest))
        }
        return ExpansionGateInputs(
            gateResults: results,
            d013Settled: false,
            d021Settled: false
        )
    }
}
