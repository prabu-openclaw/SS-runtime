import Foundation
import Testing
@testable import SurveillanceCore

@Suite struct PlaytestEvidenceLoaderTests {
    @Test func playtestT903LoaderParsesSessions() throws {
        let json = """
        {
          "schemaVersion":"playtest-evidence-001",
          "taskId":"T903",
          "sessions":[
            {"participantId":"p1","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true},
            {"participantId":"p2","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":false}
          ]
        }
        """.data(using: .utf8)!
        let evidence = try PlaytestEvidenceLoader.load(json: json)
        #expect(evidence.taskId == "T903")
        #expect(evidence.sessions.count == 2)
        let results = evidence.gateResults()
        #expect(results.contains { $0.gateId == "G-001" })
    }

    @Test func playtestT904LoaderRequiresVoluntaryReplayField() throws {
        let json = """
        {
          "schemaVersion":"playtest-evidence-001",
          "taskId":"T904",
          "sessions":[
            {"participantId":"p1","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true,"beganVoluntaryReplay":true},
            {"participantId":"p2","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true,"beganVoluntaryReplay":true},
            {"participantId":"p3","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true,"beganVoluntaryReplay":true},
            {"participantId":"p4","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true,"beganVoluntaryReplay":false},
            {"participantId":"p5","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true,"beganVoluntaryReplay":false}
          ]
        }
        """.data(using: .utf8)!
        let evidence = try PlaytestEvidenceLoader.load(json: json)
        #expect(evidence.gateResults().contains { $0.gateId == "G-004" && $0.passed })
    }

    @Test func playtestLoaderRejectsInvalidTaskId() {
        let json = """
        {"taskId":"T999","sessions":[{"participantId":"p1","completedOnboardingWithoutInstruction":true,"describedExposureCorrectly":true}]}
        """.data(using: .utf8)!
        #expect(throws: PlaytestEvidenceError.invalidJSON) {
            try PlaytestEvidenceLoader.load(json: json)
        }
    }

    @Test func playtestT903EvidenceAdvancesReleaseCandidateCollection() throws {
        let sessions = (1...5).map { index in
            PlaytestSessionRecord(
                participantId: "p\(index)",
                completedOnboardingWithoutInstruction: index <= 4,
                describedExposureCorrectly: index <= 4
            )
        }
        let evidence = try ReleaseCandidateEvidenceCollector.collect(
            options: ReleaseCandidateEvidenceCollector.Options(
                playtestEvidence: [PlaytestEvidence(taskId: "T903", sessions: sessions)]
            )
        )
        #expect(evidence.expansionGateDecision == .notComputable)
        #expect(!evidence.pendingGateIds.isEmpty)
    }
}
