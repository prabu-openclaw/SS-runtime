# Intent — an App-layer test target

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

`App/` had no automated coverage of any kind. `Package.swift` declares a single
test target, `SurveillanceCoreTests`, depending only on `SurveillanceCore`;
`App/` is built by XcodeGen and is never compiled by `swift test`. So touch
routing, input normalization, HUD interaction, and every hit test shipped
unverified except by hand.

That gap produced two defects on `main` in a single week:

- **#65** — completing M-A sets `outcome = .upgradeSelectionPending`, and
  `touchesBegan` treated "not playing" as "finished", so the first tap at the
  upgrade gate restarted the run and the card-selection branch was unreachable.
- **#66** — `TouchController.reset()` existed, was correct, and was never called,
  so a stick held across a pause could leave `stickTouch` bound to a token that
  never ends, refusing every subsequent stick press.

Both are ordinary unit-test material. Neither could be caught, because the code
was not in any test target, and `DebugAutopilot` drives `session` fields directly
rather than going through touch handling — so harness-green says nothing about
the input path.

[verified: `Package.swift` has one `testTarget`, depending on `SurveillanceCore`
alone; `grep -rn "controller.reset()" App/` returned nothing before #66.]

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- `xcodebuild test -scheme SSRuntime` runs App-layer tests on a simulator.
- CI runs them on every change, in the same job that already builds the app.
- The two defects above have regression tests that fail against the old code.
- `player-controller-001` normalization — dead zone, unit-circle clamp, y-axis
  direction, quantization — is asserted rather than assumed.

## Affected users/systems

- Users: none directly. This is engineering capacity, not behaviour.
- Systems: `project.yml` (a `SSRuntimeTests` bundle and a scheme test target),
  new `AppTests/`, and the CI `app` job, which changes from `build` to `test`.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- **No production code changes.** This adds tests and build wiring only, so a
  failure here is a real finding rather than a change of behaviour.
- `SurveillanceCore` stays a SwiftPM package, tested by `swift test`. The comment
  in `project.yml` explaining why it is not an Xcode framework target still
  holds; this bundle tests `App/`, not the package.
- Tests must run on a simulator, because the types under test need UIKit and
  SpriteKit and cannot be hosted on macOS.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Moving `TouchController` into `SurveillanceCore`. It is typed in `CGPoint` and
  Core deliberately avoids CoreGraphics; testing it where it lives is the
  smaller and more honest change.
- UI or snapshot testing. This is unit coverage of logic.
- Backfilling every App type at once. `TouchController` first, because that is
  where both defects were.

## Open questions

- `GameScene`'s touch routing is still untested: it needs an `SKView` and a
  running scene, so it is a heavier fixture than this PR takes on. The routing
  bug in #65 is currently pinned in `SurveillanceCoreTests` through
  `RunOutcome.isTerminal` rather than through `touchesBegan` itself. Extracting
  the routing decision into a pure function would close that, and is the natural
  follow-up.
- Should the `app` CI job be split into build and test lanes, so a test failure
  is distinguishable from a compile failure at a glance?

## Claims

| Claim | Label |
|---|---|
| `App/` had no test coverage | `[verified: one testTarget in Package.swift, depending on SurveillanceCore only]` |
| The harness cannot substitute for it | `[verified: DebugAutopilot sets session.pendingUpgradeChoice and session.moveX/moveY directly, never entering touchesBegan]` |
| The new target runs | `[verified: xcodebuild test reports 14 tests in 1 suite passing on iPhone 17 simulator]` |
| The core lane is unaffected | `[verified: swift test 388 tests in 65 suites]` |
| XcodeGen must be re-run after adding sources | `[verified: the first generate ran against an empty AppTests/ and produced a bundle with zero tests, which reported TEST SUCCEEDED]` |

## Next

A human accepts this file (`Status: accepted`). Runtime-only tooling, so no
matching `spec.md`. The `GameScene` routing extraction in Open questions is the
follow-up worth scheduling.
