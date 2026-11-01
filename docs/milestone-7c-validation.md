# Milestone 7C validation

The frozen full gate passed **19,337 assertions across 97 suites and 117 separate test processes**, plus a fresh import and 120-frame startup. All accepted runtime logs exited cleanly without script errors, warnings or leaks. [Machine-readable results](milestone-7c-test-results.json) preserve exact arguments, timings, log hashes, source identity, reader modes and development evidence. Focused attempts and controlled diagnostic runs are excluded from the accepted totals.

## Frozen source and preservation

- Base commit `55010cdec8922372640fb4010563b0a1122e7377`, plus the reviewed 7C changes.
- **795 semantic files**, SHA256 `0d017594825a66eb7181d59127252b86cd38335659e961cc3e73aae111833e0e`. Opening, closing and final workspace manifests match. Scope is `project.godot`, scripts, resources, scenes, assets and tests; generated `.uid`/`.import` sidecars are excluded.
- Export preset SHA256 `7b904cb5b912a9db95c337d16639910c48a1b2844a3360e9c37aacbab41dbb2b`; project/Android version **0.7.0-7c**, Android code **14**, profile schema **6**.
- Godot **4.6.3.stable.official.7d41c59c4**, Linux headless, Compatibility configuration. Source contains **232 GDScript files, 59 scenes, 473 resources, 7 shaders and 19 SVG assets**.
- Every engine ran sequentially from a copied snapshot with disposable XDG data/config/cache and `/tmp` save fixtures. Normal play storage was not used. There are **16 independent reader processes**.

Import recorded only the established sandbox local-socket and missing Android build-tools notices. Runtime checks retain the strict error/warning/leak filter. The full gate includes every prior 6F suite/process and the 7B capital suite: **90 preserved suites / 109 invocations**, plus **7 new suites / 8 invocations**. Earlier validation documents remain unchanged; their counts are not added again as separate runs.

## Changed files and behavior

- `depth_policy.gd`, its resource and `depth_progression.gd` define bands through Depth 50, room budgets and bounded health/damage/encounter-DM/extraction-XP factors. `profile_store.gd` adds the small v6 namespace and exact migration backups; `inventory_model.gd` accepts the new source version without changing item ownership formats.
- `expedition_session.gd` issues a detached floor policy, admits only available unlocked depths and commits unlocks in the existing extraction transaction with loot, pet findings, XP and statistics. Failed writes remain retryable; death, abandonment and repeated callbacks cannot award a new unlock.
- `dungeon_generator.gd`, `abyss_level.gd`, `encounter_manager.gd` and `monster_rewards.gd` add configured 6–24-room generation, deterministic separate streams, immutable world policy and once-only floor scaling. The old generator API remains available and its original seeded output is retained.
- `game.gd`, `sanctuary_panel.gd`, `hud.gd` and `expedition_overlay.gd` extend the physical Rootbound review card with depth selection, eligibility and issued-floor displays. Source, gesture, candidate and Session identity are revalidated through deferred travel. The UI accurately labels encounter DM and extraction XP; ordinary chest and item tables remain unchanged.
- `pet_follower.gd` now bounds a visible interpolation step after a slow rendered update. This targeted regression fix adds no physics query, decision or gameplay state. Existing normal-rate following and the original visible-step acceptance ceiling remain covered.
- Seven new suites and explicit retained-fixture adaptations cover the new contracts. Release metadata, [depth rules](dungeon-depths.md), README and [Android instructions](milestone-7-android.md) document the stage. No semantic source file was removed.

## New checks

| Suite / mode | Assertions |
| --- | ---: |
| `depth_policy_test` | 283 |
| `profile_v6_test` | 78 |
| `depth_session_test` | 34 |
| `depth_restart_test --write` | 4 |
| `depth_restart_test --read` | 6 |
| `depth_dungeon_test` | 793 |
| `depth_portal_ui_test` | 70 |
| `depth_travel_guard_test` | 60 |

The new suites exercise rich v1–v5 migration, exact old backup preservation, higher legacy unlock retention, malformed/unsupported metadata protection, initial locked Depth 2, atomic unlock/reward/XP commit, failed-save retry, death/abandonment and separate-process restart. Public previews/snapshots cannot alter issued policy. Runtime tests change the shared depth-policy Resource after admission and verify frozen health, damage, encounter DM, extraction XP and completion behavior. This does not claim arbitrary live catalog or drop-definition hot reload.

Configured generation validates **240 layouts**: 20 seeds at each boundary depth **1, 5, 6, 10, 11, 15, 16, 20, 21, 30, 31 and 50**, plus exact **6-, 9-, 15- and 24-room fallbacks**. Checks include deterministic reproduction, no overlap, connectivity, required roles, optional branches, retained BFS distance semantics and valid actor/room resources. The unchanged legacy **100-seed** suite also passes. Configured generator version 2 and legacy version 1 are deliberately distinct.

Depth 50 fixtures exercise actual configured enemies, Rootwarden and pooled root hazards, including later activation, culling, camera switches and once-only rewards. Existing combat, timing, range, cooldown and capped-actor tests pass. The retained actual expedition test now proves that a real Rootwarden death leaves Depth 2 locked; failed spring extraction keeps it locked; successful source-bound extraction and an independent store reload retain exactly the earned unlock and possessions.

Portal tests use the existing touch surfaces and modal ownership. They cover 18 canvas/scale/inset layouts, held-Enter cancellation when selection changes, locked/unavailable reasons, deferred route capture, actual selected-floor travel, both cameras and stale callback/candidate replacement. The viewport/footer checks retain readable selector targets and detail text. These are simulated native input checks, not physical Android touch approval.

## Preserved coverage and explicit fixture deltas

| Preserved mode | Previous assertions | Current assertions |
| --- | ---: | ---: |
| `companion_navigation_test` | 41 | 43 |
| `expedition_test` | 116 | 117 |
| `pet_follow_test` | 80 | 84 |
| `pet_world_sources_test` | 318 | 317 |
| `smoke_test` | 760 | 774 |
| `social_ui_test` | 96 | 98 |
| `starter_items_integration_test` | 107 | 108 |

The table compares the durable 6F full gate, with the 7B capital suite added to preserved coverage. Smoke grows from 760 in 6F to 770 in 7B and 774 in 7C as scripts/resources are added. `expedition_test` adds five actual-source unlock checks, but its configured Depth 1 route visits two fewer distinct rooms: old-only rooms 8, 9 and 10 are replaced by room 7. The unchanged visit helper runs discovery/current-room and enemy-budget checks for each visit, giving four fewer dynamic assertions and a net count change of **116 to 117**. No visit assertion was removed. `companion_navigation_test` gains two explicit configured-secret fixture checks while preserving all original legacy physical traversal seeds. `pet_follow_test` gains four deterministic slow-update/continuation checks. `social_ui_test` adds two native-audio ownership checks while retaining its 96 functional assertions. `starter_items_integration_test` adds a full encoded-byte/profile-intent check while retaining all discrete ownership and direct equipment/character/DM comparisons, as explained below. `pet_world_sources_test` has one fewer dynamic geometry assertion because configured seed 211 generates one fewer discovery source; its source, placement, lifecycle and anti-duplication assertions remain intact.

Other fixture edits change only legitimate schema/generator assumptions: v3/v4/v5 migration comparisons account for the additive depth namespace; historical pre-v5 bytes coexist with the genuine new pre-v6 backup; actual Game secret searches use configured Depth 1; actual room cosmetics use the configured decoration stream. Standalone legacy generation/visual checks remain unchanged. All full-profile, inventory identity, protected-file and callback assertions remain.

The real player, Guardian and Mystic again traverse all eight Sanctuary districts and both terraces across **7,045 observed physics frames**, with **zero companion recoveries** and maximum actor step **0.089334m**. Existing native chat/pet/exchange input, equipment, crafting, enhancement, collection, recruitment, revive, treasure, portals, local exchange isolation and restart suites all pass. The 7B capital suite still verifies native geometry and **4,080 camera-transition physics frames** at both orbit-pitch extremes and every quality.

## Review corrections and pet slow-frame regression

Before the full gate, review tightened frozen policy use through later world activation/completion and revalidation around fade/callback boundaries. Two early focused attempts then exposed test-only GDScript issues: assignment through a constant Resource preload and an inferred boolean derived from Dictionary fields. Typed local aliases/annotations corrected those fixtures without removing their assertions. These are separate from the production fix below. The first full gate later stopped at its 94th invocation because the new normal Rootbound card omitted the existing disclosure that generated modifiers are unknown. The original UI assertion was retained and the concise disclosure restored within the existing information row. That stopped full run is preserved separately and contributes nothing to the accepted totals.

A later tail check isolated one raw floating modifier mismatch in `inventory[17].modifiers.lifesteal`: live bytes `3ab4c876be9f8a3f` versus decoded bytes `39b4c876be9f8a3f`, adjacent doubles representing approximately 0.013. A recursive comparison found no other difference in inventory, equipment, character or Depthmarks. The existing writer already verifies exact full-precision primary bytes and normalized decoded intent. The fixture now checks that complete contract, every discrete field, direct equipment/character/DM equality and unchanged live inventory bits. No production value, tolerance, modifier roll or save precision was changed.

An affected regression run observed a **0.321674m** visible pet sample against the existing **0.30m** limit. That original run did not record the render delta. An instrumented rerun passed and did not by itself explain the failure. A separate controlled 70ms scheduling stall then reproduced a **0.439875m** step in a single rendered update at delta **0.073312s**, with observer render/physics gaps both one. The trace matched interpolation along the already validated trail segment, rather than hidden recovery or merged samples in that reproduction.

A deterministic native-follow regression independently applied a 0.07s update and failed the old implementation at **0.420000m**. The reviewed fix approaches the existing validated interpolation point by at most **0.28m per update**. In the accepted gate it measures **0.280000m**, then resumes following with **0 additional recoveries**, **10 decisions** and at most **6 queries per decision**. Normal 30/60/120 simulated-rate checks remain intact. Actual world traversal records maximum visible step **0.193138m**, below the unchanged 0.30m ceiling. No diagnostic instrumentation or real sleep was added to game source or the committed regression.

## Native audio teardown boundary

The second full gate stopped at invocation 107: the social UI suite passed all 96 functional assertions but emitted an ObjectDB leak warning at process exit. Six unchanged verbose attempts then passed and did not reproduce that warning. A separate controlled 90ms stall reproduced leaked `AudioStreamWAV` and `AudioStreamPlaybackWAV` references even though Game was already freed: the fixture's three physics waits had spanned only one rendered update.

Weak-reference probes identified the exact `OptionalGardenWind` resources. Production already stops playback and clears the stream on world exit; the native audio system can finish retiring those references later. An initial probe directly accessed native objects within an awaiting function and failed its observation bound; it is retained as diagnostic evidence, not accepted production behavior. Synchronous helpers now return only WeakRefs or booleans, so no temporary native reference crosses an await.

The narrow fixture correction preserves ambient sound, all 96 existing functional checks and the strict leak filter. It adds two assertions and observes Game deletion plus actual stream/playback retirement within at most 120 process boundaries. Under the same controlled 90ms stall, the corrected fixture passed all 98 checks and observed retirement after six render boundaries and eleven physics ticks. No timed sleep, production audio change or warning suppression was committed. The ordinary targeted suite and remaining tail passed before the fresh accepted full gate. All failed gates and probes remain separately hashed in the machine-readable report.

## Limits and manual acceptance

These checks establish headless logic, loading, native geometry, collision and simulated-input behavior. They do **not** establish rendered art quality, physical Android keyboard/touch behavior, GPU performance, sustained FPS or thermal behavior. No screenshot/video capture, APK export, public service, hosting cost, paid asset or payment processing occurred. Follow the [Milestone 7 Android checklist](milestone-7-android.md) on real devices before approving mobile presentation and performance.

7C implements Rootbound floor progression, longer configured layouts and bounded scaling of existing encounters. New biome mechanics, bosses, hives/hordes, Ancient encounters, early checkpoint extraction and later Milestone 7 stages remain separate. There is no live ranked backend, leaderboard or authenticated online progression. Local files remain development persistence, and an active run cannot resume after closing the game.
