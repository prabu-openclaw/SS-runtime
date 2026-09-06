# Intent — terminal surface, and the restart that fired too early

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

**Sequencing, stated plainly:** SS-specs `intent/run-shell-surfaces.md` is merged
but still `Status: draft`, and no `spec.md` has been written. This change stream
therefore runs *ahead* of its product intent, at the user's explicit direction,
and is scoped to the half that is already specified — restart — rather than the
half that is not — a title screen.

Three defects, found while building it:

1. **A tap at the upgrade gate restarted the whole run.** Completing M-A sets
   `upgrade.pending = true` and `outcome = .upgradeSelectionPending` together.
   `touchesBegan` opened with `if snap.outcome != .playing { restartRun() }`, and
   `.upgradeSelectionPending != .playing`, so the first touch destroyed the run
   and the card-selection branch below it was unreachable. Every human
   playthrough would end at the first upgrade gate.

2. **A finished run said nothing and restarted on any touch.** FR-004 requires
   restart to restore initial state, gate B003 verifies it, and the only surface
   reaching it was a bare touch. No panel named the outcome.

3. **World sprites could draw over the HUD.** `ignoresSiblingOrder` makes draw
   order depend on `zPosition` alone, with ties undefined. `WorldRenderer`
   assigns layers 0...8; the HUD left everything at 0.

[verified: (1) read at the M-A branch of `advanceEncounters` and at
`touchesBegan`, and pinned by `theUpgradeGateIsPendingAndNotTerminalAtOnce`;
(2) `HUDRenderer` contained no outcome copy; (3) observed on device — the player
and the extraction zone rendered on top of the terminal panel until `hud.root`
was given a `zPosition`.]

Why (1) survived this long: `DebugAutopilot` sets `session.pendingUpgradeChoice`
directly in `update()`, so every automated run bypassed `touchesBegan` entirely.
The harness exercised the hit test but never the route a finger takes to it.
This is precisely the class of defect T903/T904 exists to catch, and no human
has played yet.

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- A tap at the upgrade gate selects a card. It does not restart the run.
- A finished run displays its outcome and restarts only from a named control.
- HUD elements draw above world sprites at every layer.
- The restart control is inside its panel, at least 44 x 44 points, centred, and
  on screen at the smallest supported safe rectangle.
- The state digest is unchanged: this is presentation and touch routing only.

## Affected users/systems

- Users: anyone playing by hand — which is to say, the T903/T904 testers who
  have not started yet, and who would otherwise have lost every run at M-A.
- Systems: `RunOutcome` (adds `isTerminal`), `HUDLayout` (terminal geometry and
  copy), `HUDRenderer`, `GameScene` (touch routing, HUD `zPosition`).

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- **Terminal copy is not invented.** `audio-haptics-001` already names these
  outcomes for its accessibility captions ("Run complete", "Player down"); the
  surface reuses those words, uppercased per `hud-tutorial-001`.
- The terminal surface is **not** an `HUDElement` and does not enter the
  `hud-tutorial-001` layout table — that table describes HUD present during
  play. The upgrade overlay sets the same precedent.
- No new authoritative state, and nothing here reaches the digest.
- Scope discipline: no title screen, no menu, no run history, no statistics.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- The launch/title half of the run shell, which is still unspecified
- Deciding what a terminal surface *should* report. It states the outcome and
  offers restart, and nothing more, precisely because that is not yet specified.

## Open questions

- **`RESTART` is the one invented string here.** It borrows FR-004's own noun
  rather than inventing a voice, but no contract names it. It needs a copy row
  in SS-specs, exactly like the lethal warning in the tutorial work.
- Should the terminal surface report more — seed, elapsed ticks, cameras
  destroyed, Network Blackout? The receipt carries all of it. Left out
  deliberately; it is a product decision.
- Should the surface offer anything besides restart, given Settings is currently
  reachable only from Pause during a run?

## Claims

| Claim | Label |
|---|---|
| The upgrade gate and a terminal run were indistinguishable to the touch handler | `[verified: both set by the M-A branch; `theUpgradeGateIsPendingAndNotTerminalAtOnce` asserts `outcome != .playing` and `!isTerminal` simultaneously]` |
| The harness could not have caught it | `[verified: `DebugAutopilot` selects via `session.pendingUpgradeChoice` in `update()`, never through `touchesBegan`]` |
| World sprites drew over the HUD | `[verified: device screenshot before and after the `zPosition` change]` |
| The restart control cannot strand the player | `[verified: geometry tests across four safe rectangles — inside the panel, at least 44x44, centred, panel on screen]` |
| Touch and rect share a coordinate space | `[verified: `points(touch)` returns safe-rect points; `terminalRestart` is built from `projector.safeWidth/safeHeight`, as `upgradeCardRects` already is]` |
| No replay identity change | `[verified: 368 tests in 62 suites, including digest, receipt round-trip, and ER-007]` |
| The control responds to a real finger | `[assumed: proven by geometry, by space-equivalence with the working upgrade path, and by screenshot — but no physical tap was performed, since fronting the Simulator would have taken over the user's screen]` |

## Next

A human accepts this file (`Status: accepted`). The `RESTART` copy row and the
question of what a terminal surface reports are product intent and belong in
SS-specs, alongside `intent/run-shell-surfaces.md`.
