import SpriteKit
import SurveillanceCore

/// Loads admitted clip frames as SpriteKit textures, and says plainly when a
/// clip has no art.
///
/// `legacy-admission.md` makes partial coverage a defined state: an unbacked
/// frame falls back to the authored blockout, and a frame from another role,
/// direction, or clip must never be substituted. `ClipFrameLibrary` enforces
/// that all-or-nothing rule; this type only turns the result into textures.
@MainActor
final class SpriteLibrary {
    private let frames: ClipFrameLibrary
    /// Textures by delivered file name, loaded once.
    private var textures: [String: SKTexture] = [:]
    /// Cached animation actions by clip and direction.
    private var animations: [String: SKAction] = [:]

    let coverage: (backed: Int, total: Int)

    init() {
        let library = (try? ClipFrameLibrary.bundled())
            ?? ClipFrameLibrary(clips: [:], deliveredPaths: [:])
        frames = library
        coverage = library.coverage
    }

    var isEmpty: Bool { coverage.backed == 0 }

    func isBacked(clipId: String, direction: String? = nil) -> Bool {
        frames.isBacked(clipId: clipId, direction: direction)
    }

    /// First frame of a clip, for a static presentation.
    func firstTexture(clipId: String, direction: String? = nil) -> SKTexture? {
        guard let paths = frames.deliveredFrames(clipId: clipId, direction: direction),
              let first = paths.first
        else { return nil }
        return texture(named: first)
    }

    /// A repeating or one-shot animation for a clip, at its authored frame rate.
    func animation(clipId: String, direction: String? = nil) -> SKAction? {
        let key = "\(clipId)|\(direction ?? "-")"
        if let cached = animations[key] { return cached }
        guard let clip = frames.clip(clipId),
              let paths = frames.deliveredFrames(clipId: clipId, direction: direction)
        else { return nil }
        let textures = paths.compactMap { texture(named: $0) }
        guard textures.count == paths.count, !textures.isEmpty else { return nil }

        let perFrame = 1.0 / Double(max(1, clip.framesPerSecond))
        let sequence = SKAction.animate(with: textures, timePerFrame: perFrame, resize: false, restore: false)
        let action = clip.loop ? SKAction.repeatForever(sequence) : sequence
        animations[key] = action
        return action
    }

    /// Authored anchor for a clip, as a SpriteKit unit anchor point.
    ///
    /// The contract's anchor is in sprite-box pixels measured from the top-left;
    /// SpriteKit anchors are 0…1 from the bottom-left, so y inverts.
    func anchorPoint(clipId: String, boxHeight: CGFloat, boxWidth: CGFloat) -> CGPoint {
        guard let clip = frames.clip(clipId), boxWidth > 0, boxHeight > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(
            x: CGFloat(clip.anchor.x) / boxWidth,
            y: 1 - CGFloat(clip.anchor.y) / boxHeight
        )
    }

    private func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let url = RuntimeAssetBundle.url(forFile: name),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        let texture = SKTexture(image: image)
        // visual-language-001: nearestNeighbor. Authored pixels stay crisp.
        texture.filteringMode = .nearest
        textures[name] = texture
        return texture
    }
}
