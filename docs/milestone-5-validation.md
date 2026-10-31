# Milestone 5 validation

Validated on **2026-10-31** with **Godot 4.6.3 stable**, Linux headless, GDScript and the existing Compatibility renderer configuration. This report covers RPG progression and regression checks for Milestones 1–4. **No physical Android device, rendered GPU review, APK export/signing or mobile performance measurement was performed.**

## Implemented and exercised

The item catalog contains **30 definitions, seven rarities and eight crafting recipes**. It retains the original twelve item IDs and the existing sword/shield and staff families. Definitions provide icons, bounded native display models, requirements, statistics, values, stack limits and salvage/crafting data. Owned equipment has a unique instance ID, deterministic rolled modifiers, enhancement, condition, identification state and protection flags. Shared definitions remain separate from owned instances.

The forty-slot inventory supports stacking, categories, comparison, sorting, filtering, touch scrolling, favorites and locks. Six equipment slots update the existing player's real statistics without replacing the combat controller. Weapon/shield bonuses respect the active family. Changing gear preserves current health/stamina rather than repeatedly healing the actor; broken or unidentified gear provides no equipment bonuses.

Sanctuary has a General Merchant, Equipment Trader, Relic Appraiser and Blacksmith. Purchases, sales, identification, crafting, upgrades, repairs and salvage validate ownership, quantities, gold, capacity, protection and service access. Stock rotation follows completed expeditions. Upgrades succeed deterministically through +5. Quotes bind a request to a profile revision, retain their trusted arguments inside the session and save the validated candidate before publishing it. Stale/repeated confirmations and caller-edited price/quantity fields cannot repeat or change a quoted transaction.

Character progression uses an authored table through level 30, with modest health/stamina growth and three ten-rank talent branches. Successful extraction grants 250 XP plus 20 per normal enemy defeated; failed or abandoned runs grant none. Existing companion progression remains separate and preserved. A separate normalized-stat calculation prepares for later PvP work; it does not implement PvP or networking.

The Collection Hall adds eight equipment stands, four relic pedestals, a Rootwarden trophy wall and item/monster journal lecterns. Exhibits reference owned instance IDs without copying or removing inventory. Re-entering the Hall and restarting reconstruct those selections. Journal lecterns open their appropriate discovery filter and cannot authorize changes to a distant display stand. The existing party travels through the Hall and its Sanctuary return portal.

The version-two profile preserves valid version-one gold, inventory counts, equipment selection, companions, discoveries and expedition history. Migration occurs in memory without rewriting the old file on load. Excess legacy quantities and unknown IDs remain in a reserve; supported entries can be claimed when space becomes available. New dungeon rewards check the capacity of the full pending bag before a chest is claimed. Extraction secures loot, XP and discoveries together; later death retains secured ownership, enhancements, talents, displays and recruited companions, with the documented condition wear.

Save validation rejects incomplete version-two sections and malformed instance/reference/stat data. Writes use verified temporary files and atomic replacement with a previous valid backup. A corrupt primary can recover from a valid backup; unreadable or unsupported profiles without a usable recovery path remain preserved and read-only. A loading error must not silently replace progress with empty defaults.

## Automated results

All listed suites passed: **2,659 assertions across 27 engine invocations**. Runtime logs were inspected for script errors, warnings and resource leaks as well as process exit status. Repeated verification runs and additional exploratory probes are not counted twice.

| Suite | Passed assertions | Main coverage |
| --- | ---: | --- |
| `smoke_test.gd` | 283 | Every game resource, startup, movement, both cameras, touch routing and original portals |
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

Tests use disposable `/tmp` profiles rather than the normal `user://vaultbound/profile.json` save. Writer and reader checks run in separate engine processes. The RPG restart reader boots the actual game, reconstructs the player/party and Hall, then verifies that a subsequent failed expedition still preserves secured possessions on disk.

Integration fixtures deliberately position actors, provide known items/XP and inject controlled damage or boss-completion signals to isolate persistence and transition contracts. Boss attacks and enemy behavior are exercised in their focused suites. These results do not claim a human-completed balanced expedition. Synthetic Godot touch events verify the real input router and confirmation behavior, not touchscreen hardware delivery or physical target comfort.

The old loot tests now expect the intentional seven-tier catalog; common/reinforced tables retain their configured subsets. Count-only historical fixtures explicitly use the version-one schema, while new fixtures create canonical version-two inventory. Existing corruption, backup, ownership and progression checks remain enforced.

## Issues found and resolved

- Strict version-two validation now rejects missing companion/statistic/character/inventory/equipment/display sections and missing talent branches. A readable but partial file cannot silently erase data through default values.
- Migration retains over-capacity and unknown legacy holdings instead of truncating inventory to forty slots or discarding unrecognized IDs.
- Modifier values and player calculations use the same fractional damage convention; family-specific gear does not boost an incompatible active weapon.
- Transaction previews use trusted session records, revision checks and one-use receipts. Protected or displayed items remain owned when a sale/salvage is attempted.
- RPG touch actions commit on a completed gesture; scrolling and canceled touches do not purchase items, and two fingers confirming one preview produce one mutation.
- The inventory list clips scrolled rows, and the hidden avatar preview stops rendering. Journal interactions now route to the correct filtered journal and require a real display stand for display changes.
- Current player resources remain bounded without healing on repeated equip/unequip, and exact saved instance IDs survive travel, extraction and restart.

The editor import completed without missing project resources or GDScript parse errors. The restricted environment reported an unavailable editor TCP listener and missing Android build-tools configuration during editor setup. These environment/export messages do not prevent headless game execution and do not establish that Android export is configured.

## Remaining review and limitations

- Physical Android touch comfort, system gestures/cutouts, suspend/resume, GPU visuals, audio output, frame pacing, heat and battery use require the device checklist. APK export/signing is untested.
- Art uses native low-poly models and restrained changes to existing avatar parts. Detailed per-item armor meshes, final character animation, final sound and a rendered clipping/scale review remain outside the automated evidence.
- Loot pacing, prices, XP progression, talent balance and the full human-led dungeon loop need playtesting in both cameras. Passing logic tests is not a claim of final balance or mobile frame rate.
- Inventory has forty active slots. The recoverable reserve exists to preserve historical saves, not to provide unlimited storage for new rewards. Unknown legacy IDs stay stored until a future compatible definition or migration can handle them.
- The small talents have no respec yet. Companion gear/talents, additional classes, arbitrary multilevel navigation, extra dungeon biomes and mid-expedition save/resume are not implemented.
- Local development saves are editable and offline. Secure server-side persistence, authentication, authoritative networking, online multiplayer, player-to-player trading and guilds are not implemented.

Follow [README](../README.md) for Android import and controls, and [the test plan](test-plan.md) for commands and the physical-device checklist. Work stops after Milestone 5 pending prototype review.
