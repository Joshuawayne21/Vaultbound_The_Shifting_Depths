# Milestone 7B validation

The frozen 7B gate passed **2,118 assertions across 16 suites and 17 separate test processes**, plus a fresh import and 120-frame startup. All accepted runtime logs exited cleanly without script errors, warnings or leaks. [Machine-readable results](milestone-7b-test-results.json) preserve source identity, exact engine arguments, timings, log hashes and measured geometry/navigation evidence. Development runs are recorded separately and excluded from these totals.

## Frozen source and isolation

- Base commit: `d3e812526652bb70fc3fea2a3702c2339a578ca2` plus the reviewed 7B changes.
- Semantic source: `9a8823d1d9b2fb3621dbb908d28008ea3b33a27411aeb3fa74d793e985a30b18` over **785 files**. Opening, closing and final workspace manifests match. Scope is `project.godot`, scripts, resources, scenes, assets and tests, excluding generated `.uid`/`.import` sidecars.
- Export preset: `870e9be40e5d1c366f8643ebbf4d8bd5735f4bf7cbab46d06dcfc0fd5dc984d7`; project/Android version `0.7.0-7b`, Android code **13**.
- Godot **4.6.3.stable.official.7d41c59c4**, Linux headless, Compatibility configuration. The source contains 223 GDScript files, 59 scenes, 472 resources, 7 shaders and 19 SVG assets.
- Every engine process ran sequentially against a copied snapshot with disposable XDG data/config/cache directories. Explicit save fixtures remained under `/tmp`; normal play storage was not used. The preference reader ran in its own process against the writer's fixture.

Import recorded only the established sandbox local-socket errors and missing Android build-tools notice. No APK export was attempted. Runtime checks use the strict error/warning/leak filter. The prior 6F full gate remains **17,741 assertions / 89 suites / 108 invocations**; it was not repeated or added to the new totals for this visual stage.

## Changed files and measured presentation

- `sanctuary_city_builder.gd` raises the 64 original wall segments to **3.2/3.7/4.2 m**, retaining their X/Z footprints and matching solid shapes. Sixteen existing column sites now carry **5.6/6.8/8 m** tower silhouettes with original unrotated ground bases, matching shafts and camera-only crown blockers.
- `sanctuary_landmark_data.gd`, `capital_landmarks.tres` and `sanctuary_landmarks.gd`, installed by the narrow Sanctuary hook, add four distinct elder trees, two distant cascades and floating rock forms. Independent native mesh inspection measured **19 combined meshes and 8,671 triangles**, within the 20-mesh/12,000-triangle budget. Tree tops are **22, 24, 26 and 29.1 m** above ground; cliff-root foundations extend to Y=-8. Complete native bounds remain outside radius 56 m.
- Low/Medium/High preserve 12 mandatory silhouette surfaces and enable **2/4/7** optional accent meshes. Reduced effects uses the Low accent budget. These settings reuse the same built geometry. The landmark layer adds no lights, gameplay collision, navigation regions or per-frame processing. These are structural budgets, not measured GPU draw calls or device FPS.
- `portal_visual_profile.gd`, five profile resources and `portal.gd` give existing routes distinct ornament and labels: blue Rootbound, gold Collection Hall, explicitly local practice routes and Sanctuary returns. New opaque ornaments have corresponding camera-only shapes. Existing portal positions, entry review, interaction radius, player passage and destination connections remain intact. Purple/red destinations are not exposed before their actual scenes exist.
- `sanctuary_capital_test.gd` adds the focused geometry, collider, reproducibility, graphics, save-preservation and camera coverage. No semantic source file was removed; combat, inventory, progression, party, pet, generator and store implementations are unchanged. Release metadata and this stage's documentation complete the changes.

These are original authored native-mesh additions using the existing material families. They remain prototype artwork; no downloaded production character/environment asset is represented as complete.

## Accepted checks

| Suite | Assertions |
| --- | ---: |
| `sanctuary_capital_test` | 245 |
| `smoke_test` | 770 |
| `sanctuary_world_test` | 225 |
| `sanctuary_ui_test` | 59 |
| `city_navigation_test` | 68 |
| `city_surface_test` | 21 |
| `companion_navigation_test` | 41 |
| `pet_follow_test` | 80 |
| `city_scenery_test` | 141 |
| `static_visual_batcher_test` | 32 |
| `visual_integration_test` | 63 |
| `visual_style_test` | 48 |
| `visual_settings_test` | 54 |
| `visual_accessibility_test` | 144 |
| `accessibility_preferences_test` | 41 |
| `accessibility_preferences_test --read` | 3 |
| `demo_exchange_controller_test` | 83 |

The new suite measures native mesh vertices, faces, world AABBs and actual collision shapes, independently of the exposed snapshot. It also verifies deterministic geometry without consuming gameplay RNG, no reconstruction on graphics changes, teardown and exact preservation of secured profile bytes. **4,080 actual physics frames** cover smooth third-person/isometric switches near raised walls, all three tower variants and the Rootbound/Hall gateways, at minimum/maximum orbit pitch and every quality. A sphere query checks the actual `Camera3D` position against world and camera-only collision throughout each transition.

The real player, Guardian and Mystic traverse all eight city districts and both terraces on foot across **7,045 observed physics frames**, with **zero companion recoveries** and maximum actor step **0.089334 m**. Retained tests cover authored surface continuity, generated-room companion navigation, actual pet following and bounded update/query behavior. All four existing Sanctuary portal round trips, mobile entry/review controls, service access and scene identity checks pass.

Visual integration reconstructs Rootbound seeds **7, 23 and 81**, validates their layouts, retains cosmetic seeds and room visibility through graphics changes, checks both entrance camera compositions, returns safely to Sanctuary and enters the Collection Hall. Existing scenery/fauna limits, static batching, reduced motion/effects, accessibility persistence and source-bound local Ring Exchange access also pass. This stage did not repeat the unrelated full economy and 100-seed suites; their prior accepted evidence remains separate.

## Development correction and limits

The first focused test invocation stopped on a strict inferred-Variant warning in the new test's `WeakRef` local. An explicit `WeakRef` annotation corrected the fixture. The next focused run passed 227 checks; the final gate adds explicit camera probes for all three tower variants and passes 245. No production fix or weakened behavioral assertion was needed. Both development attempts and their logs remain recorded outside the accepted totals.

Headless checks establish geometry, collision, source and gameplay contracts. They do **not** establish rendered beauty, shader appearance, Android touch comfort, GPU/FPS/thermal performance or physical-device input. No screen/video capture, display/GPU installation, permission retry, paid asset, hosting or live-backend test occurred. Review both camera views, wall/tower silhouettes, trees, waterfalls and portal readability on a real device using the [Milestone 7 Android checklist](milestone-7-android.md) before treating the visual pass as approved artwork. The existing day/night cycle, fog and quality settings remain in place; no desktop-only volumetric feature was added.

Depth progression and later Milestone 7 stages are not part of this 7B acceptance record.
