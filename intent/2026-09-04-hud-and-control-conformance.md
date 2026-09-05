# Intent — HUD and control conformance

Author: prabu
Date: 2026-09-04
Status: draft
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

One committed intent per **runtime-only** change stream. Live under `intent/`.
Do not invent gameplay. Product intent stays in SS-specs.

## Problem / why now

`hud-tutorial-001` and `player-controller-001` are fully specified and fully
projected in `SurveillanceCore`, and the App consumed almost none of it.

[verified: `App/GameScene.swift` at `80dcfc0` drew five grey rectangles at raw
reference coordinates and concatenated every reading into one `SKLabelNode`.]

Three separate faults:

1. **`HUDLayout.mapReferenceRect` was off by the permille factor.** It computed
   `mulDivHalfAway(referenceWidth * canvasPermille, 1000, 1000)`, which is
   `referenceWidth * canvasPermille`, not `referenceWidth * canvasPermille /
   1000`. Three sites had the same slip. On an iPhone 17 safe rectangle of
   750 × 382 every mapped control came back ~889× too large and
   `mapControlRect` clamped it to the whole safe rectangle, so the stick and
   Dodge each became the full screen.

   [verified: instrumented run printed `stickCentre=(375.0, 191.0) r=375.0
   dodge=(0.0, 0.0, 750.0, 382.0)`.]

   The existing `HUDLayout.validate` coverage could not catch this, because it
   checks the *clamped* rect, which is inside the safe area by construction.

2. **Controls scaled below their baseline.** With the scaling fixed, Pause maps
   to 35 points on the SE-class canvas — under the 44-point touch target.
   `hud-tutorial-001` says controls "remain at least their baseline size" and
   every interactive rectangle is at least 44 × 44.

3. **The controls did not match the contract.** The whole screen was one
   floating stick and Dodge fired whenever the drag exceeded 160 points, so
   Dodge was impossible to use deliberately and impossible to avoid at full
   stick. The dead zone was 24 points of screen distance rather than the
   specified radial 0.15 of stick travel. There was no Pause, and multi-touch
   was off, so a player could not steer and Dodge at once.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- `mapReferenceRect` scales proportionally; a 1:1 safe rectangle is the
  identity, and no element needs clamping to fit.
- Controls never scale below their authored size or below 44 × 44.
- The HUD draws every element in the `hud-tutorial-001` layout table at its
  anchor, honouring the visibility rules: Camera counter hidden until first
  Camera damage, boss bar only while the boss lives, Extraction countdown only
  while armed, upgrade badge only after selection.
- Detection state is carried by label, glyph shape, **and** bar pattern, so
  UI-008 holds without colour.
- Input produces the normalized command the contract defines: radial 0.15 dead
  zone, linear remap to 0…1, unit-circle clamp, half-away-from-zero quantize.
- Dodge is a discrete button with a rising edge that is never buffered.
- Pause exists and creates no simulation ticks (PC-008).
- Stick and Dodge work simultaneously.

## Affected users / systems

- Users: every player (the HUD was unreadable and Dodge unusable).
- Systems: `SurveillanceCore/Presentation/HUDLayout` (scaling fix), `App/`
  renderer and input. No change to simulation, rules, content, arena, or replay
  identity.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- No gameplay state may depend on points, scale, safe area, or handedness.
- Replays carry normalized commands, never touch coordinates.
- The gameplay digest must not change.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Final HUD art or the control asset IDs (asset intake, still open)
- Audio, haptics, and captions (separate change stream)

## Open questions

**Anchor semantics are ambiguous in the layout table and need a spec answer.**
The table annotates rows inconsistently — `(24, 24), top-left` versus
`(422, 26), top-center` — and leaves the three control rows unannotated. Pause
at `(806, 36)` sized 44 × 44 runs to x = 850 on an 844-wide canvas if `x` is a
left edge, so only a centre reading fits; and only a centre reading keeps the
stick on canvas after `reflected(acrossX: 422)` in left-handed mode (UI-002).

I implemented the reading each row's annotation implies, with the three
controls as centre-anchored, in `App/HUDAnchor.swift`. If that is wrong, the
fix is one table there. Worth pinning the anchor mode explicitly in
`hud-tutorial.md`.

Also deferred: the HUD scale setting and handedness are hard-wired to
`.standard` / `.right` because there is no settings surface yet.

## Claims

| Claim | Label |
|---|---|
| `mapReferenceRect` was off by the permille factor at three sites | `[verified: mulDivHalfAway(a,b,d) = a*b/d; instrumented device run showed full-screen controls]` |
| `validate` could not have caught it | `[verified: it inspects the post-clamp rect, which is inside the safe area by construction]` |
| Pause falls under the 44-point target once scaling is correct | `[verified: SE-class permille 790; 44 × 0.790 = 35]` |
| Movement still matches PC-001 after the input rewrite | `[verified: device run, 240 units per 60 ticks]` |
| Gameplay digest unchanged | `[verified: swift test 295 green, replay and complete-run vectors included]` |

## Next

A human accepts this file (`Status: accepted`). Then specify in SS-specs
(`spec.md` + `## Workflows`) if product behavior is affected — the anchor
ambiguity above is a specify-stage question. Do not implement from this file
alone.
