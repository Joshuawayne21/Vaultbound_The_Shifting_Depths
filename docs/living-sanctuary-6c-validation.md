# Living Sanctuary 6C validation

The frozen 6C gate passed **11,480 assertions across 65 suites and 79 separate process invocations**, with no failed invocation, script error, warning or leak. [Durable results](living-sanctuary-6c-test-results.json) contain every command, assertion count, timing and log hash. The completed [6B validation](living-sanctuary-validation.md) and [6B results](living-sanctuary-test-results.json) remain unchanged historical evidence; focused development runs are excluded from the 6C total.

## Frozen source and execution

- Base commit: `9bbf08fd148f608cf5e61faa30520a7d41f0a46f`, plus the frozen 6C working tree.
- Semantic source: `bf971952455568829b5883cc24c8c3ae1b00bd0ee3740d8f948aa1be1384f3ca` over **702 files**. Opening, closing and final workspace manifests match. Scope is project.godot, scripts, resources, scenes, assets and tests; generated .uid/.import sidecars are excluded.
- Export preset: `5b554892318049e8de81386fddf619536fce1a9f53a1430db11b2c6eb6222868`, exactly matching the workspace. Project and Android version name `0.6.0-6c`, Android version code **9**. APK export was not attempted.
- Engine: Godot 4.6.3.stable.official.7d41c59c4, Linux headless Compatibility. Sequential editor import, 120-frame startup, then every suite process; all three XDG storage roots were disposable. Explicit restart fixtures stayed under /tmp. Normal play storage was not used.

Import reported only the established host local-socket notices and absent Android build-tools directory. Startup and all test logs were clean. No generated script UID was missing from the workspace after the validated import.

## Coverage

All **62 prior suites and 75 modes** were rerun, with 11,144 assertions. The three added suites contribute 336 assertions across four processes: `biome_art_direction_test` (47), `city_scenery_test` (141), and `visual_accessibility_test` (144 plus its independent 4-assertion reader). The complete inventory includes **11 independent reader invocations**; the new visual reader runs after its writer with the same disposable preference fixture.

The gate passed structural validation and exact reproduction for dungeon seeds **0–99**. Strengthened Abyss checks also passed **100 cosmetic seeds × 14 modules = 1,400 cases**, covering full transformed mesh bounds plus shader sway, protected lanes/anchors/combat space, same/changed-input fingerprints, native collider identity and transforms, global gameplay RNG neutrality, fair quality prefixes and world/preview ownership. Six art-direction definitions are verified; Rootbound remains the only playable biome.

City checks cover original collider and navigation-graph identity, full swept scenery bounds, quality caps, world-scoped fauna cleanup, nested viewport isolation, day/night and reduced-motion behavior, optional audio allocation/cleanup and exact protected progression bytes. Existing service, camera, spawn and portal tests remain in the complete gate. The new preference schema stays separate from progression: unknown future versions reject Apply replacement; malformed current preferences preserve their bytes and live choices on load, while a later explicit valid Apply may replace them. Progression retains its unchanged version-four save boundary.

The actual player and both companions walked all eight district approaches, all ring sectors and both 0.8 m terrace ramps, including Hold and Retreat descent. The final run observed **7,067 physics frames**, distances of 496.3 m for the player, 488.2 m for Guardian and 496.3 m for Mystic, **zero recovery teleports**, and a maximum actor step of **0.089334 m**. Replans were 165 / 270 / 233 and geometry probes 18,796 / 14,095 / 11,141 respectively. These are traversal/work counters, not FPS measurements.

## Geometry evidence and limitations

The development audit found that the headless dummy renderer returns identity transforms and empty buffers from MultiMesh getters. Earlier cosmetic checks that relied on those getters did not establish the intended per-instance placement; native collider/controller/navigation checks remain separate and valid. The replacement full-bounds and cosmetic-seed checks above passed using exact transforms/colors supplied to construction setters and native mesh bounds. Production discards optional static transform snapshots; the retained canonical fauna records serve the live allocator. The [independent structure/performance report](living-sanctuary-6c-performance.md) records actual counts, validated panorama clearance, measured metadata release and carefully scoped host timings, with [raw evidence](living-sanctuary-6c-performance-results.json).

Global decorative shader motion is applied on preference updates. Reduced shader motion chooses a deterministic static phase; the city daylight and resident animation retain their current phase. The old combat, hazards, world interaction, save, economy and UI suites all passed with these changes.

## Software-capture attempt

The optional 6B capture was limited to the already installed Xorg dummy driver and Mesa libraries; no packages or services were installed. A prior historical Xorg log showed local-socket binding failures. The new permission-bearing Xorg command returned **“aborted by user” before returning any PID or execution-session ID**. Subsequent inspection found no live Xorg and no capture output directory. No image was produced, no rendering was measured and no automatic approval-review rejection is claimed. The optional attempt was stopped; headless correctness gates completed independently.

Headless source/resource/physics and simulated-input checks do not establish rendered GPU appearance, Android touch/keyboard comfort, sustained FPS, thermal behavior, APK export or sound quality. The [manual Android checklist](living-sanctuary-android.md) remains separate from these automated results.
