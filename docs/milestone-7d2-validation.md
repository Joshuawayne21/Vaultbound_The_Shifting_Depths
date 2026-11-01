# Milestone 7D.2 — first playable Rootbound encounter batch

This checkpoint adds playable Thornmarshal and Mycelial Cantor encounters, Ascendant Thornmarshal, and the optional Root Bark Champion. It preserves the original Rootwarden, existing dungeon topology, inventory, Depthmarks, progression, Sanctuary, companions and both cameras. This is the first playable encounter batch within 7D; it does not complete the remaining dungeon expansion.

The final frozen gate passed **25,070 assertions across 122 suites and 144 invocations**, including 18 independent restart readers. Fresh import, all 48 script loads (47 changed scripts plus the Companion prerequisite), and 120 startup frames passed. The accepted mode set has no failed invocations, script errors, runtime warnings or leak warnings. Execution was interrupted once by an orchestration-only temporary-path rejection, then resumed on the identical imported source; that failed precondition attempt is disclosed and excluded. Exact editor-import sandbox socket notices and the unavailable Android build-tools directory are recorded separately; no APK export is claimed.

## What changed

- Depth 1 retains Rootwarden. At depth 2+, required boss selection uses authored weights 50/25/25 for Rootwarden/Thornmarshal/Cantor. Ascendant is a one-in-four conditional Thornmarshal variant from depth 6. At most one eligible, physically safe optional Champion replaces an ordinary pack in an off-main room from depth 6; omission is valid when no suitable room exists.
- New controllers provide real telegraphed attacks, recovery, phase transitions, cancellation, bounded arena movement and source-checked damage. Thornmarshal's charge checks the full physical body and damages its swept traveled footprint and physical contacts inside the locked warning lane. Ascendant applies its health factor once and adds a fully warned pattern. Original Rootwarden controller/data/visual/scene/resource bytes remain unchanged.
- Cantor reserves and summons real skeleton defenders through the shared scheduler. Two consumed phase attempts admit at most four defenders over the encounter, with at most two owned at once. Unsafe or canceled attempts do not retry indefinitely. Defenders share the ordinary actor cap and provide no independent loot, currency, XP, pet, journal or objective grant.
- Public summon sockets use world coordinates; the scheduler converts privately to room coordinates and the manager applies the single spawn lift. Actual nonorigin-room tests cover this boundary. Candidate floor/body probes exclude retained previous-world geometry and reject a candidate whose own floor is missing.
- Three explicit reward tables reuse existing item IDs and the existing sampler. Source-bound deaths create correctly labeled searchable caches; extraction secures their items and Depthmarks once. New tables cannot issue Rootwarden-exclusive loot or pet findings. The catalog remains 350 noncurrency items plus its existing currency row.
- Profile version 7 is retained. New journal IDs are additive. Ascendant is a subset observation paired atomically with a real Thornmarshal defeat, never another kill, boss, cache or reward. Count, depth and revision relationships are validated without using local clock ordering for eligibility.
- Portal previews disclose possible pools before generation. The HUD displays the issued required objective, optional encounter identity, phase and actual modifier. Real Ascendant and Champion cases verify label fitting and duplication rules. Late content-admission failure preserves the safe prior world or a safe Sanctuary fallback and does not overwrite secured progression.
- Guardian/Mystic danger escapes and full dodge routes now check live collidable bodies at bounded decision points. This prevents selecting a route through the boss capsule. Ordinary navigation and its static geometry cache are unchanged; no extra idle per-frame collision polling was introduced.

## Changed-file summary

The semantic source change adds 41 files and modifies 42, with no removals: ten boss/attack profiles, three reward tables, three actor scenes, ten runtime scripts, and fifteen test/helper scripts are new. Existing edits integrate content selection, admission, scheduling, rewards, journals, UI and danger navigation, plus explicit source tags on eighteen existing item definitions. The machine report lists every changed path and exact hash; release metadata, UID sidecars and documentation are recorded separately.

## Validation coverage

All 130 accepted D1 runtime modes remain in the final gate, together with 14 new modes from 13 suites. The existing modes cover Sanctuary/city navigation and interactions, portals, combat, both cameras, touch-input regressions, equipment, crafting, merchants, pets, party state, extraction, historical profile migration and isolated demo exchange behavior.

The new suites exercise 600 deterministic content plans; all fourteen real room shells, floors, connectors and anchors; attack envelopes in the required boss arena and four eligible optional combat modules; actual boss and Champion actors; full-body charge clipping; warning timing and active-window retirement; recovery enforcement; target-order reentrant cancellation; real summon reservations and nonorigin spawn placement; optional-objective isolation; actual Guardian/Mystic escapes in both cameras; pool and boss UI layouts; and death → Search → Take → extraction → independent restart. Source identity, one-time grants and saved possessions are tested through the production Game/Session/world path.

| New suite / mode | Passed assertions |
| --- | ---: |
| `rootbound_rewards` | 755 |
| `variant_journal` | 32 |
| `rootbound_content` | 1,813 |
| `rootbound_room_structure` | 128 |
| `rootbound_boss_visual` | 59 |
| `rootbound_boss_controller` | 204 |
| `boss_spawn_scheduler` | 43 |
| `boss_summon_lifecycle` | 48 |
| `rootbound_miniboss` | 36 |
| `rootbound_rewards_integration` | 147 |
| `rootbound_rewards_restart (write)` | 99 |
| `rootbound_rewards_restart (read)` | 26 |
| `rootbound_boss_companion` | 315 |
| `rootbound_boss_ui` | 224 |

Preserved assertion deltas are explicit:

- `content_registry_test` 260 → 261 (+1) — One explicit bounded Rootwarden seed-selection precondition preserves the old required-Rootwarden identity assertions under the newly randomized pool.
- `content_travel_guard_test` 87 → 95 (+8) — Eight additive checks reject corrupted post-ready physical encounter registries and preserve safe rollback/party/player/source state.
- `depth_dungeon_test` 793 → 794 (+1) — One explicit bounded Rootwarden seed-selection precondition preserves existing actual depth-50 Rootwarden scaling assertions.
- `smoke_test` 791 → 820 (+29) — Unchanged resource walker adds 26 actual native resource loads (10 scripts, 13 Resources, 3 scenes) and 3 newly opened directories; gameplay assertions unchanged.

No old mode was removed. Dynamic resource-loader assertions are reported separately from behavioral additions.

## Visual and mobile limits

The new boss bodies are original procedural mesh assemblies with transform-based poses. They are not imported production rigs or finished animation assets. Native face/pose inspection verifies distinct silhouettes, bounded geometry, four warning slots, shared materials, depth-tested warning height and room clearance. Measured native bodies: Thornmarshal: 19 meshes, 4 materials and 660 triangles; Mycelial Cantor: 15 meshes, 4 materials and 552 triangles. These are geometry counts, not device draw-call or frame-rate measurements.

The test environment used Godot 4.6.3 stable on Linux, with `gl_compatibility` configured and headless execution. Native geometry, collision, input and Control-layout checks do not establish rendered art approval, physical Android touch/keyboard behavior, GPU/FPS, thermal behavior or device memory use. The 30 FPS goal and optional higher frame rate still require real-device profiling. No live server, multiplayer authority, leaderboard or billing capability is added or claimed.

## Corrections found before acceptance

Initial parser checks rejected a nonconstant MinibossDefinition array expression and missing explicit types. Runtime checks then identified native typed-array construction/call issues; the real Cantor caller now passes the scheduler's required typed array without weakening the API.

Fixture corrections were based on measured evidence: the catalog includes its longstanding currency row; native reward weights are floats; genuine version 2 saves use their legacy slots; water foam markers animate between asynchronous snapshots; ArrayMesh normals use encoded native representation; and SceneTree target ordering places the additional test Player before the main Player. Exact weights, geometry, collision, damage and save restrictions were retained. Reentrant cancellation now binds to the actual first target and proves one hit/one callback with no later-target damage.

The companion trace exposed a real blocked path: the selected destination lay inside Cantor's physical capsule, which ordinary static-only route queries did not include. Bounded live-body escape checks corrected this while retaining the original 0.65m warning margin and no-hit assertions. A separate idle-cache fixture now checks the next real navigation query after cancellation rather than requiring idle per-frame cache clearing. The corrected actual companion suite and preserved danger/navigation/behavior suites passed before the fresh full gate.

The first full attempt also exposed an older starter-item fixture that enumerated only the original loot tables. It now independently reads the three new authored tables, including entries and guaranteed drops, while retaining exact declared-versus-actual source equality and all 324 existing assertions. Other source enumerators were audited; the unchanged item catalog suite also passed. No acquisition source was inferred from the item metadata being checked.

The full gate later paused at the exchange restart writer because the reconstructed runner used a generic `/tmp` symlink alias. The existing exchange factory requires its historical `/tmp/vaultbound-6f-` prefix and rejects symlinked ancestors. Only orchestration changed: a fresh physical directory satisfied both guards, and its exact bytes were copied and hashed into durable evidence after writer and reader. Production and test guards remained unchanged.

Acceptance consists of the first 67 clean modes plus the corrected writer and remaining 76 modes, all on the same imported physical snapshot after exact workspace/source verification. The original failed precondition log, results and summary remain intact. No setup or successful mode was repeated for this harness correction, and no mode is counted twice. Earlier diagnostic runs are excluded; this is explicitly an interrupted and resumed gate, not an uninterrupted pass or a collection of earlier development results.

## Evidence and preservation

- Candidate: `0.7.0-7d2`, Android version code `16`, profile schema `7`, content plan version `2`.
- Accepted base: local `8197289e1df45f19cae7f65bcd417510292a5ff4`; published counterpart `253b3e3b429b1731ec81030f9fd79bf42cf26a1b`, identical tree `f642b0f31b39b5d5c510a24ca26fadf2c8b811f0`.
- Final semantic source: `216f0f36fa8237f9695c361ced0722f005ddd4b55a1e207e07492265e96d281c` across 863 files. Opening, closing and workspace fingerprints match.
- Export settings: `3901d917437aa1c20bf55099c0b05d7e5f4a8424c92e0937500e3c0e7192b1ba`.
- Frozen evidence directory: `/workspace/scratch/vaultbound-7d2-validation/accepted-resume-9rhsgmhw`. Exact commands, source manifests, new UID sidecars and per-log hashes are in [the machine report](milestone-7d2-test-results.json).

The managed environment was replaced while this checkpoint was in progress. `/workspace`, Git history and release archives survived; earlier D1 `/tmp` raw logs and copied sources did not. Historical reports remain byte-identical, their archive hash is preserved, and all 822 D1 semantic files were independently checked against the accepted Git tree. New evidence lives in durable workspace scratch storage. The current full gate reruns every retained mode; it does not claim access to the lost raw logs.

All new test storage is disposable. Most explicit restart arguments retain the required `/tmp` prefix through a unique symlink into the evidence directory. The exchange writer/reader instead use the required physical `/tmp/vaultbound-6f-` directory; exact durable snapshots preserve their bytes and keep the no-symlink guard intact. No normal player profile was opened. Import-generated UID sidecars are retained only for new scripts and never overwrite existing tracked UIDs.

## Remaining work and Android testing

Further themes and boss families, Ancient encounters, additional hazards/hives/hordes, early extraction, shortcuts and set pieces remain subsequent verified batches. Broader Milestone 7 companion tiers, pet genetics/habitat, trophy expansion and ranked-world infrastructure are not represented as completed here. Offline source guards and local saves are not secure online authority.

Follow [the Android checklist](milestone-7-android.md) and [Rootbound encounter guide](rootbound-encounters.md). Test a normal earned depth-2+ entry and depth-6+ variants without editing production progression; check both cameras, warning readability, summon escape lanes, Guardian/Mystic behavior, optional versus required objectives, Search/Take, extraction and restart on a real device. Review controls, safe areas and UI scale at the intended phone aspect ratios, then profile representative quality settings and prolonged sessions. Do not infer device approval from the headless gate.
