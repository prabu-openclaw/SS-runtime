import SpriteKit
import SurveillanceCore
import UIKit

final class GameSession {
    private(set) var simulation: Simulation
    var moveX: Int16 = 0
    var moveY: Int16 = 0
    var dodgePressed = false

    init(seed: UInt64 = 1) {
        simulation = try! Simulation.make(seed: seed)
    }

    func step() {
        let tick = simulation.state.tick + 1
        if simulation.state.upgrade.pending {
            if let choice = pendingUpgradeChoice {
                _ = simulation.step(
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
                _ = simulation.step(command: nil)
            }
            return
        }
        _ = simulation.step(
            command: PlayerCommand(
                tick: tick,
                moveX: moveX,
                moveY: moveY,
                dodgePressed: dodgePressed
            )
        )
    }

    var pendingUpgradeChoice: UInt8?

    var snapshot: PresentationSnapshot {
        PresentationSnapshot(simulation.state)
    }
}

final class GameScene: SKScene {
    private let session = GameSession()
    private var worldNode = SKNode()
    private var stickOrigin: CGPoint?

    override func didMove(to view: SKView) {
        backgroundColor = .init(red: 0.055, green: 0.075, blue: 0.10, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        size = CGSize(width: 2304, height: 1536)
        scaleMode = .aspectFit
        addChild(worldNode)
        redraw()
    }

    override func update(_ currentTime: TimeInterval) {
        session.step()
        redraw()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        stickOrigin = touch.location(in: self)
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
        let snap = session.snapshot
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
            body.fillColor = camera.integrity == 0 ? SKColor(white: 0.2, alpha: 1) : SKColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1)
            body.strokeColor = .clear
            worldNode.addChild(body)
            if camera.integrity > 0 {
                let path = CGMutablePath()
                path.move(to: .zero)
                let half = CGFloat(camera.fieldAngleMilli) / 2000
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

        let hud = SKLabelNode(text: "TICK \(snap.tick)  HP \(snap.playerIntegrity)  EXP \(snap.exposure) \(snap.detection.rawValue.uppercased())  CAM \(snap.camerasDestroyed)/8")
        hud.fontName = "Menlo-Bold"
        hud.fontSize = 28
        hud.fontColor = SKColor(white: 0.9, alpha: 1)
        hud.horizontalAlignmentMode = .left
        hud.position = CGPoint(x: 24, y: 1480)
        worldNode.addChild(hud)
        if snap.upgradePending {
            let upgrade = SKLabelNode(text: "CHOOSE ONE COUNTERMEASURE")
            upgrade.fontName = "Menlo-Bold"
            upgrade.fontSize = 32
            upgrade.fontColor = SKColor(white: 0.95, alpha: 1)
            upgrade.position = CGPoint(x: 1152, y: 768)
            worldNode.addChild(upgrade)
        }
        player.position = CGPoint(x: snap.player.x, y: snap.player.y)
        player.fillColor = SKColor(white: 0.92, alpha: 1)
        player.strokeColor = .clear
        worldNode.addChild(player)
        for enemy in snap.enemies {
            let node = SKShapeNode(circleOfRadius: CGFloat(enemy.radius))
            node.position = CGPoint(x: enemy.x, y: enemy.y)
            node.fillColor = SKColor(white: 0.55, alpha: 1)
            node.strokeColor = .clear
            worldNode.addChild(node)
        }
    }
}
