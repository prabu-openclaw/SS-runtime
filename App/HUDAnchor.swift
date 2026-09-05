import SurveillanceCore

/// How a `hud-tutorial-001` anchor coordinate relates to its element box.
///
/// The contract's layout table annotates most rows — `top-left`, `top-center`,
/// `top-right`, `center` — and the annotation is what fixes the meaning of the
/// `(x, y)` pair. The three control rows carry no annotation, but their
/// geometry settles it: Pause at `(806, 36)` sized 44 × 44 runs to x = 850 on
/// an 844-wide canvas if `x` is a left edge, and to 828 if `x` is a centre.
/// Only the centre reading fits, and only the centre reading makes
/// `HUDRect.reflected(acrossX: 422)` keep the stick and Dodge on canvas in
/// left-handed mode (UI-002).
///
/// Resolving anchors here keeps `HUDLayout` — which maps a plain top-left rect
/// and is already covered by adopted tests — unchanged.
enum HUDAnchor {
    case topLeft
    case topCentre
    case topRight
    case centre

    /// The contract's anchor mode for each element.
    static func mode(for element: HUDElement) -> HUDAnchor {
        switch element {
        case .playerIntegrity, .combatObjective, .cameraObjective:
            .topLeft
        case .exposureBar, .detectionLabel, .bossIntegrity, .tutorialCard, .tamperSpike:
            .topCentre
        case .upgradeBadge:
            .topRight
        case .extractionCountdown:
            .centre
        case .stick, .dodge, .pause:
            .centre
        }
    }

    /// Converts an anchored reference-canvas rect into the plain top-left rect
    /// `HUDLayout.mapReferenceRect` expects.
    func topLeftRect(_ rect: HUDRect) -> HUDRect {
        switch self {
        case .topLeft:
            rect
        case .topCentre:
            HUDRect(x: rect.x - rect.width / 2, y: rect.y, width: rect.width, height: rect.height)
        case .topRight:
            HUDRect(x: rect.x - rect.width, y: rect.y, width: rect.width, height: rect.height)
        case .centre:
            HUDRect(
                x: rect.x - rect.width / 2,
                y: rect.y - rect.height / 2,
                width: rect.width,
                height: rect.height
            )
        }
    }
}

/// Every HUD element the contract's layout table names.
enum HUDElement: CaseIterable {
    case playerIntegrity
    case exposureBar
    case detectionLabel
    case combatObjective
    case cameraObjective
    case bossIntegrity
    case extractionCountdown
    case upgradeBadge
    case tutorialCard
    case tamperSpike
    case stick
    case dodge
    case pause

    /// Controls keep their baseline size; informational elements take the HUD
    /// scale setting.
    var isControl: Bool {
        switch self {
        case .stick, .dodge, .pause: true
        default: false
        }
    }

    func referenceRect(handedness: Handedness) -> HUDRect {
        switch self {
        case .playerIntegrity: HUDLayout.playerIntegrity()
        case .exposureBar: HUDLayout.exposureBar()
        case .detectionLabel: HUDLayout.detectionLabel()
        case .combatObjective: HUDLayout.combatObjective()
        case .cameraObjective: HUDLayout.cameraObjective()
        case .bossIntegrity: HUDLayout.bossIntegrity()
        case .extractionCountdown: HUDLayout.extractionCountdown()
        case .upgradeBadge: HUDLayout.upgradeBadge()
        case .tutorialCard: HUDLayout.tutorialCard()
        case .tamperSpike: HUDLayout.tamperSpike()
        case .stick: HUDLayout.stick(handedness: handedness)
        case .dodge: HUDLayout.dodge(handedness: handedness)
        case .pause: HUDLayout.pause()
        }
    }

    /// Anchored reference rect resolved to a top-left rect.
    func topLeftReferenceRect(handedness: Handedness) -> HUDRect {
        HUDAnchor.mode(for: self).topLeftRect(referenceRect(handedness: handedness))
    }
}
