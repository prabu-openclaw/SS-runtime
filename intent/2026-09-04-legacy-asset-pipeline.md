# Intent — Legacy asset pipeline

Author: prabu
Date: 2026-09-04
Status: accepted
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

## Problem / why now

`SS-specs` PR #4 amends LC-009 and LC-010 to a bounded ADAPT, so role-identical
legacy assets may finally enter the bundle. Nothing in the runtime could act on
that: the catalog loader rejected any runtime-required asset that was not
`projectOriginal`, and there was no admission decision to express one.

[verified: `AssetCatalog.validate` threw `excludedRuntimeRequired` for
`runtimeRequired && provenance != .projectOriginal`; `AssetAdmissionDecision`
had only `excluded`, `rejected`, `sfCandidate`, `plannedOriginal`.]

So the game rendered untextured primitives with no way to change that, even
though the frozen commit holds art that fits.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- A repeatable script turns the frozen legacy checkout into delivered frames
  plus `asset-record-001` entries, and refuses to run against any other source.
- 112 of the 408 `clip-metadata-001` frame IDs and 13 of the 24 audio event IDs
  are `accepted`, each with a `sha256` that matches the frozen commit.
- Every `camera_*` clip is fully backed; `player_move` is fully backed.
- The Player and the Cameras draw admitted art in the running app; everything
  unbacked keeps its authored blockout, and no frame is ever borrowed from
  another role, direction, or clip.
- `swift test` covers each clause of the admission test, including the casting
  rule.

## Affected users / systems

- Users: players — the game shows characters instead of primitives.
- Systems: `AssetCatalog`, `RuntimeBundleFilter`, `AssetIntake`, new
  `ClipFrameLibrary`; `App/SpriteLibrary` and `WorldRenderer`. No change to
  simulation, rules, arena, or replay identity.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- `scrimshawlife-ctrl/Surveillance-Survivor@3b20d88` is the only admission
  source. The script verifies a known digest before writing anything.
- No admitted asset may back a Civic Seam enemy, the Improper Search Daemon, or
  the Algorithmic Moderate.
- Collision, targeting, and Camera fields are never inferred from a sprite.
- The gameplay digest must not change.

Non-goals:

- Admitting the legacy enemy or boss cast
- The 28 HUD, control, telegraph, and objective IDs, which have no legacy
  counterpart and stay `projectOriginal`
- The audio playback engine (separate change stream; this only delivers files)

## Open questions

- **Music has no reachability slot.** `audio-haptics-001` names six music states
  but no contract enumerates music *asset* IDs, so `RuntimeBundleFilter`
  correctly refuses to bundle `music_run_loop`, `music_boss_loop`, and
  `ambience_city_identity_loop`. They are held back rather than forced in.
  `presentation-assets-001` needs a `musicAssetIds` array, which is a specify
  question.
- `player_idle` is backed 2 frames per direction against an authored 4, so it
  falls back to the blockout under the all-or-nothing rule. Either the contract
  drops to 2 frames or 8 more frames get produced.

## Claims

| Claim | Label |
|---|---|
| `mapReferenceRect`-style silent breakage is avoided: an unbacked clip is all-or-nothing | `[verified: ClipFrameLibrary.deliveredFrames returns nil unless every frame in the direction resolves]` |
| Every delivered file exists and is legally named | `[verified: LegacyAdmissionTests.everyAdmittedFileExistsAndIsNamedLegally]` |
| No admitted asset backs the canonical cast | `[verified: LegacyAdmissionTests.noAdmittedAssetBacksTheCanonicalCast]` |
| Coverage is 112/408 frames and 13/24 audio IDs | `[verified: LegacyAdmissionTests.clipCoverageIsPartialAndMeasurable]` |
| Gameplay digest unchanged | `[verified: swift test 304 green, replay and complete-run vectors included]` |
| Player and Camera art renders on device | `[verified: iPhone 17 simulator, autopilot tour, walk cycle and LPR housing visible]` |

## Next

A human accepts this file (`Status: accepted`). It depends on SS-specs #4
landing first; without that amendment this admission has no spec authority.
