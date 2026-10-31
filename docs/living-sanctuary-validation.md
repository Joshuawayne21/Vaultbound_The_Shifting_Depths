# Living Sanctuary validation

**Completed 6B gate: 10,904 assertions passed across all 62 suites in 75 separate engine invocations.** Fresh import/startup, ten independent readers, all 100 dungeon seeds and actual city traversal passed. [Durable results](living-sanctuary-test-results.json) record every command, count and source signature. Android/GPU/APK validation remains outstanding.

## 6A — preservation baseline

The initial gate passed on 2026-10-31: fresh editor import, a separate 120-frame main-scene startup, and **686 smoke assertions**. This is a baseline for the Living Sanctuary work, not evidence that its later stages are complete.

The gate used a frozen archive of local commit `d77e4d658a8e64bf3a742f58d7c8e40cfdeceb52` with **Godot 4.6.3.stable.official.7d41c59c4**, Linux headless, Compatibility. Opening and closing manifests match all **673 semantic source files** at SHA-256 `05dc770e1535140c23172bdd4824780f1d3671743eea233a2045edb3b04435af`. The manifest also matches the previously tested `4ae9c46cc2984b4a45b1a7606cdfe857bb2c809e` source. The intervening documentation changes do not change gameplay, resources or tests.

| Invocation | Result | Evidence |
| --- | --- | --- |
| Fresh editor import | Exit 0; no project/script failures | `/tmp/vaultbound-living-6a-baseline/import.log` |
| Main-scene startup, 120 frames | Exit 0; clean log | `/tmp/vaultbound-living-6a-baseline/startup.log` |
| `smoke_test.gd` | 686 assertions; exit 0; clean log | `/tmp/vaultbound-living-6a-baseline/smoke_test.log` |

The import reported the existing host socket-creation notices and missing Android build-tools directory. These environmental notices were recorded separately from project errors. The startup and smoke logs contain no errors, warnings, failed assertions or leaked-object messages. No Android export was attempted.

Every process used disposable `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` directories below the evidence directory. Normal play storage was not used. The source archive is `/tmp/vaultbound-living-6a-source`; `source-opening.json`, `source-closing.json`, `setup.json`, `results.json` and `summary.json` are in `/tmp/vaultbound-living-6a-baseline`.

The reproducible baseline command was:

```sh
python3 /tmp/vaultbound-56-validation-gate.py \
  /tmp/vaultbound-living-6a-source \
  /tmp/vaultbound-living-6a-baseline smoke_test \
  --import-project --startup \
  --reference /tmp/vaultbound-56-final-release-reference.json
```

## Preserved regression inventory

All **58** existing `tests/*_test.gd` suites match the suite identities in [the durable Milestone 5.6 results](milestone-5.6-test-results.json). That record contains **71** invocations, including every existing writer/reader mode. Its prior result of **10,519 assertions** is historical evidence on the matching baseline source; it is not added to the 6A smoke total or represented as a new full regression run.

The old `/tmp/vaultbound-56-final-suite-inventory.json` predates the final catalog and presentation merges and lists 53 main-tree suites. The final runner discovers the current suites, preserves its known restart modes, and explicitly adds the category integration reader. The durable result and current discovery, rather than that older inventory's headline count, establish the 58-suite/71-invocation baseline.

`dungeon_layout_test.gd` already validates and reproduces every seed from **0 through 99**, checks distinct adjacent connected cells and the entrance/boss/extraction route, then checks generated module collision. It must run again in the final Living Sanctuary regression; the 6A smoke gate did not rerun those 100 seeds.

## Existing coordinate-fixture audit

This was a read-only audit; no test fixture changed in 6A.

| Existing fixture | World dependency | Preservation requirement |
| --- | --- | --- |
| `collection_world_test.gd` | Old approach points; floor helper ignores supplied elevation and assumes `y=0` | Follow relocated authored approaches and their elevations; retain capsule clearance, groundedness, upward surface normals and all four service identities |
| `static_visual_batcher_test.gd` | Old approach points and zero-height floor hits | Follow authored approaches; retain exact collider identity/transform equality and measured draw reduction before/after batching |
| `visual_integration_test.gd` | Old Hall-side sample; crystal directly over the origin and its specific camera clearance band | Follow explicit authored geometry if moved; retain both-camera clearance at every quality, opaque portal obstruction and absence of player blockers |
| Commerce, Tavern and portal interaction fixtures | Most positions follow live service nodes, but several offsets use world `+Z` or `+X` | Use local approach offsets if services rotate; retain actual proximity, visibility, interaction and transaction checks |
| Controlled combat/party fixtures | Clear zero-height central floor, approximately `x=-2…12`, `z=0…12` | If obstructed by new geometry, translate each complete fixture together, retaining relative distances, headings, cover, timing and hit checks |
| Explicit arrival assertions | Dungeon return near `(0,0,-5.4)`; death recovery near `(0,0,8)` | Keep these existing contracts and the remaining authored spawn transforms |

Sanctuary tests discover services and portals primarily through groups and destination IDs, not private world child names. Dungeon coordinates and independent combat-arena fixtures do not need changes for the Sanctuary expansion.

## 6B — connected city gate

**All 10,904 assertions passed across all 62 suites in 75 separate engine invocations.** Every final invocation passed on its first attempt against the frozen source; no development failure, focused repeat or earlier checkpoint is added to this total. Fresh editor import and a separate 120-frame startup also passed. All test and startup logs contain no errors, warnings, failed assertions or leaked-object messages. Import records only the known host socket-creation and missing Android build-tools notices separately.

| Complete gate coverage | Suites / invocations | Passed assertions |
| --- | ---: | ---: |
| Preserved Milestone 5.6 suite identities and process modes | 58 / 71 | 10,531 |
| `city_navigation_test.gd` | 1 / 1 | 68 |
| `city_surface_test.gd` | 1 / 1 | 21 |
| `sanctuary_ui_test.gd` | 1 / 1 | 59 |
| `sanctuary_world_test.gd` | 1 / 1 | 225 |
| **Complete 6B total** | **62 / 75** | **10,904** |

The gate ran on **Godot 4.6.3.stable.official.7d41c59c4**, Linux headless, Compatibility, using `/tmp/vaultbound-living-6b-frozen-source`, copied from the frozen working tree based on commit `6939d7e6955719740db682c0b825bb9fba500b69`. Opening and closing manifests match all **683 semantic source files** at SHA-256 `d134c4aedba5cf4603c10cab6cd233fc16080c157e0868015a163e83be8678ea`. A complete recomputed workspace manifest matches that same source after the gate, including file additions/deletions; no runtime or test drift occurred. The source scope is `project.godot` plus scripts, resources, scenes, assets and tests, excluding generated `.uid`/`.import` sidecars.

Project and Android version names are **`0.6.0-6b`**, with Android version code **8**. The separate export-preset SHA-256 is `3fdb1839e169360694381a5fa806070b8e484c7b93a8b42a7bcecb6c1e29e48b`; frozen and workspace presets match exactly. This is metadata verification, not an APK export result.

Every process had isolated disposable XDG data/config/cache storage, including import and startup. Every old reader followed its writer in another engine process; ten reader invocations ran. Explicit fixture profiles remain under `/tmp`. Normal play data was not used. Evidence is `/tmp/vaultbound-living-6b-final-regression/`, and [the durable results](living-sanctuary-test-results.json) include all 75 commands/counts, setup notices, opening/closing source identity and navigation metrics. `dungeon_layout_test.gd` passed structural validation and exact reproduction for every seed **0–99**, along with its native module collision checks.

The actual-city test drove the original player controller through touch input while both original companions followed. It covered all eight district approaches, the full ring, the opposite-city crossing, both 0.8-metre terrace ascents, raised Hold positions and Retreat descents. Across **7,067 observed physics frames**, the player traveled **496.33 m**, Guardian **488.24 m** and Mystic **496.27 m**. Both companions recorded **zero recovery teleports**; the largest observed actor step was **0.089334 m**. Replans were 165/270/233 and geometry probes 18,796/14,095/11,141 for player/Guardian/Mystic. These are traversal and bounded-work counters, not rendered FPS or Android performance measurements.

### Focused development check — separate evidence

Before the complete gate, the focused world gate passed **1,051 assertions across five invocations**, plus fresh import and a separate 120-frame startup. These repeated checks are excluded from the complete total above.

| Focused suite | Passed assertions |
| --- | ---: |
| `sanctuary_world_test.gd` | 225 |
| `smoke_test.gd` | 695 |
| `collection_world_test.gd` | 36 |
| `static_visual_batcher_test.gd` | 32 |
| `visual_integration_test.gd` | 63 |

This gate ran against `/tmp/vaultbound-6b-world-dev2-source` with isolated XDG storage. Opening and closing semantic source manifests match at `b01966d36691c9ea2c903deaf6c213127199083ca456c0581476c75fcb656fb6`. Evidence is `/tmp/vaultbound-6b-world-dev2/`; all five game logs and startup were clean. Import reported only the same host socket/Android-tools notices as 6A. This is focused development evidence, not a final full-regression total. An earlier development attempt exposed two errors in the newly written test itself (StringName ordering/equality and a typed conditional array); those were corrected, and that failed attempt is excluded.

The existing commerce fixtures now use a shared test helper that resolves the live world's service approach. Tavern and outward portal fixtures use the authored point-of-interest approaches. Collection clearance casts relative to the expected elevation and places its original capsule above the measured floor; batching checks compare the hit against each authored floor height. The original service identities, clearance/normal checks, collider comparisons, transaction checks and save assertions remain intact. Central combat coordinates, heart-crystal obstruction limits and all four arrival transforms remain unchanged.

Only two old fixtures interacted with an outward Sanctuary portal: smoke's dungeon passage and RPG integration's Collection Hall visit. They now assert that information opens before travel and then activate the real Enter control. Smoke retains repeated interaction and repeated Enter attempts before its one-world/one-player assertions. Existing dungeon, arena, Hall and expedition return interactions remain immediate and retain their previous assertions.

The new `sanctuary_world_test.gd` checks actual city and ring floors, all eight district and point-of-interest approaches, the four original spawn transforms, both terrace elevations, real nearby service/Tavern authorization, camera clearance on district/ramp samples and all four playable outward routes. It checks both compositions; third person samples four orbit headings while isometric uses its authored fixed heading. Its controlled setup placements establish geometry and interaction, not walking. The separate `city_navigation_test.gd` owns actual player/two-companion movement, and `city_surface_test.gd` owns slope/ledge/navigation safety. `sanctuary_ui_test.gd` owns map/card gestures, source expiry, mobile canvas geometry and presentation-only save preservation.

## Gates for subsequent stages

Each completed implementation stage will record its exact source manifest, focused suites, assertion counts, log review and limitations here. A final gate must run all 58 preserved suites, every independent restart mode and the new Living Sanctuary suites, including the existing 100-seed dungeon validation. Writer/reader pairs run sequentially because several fixtures use explicit shared `/tmp` paths. Imports and startup processes need the same XDG isolation as tests because autoloads initialize before a test can redirect storage.

Coordinate fixtures may change only to follow the authored world and service positions. Preserve their behavioral assertions: valid walkable floors, clear approaches, actual nearby services, camera clearance, one active world, retained player identity, saved ownership and safe portal arrivals. Fixed spawn expectations remain contracts unless explicitly changed in the implementation plan. Do not weaken geometry, combat, economy or persistence assertions to make a relocated world pass.

Headless checks establish logic, resource, physics and simulated input contracts. They do not establish rendered GPU appearance, physical Android touch or keyboard behavior, cutout comfort, sustained FPS, thermal behavior, APK export or production art quality. These remain separate device/rendering checks until actual evidence is recorded.
