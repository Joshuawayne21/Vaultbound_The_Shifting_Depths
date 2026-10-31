# Milestone 3 validation

Validation uses **Godot 4.6.3** in the Linux cloud workspace. The Milestone 2 baseline remains in Git at `e85923d`; its player, combat, camera, touch and portal tests are retained.

## Automated results

**1,371 assertions passed** across the retained and new suites. Final suite processes exited with code 0, and their logs were inspected for parser, resource, runtime and shutdown errors rather than relying only on process exit status.

The final editor import also exited successfully with no project parser/resource errors, and a 180-frame main-scene startup exited cleanly without runtime errors or warnings. The import's restricted debug-listener and missing Android build-tools messages are described below.

| Suite | Passed | Coverage |
| --- | ---: | --- |
| `tests/smoke_test.gd` | 214 | All game resources, Sanctuary, player/camera continuity, touch ownership and existing portal routes |
| `tests/combat_test.gd` | 177 | Existing weapons, abilities, damage rules, enemy AI, arena reset and death recovery |
| `tests/ui_layout_test.gd` | 247 | Three landscape layouts, simultaneous touch roles, keyboard bindings, canceled holds and pause/resume |
| `tests/dungeon_layout_test.gd` | 480 | 100 seeded layouts, negative structural cases and physical checks on all 14 authored modules |
| `tests/loot_persistence_test.gd` | 46 | 5,000 seeded loot rolls, item/rarity contracts, atomic save validation and corruption/version recovery |
| `tests/rootwarden_test.gd` | 53 | All boss attacks, telegraphs, damage windows, Fury, modifiers, obstruction, deactivation and death |
| `tests/expedition_test.gd` | 114 | Actual generated-run interactions, treasure, awareness, secrets, encounters, extraction, results and secured-loot death preservation |
| `tests/expedition_ui_test.gd` | 19 | Discovery map, secured/unsecured pack behavior and modal input isolation |
| `tests/persistence_restart_test.gd -- --write ...` | 8 | Extracted-profile fixture written by the first engine process |
| `tests/persistence_restart_test.gd -- --read ...` | 13 | Persisted gold/equipment/discoveries/statistics loaded by a new engine process, then retained after dungeon death |

The layout suite validates **100 seeds**, exceeding the requested 20. It checks 8–12 rooms, guaranteed connected main routes, distinct grid cells, reciprocal adjacent connections, a reachable boss/extraction, treasure branches and optional hidden passages. All 14 native module variants are selected in the sample. Physics checks verify spawn clearance and actual doorway opening/closure; these are separate from topology assertions.

The expedition suite follows the complete system loop using the real scene shell, player, chest, boss and extraction implementations. It repositions the character to exercise generated room activation and uses controlled damage to finish the boss. The separate Rootwarden suite advances attacks through normal physics timing, including dodge and cover avoidance. These checks do not claim a human playthrough, final difficulty balance or rendered visual quality.

Persistence fixtures live under isolated `/tmp/vaultbound-m3-*` paths. The restart test launches **two separate Godot processes**. Extracted gold, equipment, materials, collectible discovery and completed-run statistics survive the restart; a subsequent death removes only its new unsecured bag. Save-failure tests retain the live bag and keep extraction retryable.

## Issues found and corrected during review

- Generation validation now rejects malformed route IDs, mismatched required-room references and doors leading to nonexistent connections.
- Corrupt or unsupported orphan backups are preserved and made read-only instead of silently creating a writable empty bank.
- Real expedition durations exposed JSON float precision loss during strict save read-back verification. Saves now use full precision, with a fractional-duration regression.
- Shared combat receipt/counter state now belongs to the scene tree, preserving IDs across transitions while avoiding a Godot static-script retention warning at shutdown.
- Boss deactivation cancels pending telegraphs immediately; reactivation gives a fresh warning. Boss-room activation suppresses ordinary encounters, and dormant room floors remain registered for safe transitions and re-entry.

## Remaining manual checks and limitations

- **No physical Android testing was performed.** Touch delivery, visual readability, audio, camera/telegraph presentation, frame pacing, thermal behavior and battery consumption require the device checklist in `test-plan.md`.
- GPU visual review was unavailable in the cloud socket-restricted environment. Headless rendering does not establish the appearance of the jungle, water, mist or lighting.
- Android SDK build-tools/signing were unavailable; APK export and installation were not tested. Editor-only debug-listener restrictions are environment warnings, separate from project syntax/resource failures.
- Generation uses one floor of authored grid modules; room geometry remains resident while nearby visibility/simulation and active enemies are bounded. This is a small offline expedition prototype, not an endless streaming world.
- Secured equipment selects existing sword/staff styles; it does not introduce new stat bonuses or an equipment-stat system. Unsecured expeditions are intentionally memory-only and lost on exit/death/retreat.
- No multiplayer, AI teammates, additional biome or marketplace is implemented or represented as complete.

Run commands and the Android playtest sequence are documented in `test-plan.md` and the repository README. Milestone 3 stops for review before further gameplay expansion.
