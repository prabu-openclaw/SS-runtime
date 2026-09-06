import CoreGraphics
import Testing
@testable import SSRuntime
@testable import SurveillanceCore

/// `player-controller-001` normalization, and the controller lifecycle.
///
/// This file exists because `App/` had no tests. Two defects reached `main`
/// through that gap — the upgrade-gate restart and the never-called
/// `reset()` — and both were in code a unit test would have caught in seconds.
@Suite(.serialized)
struct TouchControllerTests {
    /// A layout with the stick centred at (100, 100), radius 72, so the
    /// arithmetic below is checkable by hand.
    static func layout() -> ControlLayout {
        ControlLayout(
            stickCentre: CGPoint(x: 100, y: 100),
            stickRadius: 72,
            stickZone: CGRect(x: 0, y: 0, width: 280, height: 280),
            dodgeRect: CGRect(x: 300, y: 100, width: 88, height: 88),
            pauseRect: CGRect(x: 400, y: 0, width: 44, height: 44)
        )
    }

    /// A distinct touch identity. `TouchToken` wraps an `ObjectIdentifier` of a
    /// live `UITouch` in production, so a test needs some object to stand in —
    /// and must keep it alive, since a freed object's identity can be reused.
    final class TouchStandIn {}

    static func token(_ box: TouchStandIn) -> TouchController.TouchToken {
        TouchController.TouchToken(id: ObjectIdentifier(box))
    }

    // MARK: - Normalization

    /// A press inside the dead zone produces no movement at all.
    @Test func theDeadZoneProducesNoCommand() {
        let box1 = TouchStandIn()
        var controller = TouchController()
        // 150 permille of radius 72 is 10.8 points; 8 is comfortably inside.
        _ = controller.began(token: Self.token(box1), atPoints: CGPoint(x: 108, y: 100), layout: Self.layout())

        #expect(controller.moveX == 0)
        #expect(controller.moveY == 0)
    }

    /// At the rim the command saturates.
    @Test func theRimProducesFullMagnitude() {
        let box2 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box2), atPoints: CGPoint(x: 172, y: 100), layout: Self.layout())

        #expect(controller.moveX == Int16(TouchController.maximum))
        #expect(controller.moveY == 0)
    }

    /// Point space is y-down and the command is y-up, so pushing up the screen
    /// must produce a positive `moveY`. Getting this backwards would invert
    /// vertical movement — the kind of thing only a human would notice.
    @Test func pushingUpTheScreenMovesUpInCommandSpace() {
        let box3 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box3), atPoints: CGPoint(x: 100, y: 20), layout: Self.layout())

        #expect(controller.moveY > 0)
        #expect(controller.moveX == 0)
    }

    /// A diagonal at the rim cannot exceed full magnitude on either axis.
    @Test func aDiagonalIsClampedToTheUnitCircle() {
        let box4 = TouchStandIn()
        var controller = TouchController()
        // Well beyond the rim, diagonally, but inside the activation zone.
        _ = controller.began(token: Self.token(box4), atPoints: CGPoint(x: 240, y: 20), layout: Self.layout())
        #expect(controller.stickTouch != nil)
        #expect(controller.moveX != 0 && controller.moveY != 0)

        let magnitude = (Double(controller.moveX) * Double(controller.moveX)
            + Double(controller.moveY) * Double(controller.moveY)).squareRoot()
        #expect(magnitude <= Double(TouchController.maximum) + 1)
    }

    // MARK: - Claiming

    /// A second finger cannot steal the stick from the first.
    @Test func theStickIsClaimedByOneTouch() {
        let box10 = TouchStandIn()
        let box11 = TouchStandIn()
        var controller = TouchController()
        let first = Self.token(box10)
        _ = controller.began(token: first, atPoints: CGPoint(x: 160, y: 100), layout: Self.layout())
        let hit = controller.began(token: Self.token(box11), atPoints: CGPoint(x: 40, y: 100), layout: Self.layout())

        #expect(hit == .none)
        #expect(controller.stickTouch == first)
    }

    /// A touch that never claimed the stick cannot steer it.
    @Test func onlyTheClaimingTouchSteers() {
        let box12 = TouchStandIn()
        let box13 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box12), atPoints: CGPoint(x: 160, y: 100), layout: Self.layout())
        let before = controller.moveX

        controller.moved(token: Self.token(box13), toPoints: CGPoint(x: 100, y: 100), layout: Self.layout())

        #expect(controller.moveX == before)
    }

    /// Releasing the stick centres it immediately.
    @Test func releasingTheStickZeroesTheCommand() {
        let box14 = TouchStandIn()
        var controller = TouchController()
        let stick = Self.token(box14)
        _ = controller.began(token: stick, atPoints: CGPoint(x: 172, y: 100), layout: Self.layout())
        #expect(controller.moveX != 0)

        controller.ended(token: stick)

        #expect(controller.moveX == 0)
        #expect(controller.moveY == 0)
        #expect(controller.stickTouch == nil)
        #expect(controller.knobOffset == .zero)
    }

    // MARK: - Dodge

    /// `player-controller-001`: Dodge is a rising edge, delivered once.
    @Test func dodgeIsARisingEdgeConsumedExactlyOnce() {
        let box20 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box20), atPoints: CGPoint(x: 340, y: 140), layout: Self.layout())

        #expect(controller.takeCommand().dodgePressed)
        #expect(!controller.takeCommand().dodgePressed)
    }

    /// Holding Dodge does not repeat it.
    @Test func holdingDodgeDoesNotRepeat() {
        let box21 = TouchStandIn()
        var controller = TouchController()
        let dodge = Self.token(box21)
        _ = controller.began(token: dodge, atPoints: CGPoint(x: 340, y: 140), layout: Self.layout())
        _ = controller.takeCommand()

        controller.moved(token: dodge, toPoints: CGPoint(x: 341, y: 141), layout: Self.layout())

        #expect(!controller.takeCommand().dodgePressed)
    }

    /// Pause is reported to the caller and claims nothing.
    @Test func pauseIsReportedAndClaimsNoControl() {
        let box22 = TouchStandIn()
        var controller = TouchController()
        let hit = controller.began(token: Self.token(box22), atPoints: CGPoint(x: 410, y: 10), layout: Self.layout())

        #expect(hit == .pause)
        #expect(controller.stickTouch == nil)
        #expect(controller.dodgeTouch == nil)
    }

    // MARK: - reset(), the #66 regression

    /// The bug: `reset()` was never called, so a stick held across a pause left
    /// `stickTouch` bound to a token that could never end — and `began`'s
    /// `stickTouch == nil` guard then refused every future stick press for the
    /// rest of the run. This asserts the stick is usable again after a reset.
    @Test func resetReleasesTheStickSoANewPressIsAccepted() {
        let box30 = TouchStandIn()
        let box31 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box30), atPoints: CGPoint(x: 172, y: 100), layout: Self.layout())
        #expect(controller.stickTouch != nil)

        // The held touch never ends: the scene was covered before touchesEnded.
        controller.reset()

        let hit = controller.began(token: Self.token(box31), atPoints: CGPoint(x: 160, y: 100), layout: Self.layout())
        #expect(hit == .stick)
        #expect(controller.stickTouch == Self.token(box31))
    }

    /// The other half: a stale heading must not survive into the resumed or
    /// restarted run.
    @Test func resetZeroesTheCommand() {
        let box32 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box32), atPoints: CGPoint(x: 172, y: 100), layout: Self.layout())
        #expect(controller.moveX != 0)

        controller.reset()

        #expect(controller.moveX == 0)
        #expect(controller.moveY == 0)
        #expect(controller.knobOffset == .zero)
    }

    /// A buffered Dodge must not fire on the first tick after a resume.
    @Test func resetDropsThePendingDodgeEdge() {
        let box33 = TouchStandIn()
        var controller = TouchController()
        _ = controller.began(token: Self.token(box33), atPoints: CGPoint(x: 340, y: 140), layout: Self.layout())

        controller.reset()

        #expect(!controller.takeCommand().dodgePressed)
    }

    // MARK: - Quantization

    /// Half-away-from-zero, and symmetric about zero.
    @Test func quantizationIsSymmetricAndSaturates() {
        #expect(TouchController.quantize(0) == 0)
        #expect(TouchController.quantize(1) == Int16(TouchController.maximum))
        #expect(TouchController.quantize(-1) == Int16(-TouchController.maximum))
        #expect(TouchController.quantize(2) == Int16(TouchController.maximum))
        #expect(TouchController.quantize(-2) == Int16(-TouchController.maximum))
    }
}
