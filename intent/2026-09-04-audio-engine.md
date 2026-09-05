# Intent — Audio engine

Author: prabu
Date: 2026-09-04
Status: draft
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

## Problem / why now

`AudioProjector` implements `audio-haptics-001` completely — the event map,
priority, the eight-voice ceiling with oldest-lowest stealing, every
coalescence rule, the six music states, sector captions, and an eight-entry
caption history. None of it reached a speaker, because nothing consumed it.

[verified: `graft callers AudioProjector.project` returns only
`AudioProjectorTests` and `AudioProjectorSmokeTests`; `App/` contained no
reference to AVFoundation, CoreHaptics, or captions at `1946680`.]

So the game was silent, and its accessibility obligation went unmet: the
contract requires that "Every safety-critical audio event has a visual
caption/event equivalent", and no caption was drawn anywhere.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- Every projected cue with an accepted asset plays; each one that has no asset
  is named rather than silently dropped.
- Music follows `explore → observed → lockdown → boss → extraction → terminal`
  with a one-second crossfade, and terminal within 100 ms.
- Haptics fire from the projected pattern, and never as the only carrier.
- The caption history is on screen, newest emphasised, clear of the tutorial
  card.
- Turning effects, music, or haptics off changes no gameplay state (AH-004).

## Affected users / systems

- Users: every player, and specifically players relying on captions.
- Systems: `App/AudioEngine`, `GameScene`, `HUDRenderer`;
  `presentation-assets-001` gains `musicAssetIds`. No change to simulation,
  rules, arena, or replay identity.

## Constraints

Product-true locks (do not reopen in implement):

- Audio and haptics project authoritative events. They never create, delay,
  cancel, or acknowledge gameplay state.
- The projector owns the rules. The device layer owns files, voices, buses, and
  fades, and must not re-implement priority or coalescence.
- Settings are local and excluded from replay authority.
- Haptics are never the only carrier of a safety-critical event.

Non-goals:

- Producing the 11 unbacked cues or the 3 unbacked music beds
- A settings surface for the mix buses (values are contract defaults for now)
- Directional caption sectors in the HUD; the projector computes the sector,
  but rendering an eight-sector indicator is a separate presentation change

## Open questions

- The mix buses are fixed at their `audio-haptics-001` defaults because there is
  no settings screen yet. Same gap as HUD scale and handedness.
- `camera_hit_01` and `camera_hit_02` alternate by hit count. Only `_01` is
  backed, so the engine pitches by the projector's `variant` rather than
  playing a second file. That is a stand-in, not the contract's intent.

## Claims

| Claim | Label |
|---|---|
| The projector was wired to nothing | `[verified: graft callers showed test-only callers]` |
| Cues resolve and play; unbacked ones are reported | `[verified: device run reported missingCues=camera_critical,camera_hit_02,camera_network_tamper and nothing else, while weapon, impact, and damage cues resolved]` |
| The music bed starts and reports its state | `[verified: device run reported music=explore continuously]` |
| Captions render clear of the tutorial card | `[verified: device screenshot, right-hand column]` |
| Only `explore` was exercised live | `[assumed: the autopilot never reached Lockdown, the boss, or a terminal outcome in the runs observed. The other five states are covered by AudioProjectorTests in Core, not on device.]` |
| Gameplay digest unchanged | `[verified: swift test 310 green]` |

## Next

A human accepts this file (`Status: accepted`). It depends on SS-specs #4,
which registers `musicAssetIds`; without that the music beds are unreachable
and cannot ship.
