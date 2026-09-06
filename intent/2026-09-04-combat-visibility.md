# Intent — Combat visibility

Author: prabu
Date: 2026-09-04
Status: accepted
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

One committed intent per **runtime-only** change stream. Live under `intent/`.
Do not invent gameplay. Product intent stays in SS-specs.

## Problem / why now

Several authoritative combat entities have no presentation projection, so the
renderer cannot draw them at all. The simulation is correct; the player simply
cannot see it.

[verified: `PresentationSnapshot` exposes no `projectiles`, `mines`, boss
Integrity, or telegraph geometry, while `WorldState` carries
`projectiles`, `mines`, `bossRuntime`, and per-enemy `state` at
`80dcfc0`. `App/GameScene.redraw()` therefore draws none of them.]

Concretely, at the pinned baseline:

| Authoritative state | Drawn? |
|---|---|
| `state.projectiles` (Civic Pulse, boss bolts, Sutro bolts) | no |
| `state.mines` (Victorian Vendor) | no |
| Boss Integrity / phase — `HUDLayout.bossIntegrity()` exists | no |
| Boss telegraphs (`bosses.md` §Attack vocabulary) | no |
| Elite Redaction Dash telegraph | no |

The boss telegraphs matter most: `bosses.md` gives every attack an exact
wind-up shape and duration, which is the only warning the player gets. Without
them the Algorithmic Moderate deals unavoidable damage, so the encounter cannot
be fairly playtested and Gates G-001–G-007 cannot be run honestly.

Separately, `redraw()` called `removeAllChildren()` on the world and HUD every
tick and rebuilt every node at 60 Hz.

[verified: `App/GameScene.swift` `redraw()` at `80dcfc0`.]

That makes the transient-node and draw budgets in `plan.md` (T606) unmeasurable,
because the measurement would only ever describe the rebuild.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- `PresentationSnapshot` exposes `projectiles`, `mines`, `boss`, and
  `telegraphs`, each projected from authoritative state only, ordered by stable
  entity ID.
- Projected telegraph geometry equals the `bosses.md` constants: Safety
  Rationale 45 ticks / 70° cone / range 260; Narrow Tailoring 30 ticks / three
  lanes at −12°, 0°, +12°; Temporary Order 48 ticks at the pending authored
  emitter; Independent Review 60 ticks / five lanes with the safe gap omitted;
  Redaction Dash 36 ticks / 72-unit lane.
- The app draws all of the above, and the boss Integrity bar appears only while
  the boss is alive.
- The world layer reuses nodes keyed by stable entity ID across frames instead
  of rebuilding the scene graph every tick.
- `swift test` stays green and gains coverage for each new projection.

## Affected users / systems

- Users: players (combat and boss legibility); playtest facilitators (G-001–G-007
  need a fair boss).
- Systems: `SurveillanceCore/Presentation`, `App/` renderer. No change to
  simulation, rules, content, arena, or replay identity.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- Projection only. No new rule, damage number, timing, or geometry may originate
  here; every constant traces to `bosses.md` or `combat-001`.
- `SurveillanceCore` stays free of SpriteKit, UIKit, wall clock, and unseeded
  randomness. Path construction stays in `App/`.
- Never infer collision, targeting, or Camera fields from rendered nodes.
- The gameplay digest must not change. This is presentation only.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Final art, atlases, or asset intake (T503–T509, T800)
- The full `hud-tutorial-001` HUD conformance pass (separate change stream)

## Open questions

- Should standard-enemy telegraph states (`pulse`, `charge`, `shot` wind-ups in
  `enemies-and-encounters.md`) also project, or is the boss/elite set enough for
  the first playtest? Deferred; not blocking.

## Claims

| Claim | Label |
|---|---|
| Authoritative headings are clockwise-positive, so a SpriteKit renderer must draw at `−heading` | `[verified: Cordic.headingUnit(θ) = (cos θ, −sin θ); atan2Milli = circle − atan2CCW; pinned by ConeOrientationTests]` |
| Every authored Camera and Captain emitter heading is off-axis, so a mirrored render is always visibly wrong | `[verified: civic-seam-arena-001.json headings are 20000…330000, none 0 or 180000]` |
| Temporary Order telegraphs at `emitters[emitterIndex % count]` | `[verified: BossSystem.resolve advances emitterIndex only when the attack fires]` |
| Projectile reach = speed × lifetimeTicks / 60 | `[verified: 60 Hz authoritative tick rate in plan.md; matches 420×72/60 = 504]` |
| Node reuse does not change simulation output | `[verified: full swift test suite green, 289 tests]` |

## Next

A human accepts this file (`Status: accepted`). Then specify in SS-specs
(`spec.md` + `## Workflows`) if product behavior is affected. Do not
implement from this file alone.
