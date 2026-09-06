# Intent — an environment layer the art can land in

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

Environment art is being produced now. Two things had to exist before it could
land, and neither did.

**It was unreachable by construction.** `RuntimeBundleFilter` bundles only assets
an ID in `presentation-assets-001` names, and no environment ID existed — so
correctly produced, correctly admitted environment art would have been excluded.
This is the same gap `musicAssetIds` closed for music, and it was found the same
way: art about to exist with nothing able to load it. The companion SS-specs
change adds `environmentAssetIds`.

**There was nowhere to draw it.** Solids rendered as `SKShapeNode` with a flat
fill, and the street plane had no layer at all — it was the scene's background
colour.

[verified: `reachableAssetIds` unioned only `requiredAssetIds`, `audioEventIds`
and `musicAssetIds`; `renderSolids` built `SKShapeNode` per solid; `Layer` had no
ground case.]

## Proposed outcome

Observable done (a stranger can check this without reading the chat):

- Delivered environment art appears with no further code change.
- With nothing delivered, the game looks **exactly** as it did — same grey
  blockout, same background.
- A solid's art fills its collision box exactly.
- Ground surface follows zone identity rather than being uniform.
- Environment IDs are runtime-reachable, and every arena solid has one.

## Affected users / systems

- Users: none yet; this is the socket the art plugs into.
- Systems: `EnvironmentLibrary` (new, core), `EnvironmentTextures` (new, app),
  `WorldRenderer` (ground layer, solids as sprites), `PresentationSnapshot`
  (solid ids, arena bounds, zones), `RuntimeBundleFilter`.

## Constraints

Product-true locks (do not reopen in implement):

- Spec-pinned runtime. Do not invent gameplay the pinned SS-specs commit does not name.
- **All-or-nothing per group.** One missing ground tile leaves the whole plane on
  its authored fill. Partial art is a legibility hazard rather than a partial
  improvement: a player cannot tell which grey rectangles are unfinished and
  which are meant to read as concrete. Same rule `ClipFrameLibrary` applies.
- **Art is sized to the collision box and may not overhang it.** A player must
  never be blocked by something that looks passable, or pass through something
  that looks solid.
- Presentation only. No authoritative state, no digest effect.
- Nothing may compete with a threat. Telegraphs, projectiles and camera fields
  stay the brightest things on screen; the world is matte and quiet.

Non-goals:

- Another level, weapon, character, campaign system, online feature, or meta-progression
- Producing the art. That is the delivery this prepares for.
- Props and motif sheets. Their IDs are declared, but nothing places them yet —
  placement is authored data the arena does not carry.

## Open questions

- Props and motifs are declared and loadable but **unplaced**. Placing them needs
  authored positions in the arena manifest, which is a specification change
  rather than a rendering one.
- Ground is tiled at 128 units with one surface per zone. If a zone ever wants
  more than one surface, that becomes authored data too.
- Camera housing art is declared per family but the camera renderer still draws
  its existing clip; wiring housings is a follow-up once the art exists.

## Claims

| Claim | Label |
|---|---|
| Environment art was unreachable | `[verified: reachableAssetIds unioned three arrays, none environment; test now asserts every declared ID is reachable]` |
| Every arena solid has an ID | `[verified: test derives from ArenaManifest.permanentSolids and asserts the contract names each]` |
| One missing asset disables its group | `[verified: test builds a library with a deliberate hole and asserts even the delivered asset is withheld]` |
| Runtime camera mounts get no art | `[verified: mount-<socket> solids are synthesised per tick and resolve to no asset]` |
| Nothing delivered means no visual change | `[verified: device run with no environment art — grey blockout, no ground, sprites 588/588, identical to before]` |
| No replay identity change | `[verified: 398 tests in 67 suites, App 14 in 1]` |

## Next

A human accepts this file (`Status: accepted`). The contract half is the
companion SS-specs change adding `environmentAssetIds`.
