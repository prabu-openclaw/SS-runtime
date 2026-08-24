import Foundation

public enum ArchetypeID: String, Equatable, Sendable, Codable, CaseIterable {
    case fogAnalyticsCloud
    case cableCarCorrelator
    case sutroSignalWitch
    case autonomousInformant
    case victorianVendor
    case improperSearchDaemon
    case algorithmicModerate
}

public enum UpgradeID: String, Equatable, Sendable, CaseIterable {
    case signalJammer
    case ricochetPulse
    case ghostStep

    public var selectionIndex: UInt8 {
        switch self {
        case .signalJammer: 0
        case .ricochetPulse: 1
        case .ghostStep: 2
        }
    }

    public static func from(index: UInt8) -> UpgradeID? {
        switch index {
        case 0: .signalJammer
        case 1: .ricochetPulse
        case 2: .ghostStep
        default: nil
        }
    }
}

public struct StandardEnemyStats: Equatable, Sendable {
    public var hp: Int
    public var radius: Int
    public var speed: Int
    public var contactDps: Int
    public var pulse: Pulse?
    public var charge: Charge?
    public var shot: Shot?
    public var range: [Int]?
    public var mine: Mine?

    public struct Pulse: Equatable, Sendable {
        public var first: Int
        public var cooldown: Int
        public var telegraph: Int
        public var range: Int
        public var exposure: Int
    }

    public struct Charge: Equatable, Sendable {
        public var first: Int
        public var cooldown: Int
        public var telegraph: Int
        public var ticks: Int
        public var speed: Int
        public var recover: Int
    }

    public struct Shot: Equatable, Sendable {
        public var first: Int
        public var cooldown: Int
        public var telegraph: Int
        public var speed: Int
        public var radius: Int
        public var lifetime: Int
        public var damage: Int
    }

    public struct Mine: Equatable, Sendable {
        public var first: Int
        public var cooldown: Int
        public var telegraph: Int
        public var maximum: Int
        public var arm: Int
        public var lifetime: Int
        public var radius: Int
        public var damage: Int
    }
}

public struct WaveMember: Equatable, Sendable {
    public var archetype: ArchetypeID
    public var count: Int
}

public struct WaveSpec: Equatable, Sendable {
    public var id: String
    public var interval: Int
    public var delay: Int
    public var members: [WaveMember]
}

public struct EncounterSpec: Equatable, Sendable {
    public var zone: String
    public var totals: Int
    public var activationExposure: Int?
    public var initialDelay: Int?
    public var waves: [WaveSpec]
}

public struct CombatContent: Equatable, Sendable {
    public var standardEnemies: [ArchetypeID: StandardEnemyStats]
    public var encounters: [String: EncounterSpec]
    public var eliteHP: Int
    public var eliteRadius: Int
    public var eliteSpeed: Int
    public var eliteContactDps: Int
    public var eliteSpawnDelay: Int
    public var bossHP: Int
    public var bossRadius: Int
    public var bossSpeed: Int
    public var bossContactDps: Int
    public var bossInitialDelay: Int

    public static func bundled() -> CombatContent {
        let data = BundledResource.data(name: "combat-content-001", subdirectory: "contracts")
        return try! decode(data)
    }

    public static func decode(_ data: Data) throws -> CombatContent {
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let enemiesRaw = raw["standardEnemies"] as! [String: [String: Any]]
        var enemies: [ArchetypeID: StandardEnemyStats] = [:]
        for (key, value) in enemiesRaw {
            let id = ArchetypeID(rawValue: key)!
            enemies[id] = parseEnemy(value)
        }
        let encountersRaw = raw["encounters"] as! [String: [String: Any]]
        var encounters: [String: EncounterSpec] = [:]
        for (key, value) in encountersRaw {
            encounters[key] = parseEncounter(value)
        }
        let elite = raw["elite"] as! [String: Any]
        let boss = raw["boss"] as! [String: Any]
        return CombatContent(
            standardEnemies: enemies,
            encounters: encounters,
            eliteHP: elite["hp"] as! Int,
            eliteRadius: elite["radius"] as! Int,
            eliteSpeed: elite["speed"] as! Int,
            eliteContactDps: elite["contactDps"] as! Int,
            eliteSpawnDelay: elite["spawnDelay"] as! Int,
            bossHP: boss["hp"] as! Int,
            bossRadius: boss["radius"] as! Int,
            bossSpeed: boss["baseSpeed"] as! Int,
            bossContactDps: boss["baseContactDps"] as! Int,
            bossInitialDelay: boss["initialDelay"] as! Int
        )
    }

    private static func parseEnemy(_ value: [String: Any]) -> StandardEnemyStats {
        var pulse: StandardEnemyStats.Pulse?
        if let p = value["pulse"] as? [String: Int] {
            pulse = .init(first: p["first"]!, cooldown: p["cooldown"]!, telegraph: p["telegraph"]!, range: p["range"]!, exposure: p["exposure"]!)
        }
        var charge: StandardEnemyStats.Charge?
        if let c = value["charge"] as? [String: Int] {
            charge = .init(first: c["first"]!, cooldown: c["cooldown"]!, telegraph: c["telegraph"]!, ticks: c["ticks"]!, speed: c["speed"]!, recover: c["recover"]!)
        }
        var shot: StandardEnemyStats.Shot?
        if let s = value["shot"] as? [String: Int] {
            shot = .init(first: s["first"]!, cooldown: s["cooldown"]!, telegraph: s["telegraph"]!, speed: s["speed"]!, radius: s["radius"]!, lifetime: s["lifetime"]!, damage: s["damage"]!)
        }
        var mine: StandardEnemyStats.Mine?
        if let m = value["mine"] as? [String: Int] {
            mine = .init(first: m["first"]!, cooldown: m["cooldown"]!, telegraph: m["telegraph"]!, maximum: m["maximum"]!, arm: m["arm"]!, lifetime: m["lifetime"]!, radius: m["radius"]!, damage: m["damage"]!)
        }
        return StandardEnemyStats(
            hp: value["hp"] as! Int,
            radius: value["radius"] as! Int,
            speed: value["speed"] as! Int,
            contactDps: value["contactDps"] as! Int,
            pulse: pulse,
            charge: charge,
            shot: shot,
            range: value["range"] as? [Int],
            mine: mine
        )
    }

    private static func parseEncounter(_ value: [String: Any]) -> EncounterSpec {
        let wavesRaw = value["waves"] as! [[String: Any]]
        let waves: [WaveSpec] = wavesRaw.map { wave in
            let membersRaw = wave["members"] as! [String: Int]
            let members = membersRaw.keys.sorted().compactMap { key -> WaveMember? in
                guard let id = ArchetypeID(rawValue: key) else { return nil }
                return WaveMember(archetype: id, count: membersRaw[key]!)
            }
            return WaveSpec(
                id: wave["id"] as! String,
                interval: wave["interval"] as! Int,
                delay: wave["delay"] as? Int ?? 0,
                members: members
            )
        }
        return EncounterSpec(
            zone: value["zone"] as! String,
            totals: value["totals"] as! Int,
            activationExposure: value["activationExposure"] as? Int,
            initialDelay: value["initialDelay"] as? Int,
            waves: waves
        )
    }
}
