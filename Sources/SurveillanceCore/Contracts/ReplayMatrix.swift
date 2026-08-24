import Foundation

public enum ReplayMatrixError: Equatable, Sendable, Error {
    case invalidFixture
    case missingFixture(String)
    case executionFailed(String)
    case digestMismatch(fixture: String, expected: String, received: String)
    case tripleRunMismatch(fixture: String, digests: [String])
}

public struct ReplayMatrixEntry: Equatable, Sendable {
    public var id: String
    public var fixture: String
    public var expectedFinalDigest: String
    public var tripleRunRequired: Bool
}

public enum ReplayMatrix {
    public static let fixtureVersion = "replay-matrix-001"

    public static func load() throws -> [ReplayMatrixEntry] {
        let data = SpecBundle.fixture(fixtureVersion)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["fixtureVersion"] as? String,
              version == fixtureVersion,
              let rawEntries = object["entries"] as? [[String: Any]]
        else {
            throw ReplayMatrixError.invalidFixture
        }

        return try rawEntries.map { raw in
            guard let id = raw["id"] as? String,
                  let fixture = raw["fixture"] as? String,
                  let digest = raw["expectedFinalDigest"] as? String,
                  digest.count == 64
            else {
                throw ReplayMatrixError.invalidFixture
            }
            let triple = raw["tripleRunRequired"] as? Bool ?? true
            return ReplayMatrixEntry(
                id: id,
                fixture: fixture,
                expectedFinalDigest: digest,
                tripleRunRequired: triple
            )
        }
    }

    public static func execute(_ entry: ReplayMatrixEntry) throws -> TickResult {
        let data = SpecBundle.fixture(entry.fixture)
        let envelope = try ReplayEnvelope.load(json: data).get()
        if envelope.expectedFinalDigest == nil {
            let enriched = ReplayEnvelope(
                identity: envelope.identity,
                seed: envelope.seed,
                commands: envelope.commands,
                expectedFinalDigest: entry.expectedFinalDigest
            )
            switch Simulation.execute(enriched) {
            case .success(let result):
                if result.outcome == .invalid {
                    throw ReplayMatrixError.digestMismatch(
                        fixture: entry.fixture,
                        expected: entry.expectedFinalDigest,
                        received: result.digest
                    )
                }
                return result
            case .failure:
                throw ReplayMatrixError.executionFailed(entry.id)
            }
        }

        switch Simulation.execute(envelope) {
        case .success(let result):
            if result.digest != entry.expectedFinalDigest {
                throw ReplayMatrixError.digestMismatch(
                    fixture: entry.fixture,
                    expected: entry.expectedFinalDigest,
                    received: result.digest
                )
            }
            return result
        case .failure:
            throw ReplayMatrixError.executionFailed(entry.id)
        }
    }

    public static func tripleRunDigest(_ entry: ReplayMatrixEntry) throws -> String {
        var digests: [String] = []
        for _ in 0..<3 {
            let result = try execute(entry)
            digests.append(result.digest)
        }
        guard Set(digests).count == 1 else {
            throw ReplayMatrixError.tripleRunMismatch(fixture: entry.fixture, digests: digests)
        }
        return digests[0]
    }
}
