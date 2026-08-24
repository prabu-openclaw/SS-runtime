import Foundation
import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct AmbientMotionTests {
    @Test func ambientT607CatalogEncodesPersistentRareAndCameraLock() throws {
        let catalog = try AmbientMotionCatalog.bundled()
        let ids = catalog.recipes.map(\.id)
        let camera = try #require(catalog.recipesById["cameraStatus"])
        let parrot = try #require(catalog.recipesById["greenParrotCrossing"])
        let gameplay = catalog.recipes.contains {
            $0.impliesGameplay || $0.salience != "belowGameplay"
        }
        let cameraMoves = camera.translateHousing || camera.rotateHousing || !camera.housingTransformLocked
        let rarePause = catalog.recipes.filter { $0.kind == "rare" }.allSatisfy(\.pausesWhenCaptainTelegraph)
        let persistentCount = catalog.recipes.filter { $0.kind == "persistent" }.count
        let rareCount = catalog.recipes.filter { $0.kind == "rare" }.count
        #expect(catalog.schemaVersion == ContractVersions.ambientMotion)
        #expect(ids == AmbientMotionCatalog.requiredPersistentIds + AmbientMotionCatalog.requiredRareIds)
        #expect(persistentCount == 9)
        #expect(rareCount == 7)
        #expect(catalog.maxConcurrentAmbient == 12)
        #expect(catalog.maxConcurrentRare == 1)
        #expect(!gameplay)
        #expect(!cameraMoves)
        #expect(rarePause)
        #expect(parrot.tier == "p1")
    }

    @Test func ambientUnknownSchemaFailsClosed() throws {
        let json = #"{"schemaVersion":"ambient-motion-000"}"#.data(using: .utf8)!
        do {
            _ = try AmbientMotionLoader.decode(json)
            Issue.record("expected schema failure")
        } catch AmbientMotionError.schemaVersion {
        }
    }

    @Test func ambientGameplayImplicationFailsClosed() throws {
        let json = try mutatedBundled { recipes in
            recipes[0]["impliesCollision"] = true
        }
        do {
            _ = try AmbientMotionLoader.decode(json)
            Issue.record("expected gameplay implication")
        } catch AmbientMotionError.gameplayImplication("fogDrift") {
        }
    }

    @Test func ambientCameraHousingMotionFailsClosed() throws {
        let json = try mutatedBundled { recipes in
            if let index = recipes.firstIndex(where: { ($0["id"] as? String) == "cameraStatus" }) {
                recipes[index]["rotateHousing"] = true
            }
        }
        do {
            _ = try AmbientMotionLoader.decode(json)
            Issue.record("expected camera housing failure")
        } catch AmbientMotionError.cameraHousing("cameraStatus") {
        }
    }

    @Test func ambientRareWithoutTelegraphPauseFailsClosed() throws {
        let json = try mutatedBundled { recipes in
            if let index = recipes.firstIndex(where: { ($0["id"] as? String) == "greenParrotCrossing" }) {
                recipes[index]["pausesWhenCaptainTelegraph"] = false
            }
        }
        do {
            _ = try AmbientMotionLoader.decode(json)
            Issue.record("expected rare telegraph failure")
        } catch AmbientMotionError.rareTelegraph("greenParrotCrossing") {
        }
    }

    @Test func ambientCosmeticStreamIsIsolatedFromCombatAndPlacement() {
        var combat = Xoshiro256StarStar.combat(runSeed: 1)
        var cosmetic = Xoshiro256StarStar.cosmetic(runSeed: 1)
        var placement = Xoshiro256StarStar.cameraPlacement(runSeed: 1)
        let combatDraw = combat.next()
        let cosmeticDraw = cosmetic.next()
        let placementDraw = placement.next()
        var combatAgain = Xoshiro256StarStar.combat(runSeed: 1)
        _ = Xoshiro256StarStar.cosmetic(runSeed: 1)
        var combatControl = Xoshiro256StarStar.combat(runSeed: 1)
        #expect(combatDraw != cosmeticDraw)
        #expect(cosmeticDraw != placementDraw)
        #expect(combatAgain.next() == combatControl.next())
    }

    @Test func ambientScheduleIsSeededDeterministicAndOmitsDigestInputs() throws {
        let catalog = try AmbientMotionCatalog.bundled()
        let query = AmbientMotionQuery(tick: 240, runSeed: 1)
        let first = AmbientMotion.project(query: query, catalog: catalog)
        let second = AmbientMotion.project(query: query, catalog: catalog)
        let ids = first.layers.map(\.recipeId)
        let same = first == second
        let p0 = first.layers.filter { $0.tier == "p0" }.map(\.recipeId)
        let camera = first.layers.first { $0.recipeId == "cameraStatus" }
        let pigeons = first.layers.contains { $0.recipeId == "pigeonsScatter" }
        let cameraLocked = camera?.housingTransformLocked
        let pigeonsPresent = pigeons
        #expect(same)
        #expect(ids == second.layers.map(\.recipeId))
        #expect(p0 == ["fogDrift", "trolleyWireSway", "rooftopFans", "cameraStatus"])
        #expect(cameraLocked == true)
        #expect(pigeonsPresent == false)
    }

    @Test func ambientReducedMotionPausesRareAndSimplifiesPersistent() throws {
        let catalog = try AmbientMotionCatalog.bundled()
        let reduced = AmbientMotion.project(
            query: AmbientMotionQuery(tick: 60, runSeed: 1, reducedMotion: true),
            catalog: catalog
        )
        let rare = reduced.layers.contains { $0.kind == "rare" }
        let fog = reduced.layers.first { $0.recipeId == "fogDrift" }?.language
        #expect(rare == false)
        #expect(fog == "staticFogOpacity")
    }

    @Test func ambientRareDoesNotBeginDuringCaptainTelegraph() throws {
        let catalog = try AmbientMotionCatalog.bundled()
        var foundTick: UInt64?
        var foundSeed: UInt64?
        seedLoop: for seed in UInt64(1)...24 {
            for tick in stride(from: UInt64(0), to: 5400, by: 15) {
                let open = AmbientMotion.project(
                    query: AmbientMotionQuery(tick: tick, runSeed: seed),
                    catalog: catalog
                )
                if open.layers.contains(where: { $0.kind == "rare" }) {
                    foundTick = tick
                    foundSeed = seed
                    break seedLoop
                }
            }
        }
        let tick = try #require(foundTick)
        let seed = try #require(foundSeed)
        let closed = AmbientMotion.project(
            query: AmbientMotionQuery(tick: tick, runSeed: seed, captainTelegraphActive: true),
            catalog: catalog
        )
        let rareWhileTelegraph = closed.layers.contains { $0.kind == "rare" }
        #expect(rareWhileTelegraph == false)
    }

    @Test func ambientBudgetsDropP1P2AndPigeonsNeedCombat() throws {
        let catalog = try AmbientMotionCatalog.bundled()
        let dense = AmbientMotion.project(
            query: AmbientMotionQuery(tick: 90, runSeed: 1, disableP1: true, disableP2: true),
            catalog: catalog
        )
        let withCombat = AmbientMotion.project(
            query: AmbientMotionQuery(tick: 90, runSeed: 1, combatNearby: true),
            catalog: catalog
        )
        let tiers = Set(dense.layers.map(\.tier))
        let pigeons = withCombat.layers.contains { $0.recipeId == "pigeonsScatter" }
        let maxed = dense.layers.count
        #expect(tiers == ["p0"])
        #expect(pigeons)
        #expect(maxed <= catalog.maxConcurrentAmbient)
    }

    private func mutatedBundled(_ mutate: (inout [[String: Any]]) -> Void) throws -> Data {
        var root = try JSONSerialization.jsonObject(with: SpecBundle.contract("ambient-motion-001")) as! [String: Any]
        var recipes = root["recipes"] as! [[String: Any]]
        mutate(&recipes)
        root["recipes"] = recipes
        return try JSONSerialization.data(withJSONObject: root)
    }
}
