# Intent — hud-tutorial-001 conformance

Author: prabu-openclaw
Date: 2026-09-05
Status: draft
Product: Surveillance Survivor Runtime (`scrimshawlife-ctrl/SS-runtime`)

This file is a proto-spec. It comes **before** specify.
Next stage is `spec.md` in `scrimshawlife-ctrl/SS-specs` (pinned by
`SPEC_BASELINE.md`). Do not skip to code.

One committed intent per **runtime-only** change stream. Live under `intent/`.
Do not invent gameplay. Product intent stays in SS-specs.

## Problem / why now

`hud-tutorial-001` is CANONICAL and the implementation is close to it — six
phases, every threshold, every copy string, and the card anchor all match. Three
requirements are simply absent:

1. **The tutorial setting does nothing.** `tutorialsEnabled` reaches
   `PresentationSettings` and the receipt, and `SettingsView` offers a "Tutorial
   prompts" toggle, but `PresentationSnapshot` sets `tutorialCopy` without ever
   consulting it. The receipt test passes, so the gap reads as covered.
2. **No maximum visual duration.** The contract says "Each card has a maximum
   visual duration of 300 ticks, but its completion condition remains
   authoritative where specified." No counter existed, so a card could persist
   indefinitely.
3. **Only Lockdown preempts.** The contract names three higher safety messages —
   lethal warning, Lockdown, Extraction. `lockdownPreempts` existed;
   `lockedExtractionCopy` and `phoenixStepsOpenCopy` were defined and never read.

(2) is observable: with `-SSSeed boss` the tutorial stranded in its upgrade phase
and displayed `CHOOSE ONE COUNTERMEASURE` for the whole boss fight, with nothing
to choose.

[verified: read against `specs/001-single-level-vertical-slice/hud-tutorial.md`
at spec commit 484599f; `graft grep` confirms the two Extraction constants had no
readers; device screenshot shows the stranded card before, and a clean HUD after.]

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- A tutorial card disappears after 300 presented ticks and its phase does not
  advance because of it.
- Turning "Tutorial prompts" off hides tutorial cards and **leaves Lockdown and
  Extraction messages visible**.
- Armed Extraction shows `PHOENIX STEPS OPEN`; contact with a locked Extraction
  shows `DEFEAT THE CURRENT AUTHORITY`; Lockdown outranks both.
- Every T0–T4 transition in the contract has a test naming its threshold.
- The state digest is byte-identical: `state.tutorial` is not a digest field.

## Affected users / systems

- Users: anyone playing with tutorials off (previously impossible), and anyone
  who saw a stale card outlive its moment.
- Systems: `TutorialState` and `HUDLayout`, `Simulation` (tutorial wiring only),
  `PresentationSnapshot`, `HUDRenderer`, `GameScene.apply(settings:)`.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- **The setting hides tutorial cards, never safety copy.** Lockdown and
  Extraction share the card but are not tutorial content; suppressing a Lockdown
  because tutorials are off would be a safety regression. Hence
  `copyIsSafetyMessage`, and why safety copy is read before the duration cap.
- Tutorial state stays out of the digest, so none of this can move replay identity.
- The cap is visual only. Completion conditions remain authoritative.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Rewording any copy. Every string here already exists in the contract.
- The lethal-warning preemptor (see below).

## Open questions

- **The lethal warning has no HUD copy anywhere in SS-specs.** `hud-tutorial.md`
  names it as one of three preemptors, and `audio-haptics.md` and
  `camera-destruction.md` name it as audio priority 1, but no contract gives it a
  string, and the `## Exact copy` table has no row for it. Implementing it would
  mean inventing product copy, so this change deliberately implements the two
  preemptors that *are* specified and leaves the third. **It needs a copy row in
  SS-specs before it can be built.**

## Claims

| Claim | Label |
|---|---|
| Tutorial state is excluded from the digest | `[verified: `StateDigest.canonical` enumerates its fields and `state.tutorial` is not among them]` |
| The setting was inert before this change | `[verified: `PresentationSnapshot.swift:194` set `tutorialCopy` with no `tutorialsEnabled` reference]` |
| The two Extraction constants were dead code | `[verified: `graft grep` found definitions at `HUDLayout.swift:204-205` and no readers]` |
| The stranded card is fixed | `[verified: device screenshot at `-SSSeed boss`, 22 s in — card present before, absent after]` |
| No replay identity change | `[verified: 376 tests in 63 suites pass, including the digest, receipt round-trip, and ER-007 gates]` |
| The lethal warning has no specified copy | `[verified: grep for "lethal" across `specs/` returns only audio-priority and visual-language hits, no copy row]` |

## Next

A human accepts this file (`Status: accepted`). This implements an existing
CANONICAL contract, so it needs no new `spec.md`. The lethal-warning copy row
above is product intent and belongs in SS-specs.
