public enum Handedness: String, Equatable, Sendable {
    case right
    case left
}

public struct HUDRect: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public var meetsTouchTarget: Bool { width >= 44 && height >= 44 }

    public func reflected(acrossX axis: Int = 422) -> HUDRect {
        HUDRect(x: axis * 2 - x, y: y, width: width, height: height)
    }
}

/// hud-tutorial-001 reference canvas. Layout is presentation-only.
public enum HUDLayout {
    public static let referenceWidth = 844
    public static let referenceHeight = 390

    public static func scale(safeWidth: Int, safeHeight: Int) -> Int {
        Int(min(
            IntMath.mulDivHalfAway(Int64(safeWidth), 1000, Int64(referenceWidth)),
            IntMath.mulDivHalfAway(Int64(safeHeight), 1000, Int64(referenceHeight))
        ))
    }

    public static func stick(handedness: Handedness) -> HUDRect {
        reflect(HUDRect(x: 104, y: 286, width: 144, height: 144), handedness)
    }

    public static func dodge(handedness: Handedness) -> HUDRect {
        reflect(HUDRect(x: 760, y: 286, width: 88, height: 88), handedness)
    }

    public static func pause() -> HUDRect { HUDRect(x: 806, y: 36, width: 44, height: 44) }
    public static func playerIntegrity() -> HUDRect { HUDRect(x: 24, y: 24, width: 220, height: 20) }
    public static func exposureBar() -> HUDRect { HUDRect(x: 422, y: 26, width: 300, height: 24) }
    public static func detectionLabel() -> HUDRect { HUDRect(x: 422, y: 54, width: 180, height: 24) }
    public static func combatObjective() -> HUDRect { HUDRect(x: 24, y: 58, width: 300, height: 48) }
    public static func cameraObjective() -> HUDRect { HUDRect(x: 24, y: 110, width: 180, height: 28) }
    public static func bossIntegrity() -> HUDRect { HUDRect(x: 422, y: 82, width: 360, height: 24) }
    public static func extractionCountdown() -> HUDRect { HUDRect(x: 422, y: 134, width: 220, height: 56) }
    public static func upgradeBadge() -> HUDRect { HUDRect(x: 760, y: 88, width: 64, height: 64) }
    public static func tutorialCard() -> HUDRect { HUDRect(x: 422, y: 318, width: 520, height: 56) }
    public static func tamperSpike() -> HUDRect { HUDRect(x: 642, y: 26, width: 120, height: 24) }

    public static let tamperCopy = "+100 TAMPER"
    public static let integrityNotchCount = 3
    public static let integrityNotchPersistTicks: UInt64 = 90
    public static let firstEncounterCameraCopy = "CAMERAS: 3 HITS • DESTRUCTION ADDS EXPOSURE"

    public static func integrityNotchFilled(integrity: Int, index: Int) -> Bool {
        index >= 0 && index < integrityNotchCount && index < max(0, integrity)
    }

    public static func extractionSeconds(_ remainingTicks: Int) -> Int {
        remainingTicks <= 0 ? 0 : (remainingTicks + 59) / 60
    }

    public static let cameraObjectiveTotal = 8
    public static let networkBlackoutAccolade = "NETWORK BLACKOUT 8/8"

    public static func cameraObjectiveVisible(destroyed: Int, damaged: Bool, pinned: Bool = false) -> Bool {
        pinned || damaged || destroyed > 0
    }

    public static func cameraObjectiveCopy(destroyed: Int, complete: Bool) -> String {
        complete ? networkBlackoutAccolade : "CAM \(destroyed)/\(cameraObjectiveTotal)"
    }

    private static func reflect(_ rect: HUDRect, _ handedness: Handedness) -> HUDRect {
        handedness == .left ? rect.reflected() : rect
    }
}

public enum TutorialPhase: Equatable, Sendable {
    case move
    case field
    case contact
    case cameraDamage
    case upgrade
    case complete
}

public struct TutorialState: Equatable, Sendable {
    public var phase: TutorialPhase
    public var displacementUnits: Int
    public var fieldTicks: Int
    public var noContactTicks: Int
    public var cameraEligibleTicks: Int
    public var lockdownPreempts: Bool

    public init() {
        phase = .move
        displacementUnits = 0
        fieldTicks = 0
        noContactTicks = 0
        cameraEligibleTicks = 0
        lockdownPreempts = false
    }

    public var copy: String {
        if lockdownPreempts { return "LOCKDOWN" }
        switch phase {
        case .move: return "MOVE"
        case .field: return "CAMERA FIELDS RAISE EXPOSURE"
        case .contact: return "BREAK LINE OF SIGHT TO RECOVER"
        case .cameraDamage: return HUDLayout.firstEncounterCameraCopy
        case .upgrade: return "CHOOSE ONE COUNTERMEASURE"
        case .complete: return ""
        }
    }

    public mutating func noteDisplacement(_ units: Int) {
        displacementUnits += max(0, units)
        if phase == .move, displacementUnits >= 96 {
            phase = .field
        }
    }

    public mutating func noteCameraInViewport() {
        guard phase == .field else { return }
        fieldTicks += 1
        if fieldTicks >= 60 { phase = .contact }
    }

    public mutating func noteContact(_ contacting: Bool) {
        if phase == .field, contacting {
            phase = .contact
        }
        if phase == .contact {
            if contacting {
                noContactTicks = 0
            } else {
                noContactTicks += 1
                if noContactTicks >= 30 { phase = .cameraDamage }
            }
        }
    }

    public mutating func noteCameraTargetable() {
        if phase == .contact || phase == .field {
            phase = .cameraDamage
        }
        if phase == .cameraDamage {
            cameraEligibleTicks += 1
            if cameraEligibleTicks >= 300 { phase = .upgrade }
        }
    }

    public mutating func noteCameraImpact() {
        if phase == .cameraDamage { phase = .upgrade }
    }

    public mutating func noteMobAComplete() {
        phase = .upgrade
    }

    public mutating func noteUpgradeSelected() {
        if phase == .upgrade { phase = .complete }
    }
}

public struct PresentationCamera: Equatable, Sendable {
    public static let visibleWidth = 896
    public static let visibleHeight = 414
    public static let deadZoneWidth = 96
    public static let deadZoneHeight = 64
    public static let maxLookAhead = 96

    public var center: VecI

    public static func follow(player: VecI, heading: VecQ8, bounds: ArenaManifest.Bounds) -> PresentationCamera {
        var look = 0
        if heading != .zero {
            look = min(maxLookAhead, 48)
        }
        let dirX = heading.x.raw >= 0 ? 1 : -1
        var x = player.x + dirX * look
        var y = player.y
        let halfW = visibleWidth / 2
        let halfH = visibleHeight / 2
        x = min(max(x, bounds.minX + halfW), bounds.maxX - halfW)
        y = min(max(y, bounds.minY + halfH), bounds.maxY - halfH)
        return PresentationCamera(center: VecI(x: x, y: y))
    }
}
