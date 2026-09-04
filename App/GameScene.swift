import SpriteKit
import SurveillanceCore
import UIKit

final class GameSession {
    private(set) var simulation: Simulation
    private var cameraHUD = CameraHUDProjector()
    private(set) var cameraHUDProjection = CameraHUDProjection(
        notchesVisible: false,
        notchFilled: [false, false, false],
        tamperVisible: false,
        tamperCopy: ""
    )
    private(set) var terminalReceiptStored = false
    var moveX: Int16 = 0
    var moveY: Int16 = 0
    var dodgePressed = false
    var pendingUpgradeChoice: UInt8?

    init(seed: UInt64 = 1) {
        simulation = try! Simulation.make(seed: seed)
    }

    func step() {
        let tick = simulation.state.tick + 1
        let result: TickResult
        if simulation.state.upgrade.pending {
            if let choice = pendingUpgradeChoice {
                result = simulation.step(
                    command: PlayerCommand(
                        tick: tick,
                        moveX: 0,
                        moveY: 0,
                        dodgePressed: false,
                        upgradeChoiceIndex: choice
                    )
                )
                pendingUpgradeChoice = nil
            } else {
                result = simulation.step(command: nil)
            }
        } else {
            result = simulation.step(
                command: PlayerCommand(
                    tick: tick,
                    moveX: moveX,
                    moveY: moveY,
                    dodgePressed: dodgePressed
                )
            )
        }
        applyCameraHUD(result)
        persistTerminalReceiptIfNeeded()
    }

    private func persistTerminalReceiptIfNeeded() {
        guard !terminalReceiptStored, simulation.state.outcome != .playing else { return }
        if (try? ReceiptStore.persistTerminalReceipt(for: simulation.state)) != nil {
            terminalReceiptStored = true
        }
    }

    func restartRun(seed: UInt64 = 1) {
        simulation = try! Simulation.make(seed: seed)
        terminalReceiptStored = false
        pendingUpgradeChoice = nil
        moveX = 0
        moveY = 0
        dodgePressed = false
    }

    private func applyCameraHUD(_ result: TickResult) {
        let state = simulation.state
        let selected = Targeting.select(
            player: state.player,
            enemies: state.enemies,
            cameras: state.cameras,
            solids: state.liveSolids
        )
        var query = CameraHUDQuery.none
        if let selected, let camera = state.cameras.first(where: { $0.entityId == selected.0 }) {
            query = CameraHUDQuery(
                targetIntegrity: camera.integrity,
                damageable: camera.isDamageable,
                targeted: true,
                inRange: true,
                damaged: camera.integrity < 3
            )
        }
        cameraHUDProjection = cameraHUD.project(tick: result.tick, events: result.events, query: query)
    }

    var snapshot: PresentationSnapshot {
        PresentationSnapshot(simulation.state)
    }
}

final class GameScene: SKScene {
    private let session = GameSession()
    private let instrumentation = RunInstrumentation()
    private let deviceRunTracker = DeviceRunTracker()
    private var terminalEvidenceStored = false
    private let renderer = WorldRenderer()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private var stickOrigin: CGPoint?
#if DEBUG
    private var autopilot: DebugAutopilot?
#endif

    override func didMove(to view: SKView) {
        backgroundColor = .init(red: 0.055, green: 0.075, blue: 0.10, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        size = CGSize(width: CGFloat(PresentationCamera.visibleWidth), height: CGFloat(PresentationCamera.visibleHeight))
        scaleMode = .aspectFit
        addChild(renderer.root)
        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(hudNode)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.instrumentation.noteMemoryWarning()
        }
#if DEBUG
        autopilot = DebugAutopilot.fromLaunchArguments(
            ProcessInfo.processInfo.arguments,
            arena: session.simulation.state.arena
        )
#endif
        redraw()
    }

    override func update(_ currentTime: TimeInterval) {
        instrumentation.frameTimes.recordFrame(timestamp: currentTime)
#if DEBUG
        if autopilot != nil {
            let snapshot = session.snapshot
            let steer = autopilot!.command(from: VecI(x: snapshot.player.x, y: snapshot.player.y))
            session.moveX = steer.moveX
            session.moveY = steer.moveY
            if snapshot.tick % 60 == 0 {
                print("""
                    SSAUTOPILOT tick=\(snapshot.tick)                     player=\(snapshot.player.x),\(snapshot.player.y)                     hp=\(snapshot.playerIntegrity) exposure=\(snapshot.exposure)                     enemies=\(snapshot.enemies.count) shots=\(snapshot.projectiles.count)                     telegraphs=\(snapshot.telegraphs.count) boss=\(snapshot.boss?.integrity ?? -1)                     objective=\(snapshot.combatObjectiveCopy)
                    """)
            }
        }
#endif
        session.step()
        instrumentation.recordSimulation(session.simulation.state)
        persistDeviceEvidenceIfNeeded()
        redraw()
    }

    private func persistDeviceEvidenceIfNeeded() {
        guard !terminalEvidenceStored, session.simulation.state.outcome != .playing else { return }
        terminalEvidenceStored = true
        deviceRunTracker.noteTerminalOutcome(session.simulation.state.outcome)
        let snapshot = instrumentation.evidence()
        let deviceEvidence = snapshot.makeDeviceRunEvidence(
            deviceClass: "iPhone 12",
            consecutiveCompleteRuns: deviceRunTracker.consecutiveCompleteRuns,
            atlasMemoryBytes: nil
        )
        _ = try? ReleaseEvidenceStore.exportDeviceRunEvidence(deviceEvidence)
        if deviceRunTracker.consecutiveCompleteRuns >= 3,
           let simulationCeilings = try? D021CeilingEvaluator.profileAndMeasure(),
           let settled = deviceEvidence.settledD021Ceilings(from: simulationCeilings) {
            _ = try? ReleaseEvidenceStore.exportReleaseCandidateWithBundledPlaytests(
                deviceEvidence: [deviceEvidence],
                d021DeviceProfiling: settled
            )
        }
    }

    func restartRun(seed: UInt64? = nil) {
        let nextSeed = seed ?? session.simulation.state.seed
        session.restartRun(seed: nextSeed)
        renderer.reset()
        instrumentation.reset()
        terminalEvidenceStored = false
        redraw()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if session.snapshot.outcome != .playing {
            restartRun()
            return
        }
        stickOrigin = touch.location(in: self)
        let local = touch.location(in: hudNode)
        if session.snapshot.upgradePending {
            if local.x < 0 { session.pendingUpgradeChoice = 0 }
            else if local.x < 80 { session.pendingUpgradeChoice = 1 }
            else { session.pendingUpgradeChoice = 2 }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let origin = stickOrigin, let touch = touches.first else { return }
        let point = touch.location(in: self)
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let mag = hypot(dx, dy)
        let dead = 24.0
        if mag <= dead {
            session.moveX = 0
            session.moveY = 0
            return
        }
        let nx = dx / mag
        let ny = dy / mag
        let scaled = min(1, (mag - dead) / 120)
        session.moveX = Int16((nx * scaled * 32767).rounded(.toNearestOrAwayFromZero))
        session.moveY = Int16((ny * scaled * 32767).rounded(.toNearestOrAwayFromZero))
        session.dodgePressed = mag > 160
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        session.moveX = 0
        session.moveY = 0
        session.dodgePressed = false
        stickOrigin = nil
    }

    private func redraw() {
        let snap = session.snapshot
        cameraNode.position = CGPoint(x: snap.camera.center.x, y: snap.camera.center.y)
        renderer.render(snap)
        hudNode.removeAllChildren()
        drawHUD(snap)
    }

    private func drawHUD(_ snap: PresentationSnapshot) {
        func bar(_ rect: HUDRect, assetId: String, color: SKColor) {
            let node = SKShapeNode(rectOf: CGSize(width: CGFloat(rect.width), height: CGFloat(rect.height)))
            node.name = assetId
            node.fillColor = color
            node.strokeColor = SKColor(white: 0.8, alpha: 0.5)
            node.position = CGPoint(
                x: CGFloat(rect.x) - CGFloat(HUDLayout.referenceWidth) / 2,
                y: CGFloat(HUDLayout.referenceHeight) / 2 - CGFloat(rect.y)
            )
            hudNode.addChild(node)
        }
        bar(HUDLayout.playerIntegrity(), assetId: RuntimeAssetRegistry.HUD.integrityFrame, color: SKColor(white: 0.85, alpha: 0.8))
        bar(HUDLayout.exposureBar(), assetId: RuntimeAssetRegistry.HUD.exposureBar, color: SKColor(white: 0.55, alpha: 0.8))
        bar(HUDLayout.stick(handedness: snap.handedness), assetId: RuntimeAssetRegistry.HUD.stickBase, color: SKColor(white: 0.4, alpha: 0.35))
        bar(HUDLayout.dodge(handedness: snap.handedness), assetId: RuntimeAssetRegistry.HUD.dodge, color: SKColor(white: 0.5, alpha: 0.35))
        bar(HUDLayout.pause(), assetId: RuntimeAssetRegistry.HUD.pause, color: SKColor(white: 0.6, alpha: 0.4))

        // hud-tutorial-001: boss bar only while the boss is active.
        if let boss = snap.boss {
            let rect = HUDLayout.bossIntegrity()
            let origin = CGPoint(
                x: CGFloat(rect.x) - CGFloat(HUDLayout.referenceWidth) / 2,
                y: CGFloat(HUDLayout.referenceHeight) / 2 - CGFloat(rect.y)
            )
            let frame = SKShapeNode(rectOf: CGSize(width: CGFloat(rect.width), height: CGFloat(rect.height)))
            frame.name = "boss_integrity_frame"
            frame.fillColor = .clear
            frame.strokeColor = SKColor(white: 0.8, alpha: 0.7)
            frame.position = origin
            hudNode.addChild(frame)

            let ratio = boss.maxIntegrity > 0
                ? max(0, min(1, CGFloat(boss.integrity) / CGFloat(boss.maxIntegrity)))
                : 0
            let fillWidth = CGFloat(rect.width) * ratio
            if fillWidth > 0 {
                let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: CGFloat(rect.height) - 4))
                fill.fillColor = SKColor(white: boss.inTransition ? 0.55 : 0.85, alpha: 0.9)
                fill.strokeColor = .clear
                // Drain from the right by keeping the left edge pinned.
                fill.position = CGPoint(x: origin.x - (CGFloat(rect.width) - fillWidth) / 2, y: origin.y)
                hudNode.addChild(fill)
            }

            let phase = SKLabelNode(text: boss.phase.rawValue.uppercased())
            phase.fontName = "Menlo-Bold"
            phase.fontSize = 9
            phase.fontColor = SKColor(white: 0.9, alpha: 1)
            phase.position = CGPoint(x: origin.x, y: origin.y - CGFloat(rect.height))
            hudNode.addChild(phase)
        }

        var hudText = "HP \(snap.playerIntegrity)  EXP \(snap.exposure) \(snap.detection.rawValue.uppercased())"
        hudText += "  \(snap.combatObjectiveCopy)"
        if snap.cameraObjectiveVisible {
            hudText += "  \(snap.cameraObjectiveCopy)"
        }
        if session.cameraHUDProjection.notchesVisible {
            let marks = session.cameraHUDProjection.notchFilled.map { $0 ? "|" : "." }.joined()
            hudText += "  CAM[\(marks)]"
        }
        if session.cameraHUDProjection.tamperVisible {
            hudText += "  \(session.cameraHUDProjection.tamperCopy)"
        }
        let hud = SKLabelNode(text: hudText)
        hud.fontName = "Menlo-Bold"
        hud.fontSize = 10
        hud.fontColor = SKColor(white: 0.95, alpha: 1)
        hud.position = CGPoint(x: 0, y: CGFloat(HUDLayout.referenceHeight) / 2 - 20)
        hudNode.addChild(hud)

        if let copy = snap.tutorialCopy {
            let tutorial = SKLabelNode(text: copy)
            tutorial.fontName = "Menlo-Bold"
            tutorial.fontSize = 12
            tutorial.fontColor = SKColor(white: 0.95, alpha: 1)
            tutorial.position = CGPoint(x: 0, y: -CGFloat(HUDLayout.referenceHeight) / 2 + 40)
            hudNode.addChild(tutorial)
        }
        if snap.extractionArmed {
            let ring = SKLabelNode(text: "\(snap.extractionSeconds)")
            ring.name = RuntimeAssetRegistry.HUD.extractionRing
            ring.fontName = "Menlo-Bold"
            ring.fontSize = 18
            ring.fontColor = SKColor(white: 0.9, alpha: 1)
            ring.position = CGPoint(x: 0, y: 40)
            hudNode.addChild(ring)
        }
        if snap.upgradePending {
            drawUpgradeSelection()
        }
    }

    private func drawUpgradeSelection() {
        let cards = UpgradePresentation.selectionCards()
        let startX = -CGFloat(HUDLayout.referenceWidth) / 2 + 40
        for (index, card) in cards.enumerated() {
            let x = startX + CGFloat(index) * 120
            let backdrop = SKShapeNode(rectOf: CGSize(width: 110, height: 72), cornerRadius: 8)
            backdrop.name = "upgrade_card_\(card.upgrade.rawValue)"
            backdrop.fillColor = SKColor(white: 0.2, alpha: 0.85)
            backdrop.strokeColor = SKColor(white: 0.7, alpha: 0.8)
            backdrop.position = CGPoint(x: x, y: -CGFloat(HUDLayout.referenceHeight) / 2 + 96)
            backdrop.accessibilityLabel = card.voiceOverLabel
            hudNode.addChild(backdrop)

            let title = SKLabelNode(text: card.name)
            title.fontName = "Menlo-Bold"
            title.fontSize = 10
            title.fontColor = SKColor(white: 0.95, alpha: 1)
            title.position = CGPoint(x: x, y: backdrop.position.y + 16)
            hudNode.addChild(title)

            let summary = SKLabelNode(text: card.role)
            summary.fontName = "Menlo"
            summary.fontSize = 8
            summary.fontColor = SKColor(white: 0.8, alpha: 1)
            summary.position = CGPoint(x: x, y: backdrop.position.y - 4)
            hudNode.addChild(summary)
        }
    }


}
