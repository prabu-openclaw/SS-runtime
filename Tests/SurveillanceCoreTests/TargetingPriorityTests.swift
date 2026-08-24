import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct TargetingPriorityTests {
    @Test func combatCB002EqualDistanceEnemiesPreferLowerID() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let a = enemy(id: 11, at: VecI(x: 64, y: 0))
        let b = enemy(id: 7, at: VecI(x: 0, y: 64))
        let chosen = Targeting.select(player: player, enemies: [a, b], cameras: [], solids: [])
        let id = chosen?.0.raw
        #expect(id == 7)
    }

    @Test func cameraCD011EqualDistanceCamerasPreferLowerID() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let high = camera(id: 11, anchor: VecI(x: 64, y: 0), detecting: false)
        let low = camera(id: 7, anchor: VecI(x: 0, y: 64), detecting: false)
        let chosen = Targeting.select(player: player, enemies: [], cameras: [high, low], solids: [])
        let id = chosen?.0.raw
        #expect(id == 7)
    }

    @Test func targetingT409CloseEnemyBeatsDetectingCamera() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let close = enemy(id: 20, at: VecI(x: 80, y: 0))
        let detecting = camera(id: 5, anchor: VecI(x: 20, y: 0), detecting: true)
        let chosen = Targeting.select(player: player, enemies: [close], cameras: [detecting], solids: [])
        let id = chosen?.0.raw
        #expect(id == 20)
    }

    @Test func targetingT409DetectingCameraBeatsFarEnemy() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let far = enemy(id: 20, at: VecI(x: 200, y: 0))
        let detecting = camera(id: 5, anchor: VecI(x: 400, y: 0), detecting: true)
        let chosen = Targeting.select(player: player, enemies: [far], cameras: [detecting], solids: [])
        let id = chosen?.0.raw
        #expect(id == 5)
    }

    @Test func targetingT409FarEnemyBeatsOtherCamera() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let far = enemy(id: 20, at: VecI(x: 200, y: 0))
        let other = camera(id: 5, anchor: VecI(x: 40, y: 0), detecting: false)
        let chosen = Targeting.select(player: player, enemies: [far], cameras: [other], solids: [])
        let id = chosen?.0.raw
        #expect(id == 20)
    }

    @Test func targetingT409InclusiveCloseRangeIsNinetySix() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let atRange = enemy(id: 20, at: VecI(x: 96, y: 0))
        let detecting = camera(id: 5, anchor: VecI(x: 10, y: 0), detecting: true)
        let chosenClose = Targeting.select(player: player, enemies: [atRange], cameras: [detecting], solids: [])
        let closeID = chosenClose?.0.raw
        let beyond = enemy(id: 21, at: VecI(x: 97, y: 0))
        let chosenBeyond = Targeting.select(player: player, enemies: [beyond], cameras: [detecting], solids: [])
        let beyondID = chosenBeyond?.0.raw
        #expect(closeID == 20)
        #expect(beyondID == 5)
    }

    @Test func targetingT409DestroyedAndBlockedCamerasAreSkipped() {
        let player = PlayerBody(id: EntityID(1), spawn: VecI(x: 0, y: 0))
        let destroyed = camera(id: 5, anchor: VecI(x: 40, y: 0), detecting: true, integrity: 0)
        let blocked = camera(id: 6, anchor: VecI(x: 200, y: 0), detecting: true)
        let far = enemy(id: 20, at: VecI(x: 0, y: 180))
        let wall = [(id: "wall", box: AABB(center: VecI(x: 100, y: 0), halfSize: VecI(x: 8, y: 40)))]
        let chosen = Targeting.select(
            player: player,
            enemies: [far],
            cameras: [destroyed, blocked],
            solids: wall
        )
        let id = chosen?.0.raw
        #expect(id == 20)
    }
}

private func enemy(id: UInt64, at position: VecI) -> EnemyBody {
    EnemyBody(
        id: EntityID(id),
        archetype: .autonomousInformant,
        position: position.asQ8,
        velocity: .zero,
        integrity: 20,
        radius: 16,
        speedUnitsPerSecond: 0,
        contactDps: 0,
        state: .pursue,
        stateTicks: 0,
        spawnTick: 0,
        nextSpecialTick: 0,
        lockPosition: nil,
        encounterId: "test"
    )
}

private func camera(id: UInt64, anchor: VecI, detecting: Bool, integrity: Int = 3) -> SelectedCamera {
    let q = anchor.asQ8
    return SelectedCamera(
        socketId: "test-\(id)",
        entityId: EntityID(id),
        housingFamily: .municipalDome,
        zoneId: "Z-03",
        position: anchor,
        headingMilliDegrees: 0,
        rangeUnits: 300,
        fieldAngleMilliDegrees: 60_000,
        tutorialEligible: false,
        returnVisible: true,
        integrity: integrity,
        mountCollisionRadius: 12,
        hitRadius: 16,
        fieldOrigin: q,
        targetAnchor: q,
        wasDetecting: detecting,
        incompatibleSocketIds: []
    )
}
