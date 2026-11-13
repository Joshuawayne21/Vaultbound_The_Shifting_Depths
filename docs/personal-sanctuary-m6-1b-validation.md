# Sanctuary Stage 6.1b — validation

Build **`0.7.0-home6b`**, Android export code **29**, passed **8,435 checks across 33 runtime modes and 31 suites**, including two independent restart readers. Fresh import, **22 strict script loads** and **120 startup frames** passed. All accepted modes used one frozen source. Earlier diagnostics and the separate geometry-budget probe are excluded from this total. No rendered or physical Android acceptance is claimed.

Final source SHA-256: `d1b61d9b51efc6cec6d3656d57ac573b106868d690f76eeb0d928ad7f80af2f6` (1,210 semantic files). Accepted run: `/workspace/scratch/vaultbound-home-courtyard-validation/focused-5uwfywcr`. Root independently verified **36 logs**, source equality and **957 unchanged protected files with zero exceptions**. Four new GDScript UIDs were imported separately. Summary SHA-256: `462791a7cf2ae908c95274bdc05e463793c769776bfb1d6e25ecae84c0bcf1c5`. See [the machine report](personal-sanctuary-m6-1b-test-results.json) for commands, hashes and detailed scope.

## Implemented and preserved

The perimeter now uses **4.6 / 5.2 / 5.8 m** walls and four **9 / 10 / 11 / 12 m** exterior towers. Separate wall cores, coping and relief remove the confirmed overlapping visible surfaces. The spacious Exchange has an enclosure at radius 23.5 m, eight 9.4 m clear-width arches and eight bridge presentations. Six routes have new eight-metre-wide ramp/deck/ramp floors with a 0.40 m rise; Forge and Tavern reuse their existing ramps. Shallow ornamental channels retain safe ground underneath. Larger coral, turquoise, gold and violet blooms and varied distant canopies enrich the existing garden pockets.

The original 90 m city footprint, four arrivals, thirteen service POIs, eight district transforms, existing ring route, portal destinations and six shared **DEMO / NOT LIVE** exchange booths remain. Real inventory, Depthmarks, combat, dungeon progression, AI roles, pets, home services, profile v11/home v3 and saved TEST ACCESS remain outside the production changes. The southeast Personal Sanctuary gate still reaches the same home. No player save was reset or edited to make tests pass.

Baseline: local `1a34f351e0c07576795afe3f1b14bfeb372cc24b`, published main `d362893b184710a56283a38169d524acaa3f6bf1`, matching tree `fbc627483916a79729a4344914029ee2f4f1c3b9`. The verified source-history backup is documented in [the integration plan](personal-sanctuary-m6-1b-plan.md); it is not a backup of the user's phone profile.

## Accepted checks and traversal scope

| Coverage | Checks |
| --- | ---: |
| New courtyard, native wall relief, bridges and flower colors | 146 |
| Six shared exchange booths and touch/source guards | 294 |
| Capital geometry, arrivals, camera matrix and presets | 460 |
| Continuous player/Guardian/Mystic city walk | 119 |
| 29 retained modes | 7,416 |
| **Total** | **8,435** |

The courtyard suite checks actual opaque mesh vertices against native collision, all eight clear openings, full-width floor/capsule paths, canal safety floors and matching camera obstruction. It examines visible wall-front triangles using exact uploaded relief transforms, includes a deliberately overlapping negative fixture, and checks all 64 walls. Native flower vertices confirm eighty complete six-petal blooms in four color families. These are geometry/input/physics checks, not rendered image review.

The physical route observes the **player, Guardian and Mystic**, visiting the six booths, City Guide, ring, six flat districts and both terrace districts. All **24 actor/bridge witnesses** passed. Across **9,407 observed physics frames**, maximum actor step was **0.086615 m**, with zero companion recovery relocations. Travel was **611.79 / 622.39 / 636.17 m** respectively. The existing step limit and recovery constraints were retained. Separate arrival checks cover all four floor/capsule formations. This route did not include an active pet or every possible arrival-to-service permutation; those combinations remain in the manual checklist.

Capital camera checks cover **11,016 transition frames across Low/Medium/High**. Native obstruction remains consistent between presets, including the retained camera-only Prismheart envelope. Both perspectives are exercised through the changed city; this does not establish attractive rendered framing on a phone.

Retained modes cover actual batching policy, visual integration, Sanctuary UI/surfaces/scenery/settings, demo exchange custody and authorization, real touch paths, restart/isolation, home integration/services, tester UI, depth and early-return guards, mobile layout and smoke. The two independent readers exercise exchange restart and real-profile isolation. This is a scoped native gate, not a rerun of every historical suite. Synthetic DEMO trades did not mutate real-profile fixture balances or item/backup/config bytes.

## Geometry and mobile evidence

An independently reviewed **12-check budget diagnostic** used the same frozen source and is excluded from the 8,435-check acceptance total:

| Scope | Native count |
| --- | --- |
| New courtyard only | 32 meshes, 6,968 triangles, eight labels; zero lights/processing nodes |
| Retained PrismheartArchitecture layer | 214 meshes, 4,578 triangles |
| Distant CapitalLandmarks layer | 19 meshes, 8,671 triangles |
| Whole active Sanctuary, after batching | 3,332 nodes; 1,102 nonempty Mesh + 208 MultiMesh nodes; 110,661 allocated instance triangles |
| Scene-visible triangles, Low / Medium / High | 97,260 / 102,730 / 107,335, before frustum/distance culling |
| Whole active-world lighting | One directional key, zero local lights |

The courtyard fits its 12,000-triangle / 40-mesh limits. Layer counts are not the full city, and scene-visible mesh inventories are not measured draw calls. Compared with the preceding home6a inventory, the whole active city adds 540 nodes, 21 mesh objects and 8,032 allocated instance triangles; native geometry remains substantial and needs device profiling. The full Game hierarchy also contains player/party/UI preview objects outside the Sanctuary inventory.

The garden pass uses 400 instances instead of 560, in the same 24 interior batches, with 3,680 interior triangles. Existing foliage/panorama visibility and density budgets remain. Scene-local materials avoid changing dungeon palettes. The new courtyard has static sector meshes and no per-frame simulation.

Accepted runtime processes took **592.483 host seconds**. This is test duration, not FPS, GPU draw calls, memory, battery or thermal performance. Optional 30/60 FPS settings are targets requiring Android verification. Text glyphs, sky and particle work are outside native mesh inventories.

## Development diagnostics — excluded

The first six-mode diagnostic found one wall-height assertion comparing a native float against exact decimal snapping. Godot returned `4.5999999046` for authored `4.6`. A matching exact-membership assertion in the retained capital suite needed the same correction. Both tests now use `is_equal_approx` with the intended height set; production geometry and height limits were unchanged.

The `6637604a…` run `focused-ht83oint` stopped before the long suites after four passing modes / 535 checks. It remains an interrupted diagnostic, not acceptance. The complete final gate reran all 33 modes on `d1b61d9b…`; no results are combined across snapshots. The separate budget probe does not inflate the 8,435 total.

## Wall flicker evidence and limits

Source inspection confirmed that the old wall and several opaque trim surfaces shared local `Z = 0.400`; coping overlapped masonry and the blue banner was buried behind the face. The repair separates visible front planes and the cap's vertical interval while retaining the original horizontal collision footprint. Native face checks verify that the reported geometry conflict is removed.

This does **not** establish that every possible Android flicker source is resolved. Shadow shimmer, material appearance, lighting composition and moving-camera readability need rendered Low/Medium/High comparisons. No screenshot, GL visual acceptance, physical frame rate, memory or thermal measurement was obtained. The earlier display attempt was blocked by environment Unix-socket restrictions; no new rendered result is claimed.

## Changed files and remaining work

Production changes are `exchange_courtyard.gd`, `exchange_courtyard_data.gd` and `exchange_courtyard.tres`; the existing Sanctuary layout, city builder and landscape; Prismheart capital configuration and tower architecture; and project/export build metadata. Tests add `sanctuary_courtyard_test.gd` and `courtyard_native_geometry.gd`, extend physical city traversal and update intended native capital height checks. Four new script UIDs, current guides and this report accompany the change. Exact semantic paths and hashes are in the machine report. Historical reports remain unchanged.

Use [the Android review route](personal-sanctuary-m6-1b-android.md) for the user's flicker reproduction, all eight bridges, both cameras, companions/pets, touch comfort, day/night appearance and sustained performance. Preserve phone profiles and the application/user-data identity. Download **main → Code → Download ZIP**, import its root `project.godot` and verify home6b/code29. The source download is not an installed APK.

Art remains original native-mesh/available-family prototype work. The full cardinal-wing/Nexus relocation, Bank, Guild rooms, Undercroft, new contracts and broader sky system remain later work. No live marketplace, authenticated accounts, ranked PvP, visits, hosting or billing is claimed.
