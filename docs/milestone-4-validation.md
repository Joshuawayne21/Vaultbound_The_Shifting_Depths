# Milestone 4 validation

Validated on **2026-10-31** with **Godot 4.6.3 stable**, Linux headless, GDScript and the Compatibility project configuration. This report covers local AI adventurers and regression checks for the existing game. **No physical Android device, rendered GPU review, APK export/signing or mobile performance measurement was performed.**

## Implemented and exercised

The persistent game shell now owns a three-member party: the existing human leader and up to two recruited AI actors. Rowan, the Guardian, and Lyra, the Mystic, reuse the existing health, stamina, weapon data, combat state machine and damage service. The roster records human/AI occupant types; this is preparation for future authority changes, not multiplayer implementation.

The Sanctuary Tavern saves recruitment/dismissal through the existing verified profile store. The new optional companion field migrates older profiles without changing secured gold, equipment, items, discoveries or expedition statistics. Dismissal retains progression. Successful extraction atomically awards recruited companions 150 experience plus 10 per kill; failed writes, deaths and abandonment grant none. Level caps at 20, with modest proficiency-based accuracy improvement and no gear/talent system.

Companion decisions include following, formation, investigation, target acquisition/approach, attack, dodge, support, retreat, revive, stuck recovery and return to party. Reaction intervals/jitter and accuracy are configurable. Direct commands constrain pursuit; dangerous telegraphs and unsafe rescue approaches provide valid safety exceptions. The Guardian uses sword attacks, shield blocking and interception; the Mystic uses staff attacks, ranged spacing and interruptible cooldown healing. No external language-model service is used.

Navigation combines the existing room graph with bounded local A*, cached collision/floor probes and hazard checks. Actual movement crossed three room connections in each of seeds **7, 23 and 81**, including turns. The focused suite also covered solid obstacle detours, closed/revealed secret passages, danger detours and safe recovery. Normal refresh is 0.65 seconds; moved goals cannot cause more than four replans per second. Recovery refuses active combat and checks floor, capsule clearance and nearby threats.

Downed members require a nearby, visible rescuer and a damage-interruptible channel. Defaults are 3 seconds, 2.4 m reach, 35% restored health, 30 seconds to bleed out and two completed revives per member per expedition. Duplicate rescue channels cannot revive one target twice. An exhausted or bled-out member waits for Sanctuary recovery. A wipe ends the expedition once and preserves secured progression. In this offline prototype, human-leader bleedout also ends the run to avoid leaving the player stranded watching surviving AI indefinitely; solo lethal recovery remains unchanged.

The Android interface provides party portraits, names, roles, smoothed health, downed/bleedout state, revive progress, manual revive prompts, five commands and recruitment/dismissal. Its existing overlay manages all modals together. Menus pause the player, companions and world logic while static floor/obstacle collision remains queryable for safe recruitment placement. Closing a downed leader's menu resumes living allies without restoring the leader prematurely.

## Automated results

All listed suites passed: **1,795 assertions across 18 engine invocations**. Runtime logs were inspected for script errors and resource leaks, in addition to process exit status.

| Suite | Passed assertions | Main coverage |
| --- | ---: | --- |
| `smoke_test.gd` | 228 | All game resources, startup, movement, cameras, touch routing and original portal round trip |
| `combat_test.gd` | 177 | Existing sword/staff combat, health/stamina, enemy lifecycles and solo death |
| `ui_layout_test.gd` | 247 | Existing combat control geometry, multitouch ownership, release/cancel and focus behavior |
| `dungeon_layout_test.gd` | 480 | 100 validated seeds, all 14 modules, room connectivity, collision and rejected malformed layouts |
| `loot_persistence_test.gd` | 46 | 5,000 loot samples, atomic saves, backup/read-only recovery and preserved precision |
| `rootwarden_test.gd` | 53 | Boss attacks, warnings, phases, modifiers, walls, deduplication and death |
| `expedition_test.gd` | 114 | Generated dungeon, loot, awareness, hazards, boss reward, extraction and later death |
| `expedition_ui_test.gd` | 19 | Minimap, inventory/results, notices and modal isolation |
| `persistence_restart_test.gd`, write/read | 8 + 13 | Extracted progress survives a separate engine process and later death |
| `party_test.gd` | 88 | Recruitment, save rejection, formation/orders, revive interruption/limits, actual leader rescue, randomized encounter assistance, camera switching, extraction, wipe and bleedout |
| `party_ui_test.gd` | 137 | Actual Tavern touch recruitment/dismissal, safe spawn beside benches, three landscape sizes, commands, modal pause and downed/revive routing |
| `companion_behavior_test.gd` | 38 | Autonomous shield reduction/stamina, sword/staff attacks, Mystic healing/cooldown/interruption, delayed decisions, imperfect aim, order/cover constraints and Rootwarden warning avoidance |
| `companion_navigation_test.gd` | 26 | Physical traversal across three seeded layouts, obstacles, secrets, hazards, planning limits and safe recovery |
| `party_targeting_test.gd` | 38 | Enemies/boss/hazards target living party members, locked telegraphs, downed exclusion, per-target receipts and transient effect cleanup on travel |
| `party_persistence_test.gd` | 70 | Legacy migration, strict validation, recruit/dismiss, failed writes, extraction-only XP and all 20 level/proficiency save round trips |
| `party_persistence_test.gd`, write/read | 5 + 8 | Recruited identities/progression and secured possessions survive separate engine invocations |

Tests use disposable `/tmp` profiles and do not alter the normal `user://vaultbound/profile.json` save. Integration fixtures deliberately reposition actors, shorten configurable revive time and inject controlled damage to isolate transitions and failure paths. The navigation suite moves actors through the real physics world without relocation across its tested routes. These checks do not claim a human-completed, balanced expedition or measured Android frame rate.

The original expedition tests still validate at least 100 structurally connected, nonoverlapping seeds. The additional companion navigation sample covers three layouts, not every generated layout. Roster persistence uses separate writer and reader engine processes, not only a reload of an in-memory dictionary.

## Issues found and resolved

- Direct orders previously could leave stale movement/healing intentions until a later decision. Orders now immediately clear those intentions; interrupted healing retains its spent stamina and cooldown.
- A Mystic holding a charged attack now continues to observe major telegraphs and can cancel/dodge when its ordinary action rules allow.
- Attack-order admission uses the companions' pursuit range, preventing acceptance of an order the AI would immediately reject as too distant.
- Manual revive selection filters line of sight before choosing the nearest ally. A blocked nearby ally cannot hide a slightly farther reachable rescue, and blocked-only prompts are suppressed.
- Recruitment beside the Tavern's benches exposed unsafe raw formation placement. Placement now validates a recovery landing, and paused Sanctuary collision stays active so those queries can see the floor and obstacles.
- Living companions keep enemy/boss/hazard decisions active while the human leader is downed. Party-wide warnings and damage retain one receipt per target per cast.
- Companion effects/projectiles are owned by the active world rather than the persistent party, preventing leftover effects from crossing scene transitions.

The editor import completed without missing project resources or GDScript parse errors. The restricted cloud environment reported inability to open its editor TCP listener and a missing Android `build-tools` directory. Those are environment/export-setup messages; headless game and test execution do not require either service. They do not establish that Android export is configured.

## Remaining review and limitations

- Physical Android multitouch delivery, touch comfort, cutouts/system gestures, suspend/resume behavior, GPU visuals, sound output, frame pacing, heat and battery use remain manual checks.
- Companion behavior is a bounded local state/utility prototype. Complex terrain, arbitrary stairs/multiple navigation levels, dynamic terrain rebaking and advanced tactical planning are not implemented.
- The authored flat-room navigation sample cannot prove every future seed/prop arrangement. Report a stuck follower with its seed, room and command so the layout can be reproduced.
- Combat balance and complete human-led expeditions with both companions still need playtesting. Finite reaction delays and imperfect aim intentionally allow mistakes; no perfect-reaction AI is claimed.
- Extraction restores the recruited roster, including downed/separated companions. There is no permanent companion death, companion gear/talent tree, extra class or mid-expedition save/resume.
- Saves are local and offline. Server authority, authentication, replication, online human party members and cloud synchronization are not implemented.

Follow the import instructions in [README](../README.md) and the detailed [Android review checklist](test-plan.md). Work stops at Milestone 4 pending prototype review.
