# Sanctuary Stage 6.1b — Exchange courtyard and landscape polish

Build **`0.7.0-home6b`**, Android export version code **29**, passed its scoped native integration gate: **8,435 checks / 33 modes / 31 suites**. This document records the implemented contract; rendered and physical Android acceptance remain pending. See [the validation report](personal-sanctuary-m6-1b-validation.md).

The user requested smaller walls, a spacious enclosed Grand Exchange with arches and bridges to the Sanctuary districts, richer color/scenery, and repair of wall flicker during movement. This supersedes the previous 22–30 m perimeter presentation while preserving the working city and game.

## Preserved baseline and recovery

The starting local commit is `1a34f351e0c07576795afe3f1b14bfeb372cc24b`; its tree `fbc627483916a79729a4344914029ee2f4f1c3b9` matches published `main` commit `d362893b184710a56283a38169d524acaa3f6bf1`. The home6a runtime passed its separate 8,250-check gate. Those historical checks are distinct from the fresh gate for this update.

Before modification, the complete source history was saved in `/workspace/backups/vaultbound-before-sanctuary-polish/accepted-home6a.bundle` and verified with `git bundle verify`. SHA-256: `1a0a6513867ec2d7d2b239b408b301d69d688acd2d0fa0342fed422e63f695be`. This source backup contains no phone save data; preserve device profiles separately.

## Bounded architectural change

| Area | Implemented contract |
| --- | --- |
| Outer city walls | Heights 4.6 / 5.2 / 5.8 m, modestly above the older 3.2–4.2 m perimeter. The 64 original horizontal collision footprints remain. |
| Exterior landmarks | Four towers at 9 / 10 / 11 / 12 m, with details fitted to the new scale. The original sixteen inner tower footprints remain. |
| Exchange enclosure | Wall bays 3.2 / 3.5 / 3.8 m high around radius 23.5 m, outside the existing radius-19 m ring road and its six-metre width. The six counters and central Prismheart remain inside a spacious courtyard. |
| District entrances | Eight broad archways aligned with the existing district roads. Clear opening width 9.4 m, spring height 3.9 m and top 5.7 m; native body/camera clearance checks passed. |
| Six flat-road bridges | New supported ramp/deck/ramp surfaces along the existing road axes, eight metres wide along radius 20.8–27.7 m, with a 0.40 m rise and flat deck from radius 23–25.5 m. The road and formation space remain broad. |
| Forge and Tavern bridges | Retain the existing raised-district ramps and their collision. Bridge-side decoration reuses that ascent without stacking a second contradictory deck. |
| Water and shores | Shallow ornamental side channels span local X ±4.15–6.4 m and radius 23.3–26.1 m, retaining CityGround beneath them. Consistent banks add no damage or deep-water traversal mechanic. |

The original 90 m city footprint, four arrivals, thirteen established service POIs, eight district transforms and existing portal destinations remain. The southeast Personal Sanctuary gate continues to serve the same saved home. Bridges and arches do not implement new districts, a live economy or new multiplayer transitions.

All six Exchange booths and the City Guide continue using one **DEMO / NOT LIVE** market. Their TEST balances stay separate from earned Depthmarks and owned inventory. Combat, equipment, dungeon progression, AI roles, profile v11/home v3, saved TEST ACCESS and existing home services are outside the presentation changes.

## Wall flicker repair

Source inspection confirmed that the previous wall's inner face and several gold/stone/rune surfaces ended on the same local `Z = 0.400` plane. The coping also overlapped the masonry, while the blue banner sat behind its face. Such overlapping opaque faces can fight for the same depth samples as the camera moves; static batching preserves the conflict.

The repair places a thinner visible stone core inside the retained conservative collision envelope, uses separated relief depths, and gives the cap its own vertical interval. Rune arms and crossing trim must not create new coplanar overlaps. Heights and ornament placement follow the smaller wall/tower dimensions so details cannot float above the structure.

Native verification examines actual mesh faces and shape bounds, with separate batching coverage. Removing confirmed overlapping faces does not prove that every device flicker source is fixed: shadow shimmer, lighting composition and camera motion still need rendered Low/Medium/High comparisons. Global camera precision or shadow settings should not be changed to conceal an unverified cause.

## Color and scenery

The landscape pass stays in existing garden pockets between the roads, around radius 31 m. The update replaces small uniform blossoms with larger bounded blooms in four scene-local color families, adds gold centers and richer green foliage, and varies existing distant canopy silhouettes/colors. It reuses the current instancing/density system and preserves its budgets. No global dungeon material is recolored by changing a Sanctuary palette.

New decoration must remain outside paths, formation clearance, service approaches and camera openings. It introduces no new lights, collision, navigation actors or per-frame simulation. Existing fauna, local day/night presentation, particle limits and graphics controls remain; there is no claim of a new sky system or professional imported models. All additions use original native meshes and available materials. The accepted native courtyard layer measures 6,968 triangles across 32 meshes plus eight destination labels, with zero added lights or processing nodes. These are layer counts, not whole-world or GPU performance measurements.

## Verification and delivery

The accepted integration gate covers actual wall depth separation, eight gate openings, six new bridge slopes plus two retained terrace routes, support/capsule clearance, both cameras and preset invariance. Retained checks cover city services, shared DEMO custody, portals, home travel, saved TEST ACCESS, UI and progression preservation. Actual player/Guardian/Mystic traversal and a manual pet route are distinct evidence, and must be reported as such.

The validation report states final native mesh/triangle/instance/light counts and their scope. Native scene counts and headless test duration are not GPU draw calls or Android frame rates. Device review must include the user's flicker reproduction route and sustained gameplay on supported Android hardware.

Publish the accepted update to **main**, so the normal GitHub **Code → Download ZIP** includes it. Keep `project.godot` at the archive root; current guides should identify home6b/code29. The download is Godot source, not an installed APK. Preserve historical home6a reports and all player saves.

The full cardinal-wing/Nexus rearrangement, Bank, Guild rooms, Undercroft, new contracts, broader sky system, live trading and ranked/online services remain separate later work.
