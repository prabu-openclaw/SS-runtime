/// Immutable presentation projection of authoritative state. Does not own rules.
public struct PresentationSnapshot: Equatable, Sendable {
    public struct CircleSprite: Equatable, Sendable {
        public var id: EntityID
        public var x: Int
        public var y: Int
        public var radius: Int
        public var role: String
        public var silhouette: ActorSilhouette
    }

    public struct CameraSprite: Equatable, Sendable {
        public var id: EntityID
        public var x: Int
        public var y: Int
        public var headingMilli: Int
        public var range: Int
        public var fieldAngleMilli: Int
        public var integrity: Int
        public var detecting: Bool
        public var presentationState: CameraPresentationState
        public var fieldVisible: Bool
        public var clipId: String
    }

    public var tick: UInt64
    public var outcome: RunOutcome
    public var player: CircleSprite
    public var playerIntegrity: Int
    public var exposure: Int
    public var detection: DetectionState
    public var solids: [AABB]
    public var cameras: [CameraSprite]
    public var enemies: [CircleSprite]
    public var extraction: AABB
    public var extractionArmed: Bool
    public var extractionRemaining: Int
    public var combatObjectiveCopy: String
    public var camerasDestroyed: Int
    public var cameraObjectiveVisible: Bool
    public var cameraObjectiveCopy: String
    public var networkBlackout: Bool
    public var upgrade: UpgradeID?
    public var upgradePending: Bool
    public var tutorialCopy: String?
    public var camera: PresentationCamera
    public var handedness: Handedness
    public var extractionSeconds: Int
    public var queryMarkers: [CircleSprite]
    public var captainField: CameraSprite?
    public var spawnSockets: [VecI]
    public var debugSolids: [AABB]

    public init(_ state: WorldState) {
        tick = state.tick
        outcome = state.outcome
        player = CircleSprite(
            id: state.player.id,
            x: state.player.position.x.unitsTruncated,
            y: state.player.position.y.unitsTruncated,
            radius: PlayerBody.radiusUnits,
            role: "player",
            silhouette: .playerRing
        )
        playerIntegrity = state.player.integrity
        exposure = state.exposure.exposure
        detection = state.exposure.detectionState
        solids = state.liveSolids.map(\.box)
        cameras = state.cameras.map {
            let presentationState = CameraPresentation.persistentState(integrity: $0.integrity)
            return CameraSprite(
                id: $0.entityId,
                x: $0.position.x,
                y: $0.position.y,
                headingMilli: $0.headingMilliDegrees,
                range: $0.rangeUnits,
                fieldAngleMilli: $0.fieldAngleMilliDegrees,
                integrity: $0.integrity,
                detecting: $0.wasDetecting,
                presentationState: presentationState,
                fieldVisible: $0.integrity > 0,
                clipId: CameraPresentation.clipId(for: presentationState)
            )
        }
        enemies = state.enemies.filter(\.alive).map {
            CircleSprite(
                id: $0.id,
                x: $0.position.x.unitsTruncated,
                y: $0.position.y.unitsTruncated,
                radius: $0.radius,
                role: $0.archetype.rawValue,
                silhouette: ActorSilhouette.enemy($0.archetype)
            )
        }
        extraction = state.arena.extraction.aabb
        extractionArmed = state.extraction.armed
        extractionRemaining = state.extraction.remaining
        let authority = CombatAuthoritySnapshot.project(state)
        let playerPoint = VecI(
            x: state.player.position.x.unitsTruncated,
            y: state.player.position.y.unitsTruncated
        )
        let insideExtraction = state.arena.extraction.aabb.contains(playerPoint)
        combatObjectiveCopy = HUDLayout.combatObjectiveCopy(
            node: authority.currentNode,
            extractionArmed: state.extraction.armed,
            insideLockedExtraction: insideExtraction && !state.extraction.armed
        )
        camerasDestroyed = state.destructions.count
        let damaged = camerasDestroyed > 0 || state.cameras.contains { $0.integrity < 3 }
        cameraObjectiveVisible = HUDLayout.cameraObjectiveVisible(
            destroyed: camerasDestroyed,
            damaged: damaged
        )
        networkBlackout = state.networkBlackout
        cameraObjectiveCopy = HUDLayout.cameraObjectiveCopy(
            destroyed: camerasDestroyed,
            complete: state.networkBlackout
        )
        upgrade = state.upgrade.selected
        upgradePending = state.upgrade.pending
        tutorialCopy = state.tutorial.copy.isEmpty ? nil : state.tutorial.copy
        camera = PresentationCamera.follow(
            player: VecI(x: state.player.position.x.unitsTruncated, y: state.player.position.y.unitsTruncated),
            heading: state.player.facing,
            bounds: state.arena.boundsUnits
        )
        handedness = state.handedness
        extractionSeconds = HUDLayout.extractionSeconds(state.extraction.remaining)
        queryMarkers = state.enemies.flatMap { enemy -> [CircleSprite] in
            guard enemy.archetype == .improperSearchDaemon,
                  enemy.state == .queryTelegraph || enemy.state == .queryResolve
            else { return [] }
            return enemy.queryMarkers.map { center in
                CircleSprite(
                    id: enemy.id,
                    x: center.x.unitsTruncated,
                    y: center.y.unitsTruncated,
                    radius: DaemonQuery.circleRadius,
                    role: "daemonQuery",
                    silhouette: .queryApertures
                )
            }
        }
        if let emitter = state.bossRuntime?.activeEmitter, (state.bossRuntime?.fieldRemaining ?? 0) > 0 {
            captainField = CameraSprite(
                id: EntityID(0),
                x: emitter.x,
                y: emitter.y,
                headingMilli: emitter.headingMilliDegrees,
                range: emitter.rangeUnits,
                fieldAngleMilli: emitter.fieldAngleMilliDegrees,
                integrity: 1,
                detecting: true,
                presentationState: .critical,
                fieldVisible: true,
                clipId: CameraPresentation.clipId(for: .critical)
            )
        } else {
            captainField = nil
        }
        spawnSockets = state.arena.enemySpawnSockets.values.flatMap { sockets in
            sockets.map { VecI(x: $0.x, y: $0.y) }
        } + [
            VecI(x: state.arena.eliteSpawn.x, y: state.arena.eliteSpawn.y),
            VecI(x: state.arena.bossSpawn.x, y: state.arena.bossSpawn.y)
        ]
        debugSolids = solids
    }
}
