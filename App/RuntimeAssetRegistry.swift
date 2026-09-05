import SurveillanceCore

/// App-side gate: only runtime-reachable SS-001 asset IDs may be referenced at integration time.
enum RuntimeAssetRegistry {
    static let presentation: PresentationAssetRegistry = try! PresentationAssetRegistry.bundled()

    static func require(_ assetId: String) -> String {
        (try? presentation.require(assetId)) ?? assetId
    }

    enum HUD {
        static let integrityFrame = require("hud_integrity_frame")
        static let exposureBar = require("hud_exposure_bar")
        static let bossBar = require("hud_boss_bar")
        static let cameraCounter = require("hud_camera_counter")
        static let cameraNotchFull = require("hud_camera_notch_full")
        static let cameraNotchEmpty = require("hud_camera_notch_empty")
        static let stickBase = require("control_stick_base")
        static let stickKnob = require("control_stick_knob")
        static let dodge = require("control_dodge")
        static let pause = require("control_pause")
        static let extractionRing = require("hud_extraction_ring")

        static func detection(_ state: DetectionState) -> String {
            require("hud_detection_\(state.rawValue)")
        }

        static func upgradeBadge(for upgrade: UpgradeID) -> String {
            switch upgrade {
            case .signalJammer: require("hud_upgrade_signal_jammer")
            case .ricochetPulse: require("hud_upgrade_ricochet_pulse")
            case .ghostStep: require("hud_upgrade_ghost_step")
            }
        }
    }

    /// bosses.md telegraph presentation identities.
    enum Telegraph {
        static let daemonQuery = require("telegraph_daemon_query")
        static let daemonDash = require("telegraph_daemon_dash")
        static let safetyRationale = require("telegraph_safety_rationale")
        static let narrowTailoring = require("telegraph_narrow_tailoring")
        static let temporaryOrder = require("telegraph_temporary_order")
        static let independentReview = require("telegraph_independent_review")
    }

    enum Objective {
        static let phoenixStepsLocked = require("objective_phoenix_steps_locked")
        static let phoenixStepsArmed = require("objective_phoenix_steps_armed")
        static let networkBlackout = require("objective_network_blackout")
    }
}
