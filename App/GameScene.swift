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
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private var stickOrigin: CGPoint?

    override func didMove(to view: SKView) {
        backgroundColor = .init(red: 0.055, green: 0.075, blue: 0.10, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        size = CGSize(width: CGFloat(PresentationCamera.visibleWidth), height: CGFloat(PresentationCamera.visibleHeight))
        scaleMode = .aspectFit
        addChild(worldNode)
        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(hudNode)
        redraw()
    }

    override func update(_ currentTime: TimeInterval) {
        session.step()
        redraw()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
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
        worldNode.removeAllChildren()
        hudNode.removeAllChildren()
        let snap = session.snapshot
        cameraNode.position = CGPoint(x: snap.camera.center.x, y: snap.camera.center.y)

        for solid in snap.solids {
            let node = SKShapeNode(rectOf: CGSize(width: CGFloat(solid.halfSize.x * 2), height: CGFloat(solid.halfSize.y * 2)))
            node.position = CGPoint(x: solid.center.x, y: solid.center.y)
            node.fillColor = SKColor(white: 0.18, alpha: 1)
            node.strokeColor = SKColor(white: 0.32, alpha: 1)
            node.lineWidth = 2
            worldNode.addChild(node)
        }
        for camera in snap.cameras {
            let body = SKShapeNode(circleOfRadius: 12)
            body.position = CGPoint(x: camera.x, y: camera.y)
            body.fillColor = Self.cameraFill(camera.presentationState)
            body.strokeColor = .clear
            worldNode.addChild(body)
            if camera.fieldVisible {
                let path = CGMutablePath()
                path.move(to: .zero)
                let half = CGFloat(camera.fieldAngleMilli) / 2000 * .pi / 180
                let heading = CGFloat(camera.headingMilli) / 1000 * .pi / 180
                path.addArc(center: .zero, radius: CGFloat(camera.range), startAngle: -heading - half, endAngle: -heading + half, clockwise: false)
                path.closeSubpath()
                let field = SKShapeNode(path: path)
                field.position = body.position
                field.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: camera.detecting ? 0.28 : 0.12)
                field.strokeColor = .clear
                worldNode.addChild(field)
            }
        }
        let extract = SKShapeNode(rectOf: CGSize(width: CGFloat(snap.extraction.halfSize.x * 2), height: CGFloat(snap.extraction.halfSize.y * 2)))
        extract.position = CGPoint(x: snap.extraction.center.x, y: snap.extraction.center.y)
        extract.fillColor = SKColor(red: 0.2, green: 0.45, blue: 0.35, alpha: snap.extractionArmed ? 0.35 : 0.12)
        extract.strokeColor = SKColor(white: 0.7, alpha: 0.6)
        worldNode.addChild(extract)

        let player = SKShapeNode(path: Self.silhouettePath(.playerRing, at: CGPoint(x: snap.player.x, y: snap.player.y)))
        player.fillColor = SKColor(white: 0.92, alpha: 1)
        player.strokeColor = SKColor(white: 1, alpha: 0.7)
        player.lineWidth = 2
        worldNode.addChild(player)
        for enemy in snap.enemies {
            let node = SKShapeNode(path: Self.silhouettePath(enemy.silhouette, at: CGPoint(x: enemy.x, y: enemy.y)))
            node.fillColor = SKColor(white: 0.55, alpha: 1)
            node.strokeColor = SKColor(white: 0.75, alpha: 0.8)
            node.lineWidth = 1
            worldNode.addChild(node)
        }
        for marker in snap.queryMarkers {
            let ring = SKShapeNode(circleOfRadius: CGFloat(marker.radius))
            ring.position = CGPoint(x: marker.x, y: marker.y)
            ring.fillColor = .clear
            ring.strokeColor = SKColor(white: 0.8, alpha: 0.7)
            ring.lineWidth = 2
            worldNode.addChild(ring)
        }
        if let field = snap.captainField {
            let path = CGMutablePath()
            path.move(to: .zero)
            let half = CGFloat(field.fieldAngleMilli) / 2000 * .pi / 180
            let heading = CGFloat(field.headingMilli) / 1000 * .pi / 180
            path.addArc(center: .zero, radius: CGFloat(field.range), startAngle: -heading - half, endAngle: -heading + half, clockwise: false)
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.position = CGPoint(x: field.x, y: field.y)
            node.fillColor = SKColor(white: 0.75, alpha: 0.18)
            node.strokeColor = .clear
            worldNode.addChild(node)
        }
        for socket in snap.spawnSockets {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.position = CGPoint(x: socket.x, y: socket.y)
            dot.fillColor = SKColor(white: 0.45, alpha: 0.5)
            dot.strokeColor = .clear
            worldNode.addChild(dot)
        }
        drawHUD(snap)
    }

    private func drawHUD(_ snap: PresentationSnapshot) {
        func bar(_ rect: HUDRect, color: SKColor) {
            let node = SKShapeNode(rectOf: CGSize(width: CGFloat(rect.width), height: CGFloat(rect.height)))
            node.fillColor = color
            node.strokeColor = SKColor(white: 0.8, alpha: 0.5)
            node.position = CGPoint(
                x: CGFloat(rect.x) - CGFloat(HUDLayout.referenceWidth) / 2,
                y: CGFloat(HUDLayout.referenceHeight) / 2 - CGFloat(rect.y)
            )
            hudNode.addChild(node)
        }
        bar(HUDLayout.playerIntegrity(), color: SKColor(white: 0.85, alpha: 0.8))
        bar(HUDLayout.exposureBar(), color: SKColor(white: 0.55, alpha: 0.8))
        bar(HUDLayout.stick(handedness: snap.handedness), color: SKColor(white: 0.4, alpha: 0.35))
        bar(HUDLayout.dodge(handedness: snap.handedness), color: SKColor(white: 0.5, alpha: 0.35))
        bar(HUDLayout.pause(), color: SKColor(white: 0.6, alpha: 0.4))

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
            ring.fontName = "Menlo-Bold"
            ring.fontSize = 18
            ring.fontColor = SKColor(white: 0.9, alpha: 1)
            ring.position = CGPoint(x: 0, y: 40)
            hudNode.addChild(ring)
        }
    }

    private static func cameraFill(_ state: CameraPresentationState) -> SKColor {
        switch state {
        case .operational:
            return SKColor(white: 0.78, alpha: 1)
        case .damaged, .hit:
            return SKColor(white: 0.55, alpha: 1)
        case .critical:
            return SKColor(white: 0.38, alpha: 1)
        case .destroying, .fieldOff, .destroyed, .dormant:
            return SKColor(white: 0.18, alpha: 1)
        }
    }

    private static func silhouettePath(_ silhouette: ActorSilhouette, at origin: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let points = silhouette.contour
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: origin.x + CGFloat(first.x), y: origin.y + CGFloat(first.y)))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: origin.x + CGFloat(point.x), y: origin.y + CGFloat(point.y)))
        }
        path.closeSubpath()
        return path
    }
}
