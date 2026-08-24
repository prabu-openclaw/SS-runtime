/// External evidence schemas for T903/T904/T905 intake into release-candidate records.
public struct PlaytestSessionRecord: Equatable, Sendable {
    public var participantId: String
    public var completedOnboardingWithoutInstruction: Bool
    public var describedExposureCorrectly: Bool
    public var beganVoluntaryReplay: Bool
    public var competentRunDurationMinutes: Double?

    public init(
        participantId: String,
        completedOnboardingWithoutInstruction: Bool,
        describedExposureCorrectly: Bool,
        beganVoluntaryReplay: Bool = false,
        competentRunDurationMinutes: Double? = nil
    ) {
        self.participantId = participantId
        self.completedOnboardingWithoutInstruction = completedOnboardingWithoutInstruction
        self.describedExposureCorrectly = describedExposureCorrectly
        self.beganVoluntaryReplay = beganVoluntaryReplay
        self.competentRunDurationMinutes = competentRunDurationMinutes
    }
}

public struct PlaytestEvidence: Equatable, Sendable {
    public var schemaVersion: String
    public var taskId: String
    public var sessions: [PlaytestSessionRecord]

    public init(taskId: String, sessions: [PlaytestSessionRecord]) {
        schemaVersion = "playtest-evidence-001"
        self.taskId = taskId
        self.sessions = sessions
    }

    public func gateResults() -> [GatePassRecord] {
        switch taskId {
        case "T903":
            let onboardingPass = sessions.filter(\.completedOnboardingWithoutInstruction).count
            let exposurePass = sessions.filter(\.describedExposureCorrectly).count
            return [
                GatePassRecord(
                    gateId: "G-001",
                    passed: sessions.count >= 5 && onboardingPass >= 4,
                    source: .playtest
                ),
                GatePassRecord(
                    gateId: "G-002",
                    passed: sessions.count >= 5 && exposurePass >= 4,
                    source: .playtest
                )
            ]
        case "T904":
            let replayPass = sessions.filter(\.beganVoluntaryReplay).count
            return [
                GatePassRecord(
                    gateId: "G-004",
                    passed: sessions.count >= 5 && replayPass >= 3,
                    source: .playtest
                )
            ]
        default:
            return []
        }
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "taskId": .string(taskId),
            "sessions": .array(sessions.map { session in
                .object([
                    "participantId": .string(session.participantId),
                    "completedOnboardingWithoutInstruction": .bool(session.completedOnboardingWithoutInstruction),
                    "describedExposureCorrectly": .bool(session.describedExposureCorrectly),
                    "beganVoluntaryReplay": .bool(session.beganVoluntaryReplay),
                    "competentRunDurationMinutes": session.competentRunDurationMinutes.map {
                        .integer(Int64($0.rounded()))
                    } ?? .null
                ])
            })
        ])
    }
}

public struct DeviceRunEvidence: Equatable, Sendable {
    public var schemaVersion: String
    public var taskId: String
    public var deviceClass: String
    public var consecutiveCompleteRuns: Int
    public var frameTimePassesGateC: Bool
    public var memoryWarnings: Int
    public var seriousOrCriticalThermalEvents: Int

    public init(
        taskId: String = "T905",
        deviceClass: String,
        consecutiveCompleteRuns: Int,
        frameTimePassesGateC: Bool,
        memoryWarnings: Int,
        seriousOrCriticalThermalEvents: Int
    ) {
        schemaVersion = "device-run-evidence-001"
        self.taskId = taskId
        self.deviceClass = deviceClass
        self.consecutiveCompleteRuns = consecutiveCompleteRuns
        self.frameTimePassesGateC = frameTimePassesGateC
        self.memoryWarnings = memoryWarnings
        self.seriousOrCriticalThermalEvents = seriousOrCriticalThermalEvents
    }

    public func gateResults() -> [GatePassRecord] {
        let performancePass = consecutiveCompleteRuns >= 3
            && frameTimePassesGateC
            && memoryWarnings == 0
            && seriousOrCriticalThermalEvents == 0
        return [
            GatePassRecord(gateId: "C-001", passed: performancePass, source: .deviceCapture),
            GatePassRecord(gateId: "C-002", passed: frameTimePassesGateC, source: .deviceCapture),
            GatePassRecord(gateId: "C-003", passed: frameTimePassesGateC, source: .deviceCapture),
            GatePassRecord(gateId: "C-004", passed: frameTimePassesGateC, source: .deviceCapture),
            GatePassRecord(gateId: "C-005", passed: frameTimePassesGateC, source: .deviceCapture),
            GatePassRecord(gateId: "C-006", passed: frameTimePassesGateC, source: .deviceCapture),
            GatePassRecord(gateId: "C-007", passed: seriousOrCriticalThermalEvents == 0, source: .deviceCapture)
        ]
    }

    public func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string(schemaVersion),
            "taskId": .string(taskId),
            "deviceClass": .string(deviceClass),
            "consecutiveCompleteRuns": .integer(Int64(consecutiveCompleteRuns)),
            "frameTimePassesGateC": .bool(frameTimePassesGateC),
            "memoryWarnings": .integer(Int64(memoryWarnings)),
            "seriousOrCriticalThermalEvents": .integer(Int64(seriousOrCriticalThermalEvents))
        ])
    }
}
