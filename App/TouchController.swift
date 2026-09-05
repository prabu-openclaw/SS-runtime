import CoreGraphics
import SurveillanceCore

/// Turns touches into the normalized command `player-controller-001` defines.
///
/// The contract is explicit about the arithmetic: "The platform applies a
/// radial 0.15 dead zone, linearly remaps the remaining magnitude to 0…1,
/// clamps the vector to the unit circle, quantizes half-away-from-zero, and
/// then records it. Replays contain normalized commands, never touch
/// coordinates." All of that happens here, in point space, so the simulation
/// only ever sees `moveX` / `moveY` in −32767…32767.
///
/// Replaces a scheme where the whole screen was one floating stick and Dodge
/// fired whenever the drag exceeded 160 points — which made Dodge impossible to
/// use deliberately and impossible to avoid at full stick.
struct TouchController {
    static let deadZonePermille = 150
    static let maximum = 32_767

    /// A stick press may begin anywhere in its activation zone; the stick then
    /// centres on the drawn anchor and the knob tracks the finger. The zone is
    /// larger than the drawn 144 × 144 base so the control is reachable without
    /// moving the anchor UI-001 pins.
    private(set) var stickTouch: TouchToken?
    private(set) var dodgeTouch: TouchToken?

    /// Current knob offset from the stick centre, in points, for presentation.
    private(set) var knobOffset: CGPoint = .zero
    private(set) var moveX: Int16 = 0
    private(set) var moveY: Int16 = 0

    /// Rising edge: true for exactly one command, never buffered.
    private var dodgeEdgePending = false

    struct TouchToken: Equatable {
        let id: ObjectIdentifier
    }

    // MARK: - Command

    /// Consumes the pending Dodge edge. Call once per simulation tick.
    mutating func takeCommand() -> (moveX: Int16, moveY: Int16, dodgePressed: Bool) {
        let dodge = dodgeEdgePending
        dodgeEdgePending = false
        return (moveX, moveY, dodge)
    }

    mutating func reset() {
        stickTouch = nil
        dodgeTouch = nil
        knobOffset = .zero
        moveX = 0
        moveY = 0
        dodgeEdgePending = false
    }

    // MARK: - Touch lifecycle

    /// - Returns: true when the touch was claimed by a control.
    mutating func began(
        token: TouchToken,
        atPoints point: CGPoint,
        layout: ControlLayout
    ) -> ControlHit {
        if layout.dodgeContains(point) {
            dodgeTouch = token
            dodgeEdgePending = true
            return .dodge
        }
        if layout.pauseContains(point) {
            return .pause
        }
        if stickTouch == nil, layout.stickZoneContains(point) {
            stickTouch = token
            update(toPoints: point, layout: layout)
            return .stick
        }
        return .none
    }

    mutating func moved(token: TouchToken, toPoints point: CGPoint, layout: ControlLayout) {
        guard stickTouch == token else { return }
        update(toPoints: point, layout: layout)
    }

    mutating func ended(token: TouchToken) {
        if stickTouch == token {
            stickTouch = nil
            knobOffset = .zero
            moveX = 0
            moveY = 0
        }
        if dodgeTouch == token {
            dodgeTouch = nil
        }
    }

    // MARK: - Normalization

    private mutating func update(toPoints point: CGPoint, layout: ControlLayout) {
        let centre = layout.stickCentre
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let radius = layout.stickRadius
        guard radius > 0 else { return }

        let distance = (dx * dx + dy * dy).squareRoot()
        // Clamp to the unit circle: a diagonal cannot exceed full magnitude.
        let clamped = min(distance, radius)
        knobOffset = distance > 0
            ? CGPoint(x: dx / distance * clamped, y: dy / distance * clamped)
            : .zero

        let magnitudePermille = Int((clamped / radius * 1000).rounded())
        guard magnitudePermille > Self.deadZonePermille, distance > 0 else {
            moveX = 0
            moveY = 0
            return
        }
        // Linear remap of the live band to 0…1.
        let remapped = Double(magnitudePermille - Self.deadZonePermille)
            / Double(1000 - Self.deadZonePermille)
        let unitX = dx / distance
        // Point space is y-down; the command is y-up.
        let unitY = -dy / distance

        moveX = Self.quantize(unitX * remapped)
        moveY = Self.quantize(unitY * remapped)
    }

    /// Half-away-from-zero into the command range.
    static func quantize(_ value: Double) -> Int16 {
        let scaled = (value * Double(maximum)).rounded(.toNearestOrAwayFromZero)
        return Int16(max(Double(-maximum), min(Double(maximum), scaled)))
    }
}

enum ControlHit {
    case none
    case stick
    case dodge
    case pause
}

/// Mapped control geometry in safe-rectangle point space.
struct ControlLayout {
    var stickCentre: CGPoint
    var stickRadius: CGFloat
    /// Generous activation area around the stick; the anchor itself does not move.
    var stickZone: CGRect
    var dodgeRect: CGRect
    var pauseRect: CGRect

    func stickZoneContains(_ point: CGPoint) -> Bool { stickZone.contains(point) }
    func dodgeContains(_ point: CGPoint) -> Bool { dodgeRect.contains(point) }
    func pauseContains(_ point: CGPoint) -> Bool { pauseRect.contains(point) }

    static let empty = ControlLayout(
        stickCentre: .zero,
        stickRadius: 0,
        stickZone: .zero,
        dodgeRect: .zero,
        pauseRect: .zero
    )

    static func make(projector: HUDProjector, handedness: Handedness) -> ControlLayout {
        func rect(_ element: HUDElement) -> CGRect {
            let mapped = projector.mappedControl(element.topLeftReferenceRect(handedness: handedness))
            return CGRect(
                x: CGFloat(mapped.x),
                y: CGFloat(mapped.y),
                width: CGFloat(mapped.width),
                height: CGFloat(mapped.height)
            )
        }
        let stick = rect(.stick)
        let dodge = rect(.dodge)
        let safeWidth = CGFloat(projector.safeWidth)
        let safeHeight = CGFloat(projector.safeHeight)

        // The activation zone spans the stick's half of the canvas below the
        // informational band, so the control is reachable with a thumb without
        // moving the anchor the contract pins.
        let zoneTop = safeHeight * 0.30
        let zone = handedness == .right
            ? CGRect(x: 0, y: zoneTop, width: safeWidth / 2, height: safeHeight - zoneTop)
            : CGRect(x: safeWidth / 2, y: zoneTop, width: safeWidth / 2, height: safeHeight - zoneTop)

        return ControlLayout(
            stickCentre: CGPoint(x: stick.midX, y: stick.midY),
            stickRadius: stick.width / 2,
            stickZone: zone.intersection(CGRect(x: 0, y: 0, width: safeWidth, height: safeHeight)),
            dodgeRect: dodge,
            pauseRect: rect(.pause)
        )
    }
}
