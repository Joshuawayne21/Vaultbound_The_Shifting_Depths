# Milestone 5.6 implementation plan and inspection

Baseline: local commit `82a9b8838aad7f1f9ef5756ad3ce377b53d1e200`, published as `cd4d7e56a1a2411686ef6a42c24e5c64755a7c04`. The working tree was clean before inspection. Godot 4.6.3, GDScript, Android landscape and GL Compatibility remain the target. The previous milestone passed 3,025 assertions in 33 engine invocations.

## Inspection findings

The inspection covered the scene/resource inventory and the gameplay, presentation, persistence and validation code. Existing references resolve. There are 54 scenes, a single persistent game shell, one player controller and one shared combat implementation. Sword/shield and staff have working attacks, charges, defenses and abilities. Three enemy archetypes and the Rootwarden already use guarded death states. Two camera compositions share the same player and combat state.

Inventory uses forty slots, stable equipment instance IDs, bounded stacks, protected ownership, six equipment assignments and twelve display references. The version-two profile preserves counts, equipment, companions, character talents, discoveries and expedition statistics. Economy changes use private revision-bound quotes, candidate validation and verified atomic saving. The first migration backup needs improvement: existing backups normalize older records, so version-three migration must also retain the exact original bytes before the first migrated write.

The catalog has thirty definitions, eight recipes, five chest tables, three merchants and a Blacksmith. Currency is stored as `gold`; that stable integer can represent Depthmarks without creating a second writable balance. Room treasure already enters an unsecured expedition bag and becomes permanent on extraction. Ordinary monster deaths currently grant kill statistics but no loot. The existing boss reward chest is generated once and guarantees the Rootwarden heart.

The touch surface and expedition overlay already own multi-touch and modal input; RPGPanel is the existing inventory/equipment/service interface. The avatar preview reuses the actual character but has no drag rotation. Characters are procedural rigid pivots and native meshes, not imported Skeleton3D rigs or authored animation clips. Twelve SVG icons and shared family display models exist; hundreds of unique models/icons do not. Graphics presets already bound decoration/effects and use a separate preferences file.

Dungeon generation, room culling, companion navigation, boss behavior, safe portals, extraction and progression remain the implementation foundation. No new multiplayer, PvP reward system, quests, biome, or boss is introduced or represented as working.

## Verified delivery checkpoints

Dependencies require a small save foundation alongside loadout UI. The requested features are grouped into the following independently testable checkpoints. Each checkpoint receives a local commit and a matching GitHub commit after its gate passes; a critical regression blocks advancement.

1. **Owned loadouts and safe save foundation** (requested stages 1, 4/15 foundations): version-three migration, exact pre-migration backup, secondary weapon and additional slot fields, active loadout, two circular owned-weapon controls, state/cooldown guards and presentation-only switch cue. Preserve shield and existing accessory assignments as additional slots. Empty slots show no fictional weapon. Existing unassigned practice combat remains available; assigned loadouts switch only owned, supported equipment.
2. **Mobile menus and accessibility** (2, 4): shared fantasy styling, separate Inventory/Equipment entries, responsive extra slots, same-avatar drag inspection, clearer comparisons/stats, safe-area-aware UI scale and reduced motion. Preserve the existing transaction/input owner.
3. **Compatible character presentation** (3): rounded native surfaces and smoother procedural pose blending, retaining controller, pivots, collision and weapon anchors. Document missing production rigs/clips rather than claiming replacement assets.
4. **Searchable encounter loot and Depthmarks** (5, 6, 14 currency): one per-run loot ledger, stable death receipts, valid placement, bounded pooled cache views, partial Take/Take All, consolidation, configured monster/elite/boss DM and existing extraction/death rules. Keep boss reward ownership singular. Renaming currency never changes stored value.
5. **Forty functional starter definitions and rarity policy** (7 starter, 8): extend definition metadata, supported-family and content gates, readable rarity labels/patterns, acquisition sources and truthful family-art status. Validate the small set before expansion.
6. **Enhancements, materials and reusable effects** (9, 10, 14): data-driven guaranteed costs, +5/+10 rarity caps, obtainable upgrade materials, bounded effect statistics/components and exact transaction previews. Unsupported mechanics are not rolled as functional effects. Existing enhancements remain valid.
7. **Catalog expansion in tested batches** (7, 11): author distinct families toward 50 weapons, 85 armor, 35 accessories, 80 valuables, 45 materials, 25 consumables and 30 trophy artifacts. Preserve the legacy currency definition separately, yielding approximately 350 definitions. Commit each validated expansion batch. Gate unsupported combat families and trophies tied to nonexistent encounters from acquisition and use; report shared art accurately.
8. **Collection presentation and final integration** (12, 13, 16): owned-reference animated pedestals, inspection, collection completion, bounded rarity/enhancement effects and particle/aura reduction options. No display operation creates or consumes an owned item.
9. **Complete regression and delivery** (17, 18): all available automated checks, separate-process persistence, resource/import validation, fresh source startup, current reports and Android checklist. Publish the final tested source and stop after 5.6.

## Validation gates

- Migration: valid v1/v2 ownership, gold balance, equipment, companions, talents and history preserved; exact pre-migration bytes retained; corrupt/newer saves remain protected; v3 strict references and unique equipped identities; separate-process restart.
- Loadouts: actual owned icons, active state, correct abilities/models, no inactive-weapon stat stacking, no cooldown reset or duplicated damage, safe rejection during incompatible actions, both cameras and multi-touch.
- UI/character: three landscape canvases and all accessibility scales, focus/cancel/scroll ownership, hidden preview shutdown, matching equipment appearance, finite poses and stable hand/collision anchors. GPU appearance remains a manual check.
- Loot: real normal/elite/boss deaths, one receipt per reward, safe floor/LOS, no path collision, bounded views/merging, partial collection, full-inventory retry, room reentry, extraction and loss behavior.
- Economy/catalog: exact currency/material costs, protected-item sales, repeated/stale transaction rejection, every rarity cap, bounded modifiers, all enabled items have real acquisition paths, disabled future content is absent from loot/stock/recipes, no capacity relaxation to accommodate catalog growth.
- Collection/performance: ownership references survive assignment, restart and later death; effect/preview budgets follow quality/reduced settings; no per-frame inventory rebuild. Existing 100-seed layout and companion navigation checks remain required.

## Constraints and evidence boundaries

All new assets must be original or appropriately licensed; no paid assets are purchased or downloaded. Native family icons/models are explicitly shared placeholders where unique art is unavailable. Local files remain editable offline development saves, not an online security boundary. Future server authority must validate inventory, loot and transactions; no client-controlled multiplayer is implemented.

No physical Android device or usable rendered GPU display is available in this environment. Headless checks can establish logic, resource validity and physics/input contracts, not production animation quality, shader appearance, touchscreen comfort, thermal behavior or sustained 30/60 FPS. These limits must remain in the final report.
