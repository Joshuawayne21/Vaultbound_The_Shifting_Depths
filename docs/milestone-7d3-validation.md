# Milestone 7D.3 — Rootbound hazards, hive and finite horde

The accepted offline checkpoint passes **28,775 assertions in 136 suites / 159 runtime modes**, including 19 separate-process save readers. It retains every 144-mode 7D.2 regression and adds 15 modes. The isolated initial source imports and starts for 120 frames. The initial and resumed strict preflights together load all 48 changed/new scripts plus the unchanged Companion initialization prerequisite (49 unique paths). Acceptance uses 122 unchanged-dependency prefix modes and 37 resumed modes after one standalone pet-observer fixture correction; the original failure and both source manifests remain explicit.

This completes the approved first hazard/event batch within Milestone 7D. Other themes, Ancient Boss encounters, early extraction, shortcuts, the later recruitment/pet/PvP work, and the rest of Milestone 7 remain pending. Linux headless checks do not establish rendered visual quality or physical Android performance.

## Implemented behavior

- Deterministic, frozen content-v3 plans add two hazards from depth 2: Root Spike Lane in eligible trap rooms and Root Spore Patch in eligible grove rooms. Authored profiles and seeded choices are frozen at issuance; the version-1 hazard schema validates the exact two approved combat configurations, and hazards grant no rewards. Unsafe placements are omitted without rerolling the layout.
- The spike lane has a 1.8-second warning and one attempted damage delivery per target during its 0.45-second active window. The spore patch has a 2-second warning and at most three base-4 pulses over 3 seconds. Pulses have distinct identities and remain at least 1 second apart. A stalled active update does not create a catch-up damage burst or extend the fixed 3-second active lifetime; warning overrun starts one fresh active edge and discards predecessor delta. Cancellation consumes the once-only hazard attempt, without partial resume or reentry rearming. Damage applies the admitted depth factor once and respects the actual source, height, dodge and line of sight.
- From depth 6, an optional Spore Hive can occupy an eligible off-main grove after the existing Champion assignment. It is a destructible stationary core with up to two finite two-defender opportunities; bursting the core before a defender commitment is a valid zero-member result. The second opportunity also requires half health and verified deaths of the first committed pair. The hive has no ordinary enemy kill credit or core lifesteal.
- A separately seeded, once-per-run Root Horde can activate after an eligible ordinary chamber is actually cleared. It has two finite waves: four total members for a solo player, six for a party. Deeper plans can substitute an existing ordinary golem. No new enemy class is implied.
- Event spawn and resume warnings last 3.5 seconds. Every whole committed group needs valid native floor/space and sockets more than 6 metres from every current party member, including downed members. Two unsuccessful fully warned attempts cancel a horde safely; a hive instead exhausts that finite wave opportunity, remains destructible, and can still finish its valid core-only or committed-member result. Shared actor and reservation limits remain enforced, with a four-warning cap for the new registered hazard/event mode.
- Leaving an event room pauses its exact existing members, preserving IDs, health and validated death evidence. Returning requires another full warning and new attack windups; event-owned projectiles retire. A missing live member cancels the event and never counts as a death or permits a replacement reward.
- A terminal event receipt can issue one searchable aggregate cache only. Rewards use two authored tables: Hive 18–28 base DM with two item rolls; Horde 32–48 base DM with three rolls. The existing depth currency factor applies once. Tables use existing materials/supplies, with no elite-exclusive encounter materials, Rootwarden-exclusive items, Ancient or pet drops. Actual committed member discoveries and kill credit are recorded once with the aggregate result; extraction secures them through the existing save transaction.
- The hive blocks player/AI movement, camera obstruction, hostile projectiles and attacks through its body while remaining directly attackable. Companion static navigation now includes stationary encounter blockers; ordinary body collision bits and the existing live Cantor avoidance behavior remain intact. Dormant hives do not attract companions; an engaged hive can receive existing sword/staff assistance.
- The existing HUD shows actual arrival/resume countdowns, living-member counts and completion. Leaving clears the unrelated event label; an accepted reward separately emits the existing searchable-cache notice. Tests exercise both cameras, direct commands, actual companion reactions, portal travel, event interruption, and preserved loot/equipment/save behavior.

The versioned profile remains v7 with additive encounter IDs; item IDs, the 350 noncurrency definitions plus the existing currency row, Depthmarks, equipment, companions and prior records are preserved. Five original Rootwarden controller/data/visual/scene/resource files are byte-identical to 7D.2. No network authority or new public service is implemented.

## Geometry and mobile limits

Measured presenter geometry: Spike lane — 3 native batches, 27 instances, 873 triangles and 3 shared material roles; Spore patch — 3 native batches, 16 instances, 648 triangles and 3 shared material roles; Hive — 6 native batches, 13 instances, 504 triangles and 4 shared material roles. These are geometry counts, not measured device draw calls or frame rate.

These are original native-mesh prototypes pending rendered art review. The geometry counts above cover only their presenters, excluding shared warning meshes and other room geometry. The presenters borrow existing reconstructed world materials and reuse their native allocations across poses and quality settings. They add no autonomous physics/navigation/light simulation. Essential silhouettes remain across Low/Medium/High; reduced motion and ambient density affect optional presentation. The hive's measured articulated geometry remains within its existing 0.8m-radius / 1.8m-height blocker; the actual native trap/grove fixtures, floor/clearance, LOS, camera transitions and ordinary actor traversal are checked separately.

Godot's headless dummy renderer returns an identity transform and empty buffer for a known nonidentity MultiMesh submission in this environment. The tests therefore use an opt-in bounded record of the exact arguments submitted to `set_instance_transform`, expanded over actual native mesh faces, and cross-check native readback whenever a buffer exists. Normal play retains no such inspection arrays; disabling inspection clears them. This is CPU-submitted geometry evidence, not a screenshot or GPU render claim. No grounding or geometric tolerance was relaxed to accommodate the dummy renderer.

## Accepted gate and provenance

- Engine: `4.6.3.stable.official.7d41c59c4`; configured renderer `gl_compatibility`; Linux `--headless` execution.
- Release metadata: `0.7.0-7d3`, Android version code `17`; profile `7`, content/plan `3`.
- Local accepted baseline: `9cff1b688321bf4e3f00573cccccc9534e01a493`; published GitHub counterpart `3b70c58aeafaef7e58cebce11301d0a6f4ddf025`; identical Git tree `0221198a606a8477a0b3238dabe486142acfeee2`.
- Final semantic source: `0e7c2262ef4a811dd8127014594d7f8afa71b0ffd5dd244634077402f834f3a6` over 894 files. The resumed copy's opening, closing and workspace manifests are identical. The accepted prefix used source `196ec3b24f7ce67d1b9c4e06ab10805bc13e37830570a46b46e0346200f99f5c`; its exact sole difference is `tests/pet_follow_test.gd`. Production and export bytes are unchanged, and none of those 122 prefix modes references the modified standalone test. The export preset is separately hashed as `b09d22ce442e511f7df601eabd0b699193659d131f6ec765bcb8fb2a910898d1`.
- Full evidence directory: `/workspace/scratch/vaultbound-7d3-validation/accepted-resume-p20sl1bw`. The [machine report](milestone-7d3-test-results.json) includes every accepted argv, source/log hash, explicit restart fixture hash, development failure, diagnostic result, and orchestration file hash.
- Per-suite disposable XDG directories and isolated `/tmp` fixture arguments are used. The exchange restart fixture uses its required real physical `/tmp/vaultbound-6f-…` directory from the outset; exact bytes are copied into the durable evidence directory. No normal player save is opened.
- The import-only sandbox editor socket notices and missing Android build-tools directory are classified explicitly. The same strict runtime error, warning, leak and failed-assertion filter applies to every test; APK export is not claimed.
- All 144 accepted 7D.2 modes are present once in the accepted 159-mode set (122 original prefix + 37 resumed). This was not one uninterrupted pass on one semantic snapshot. Each invocation records its actual source. The original failed pet sampling attempt and diagnostic runs are excluded from accepted totals. Historical 7D.2 evidence and reports remain unchanged.

| New suite / mode | Passed assertions |
| --- | ---: |
| `hazard_definition` | 82 |
| `event_rewards` | 526 |
| `event_journal` | 26 |
| `event_source_record` | 133 |
| `event_content` | 1,811 |
| `rootbound_event_visual` | 63 |
| `rootbound_event_geometry` | 65 |
| `rootbound_hazard_runtime` | 222 |
| `event_lifecycle` | 53 |
| `event_rewards_integration` | 266 |
| `event_rewards_restart (write)` | 90 |
| `event_rewards_restart (read)` | 33 |
| `stationary_blocker_navigation` | 43 |
| `rootbound_event_companion` | 168 |
| `rootbound_event_ui` | 105 |

Retained assertion changes are explained individually:

- `pet_follow_test` 84 → 86 (+2) — All 84 original assertions and the <0.30 movement threshold are retained. Two new assertions verify consecutive post-idle sampling across three actual world bindings and stable identity/hidden recovery. The old physics observer merged multiple valid idle updates; production is unchanged.
- `smoke_test` 820 → 837 (+17) — Unchanged recursive resource walker validates 15 new runtime script/resource loads and 2 new resource directories; all gameplay assertions retained.

## Corrections found during validation

The first aggregate preflight rejected three fixture inference errors (one bool and two WeakRef annotations). Explicit types corrected them before startup/runtime. The first 26-mode diagnostic pass then found independent issues; all 11 affected retained modes already passed, while six new modes failed or cascaded. Their logs remain excluded and hashed.

Production corrections were evidence-driven:

1. Corpse cleanup left freed actor references in room arrays; subsequent typed iteration produced runtime errors. The manager now validates retained references before iteration while preserving the private immutable actor registry and verified death evidence. Missing members still fail closed.
2. Nested event retirement could ask a detached manager for its SceneTree. Detached/queued activity refresh and projectile cleanup now exit safely. A further reviewed post-`add_child` source/lifetime/attempt guard preserves cancellation from synchronous callbacks; an actual event `node_added` retirement test verifies it.
3. The initial spike presenter used 981 triangles against its declared 900 cap. Reducing the nine socket cylinders from eight to six radial segments produces the measured 873 triangles without removing sockets or changing gameplay geometry.

Test and measurement corrections preserved the actual rules:

- A lambda observing a deliberately freed hostile projectile now uses a WeakRef.
- Positive spawn fixtures originally staged the player at Z=5, blocking two corner sockets inside the unchanged 6m safety radius. The party is now staged at the valid centre. A wait that accepted either an active wave or cancellation was not evidence of a partial spawn; the roster assertion remains strict and the label now states that distinction. Restart readers explicitly require a valid writer artifact before parsing it.
- The hive geometry fixture now visits a real ordinary combat chamber first, triggering its legitimate lazy enemy spawn before checking the enemy/core obstruction relationship.
- A controlled known-transform MultiMesh probe established the dummy-renderer limitation described above. Exact captured submissions removed the false pose/grounding failures; the genuine triangle-cap failure remained until its production mesh correction.
- The two retained catalog fixtures enumerate the actual new event tables independently and continue requiring exact declared-versus-live acquisition sources. No expected sources are derived from the item metadata under test; elite and Rootwarden restrictions remain unchanged.

A fresh copied retry then passed all six rejected/cascade modes plus the two retained boss spawn/summon suites (661 assertions). The subsequent full gate stopped at its original pet-following measurement after 122 passing modes. Its physics-frame observer combined multiple legal idle updates: a copied trace reproduced 0.27999988m and 0.20246090m updates as one 0.48246077m observation, with stable identity, visibility and recovery/placement counters. The uninstrumented original failure measured 0.41317868m; its individual update timing was not captured, so the trace is identified as a reproduction.

Only the standalone test changed: a main-thread observer node samples after every actual follower idle update, including gaps between awaited physics callbacks. It retains the original `<0.30` limit and all 84 checks, adding two checks for consecutive sampling across three world bindings and hidden recovery/stable identity. The corrected route passes 86 checks. Production pet behavior did not change. A strict fixture preflight and the corrected pet mode plus the remaining 36 modes resumed on the exact one-test descendant snapshot. The 122 earlier modes have unchanged dependencies and were not redundantly rerun. The machine report preserves both manifests, the excluded failure, diagnostic hashes, and every invocation's source association; only the accepted unique 159 modes supply the totals above.

## Host-only timing observation

A separate bounded microbenchmark used an actual admitted depth-50, seed-1 world with 24 rooms and a 31,450-byte JSON / 46,368-byte Variant plan. Ten batches of 20 valid calls per path followed five warmups; the expected plan copy was outside timing. Median times were 38.35µs for Session context validation, 40.525µs for world source validation and 42.9µs for full issued-plan equality; the empty-callable control was 0.15µs. Raw batches are retained in the machine report.

This measured the current valid paths on this Linux host only. It did not measure natural call frequency, total frame cost, Android frame rate, thermals or battery consumption. No production guard was removed or optimized from this observation; full admission and transaction validation remain intact.

## Changed files and remaining tests

The semantic delta contains 31 added and 35 modified files, with no removals. The machine report lists each path and SHA. Main groups:

- `scripts/expedition/` and four new event/hazard resources: definitions, seeded placements, finite cast/event lifecycle, native admission and cancellation.
- `scripts/combat/`, `scripts/enemies/enemy.gd`, and companion brain/navigation: stationary blocker interaction while preserving prior combat rules.
- `scripts/progression/`, `scripts/treasure/`, two loot resources and ten existing item source tags: one aggregate event reward, journal integration and extraction persistence.
- `scripts/visual/` and the existing expedition overlay: bounded native presenters and actual event status.
- Fourteen new executable suites, two parser-only helpers, two exact retained source-enumeration adaptations and the corrected retained pet-observer fixture. `project.godot`, export metadata and documentation are updated separately as described above.

Before visual approval or Android release, perform the [Android play-test checklist](milestone-7-android.md) and follow the [Rootbound event guide](rootbound-events.md). Verify physical touch/keyboard/safe-area behavior, readable native warnings in both cameras, actual rendering of instance transforms, audio, portal round trips, paused/re-entered events, hive attack/obstruction, reward search/extraction, old-save recovery, and sustained Low/Medium/High device performance. No device, APK, GPU screenshot/video, online synchronization, server reward security or live payment test was performed here.
