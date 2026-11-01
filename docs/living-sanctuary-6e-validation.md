# Living Sanctuary 6E validation

The frozen 6E gate passed **13,359 assertions across 80 suites and 97 separate engine processes**, with no failed invocation, script error, warning or leak. [Durable results](living-sanctuary-6e-test-results.json) contain the exact commands, counts, timings, log hashes, source identity and required input evidence. Focused development reruns are excluded. The durable JSON also preserves two earlier stopped gates and their reasons, separately from accepted totals. The [6D report](living-sanctuary-6d-validation.md) and its durable results remain unchanged historical evidence.

## Frozen source and isolation

- Base commit: `8de48c66252017597ed0f393ef9c5aec93bc8995`, plus the frozen 6E working tree.
- Semantic source: `5b9b72b3631ddce12efd06f7eafa2dc9719e3a74c2307b9430418cb7aa07ad83` over **755 files**. Opening, closing and final workspace manifests match. Scope includes project.godot, scripts, resources, scenes, assets and tests; generated .uid/.import sidecars are excluded.
- Export preset: `f8b8cc168376553830f82e90a7c2c8642fb712acf04fac2abbdb1db6393889f0`, matching the workspace. Project/Android name `0.6.0-6e`, Android code **11**. No APK export was attempted.
- Godot 4.6.3.stable.official.7d41c59c4, Linux headless Compatibility. Fresh import and a 120-frame startup preceded all suites. Processes ran sequentially with disposable XDG data/config/cache directories and explicit /tmp fixtures. Normal play storage was not used.

Only established host local-socket/Android-tools environment notices were allowed during editor import. Startup and all suite logs passed the error, warning and leak filter. Generated script sidecars do not change the semantic source identity.

## Preserved and added checks

All **70 prior suites and 86 modes** remain present, contributing **12,267 assertions**. Ten new suites contribute **1,092 assertions across eleven processes**:

| New suite / mode | Passed assertions |
|---|---:|
| `native_pet_name_test` | 112 |
| `pet_catalog_test` | 269 |
| `pet_follow_test` | 80 |
| `pet_presentation_test` | 83 |
| `pet_progression_test` | 62 |
| `pet_restart_test --write PATH` | 7 |
| `pet_restart_test --read PATH` | 7 |
| `pet_session_test` | 37 |
| `pet_ui_test` | 72 |
| `pet_world_sources_test` | 316 |
| `profile_v5_test` | 47 |

`pet_restart_test` deliberately has only explicit writer and independent reader modes, without a no-argument invocation. The complete gate includes **13 independent readers**. Every earlier restart mode and both existing preference readers remain present.

Preserved assertion counts that changed are recorded below. Schema migration expectations now target v5 while retaining genuine legacy inputs and exact historical backups. Cache tests strengthen immutable world-generation rejection; extraction fixtures use a legitimate nearby player, including an explicitly admitted sealed spring; secret-path cache invalidation uses the real Session-bound world and player; Conservatory checks replace only the obsolete future-guide expectation. Smoke discovers newly added native resources and scripts. Abyss authoring-data capture is now an explicit per-instance option rather than a static script flag, releasing its resource dependencies at shutdown while retaining all 325 visual assertions.

| Preserved mode | 6D assertions | 6E assertions |
|---|---:|---:|
| `companion_navigation_test` | 26 | 41 |
| `expedition_test` | 115 | 116 |
| `loot_cache_world_test` | 30 | 32 |
| `session_loot_test` | 75 | 83 |
| `smoke_test` | 717 | 750 |

Dungeon seeds **0–99** again pass structural validation and exact reproduction. **100 cosmetic seeds × 14 modules** repeat the established authored-transform/native-mesh bounds gate. Separately, discovery seeds **1–100** verify deterministic bounded egg/rescue plans using existing rooms without changing dungeon RNG. Actual generated-world tests verify reachable source placement, hidden-room gating, line of sight, exact source registration, real encounters and extraction.

The original player and both AI companions again traverse all eight city districts, ring sectors and both terraces, including ascent, Hold and Retreat descent. It recorded **7,067 physics frames**, player/Guardian/Mystic distances of **496.3 / 488.2 / 496.3 m**, zero companion recoveries and maximum actor step **0.089334 m**. Exact query counters remain in the durable JSON. These are traversal measurements, not FPS results.

## Transactions and world lifecycle

V1–V4 profiles migrate in memory without automatic rewrite. Tests preserve rich equipment, rolls, enhancements, loadouts, displays, recruited AI, receipts and other original fields. The first migrated save preserves exact pre-v5 bytes and earlier historical snapshots. Incomplete v5 ownership is rejected. Structurally valid unavailable species, variants, recipes, ingredients, achievements and origin identifiers remain read-only; primary and backup bytes survive loading and rejected writes. Normal gameplay normalization does not admit unavailable content.

First-secured matching memories keep their mutation seed both within pending findings and across successful extraction. Quoting, canceling, failed writes and later matching memories cannot reroll the earned appearance. One-use source/revision-bound confirmations save before installing selection, aliases or ownership. Cross-system revision changes, queued/freed terminals, moved sources, reentry, duplicate confirmations and failed writes are covered. Cosmetic transactions preserve currency, ordinary inventory, character statistics and AI party slots.

Actual encounter tests require the registered dead actor and install ordinary loot, pet findings, receipts and kill/boss state before notifications. Same-run admission failure rolls local reservations back for retry. Same-seed callback replacement cannot let an old encounter, chest, discovery, cache manager or extraction point mutate the replacement. Candidate-world callbacks retain the prior safe scene; old departure, failed-death-save and already-deferred portal continuations cannot abandon a newer run. Successful extraction commits all findings together; failed extraction keeps exact pending data and its retryable source. Death loses unsecured findings while retaining secured pets.

## Native naming and existing input

The native naming suite uses actual viewport ScreenTouch dispatch and committed Unicode/physical-key events through `Input.parse_input_event` with explicit flushing. It proves physical W and the underlying global movement action are pressed before close, then verifies movement remains quarantined until release. Direct editor-text assignment is not the typing proof. Unicode Backspace, review-before-save, coalesced text changes, two-finger confirmation, focus loss, Back during a held button, stale editor signals, failed writes, travel and reentrant appearance changes all pass.

Naming covers **72 synthetic geometry combinations** (three canvas sizes × three scales × two safe-area insets × four keyboard heights). It shares the existing native input owner and preserves exact visual/social preference bytes. The complete prior native-chat suite also passes, including its independent 72 layout cases, held-key release behavior, scoped touch bridge and callback defenses. These are synthetic native-control checks, not physical Android IME composition results.

## Cosmetic geometry and following

Native mesh faces, actual node transforms and mesh AABBs produce the following per-species geometry measurements. Natural and luminous variants share geometry. Sampled idle, follow, sit, playful and emote poses remain within the validated clearance envelope, including reduced motion. No dummy-renderer MultiMesh transform readback is used for these figures.

| Species | Mesh instances | Triangles | Animated pivots |
|---|---:|---:|---:|
| `lantern_fox` | 14 | 828 | 6 |
| `crystal_moth` | 10 | 572 | 3 |
| `mossdrake` | 13 | 696 | 6 |
| `embercap_sprite` | 12 | 768 | 3 |
| `rift_otter` | 12 | 768 | 6 |
| `rootling_guardian` | 13 | 764 | 3 |
| `moonveil_butterfly` | 12 | 768 | 3 |
| `starbound_wisp` | 7 | 312 | 1 |

The selected pet adds no collider, light, particle emitter, combat target, gameplay action or AI slot. The same native builder supplies an isolated on-demand preview. Production selection is exercised through the actual Game-owned presenter across Sanctuary, generated Abyss and Collection Hall travel. Tests walk obstacle corners, both terrace ramps and a generated doorway, reject undiscovered/culled rooms and require hidden supported recovery before relocation. Old worlds release their presenters and signal ownership. The maximum observed visible pet step was **0.200000 m**. Obstacle and ramp routes required no recovery. The three Sanctuary recoveries correspond to the three deliberate leader relocations used to test hidden recovery, as recorded below. Pose envelopes and complete counters are in the JSON.

| World phase | Decisions | Physics queries | Max queries / decision | Recoveries | Deliberate leader relocations |
|---|---:|---:|---:|---:|---:|
| `sanctuary` | 188 | 1009 | 6 | 3 | 3 |
| `rootbound_abyss` | 67 | 388 | 6 | 0 | 0 |
| `collection_hall` | 2 | 7 | 5 | 0 | 0 |

Decisions run at a bounded 10 Hz with at most six physics queries per decision and 128 retained path points. Separate manually stepped **30/60/120 update-rate fixtures** check timing and bounded catch-up behavior; they do not measure achieved FPS or GPU cost. The resource counts are geometry evidence, not rendered draw calls, sustained performance or thermal measurements.

## Limits

No optional capture, permission retry, APK export or physical-device test occurred in this stage. Headless checks do not establish rendered art quality, Android keyboard composition, touch comfort, sustained FPS or thermal behavior. The [Android checklist](living-sanctuary-android.md) remains the manual acceptance record. The [pet behavior guide](living-sanctuary-pets.md) documents the current offline progression and cosmetic boundaries; no 6F exchange or online ownership service is added.
