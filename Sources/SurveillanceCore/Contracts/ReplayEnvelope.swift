import Foundation

public enum ReplayLoadError: Equatable, Sendable, Error {
    case invalidJSON
    case incompatibleIdentity(expected: ReplayIdentity, received: ReplayIdentity)
    case duplicateCommandTick(UInt64)
    case nonIncreasingCommandTick
    case invalidSeed
    case invalidCommandRange
}

public struct ReplayEnvelope: Equatable, Sendable {
    public var identity: ReplayIdentity
    public var seed: UInt64
    public var commands: [PlayerCommand]
    public var expectedFinalDigest: String?

    public init(
        identity: ReplayIdentity,
        seed: UInt64,
        commands: [PlayerCommand],
        expectedFinalDigest: String? = nil
    ) {
        self.identity = identity
        self.seed = seed
        self.commands = commands
        self.expectedFinalDigest = expectedFinalDigest
    }

    public static func load(json: Data) -> Result<ReplayEnvelope, ReplayLoadError> {
        let object: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
                return .failure(.invalidJSON)
            }
            object = parsed
        } catch {
            return .failure(.invalidJSON)
        }

        guard let schema = object["schemaVersion"] as? String,
              let ruleset = object["rulesetVersion"] as? String,
              let content = object["contentVersion"] as? String,
              let arena = object["arenaVersion"] as? String
        else {
            return .failure(.invalidJSON)
        }

        let identity = ReplayIdentity(
            rulesetVersion: ruleset,
            contentVersion: content,
            arenaVersion: arena,
            replaySchemaVersion: schema
        )
        if identity.compatibility() != .compatible {
            return .failure(.incompatibleIdentity(expected: .current, received: identity))
        }

        guard let seedNumber = object["seed"] as? NSNumber else {
            return .failure(.invalidJSON)
        }
        let seed = seedNumber.uint64Value
        if seedNumber.doubleValue < 0 {
            return .failure(.invalidSeed)
        }

        guard let rawCommands = object["commands"] as? [[String: Any]] else {
            return .failure(.invalidJSON)
        }

        var commands: [PlayerCommand] = []
        var previousTick: UInt64 = 0
        var seen: Set<UInt64> = []
        for raw in rawCommands {
            guard let tickNumber = raw["tick"] as? NSNumber,
                  let moveX = raw["moveX"] as? Int,
                  let moveY = raw["moveY"] as? Int,
                  let dodge = raw["dodgePressed"] as? Bool
            else {
                return .failure(.invalidJSON)
            }
            let tick = tickNumber.uint64Value
            if tick < 1 { return .failure(.invalidCommandRange) }
            if seen.contains(tick) { return .failure(.duplicateCommandTick(tick)) }
            if previousTick != 0 && tick <= previousTick { return .failure(.nonIncreasingCommandTick) }
            if moveX < Int(PlayerCommand.axisMinimum) || moveX > Int(PlayerCommand.axisMaximum)
                || moveY < Int(PlayerCommand.axisMinimum) || moveY > Int(PlayerCommand.axisMaximum)
            {
                return .failure(.invalidCommandRange)
            }
            var upgrade: UInt8?
            if let choice = raw["upgradeChoiceIndex"] as? Int {
                if choice < 0 || choice > 2 { return .failure(.invalidCommandRange) }
                upgrade = UInt8(choice)
            }
            commands.append(
                PlayerCommand(
                    tick: tick,
                    moveX: Int16(moveX),
                    moveY: Int16(moveY),
                    dodgePressed: dodge,
                    upgradeChoiceIndex: upgrade
                )
            )
            seen.insert(tick)
            previousTick = tick
        }

        let digest = object["expectedFinalDigest"] as? String
        if let digest, digest.count != 64 {
            return .failure(.invalidJSON)
        }

        return .success(
            ReplayEnvelope(
                identity: identity,
                seed: seed,
                commands: commands,
                expectedFinalDigest: digest
            )
        )
    }

    public func command(for tick: UInt64) -> PlayerCommand? {
        commands.first { $0.tick == tick }
    }
}
