# Intent — the title surface

Author: prabu-openclaw
Date: 2026-09-06
Status: draft
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

One committed intent per **runtime-only** change stream. Live under `intent/`.
Do not invent gameplay. Product intent stays in SS-specs.

## Problem / why now

`run-shell-001` §7.3 asked whether a title surface should exist at all, and left
it open. It is now decided and specified — see the companion SS-specs change —
so this implements §8 rather than inventing it.

The deciding argument was not presentation. `SettingsView` was reachable only
from Pause, **during a run**, so a player could not set handedness before
playing. A left-handed `T903`/`T904` participant would have had to begin a run,
pause, change handedness and restart — contaminating exactly the onboarding
comprehension data those playtests collect.

[verified: `SettingsView` was presented only from `scene.onPauseRequested`, and
the app presented a running `SpriteView` on launch with no other entry point.]

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- The app presents a title surface on launch and no simulation tick occurs
  while it is up.
- Start begins a run; Settings opens the existing settings surface.
- Handedness set from the title governs the run that follows.
- Wordmark and control labels meet the contrast the visual contract requires.
- Every `-SSAutopilot` and `-SSSeed` recipe keeps working unchanged.

## Affected users / systems

- Users: every player, and specifically left-handed playtesters, who could not
  configure the game before their first run.
- Systems: `App/TitleView.swift` (new), `GameContainerView`, `Assets.xcassets`.
  No simulation, no authoritative state, no digest effect.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- **Exactly two actions, Start and Settings.** No run history, no statistics, no
  continue, no difficulty choice, no meta-progression. `AGENTS.md` defers all of
  it until the expansion gate, and a title screen is where it creeps in first.
- Presentation only. `ER-007` continues to hold for settings reached here.
- Controls at least 44 x 44 points and horizontally centred, so neither
  handedness is favoured. Handedness reflects the stick and Dodge, never chrome.
- The harness must not be blocked by it.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- A route from the terminal surface back to the title. `run-shell-001` §8.1
  leaves that open, and a second control on that panel trades against the
  deliberate narrowness of §6.

## Open questions

- The three shell strings — `RESTART`, `START`, `SETTINGS` — are still
  unauthorised by any contract (`run-shell-001` §7.1).
- `TitleView` has no automated test. It is SwiftUI presentation, and the
  meaningful assertions are the acceptance vectors RS-008…RS-012, which are
  UI-level rather than unit-level. The contrast check below was measured from a
  device screenshot rather than asserted in code. A UI test target would close
  this, and is the natural follow-up to the App test target added in #67.

## Claims

| Claim | Label |
|---|---|
| Settings was unreachable before a first run | `[verified: presented only from onPauseRequested]` |
| The wordmark failed its contrast requirement over the backdrop | `[verified: measured 2.95:1 for the upper line from a device screenshot, against the 4.5:1 the visual contract requires for text and even the 3:1 UI floor]` |
| The scrim fixes it without losing the art | `[verified: re-measured 7.42:1 and 12.54:1 after the change, backdrop still legible]` |
| The harness is unaffected | `[verified: `-SSAutopilot tour` reaches M-A, M-B and M-C exactly as before; a title that paused the pilot was caught and fixed during implementation]` |
| No replay identity change | `[verified: swift test 388 in 65 suites, xcodebuild test 14 in 1; all edits are App-layer presentation]` |

## Next

A human accepts this file (`Status: accepted`). The specification half is the
companion SS-specs change resolving §7.3 and §7.4 and adding §8.
