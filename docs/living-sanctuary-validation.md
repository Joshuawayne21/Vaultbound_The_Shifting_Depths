# Living Sanctuary validation

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

## Gates for subsequent stages

Each completed implementation stage will record its exact source manifest, focused suites, assertion counts, log review and limitations here. A final gate must run all 58 preserved suites, every independent restart mode and the new Living Sanctuary suites, including the existing 100-seed dungeon validation. Writer/reader pairs run sequentially because several fixtures use explicit shared `/tmp` paths. Imports and startup processes need the same XDG isolation as tests because autoloads initialize before a test can redirect storage.

Coordinate fixtures may change only to follow the authored world and service positions. Preserve their behavioral assertions: valid walkable floors, clear approaches, actual nearby services, camera clearance, one active world, retained player identity, saved ownership and safe portal arrivals. Fixed spawn expectations remain contracts unless explicitly changed in the implementation plan. Do not weaken geometry, combat, economy or persistence assertions to make a relocated world pass.

Headless checks establish logic, resource, physics and simulated input contracts. They do not establish rendered GPU appearance, physical Android touch or keyboard behavior, cutout comfort, sustained FPS, thermal behavior, APK export or production art quality. These remain separate device/rendering checks until actual evidence is recorded.
