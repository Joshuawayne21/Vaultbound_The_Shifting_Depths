# Milestone 5.5 validation

Validation uses **Godot 4.6.3 stable, Linux headless, Compatibility**, on 2026-10-31. This report covers the visual pass and preservation of Milestones 1–5. **No physical Android testing, rendered GPU inspection, shader compilation on Android, APK export/signing or device performance measurement is claimed.**

## Implemented scope

The Sanctuary and Collection Hall now share an Enchanted Dark Fantasy palette with slate stone, bronze/gold detail, a suspended turquoise crystal, wall springs, decorated merchant/forge stations, an enriched Tavern back bar, Hall niches and trophy carving. The fourteen existing Abyss modules gain distinct authored motifs, reproducible cosmetic variations, root/rock/moss treatment, luminous plants, guardian reliefs and shallow bridge decoration. These changes reuse existing world layouts and interaction locations.

Three native environment presets, original small procedural surface textures, opaque water ripples, soft foam, anchored foliage sway and bounded ambient motes provide the common style. Combat changes add bounded impacts/sparks, spell wakes, sword/dodge ribbons and clearer Rootwarden warning borders without changing damage footprints or timing. Conservative static batching preserves collision and avoids dynamic materials or actors. Low/Medium/High graphics and independent 30/60 FPS targets are saved separately from progression, through the existing touch-modal input flow.

The initial inspection is documented in [the baseline](milestone-5.5-baseline.md); before/after scene-tree measurements, budgets and caveats are in [the performance report](milestone-5.5-performance.md). The existing M5 version-two profile and its migration/recovery rules remain unchanged. Milestone 5 publication was completed before this visual pass; the tested game was extended rather than rebuilt.

## Automated results

**All 3,025 assertions passed across 33 engine invocations.** This comprises 2,697 assertions in the 27 existing regression invocations and 328 in six new visual suites. Runtime logs were checked for script/runtime errors, warnings and leaked resources; all game-test logs were clean. Import/probe runs and repeated component verification are not counted as additional assertions.

| Suite | Passed assertions | Main coverage |
| --- | ---: | --- |
| `smoke_test.gd` | 321 | Every game resource, startup, movement, both cameras, touch routing and original portals |
| `combat_test.gd` | 177 | Existing sword/staff attacks, abilities, health/stamina, enemies and solo death |
| `ui_layout_test.gd` | 247 | Combat control geometry, multitouch ownership, cancellation and focus behavior |
| `dungeon_layout_test.gd` | 480 | 100 seeds, all 14 modules, connectivity, nonoverlap, floor/collision and malformed layouts |
| `loot_persistence_test.gd` | 47 | 5,000 loot samples, seven rarities, atomic saves, backups and preserved precision |
| `rootwarden_test.gd` | 53 | Boss attacks, warnings, phases, modifiers, obstruction, damage deduplication and death |
| `expedition_test.gd` | 114 | Generated encounters, loot, awareness, hazards, boss reward, extraction and later death |
| `expedition_ui_test.gd` | 19 | Minimap, inventory/results routing, notices and modal isolation |
| `persistence_restart_test.gd`, write/read | 8 + 13 | Extracted progress survives a separate engine process and later death |
| `party_test.gd` | 88 | Recruitment, orders, rescue/wipe rules, combat assistance, camera switching and extraction |
| `party_ui_test.gd` | 137 | Tavern touch recruitment, command geometry, modal pause, downed/revive input |
| `companion_behavior_test.gd` | 38 | Guardian blocking, Mystic healing, shared attacks, delayed decisions and boss warnings |
| `companion_navigation_test.gd` | 26 | Physical room traversal across seeds 7, 23 and 81, obstacles, secrets, hazards and recovery |
| `party_targeting_test.gd` | 38 | Enemy/boss/hazard party targeting, per-target damage receipts and effect cleanup |
| `party_persistence_test.gd` | 70 | Legacy roster migration, strict data validation, extraction-only XP and companion levels |
| `party_persistence_test.gd`, write/read | 5 + 8 | Recruited identities/progression survive separate engine processes |
| `item_catalog_test.gd` | 348 | Exactly 30 items, seven rarities, eight recipes, obtainable inputs, stock rotation, icons/model bounds and immutable snapshots |
| `inventory_economy_test.gd` | 114 | Forty-slot capacity, unique instances, all recipes/slots, protected ownership, upgrades/repair/salvage, appraisal, costs and transaction rejection |
| `character_progression_test.gd` | 69 | All 30 level thresholds, talent budgets, actual player statistics, family gating, condition and prevention of equipment healing loops |
| `collection_world_test.gd` | 36 | Sanctuary services, Hall architecture, twelve displays, journals, trophy, collision and return portal |
| `save_migration_test.gd` | 42 | Version-one preservation, huge/unknown reserves, strict version-two schema, backup recovery, read-only failures and interrupted-write handling |
| `rpg_integration_test.gd` | 117 | Real shops/player/party/Hall, exact transaction costs, trusted quotes, equipment, generated treasure, extraction, XP and later wipe preservation |
| `rpg_ui_test.gd` | 60 | Three landscape sizes, scrolling/canceling, equipment preview, talent/merchant/craft confirmations, two-finger deduplication, displays and real journal lecterns |
| `save_migration_test.gd`, write/read | 3 + 19 | Separate-process persistence of enhanced/protected equipment, condition, modifiers, talents, companions, journals, trophy and displayed models |
| `visual_style_test.gd` | 48 | Shared materials/textures, independent environments, compatible effects, water motion and bounded ambience |
| `abyss_visual_test.gd` | 100 | Fourteen distinct motifs, deterministic cosmetic variation, batch limits, quality density and preserved collision/connectors |
| `combat_presentation_test.gd` | 33 | Impact budgets/cleanup, optional spell/dodge presentation and accurate depth-tested boss warning geometry |
| `visual_settings_test.gd` | 54 | Three quality tiers, frame targets, independent preference persistence/rejection and synthetic touch confirmation behavior |
| `static_visual_batcher_test.gd` | 32 | Conservative eligibility, fewer renderable nodes, preserved geometry/UVs/normals and unchanged physics identities/transforms |
| `visual_integration_test.gd` | 61 | Actual camera clearance in both views/all tiers, portal depth/occlusion, seeds 7/23/81, room visibility, Hall and preserved progression |

Tests use disposable `/tmp` profiles and isolated user-data directories, preserving the normal player save. Persistence writers and readers are separate engine processes. The complete original gameplay suites still exercise generated layouts, monsters/boss behavior, combat, companions/navigation, inventory/economy, extraction, later death, restart and synthetic touchscreen routing.

The smoke total increased from 283 to 321 because it now loads the additional visual resources and scripts. The expedition UI suite prints `EXPEDITION UI CHECKS: 19 passed, 0 failures`; an initial log-summary parser expected a different success format. Its zero-exit, clean log was inspected and the parser corrected without rerunning or changing the game test. No gameplay failure was hidden by that reporting correction.

The editor import completed without missing project resources or GDScript parse errors. Restricted-environment editor socket/export-configuration messages are not gameplay failures and do not establish Android export readiness.

## Issues found and resolved

- Optional detail distance cuts initially affected a permanent crystal landmark. Distance culling now applies only to optional plants, preventing a hidden landmark from leaving an invisible camera blocker.
- The central crystal and four merchant canopies retain explicit camera-only occlusion while preserving player/companion movement and interaction approaches.
- Static batching excludes shader/dynamic/display geometry and nonuniform or reflected transforms. The conservative policy preserves original normals and the exact existing collision nodes, layers, shapes and transforms.
- Cosmetic room variation receives its own stable expedition seed and room ID; it does not consume encounter/loot randomness or rebuild on camera/quality changes.
- Shared resource lifetime and bounded effects were verified through clean teardown logs. Essential warnings, walls, portal veils and gameplay state remain independent of quality.

The existing 100-seed generator suite and physical checks across all fourteen room modules passed. Companion navigation also traversed seeds 7, 23 and 81. These checks support preserved connectivity/navigation; they are not a human playthrough or rendered proof of every camera angle.


## Evidence boundaries and known limitations

Headless checks establish resource loading, script syntax, scene behavior, physics queries, save contracts and synthetic input routing. They do not prove final appearance, GPU shader compatibility, touchscreen hardware behavior or a supported-device frame rate. The environment has no usable display/GPU; an Xorg dummy-display attempt failed to bind its local sockets.

The art retains native low-poly actors and procedural animation/sound placeholders. The Tavern is an open decorated bar, and bridge/stair dressing respects the existing flat navigation model. Detailed character replacement assets, a new vertical cave system, wildlife simulation and authored mesh LOD chains are not implemented. Additional geometry in the Abyss has a documented structural cost and needs real GPU profiling. No multiplayer, additional biome, player trading or guild system is implemented.

Use [README](../README.md) for Android import and controls, and [the physical Android review](test-plan.md#milestone-55-physical-android-visual-review) for device testing. Work stops after Milestone 5.5 pending visual and device review.
