# Prismheart Sanctuary Stage 6.1 — validation

Build **`0.7.0-home6a`**, Android version code **28**, passed **8,250 checks across 32 runtime modes and 30 suites**, including two independent restart readers. Fresh import, **24 strict script loads** and **120 startup frames** passed. All accepted modes used one final frozen source; earlier failed/diagnostic runs and the separate geometry-budget probe are excluded from these totals. No rendered or physical Android acceptance is claimed.

Final source SHA-256: `28ecefaf3da8d85b983c8af81119b436cc876d5062815343507665b48c91ba79` (1,205 semantic files). Accepted run: `/workspace/scratch/vaultbound-home-stage6-validation/focused-32tptk6g`. Root independently verified **35 accepted logs**, source equality and **951 unchanged protected files with zero exceptions**. Five new GDScript UIDs were imported separately. See [the machine report](personal-sanctuary-m6-1-test-results.json) for commands, hashes and detailed scope.

## Implemented and preserved

Six ivory/royal-blue/gold booths surround the enlarged Living Prismheart. All six and the legacy City Guide use the same existing **DEMO / NOT LIVE** exchange; no live market or real player-to-player transfers are implied. The capital now has 22/26/30 m walls and four exterior landmark towers at 35–45 m. The original sixteen smaller 5.6–8 m tower forms remain as buttresses. Existing distant trees/cascades rise above the walls; new inner graph paths detour around the counters.

The original horizontal city footprint, four arrivals, thirteen service POIs, eight district transforms, two terrace ramps and portal locations remain. Home identity, inventory, earned Depthmarks, combat, dungeon progression, pets, companions and profile v11/home v3 are preserved. The Personal Sanctuary gate remains southeast; this is not the later cardinal-wing/Nexus relocation.

## Accepted checks and exact traversal scope

| Coverage | Checks |
| --- | ---: |
| Six shared exchange booths and real touch/source guards | 294 |
| Capital geometry, arrivals, camera matrix and presets | 460 |
| Continuous player/Guardian/Mystic city walk | 83 |
| 29 retained modes | 7,413 |
| **Total** | **8,250** |

Retained modes cover batching, native visual integration, Sanctuary UI/surfaces/scenery/settings, the existing demo exchange model/store/sales/authorization/touch/restart/isolation, actual home-room integration/services, tester UI, depth/early-return guards, mobile layout and smoke. The two independent readers exercise exchange restart and real-profile isolation. This is a scoped native gate, not a repeat of every historical suite or a physical-device test.

The city walk starts at the ordinary initial arrival with the **player, Guardian and Mystic**. It visits six booth approaches, the legacy guide, eight ring sectors, six flat districts and both terraces. Across **8,703 observed physics frames**, maximum actor step was **0.08842 m**, with zero recovery relocations for both companions. Travel measured **588.31 m / 594.97 m / 603.28 m** respectively. All four arrival floor/capsule formations were checked separately. This does not claim every arrival-to-every-booth walk or an active pet on this route; those broader combinations remain in the manual checklist.

Capital camera checks include **11,016 transition frames across Low/Medium/High**. The enlarged crystal retains a camera-only envelope, verified native camera-sphere clearance and identical obstruction across presets; the player-space body ray remains clear. These checks establish native clearance, not attractive rendered framing.

The booth suite exercised actual input, shared listings/custody and exact current-world source identities. Stale/replaced/foreign sources and invalid confirmations were rejected. The synthetic real-profile and backup/config bytes remained unchanged by DEMO transactions. No existing player's profile was edited or reset.

## Geometry and mobile evidence

Do not confuse the new layer or backdrop with the whole city:

| Scope | Native count |
| --- | --- |
| Added PrismheartArchitecture, before batching | 226 nonempty mesh objects; 4,722 triangles; zero lights/processing nodes |
| Existing CapitalLandmarks layer only | 19 meshes; 8,671 triangles |
| Whole active Sanctuary, after batching | 2,792 nodes; 1,081 nonempty Mesh + 208 MultiMesh nodes; 102,629 allocated instance triangles |
| Whole active-world lighting | One environment, one directional key, zero local lights |

A separate **12-check budget diagnostic** captured Low/Medium/High without changing the source. It is excluded from the 8,250 acceptance count. Whole-world scene-visible triangle inventories were **89,916 / 94,954 / 99,303** before frustum/distance culling. Text glyphs, sky and particle-renderer work are outside these mesh counts. The full Game hierarchy also includes player/party/UI preview and its own preview environment/key; those are not extra Sanctuary lights.

The Sanctuary batcher combined 528 eligible source meshes into 185 batches, an internal estimate of **343 fewer mesh nodes**, not measured GPU draw calls. Actual Hall policy separately retained **104** saved mesh nodes (321 → 217). Neither small added-layer cost nor these batching estimates prove mobile performance. The complete world still has substantial geometry/material/node counts requiring real-device profiling.

Prismheart sparks are capped at **4/8/12**, with 10 Hz Low / 20 Hz other pose updates. Reduced motion freezes the pose; reduced effects and ambient density reduce optional effects without removing opaque collision. The budget snapshot observed 1/3/4 active townsfolk and 0/2/4 animals; these are bounded presentation counts, not hundreds of simulated players. Measured distant-tree tops are 58, 60, 64 and 67.9 m; full meshes include foundations sunk eight metres below ground.

Accepted runtime processes took **575.645 host seconds**. This is test duration, not FPS, GPU draw calls, memory, battery or thermal performance. The optional 30/60 FPS settings are targets requiring Android verification.

## Development repairs and excluded runs

- `focused-6s487y1m` failed before accepted runtime modes because a conditional untyped Array was assigned to typed crystal vertices. Explicit `PackedVector3Array` construction fixed it; no masking nil guard was added.
- `focused-p9wqli0t` omitted movement observations during a 36-frame camera wait. Diagnostic proof showed Mystic's 1.443840 m displacement accumulated over 37 physics frames; its real maximum single-frame step was 0.080213 m with zero recovery. Recording every physics frame fixed the test without resetting positions, raising the 0.35 m cap or changing production navigation/AI.
- Tower configuration validation now checks every authored height is finite and within 35–45 m; negative fixtures leave the live shared resource unchanged.
- `focused-f3rkn3ta` exposed an obsolete batching fixture using eight-metre cells for the Hall. Accepted Stage 5 reproduced it; the actual Hall has used twelve-metre cells since Stage 4. The test now uses actual per-scene policies and retains its original ≥80 target plus all collision/floor/exclusion checks. Production batching was unchanged.
- `focused-9ba35khw` retained the old small crystal's 2.8–3.8 m camera expectation. The replacement checks the actual canonical envelope's native lower plane, radius-based safe sphere and identical collider/clearance across presets; the original body ray and other scene checks remain.

The final 32-mode gate reran all tests on `28ecefaf…`; no diagnostic-only checks are silently added or cross-snapshot acceptance claimed.

## Changed files and remaining work

Production changes are the new `prismheart_capital.tres`, `prismheart_capital_data.gd`, `prismheart_architecture.gd` and `prismheart_visual.gd`; existing Sanctuary layout/world/builder/landmark resources; and exact booth-source integration in `demo_exchange_controller.gd`. Current tests, build metadata and documentation are updated. Source/UID manifests in the machine report give exact files. Historical reports stay unchanged.

No rendered screenshot, GL visual acceptance or physical Android test was obtained. The optional earlier Xorg attempt was blocked by environment Unix-socket restrictions; a retry ended without output. Use [the device route](personal-sanctuary-m6-1-android.md) for actual scene appearance, touch/keyboard comfort, camera readability, shadows, overdraw, sustained frame times and thermals. Back up phone saves and preserve application/user-data identity; the source ZIP is not an APK.

Art remains original native-mesh/available-family prototype work. The full blueprint's cardinal wings/Nexus, Bank, Guild rooms, Undercroft, new contracts, later landscaping/sky and social features are incomplete. No live marketplace, hosting, authenticated accounts, ranked PvP, visits or real billing are claimed. Stage 6.1 is a verified functional plaza/skyline checkpoint, not completion of the entire requested update.
