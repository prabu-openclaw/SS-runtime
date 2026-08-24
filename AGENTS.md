# Runtime Agent Rules

1. Read `SPEC_BASELINE.md` before changing gameplay.
2. Treat SS-specs commit `39b04bb00ca5d3799513efed4e7970ec42975c96` as product authority.
3. Cite task and contract IDs in gameplay commits and pull requests.
4. Keep `SurveillanceCore` independent of UIKit, SwiftUI, SpriteKit, AVFoundation, wall clock, and unseeded randomness.
5. Use fixed 60 Hz ticks, stable UInt64 entity IDs, ordered iteration, and fail-closed version loading.
6. Never infer collision, targeting, or Camera fields from rendered nodes or sprite bounds.
7. Do not add another level, weapon, character, campaign system, online feature, or meta-progression.
8. Do not copy legacy source without an ADAPT decision and exact source citation.
9. Run `swift test` before handoff.
