# Intent — input must not survive a pause or a restart

Author: prabu-openclaw
Date: 2026-09-05
Status: accepted
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

One committed intent per **runtime-only** change stream. Live under `intent/`.
Do not invent gameplay. Product intent stays in SS-specs.

## Problem / why now

`TouchController.reset()` exists, is correct, and **is never called** — not on
pause, not on restart, nowhere in the codebase.

Two consequences, both reachable by hand and neither by the harness:

1. **Pause.** Pause is reached by tapping the Pause control while the other hand
   may still hold the stick, and SwiftUI then covers the scene, so the scene is
   not guaranteed to receive `touchesEnded` for that held touch. The run resumes
   walking with no finger down; a buffered Dodge fires on the first tick back;
   and `stickTouch` stays bound to a token that can never end, so `began` refuses
   every future stick press — **movement is dead for the rest of the run.**

2. **Restart.** `GameSession.restartRun` zeroes the session's command, but the
   controller keeps its own `moveX`/`moveY`/`stickTouch`/`dodgeEdgePending`, and
   `applyController` overwrites the session from the controller on the next tick.
   A player holding the stick when the run ended carries that heading, and that
   dead binding, into the new run.

[verified: `grep -rn "controller.reset()" App/` returns nothing; `setPaused`
assigns `runPaused` and nothing else; `GameScene.restartRun` resets session,
sound, renderer, and instrumentation, but not the controller.]

Why now: this is the second input-path defect this week that the automated suite
could not see, after the upgrade-gate restart in the terminal-surface work. Both
share one root cause, recorded below.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- Pausing and resuming leaves the player stationary with no finger down.
- No Dodge fires on the first tick after a resume.
- The stick is usable after a pause taken while it was held.
- A restarted run begins with a neutral command regardless of what was held.

## Affected users/systems

- Users: anyone playing by hand. The harness cannot reach either path.
- Systems: `GameScene.setPaused`, `GameScene.restartRun`. Two call sites; no
  change to `TouchController` itself, which was already correct.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- PC-008 already requires that a paused run creates no simulation ticks. Input
  not surviving the pause boundary is the same rule applied to the command.
- Presentation and input routing only. No authoritative state, no digest effect.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Changing dead zone, quantization, or any normalization `player-controller-001` pins
- The App-layer test target discussed below — worth doing, too large to bundle here

## Open questions

- **`App/` has no tests at all.** `Package.swift` declares one test target,
  `SurveillanceCoreTests`, depending only on `SurveillanceCore`; `App/` is built
  by XcodeGen and never compiled by `swift test`. That is the shared root cause
  of this defect and the upgrade-gate one, and it will keep producing them.
  `TouchController` is pure logic and could move into `SurveillanceCore` — but it
  is typed in `CGPoint` and Core deliberately avoids CoreGraphics (`HUDLayout`
  uses its own `HUDRect`), so the move is a real refactor. **Deliberately not
  attempted here**, because an unmerged PR already edits this file and stacking a
  refactor on top is how the duplicated block in #60 happened.

## Claims

| Claim | Label |
|---|---|
| `reset()` is never called | `[verified: grep across App/ returns no call site]` |
| The harness cannot reach either path | `[verified: DebugAutopilot drives `session` fields directly and never touches `TouchController`]` |
| A held stick can outlive a pause | `[assumed: SwiftUI presenting over SpriteView is not guaranteed to deliver touchesCancelled; not reproduced by hand, since verifying it needs a physical two-finger gesture]` |
| Stale command reaches the new run | `[verified: `applyController` assigns session from controller every tick, after `restartRun` zeroed the session]` |
| No replay identity change | `[verified: 356 tests in 60 suites pass; both edits are in the App layer]` |

## Next

A human accepts this file (`Status: accepted`). Runtime-only, so no matching
`spec.md`. The App-layer test target in Open questions is the follow-up worth
scheduling.
