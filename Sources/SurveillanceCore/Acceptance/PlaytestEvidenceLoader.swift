import Foundation

public enum PlaytestEvidenceError: Equatable, Sendable, Error {
    case invalidJSON
    case invalidTaskId
    case emptySessions
}

public enum PlaytestEvidenceLoader {
    public static func load(json: Data) throws -> PlaytestEvidence {
        guard let object = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              let taskId = object["taskId"] as? String,
              taskId == "T903" || taskId == "T904",
              let rawSessions = object["sessions"] as? [[String: Any]],
              !rawSessions.isEmpty
        else {
            throw PlaytestEvidenceError.invalidJSON
        }

        let sessions = try rawSessions.map { raw -> PlaytestSessionRecord in
            guard let participantId = raw["participantId"] as? String,
                  let onboarding = raw["completedOnboardingWithoutInstruction"] as? Bool,
                  let exposure = raw["describedExposureCorrectly"] as? Bool
            else {
                throw PlaytestEvidenceError.invalidJSON
            }
            let replay = raw["beganVoluntaryReplay"] as? Bool ?? false
            let duration = raw["competentRunDurationMinutes"] as? NSNumber
            return PlaytestSessionRecord(
                participantId: participantId,
                completedOnboardingWithoutInstruction: onboarding,
                describedExposureCorrectly: exposure,
                beganVoluntaryReplay: replay,
                competentRunDurationMinutes: duration?.doubleValue
            )
        }

        return PlaytestEvidence(taskId: taskId, sessions: sessions)
    }

    public static func loadAll(from directory: URL) throws -> [PlaytestEvidence] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }

        return try urls.map { url in
            try load(json: Data(contentsOf: url))
        }
    }
}
