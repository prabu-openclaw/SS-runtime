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
        static let stickBase = require("control_stick_base")
        static let dodge = require("control_dodge")
        static let pause = require("control_pause")
        static let extractionRing = require("hud_extraction_ring")
    }
}
