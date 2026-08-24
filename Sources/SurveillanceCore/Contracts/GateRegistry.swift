/// T902: maps acceptance gate IDs to verification evidence.
public enum GateEvidenceKind: String, Equatable, Sendable {
    case automatedTest
    case deviceCapture
    case manualReview
    case playtest
}

public struct GateEvidence: Equatable, Sendable {
    public var gateId: String
    public var kind: GateEvidenceKind
    public var testReference: String?
    public var note: String?

    public init(
        gateId: String,
        kind: GateEvidenceKind,
        testReference: String? = nil,
        note: String? = nil
    ) {
        self.gateId = gateId
        self.kind = kind
        self.testReference = testReference
        self.note = note
    }
}

public enum GateRegistry {
    public static let allGateIds: [String] = functional + determinism + stability + visual + arena + accessibility + playtest

    public static let functional: [String] = (1...22).map { String(format: "A-%03d", $0) }
    public static let determinism: [String] = (1...17).map { String(format: "B-%03d", $0) }
    public static let stability: [String] = (1...11).map { String(format: "C-%03d", $0) }
    public static let visual: [String] = (1...21).map { String(format: "D-%03d", $0) }
    public static let arena: [String] = (1...20).map { String(format: "E-%03d", $0) }
    public static let accessibility: [String] = (1...17).map { String(format: "F-%03d", $0) }
    public static let playtest: [String] = (1...7).map { String(format: "G-%03d", $0) }

    public static let evidence: [GateEvidence] = [
        // Gate B — determinism (automated in SurveillanceCoreTests)
        GateEvidence(gateId: "B-001", kind: .automatedTest, testReference: "ReplayMatrixTests.replayT901TripleExecutionMatchesDigest"),
        GateEvidence(gateId: "B-003", kind: .automatedTest, testReference: "ReplayTests.restartRestoresInitialAuthoritativeState"),
        GateEvidence(gateId: "B-005", kind: .automatedTest, testReference: "ReplayTests.unknownReplayIdentityFailsBeforeTickOne"),
        GateEvidence(gateId: "B-009", kind: .automatedTest, testReference: "CameraDestructionOrderTests"),
        GateEvidence(gateId: "B-012", kind: .automatedTest, testReference: "CameraPlacementTests,CameraFairnessTests"),
        GateEvidence(gateId: "B-014", kind: .automatedTest, testReference: "ContractVectorTests"),
        GateEvidence(gateId: "B-015", kind: .automatedTest, testReference: "ContractVectorTests,GrayscaleSystemsTests"),
        GateEvidence(gateId: "B-016", kind: .automatedTest, testReference: "ReplayMatrixTests.gateB016KernelAndSmokeFixturesPass"),
        GateEvidence(gateId: "B-017", kind: .automatedTest, testReference: "RuntimeBundleTests"),
        GateEvidence(gateId: "B-002", kind: .deviceCapture, note: "Cross-architecture Linux CI + macOS/iOS device matrix (D-011)"),

        // Gate C — stability (device capture for frame/thermal; simulation automated)
        GateEvidence(gateId: "C-001", kind: .deviceCapture, note: "Physical iPhone 12 three-run capture (T905)"),
        GateEvidence(gateId: "C-002", kind: .deviceCapture, testReference: "App/Instrumentation/FrameTimeCollector"),
        GateEvidence(gateId: "C-003", kind: .deviceCapture, testReference: "App/Instrumentation/FrameTimeCollector"),
        GateEvidence(gateId: "C-004", kind: .deviceCapture, testReference: "App/Instrumentation/FrameTimeCollector"),
        GateEvidence(gateId: "C-005", kind: .deviceCapture, testReference: "App/Instrumentation/FrameTimeCollector"),
        GateEvidence(gateId: "C-006", kind: .deviceCapture, testReference: "App/Instrumentation/FrameTimeCollector"),
        GateEvidence(gateId: "C-007", kind: .deviceCapture, note: "ProcessInfo.thermalState sampling (T900)"),
        GateEvidence(gateId: "C-008", kind: .automatedTest, testReference: "RunTelemetryTests.instrumentT900PoolsRemainBounded"),
        GateEvidence(gateId: "C-009", kind: .automatedTest, testReference: "GateVerificationTests.gateC009TenConsecutiveCompleteRunsPass"),
        GateEvidence(gateId: "C-010", kind: .deviceCapture, note: "Manual restart matrix (T905)"),
        GateEvidence(gateId: "C-011", kind: .automatedTest, testReference: "PeakDensityProfilerTests.profileT406GateC011SimulationBounds"),

        // Gate A — functional (partial automated)
        GateEvidence(gateId: "A-011", kind: .automatedTest, testReference: "TerminalPrecedenceTests"),
        GateEvidence(gateId: "A-012", kind: .automatedTest, testReference: "CombatAuthorityReceiptTests,CameraDestructionReceiptTests"),
        GateEvidence(gateId: "A-013", kind: .automatedTest, testReference: "CameraPlacementTests"),
        GateEvidence(gateId: "A-019", kind: .automatedTest, testReference: "CameraDestructionReceiptTests"),
        GateEvidence(gateId: "A-020", kind: .automatedTest, testReference: "ExtractionCountdownTests"),
        GateEvidence(gateId: "A-021", kind: .automatedTest, testReference: "ExtractionCountdownTests"),
        GateEvidence(gateId: "A-022", kind: .automatedTest, testReference: "ObjectiveGraphTests"),
        GateEvidence(gateId: "A-008", kind: .automatedTest, testReference: "CompleteRunVectorTests"),

        // Gate E — arena
        GateEvidence(gateId: "E-017", kind: .automatedTest, testReference: "ArenaReachabilityTests"),
        GateEvidence(gateId: "E-018", kind: .automatedTest, testReference: "ArenaAndSimulationTests"),
        GateEvidence(gateId: "E-019", kind: .automatedTest, testReference: "ExtractionCountdownTests"),
        GateEvidence(gateId: "E-020", kind: .automatedTest, testReference: "ArenaReachabilityTests"),

        // Gate F — accessibility
        GateEvidence(gateId: "F-015", kind: .automatedTest, testReference: "HUDPresentationTests,CameraHUDTests,GrayscaleSystemsTests"),
        GateEvidence(gateId: "F-016", kind: .automatedTest, testReference: "AudioProjectorTests"),
        GateEvidence(gateId: "F-017", kind: .automatedTest, testReference: "ReplayTests,TerminalPrecedenceTests,CameraDestructionReceiptTests"),

        // Gate D — visual (partial automated)
        GateEvidence(gateId: "D-010", kind: .automatedTest, testReference: "RuntimeBundleTests,AssetIntakeTests"),
        GateEvidence(gateId: "D-011", kind: .automatedTest, testReference: "RuntimeBundleTests"),
        GateEvidence(gateId: "D-013", kind: .manualReview, note: "Civic Seam identity review plates (T802)"),
        GateEvidence(gateId: "D-015", kind: .automatedTest, testReference: "RuntimeBundleTests.runtimeBundleT807CatalogContentAuditPassesForBundledCatalog"),

        // Gate G — playtest (T903/T904)
        GateEvidence(gateId: "G-001", kind: .playtest, note: "T903 onboarding playtests"),
        GateEvidence(gateId: "G-004", kind: .playtest, note: "T904 voluntary-replay playtests"),
    ]

    public static func evidence(for gateId: String) -> GateEvidence? {
        evidence.first { $0.gateId == gateId }
    }

    public static var automatedGateIds: [String] {
        evidence.filter { $0.kind == .automatedTest }.map(\.gateId)
    }

    public static var deviceGateIds: [String] {
        evidence.filter { $0.kind == .deviceCapture }.map(\.gateId)
    }

    public static var playtestGateIds: [String] {
        evidence.filter { $0.kind == .playtest }.map(\.gateId)
    }

    public static var mappedGateIds: Set<String> {
        Set(evidence.map(\.gateId))
    }

    public static func unmappedGateIds() -> [String] {
        allGateIds.filter { !mappedGateIds.contains($0) }
    }
}
