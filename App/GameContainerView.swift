import SpriteKit
import SwiftUI
import SurveillanceCore

struct GameContainerView: View {
    private let scene: SKScene = {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .ignoresSafeArea()
            .accessibilityLabel("Surveillance Survivor gameplay")
    }
}
