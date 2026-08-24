import Foundation

public struct AmbientRecipe: Equatable, Sendable {
    public var id: String
    public var kind: String
    public var tier: String
    public var language: String
    public var reducedLanguage: String
    public var periodTicks: UInt64
    public var durationTicks: UInt64
    public var chancePercent: Int
    public var housingTransformLocked: Bool
    public var translateHousing: Bool
    public var rotateHousing: Bool
    public var impliesGameplay: Bool
    public var salience: String
    public var requiresCombatNearby: Bool
    public var requiresBeamCrossing: Bool
    public var pausesWhenCaptainTelegraph: Bool
}

public struct AmbientMotionCatalog: Equatable, Sendable {
    public var schemaVersion: String
    public var animationVersion: String
    public var maxConcurrentAmbient: Int
    public var maxConcurrentRare: Int
    public var recipes: [AmbientRecipe]

    public static let requiredPersistentIds = [
        "fogDrift", "trolleyWireSway", "rooftopFans", "cameraStatus", "trafficSignals",
        "pigeonsScatter", "blinds", "windChannels", "transitDisplay"
    ]
    public static let requiredRareIds = [
        "greenParrotCrossing", "autonomousVehicleHesitation", "streetcarShadow",
        "towerLightSync", "phoenixBlink", "occupantBlinds", "fogRevealNetwork"
    ]

    public static func bundled() throws -> AmbientMotionCatalog {
        try AmbientMotionLoader.decode(SpecBundle.contract("ambient-motion-001"))
    }

    public var recipesById: [String: AmbientRecipe] {
        Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    }
}

public enum AmbientMotionError: Equatable, Sendable, Error {
    case invalidJSON
    case schemaVersion
    case missingKey(String)
    case unexpectedKey(String)
    case missingRecipe(String)
    case gameplayImplication(String)
    case cameraHousing(String)
    case salience(String)
    case rareTelegraph(String)
    case budget(String)
}

public struct AmbientMotionQuery: Equatable, Sendable {
    public var tick: UInt64
    public var runSeed: UInt64
    public var reducedMotion: Bool
    public var disableP1: Bool
    public var disableP2: Bool
    public var captainTelegraphActive: Bool
    public var combatNearby: Bool
    public var beamCrossing: Bool

    public init(
        tick: UInt64,
        runSeed: UInt64,
        reducedMotion: Bool = false,
        disableP1: Bool = false,
        disableP2: Bool = false,
        captainTelegraphActive: Bool = false,
        combatNearby: Bool = false,
        beamCrossing: Bool = false
    ) {
        self.tick = tick
        self.runSeed = runSeed
        self.reducedMotion = reducedMotion
        self.disableP1 = disableP1
        self.disableP2 = disableP2
        self.captainTelegraphActive = captainTelegraphActive
        self.combatNearby = combatNearby
        self.beamCrossing = beamCrossing
    }
}

public struct AmbientLayer: Equatable, Sendable {
    public var recipeId: String
    public var kind: String
    public var tier: String
    public var language: String
    public var phase: UInt64
    public var housingTransformLocked: Bool
    public var salience: String
}

public struct AmbientProjection: Equatable, Sendable {
    public var layers: [AmbientLayer]
}

/// Seeded cosmetic scheduler. Uses the COSMET01 stream, never combat/placement RNG,
/// and never writes digest fields (simulation-order.md cosmetic seed exclusion).
public enum AmbientMotion {
    public static func project(
        query: AmbientMotionQuery,
        catalog: AmbientMotionCatalog
    ) -> AmbientProjection {
        var layers: [AmbientLayer] = []
        for recipe in catalog.recipes {
            if recipe.tier == "p1", query.disableP1 { continue }
            if recipe.tier == "p2", query.disableP2 { continue }
            if recipe.requiresCombatNearby, !query.combatNearby { continue }
            if recipe.requiresBeamCrossing, !query.beamCrossing { continue }
            if recipe.kind == "rare" {
                if query.reducedMotion { continue }
                if query.captainTelegraphActive, recipe.pausesWhenCaptainTelegraph { continue }
            }
            guard scheduled(recipe, query: query) else { continue }
            let language = query.reducedMotion ? recipe.reducedLanguage : recipe.language
            if language == "none" { continue }
            layers.append(
                AmbientLayer(
                    recipeId: recipe.id,
                    kind: recipe.kind,
                    tier: recipe.tier,
                    language: language,
                    phase: query.tick % recipe.periodTicks,
                    housingTransformLocked: recipe.housingTransformLocked,
                    salience: recipe.salience
                )
            )
        }
        layers = limitRare(layers, maxRare: catalog.maxConcurrentRare)
        layers = steal(layers, limit: catalog.maxConcurrentAmbient)
        return AmbientProjection(layers: layers)
    }

    private static func scheduled(_ recipe: AmbientRecipe, query: AmbientMotionQuery) -> Bool {
        let window = query.tick / recipe.periodTicks
        let local = query.tick % recipe.periodTicks
        if local >= recipe.durationTicks { return false }
        if recipe.chancePercent >= 100 { return true }
        let roll = SplitMix64.mix(
            query.runSeed
                ^ Xoshiro256StarStar.cosmeticStreamConstant
                ^ fnv(recipe.id)
                ^ window
        )
        return Int(roll % 100) < recipe.chancePercent
    }

    private static func limitRare(_ layers: [AmbientLayer], maxRare: Int) -> [AmbientLayer] {
        var remaining = layers
        var rare = remaining.filter { $0.kind == "rare" }
        while rare.count > maxRare {
            remaining.removeAll { $0.recipeId == rare.last!.recipeId }
            rare.removeLast()
        }
        return remaining
    }

    private static func steal(_ layers: [AmbientLayer], limit: Int) -> [AmbientLayer] {
        var remaining = layers
        while remaining.count > limit {
            let lowest = remaining.map(priority).max()!
            let oldest = remaining
                .enumerated()
                .filter { priority($0.element) == lowest }
                .min { $0.element.recipeId < $1.element.recipeId }!
            remaining.remove(at: oldest.offset)
        }
        return remaining
    }

    private static func priority(_ layer: AmbientLayer) -> Int {
        switch (layer.kind, layer.tier) {
        case ("persistent", "p0"): 1
        case ("persistent", "p1"): 5
        case ("persistent", "p2"): 6
        case ("rare", "p1"): 7
        default: 8
        }
    }

    private static func fnv(_ id: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return hash
    }
}

enum AmbientMotionLoader {
    private static let catalogKeys: Set<String> = [
        "schemaVersion", "animationVersion", "maxConcurrentAmbient", "maxConcurrentRare", "recipes"
    ]
    private static let recipeKeys: Set<String> = [
        "id", "kind", "tier", "language", "reducedLanguage", "periodTicks", "durationTicks",
        "chancePercent", "housingTransformLocked", "translateHousing", "rotateHousing",
        "impliesGameplay", "impliesCollision", "impliesReward", "impliesEnemy", "impliesObjective",
        "salience", "requiresCombatNearby", "requiresBeamCrossing", "pausesWhenCaptainTelegraph"
    ]

    static func decode(_ data: Data) throws -> AmbientMotionCatalog {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AmbientMotionError.invalidJSON
        }
        if let unexpected = Set(root.keys).subtracting(catalogKeys).sorted().first {
            throw AmbientMotionError.unexpectedKey(unexpected)
        }
        guard root["schemaVersion"] as? String == "ambient-motion-001" else {
            throw AmbientMotionError.schemaVersion
        }
        guard root["animationVersion"] as? String == "animation-civic-seam-001" else {
            throw AmbientMotionError.schemaVersion
        }
        guard let maxAmbient = intValue(root["maxConcurrentAmbient"]),
              let maxRare = intValue(root["maxConcurrentRare"]),
              let rawRecipes = root["recipes"] as? [[String: Any]],
              !rawRecipes.isEmpty
        else {
            throw AmbientMotionError.invalidJSON
        }
        if maxAmbient < 1 || maxRare < 1 || maxAmbient < AmbientMotionCatalog.requiredPersistentIds.count {
            throw AmbientMotionError.budget("maxConcurrentAmbient")
        }
        var recipes: [AmbientRecipe] = []
        var seen = Set<String>()
        for raw in rawRecipes {
            let recipe = try decodeRecipe(raw)
            if !seen.insert(recipe.id).inserted {
                throw AmbientMotionError.missingRecipe(recipe.id)
            }
            recipes.append(recipe)
        }
        let byId = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        for required in AmbientMotionCatalog.requiredPersistentIds + AmbientMotionCatalog.requiredRareIds {
            guard byId[required] != nil else {
                throw AmbientMotionError.missingRecipe(required)
            }
        }
        return AmbientMotionCatalog(
            schemaVersion: "ambient-motion-001",
            animationVersion: "animation-civic-seam-001",
            maxConcurrentAmbient: maxAmbient,
            maxConcurrentRare: maxRare,
            recipes: recipes
        )
    }

    private static func decodeRecipe(_ raw: [String: Any]) throws -> AmbientRecipe {
        if let extra = Set(raw.keys).subtracting(recipeKeys).sorted().first {
            throw AmbientMotionError.unexpectedKey(extra)
        }
        for key in recipeKeys {
            guard raw[key] != nil else { throw AmbientMotionError.missingKey(key) }
        }
        guard let id = raw["id"] as? String, !id.isEmpty,
              let kind = raw["kind"] as? String, kind == "persistent" || kind == "rare",
              let tier = raw["tier"] as? String, tier == "p0" || tier == "p1" || tier == "p2",
              let language = raw["language"] as? String, !language.isEmpty,
              let reduced = raw["reducedLanguage"] as? String, !reduced.isEmpty,
              let period = uintValue(raw["periodTicks"]), period > 0,
              let duration = uintValue(raw["durationTicks"]), duration > 0, duration <= period,
              let chance = intValue(raw["chancePercent"]), chance >= 0, chance <= 100,
              let housingLocked = raw["housingTransformLocked"] as? Bool,
              let translate = raw["translateHousing"] as? Bool,
              let rotate = raw["rotateHousing"] as? Bool,
              let impliesGameplay = raw["impliesGameplay"] as? Bool,
              let impliesCollision = raw["impliesCollision"] as? Bool,
              let impliesReward = raw["impliesReward"] as? Bool,
              let impliesEnemy = raw["impliesEnemy"] as? Bool,
              let impliesObjective = raw["impliesObjective"] as? Bool,
              let salience = raw["salience"] as? String,
              let combat = raw["requiresCombatNearby"] as? Bool,
              let beam = raw["requiresBeamCrossing"] as? Bool,
              let pauses = raw["pausesWhenCaptainTelegraph"] as? Bool
        else {
            throw AmbientMotionError.invalidJSON
        }
        if impliesGameplay || impliesCollision || impliesReward || impliesEnemy || impliesObjective {
            throw AmbientMotionError.gameplayImplication(id)
        }
        if salience != "belowGameplay" {
            throw AmbientMotionError.salience(id)
        }
        if id == "cameraStatus", !housingLocked || translate || rotate {
            throw AmbientMotionError.cameraHousing(id)
        }
        if kind == "rare", !pauses {
            throw AmbientMotionError.rareTelegraph(id)
        }
        return AmbientRecipe(
            id: id,
            kind: kind,
            tier: tier,
            language: language,
            reducedLanguage: reduced,
            periodTicks: period,
            durationTicks: duration,
            chancePercent: chance,
            housingTransformLocked: housingLocked,
            translateHousing: translate,
            rotateHousing: rotate,
            impliesGameplay: impliesGameplay,
            salience: salience,
            requiresCombatNearby: combat,
            requiresBeamCrossing: beam,
            pausesWhenCaptainTelegraph: pauses
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func uintValue(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 { return value }
        if let value = value as? Int, value >= 0 { return UInt64(value) }
        if let value = value as? NSNumber, value.intValue >= 0 { return value.uint64Value }
        return nil
    }
}
