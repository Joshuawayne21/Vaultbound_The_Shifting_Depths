# Milestone 7D.4 validation — Return springs

Accepted: **31,846 assertions across 147 suites and 171 runtime invocations**, including 20 separate-process readers. This is the collected-loot early-return batch for longer Rootbound Abyss expeditions. Later Milestone 7 content remains incomplete.

The accepted baseline is local commit `ce9fcc9202f54b6705e572cbcdf08dca10e89978`, published as `660bcf82fe619e4930726de692a83397cd3d7767`; both use tree `3900206933f1568310ded67be66afad2248a30ea`. Historical 7D.3 reports and durable evidence remain unchanged. The [machine report](milestone-7d4-test-results.json) records exact commands, source and log hashes, rejected development runs, fixtures and assertion deltas.

## Implemented behavior

Content-v4 plans reserve one Return spring on actual 10–15-room floors and two on 16–24-room floors. Existing room roles, cells, modules, connectors, packs, chests, required boss and final extraction remain. Normal layouts place separated springs before the boss; bounded short-route fallback uses a reachable nonhidden branch when needed. New optional encounter reservations avoid the spring rooms.

The original native-mesh spring prototype has six meshes and four material roles, no collider, healing, immunity or separate gameplay authority. Its water seal and depth-tested glyph respect reduced motion, effect density and graphics preferences. Both spring ordinals measured 6 meshes, 368 triangles, 4 materials, radius 0.68 m and top 1.2066 m. These counts cover the presenter only, excluding existing room geometry. This is CPU/native geometry evidence, not rendered art approval or measured device draw calls.

A spring requires verified local ordinary deaths, a resolved initial trap opportunity and a fresh source-bound threat check. Cancelled, expired or harmlessly omitted initial hazards are recorded honestly; missing actors do not count as defeated. Actual dispatch still unwinding, current relevant warnings, nearby threats and incoming unobstructed hostile projectiles deny return. Remote unrelated events and unassigned awareness queues do not create a permanent global lock. Advisory status is throttled; saving recomputes the full proof.

Cache views retain their original reward records and finite placement search while leaving space around springs. Body and route queries include the real stationary hive layer; floor rays keep the original world layer. Existing nearest-interaction behavior exposes Search or Return without forced Take All. Failed placement retains the ledger record.

Early return secures only actually collected items and Depthmarks, eligible pending discoveries, kill-only XP and existing wear. Before frozen floor scaling, character XP is 20 per credited kill and recruited companion XP is 10 per eligible kill; zero kills grants zero early-return XP. Wear is 2. It grants no full-clear XP bonus, completion count, next-depth unlock, fastest full-clear record, last-completed seed, merchant rotation or Ancient eligibility. Previously secured gear, recruits, discoveries and old completion statistics remain. Profile version 7 is unchanged.

The synchronous verified save occurs before result callbacks or travel. Failed writes leave the run retryable; an accepted save with failed Sanctuary arrival exposes a travel-only retry that cannot grant rewards again. Private source/world/generation identity and Game transition ownership are rechecked through deferred entry, native arrival and final fade. A newer run or adopted destination is not overwritten. The closed expedition is never reactivated.

The existing mobile action, map R/E markers and result panel expose this flow. Results distinguish **LOOT SECURED · DEPTH INCOMPLETE** from ordinary full extraction. Native font/layout checks include scaled touch prompts; this does not substitute for Android touch testing.

## Accepted validation

Godot 4.6.3.stable.official.7d41c59c4 ran serially on copied source with disposable XDG directories and synthetic save fixtures. The project configures Compatibility rendering. Import, strict aggregate script preflight (35 changed scripts plus Companion initialization prerequisite, 36 unique paths) and 120-frame startup passed before runtime suites. All 159 previously accepted modes are retained, with 12 new modes. The import’s unavailable editor-socket and missing Android build-tools notices are recorded separately; no Android export is claimed. No error, warning, leaked object or failed assertion was ignored in accepted runtime logs.

| New suite / mode | Passed assertions |
| --- | ---: |
| `checkpoint_content` | 1,829 |
| `return_spring_visual` | 31 |
| `legacy_hazard_evidence` | 67 |
| `return_spring_geometry` | 120 |
| `checkpoint_safety` | 56 |
| `checkpoint_loot_placement` | 66 |
| `early_return_transaction` | 109 |
| `early_return_reentrancy` | 97 |
| `early_return_restart (write)` | 60 |
| `early_return_restart (read)` | 27 |
| `early_return_travel` | 349 |
| `early_return_ui` | 256 |

Coverage includes 600-seed checkpoint layout contracts and forced fallback sizes 6–24; preservation of all 14 native modules and seven eligible physical chest approaches; real local combat/dispatch/projectile rejection; both cameras; partial Take and capacity/placement failure; failed/read-only saves; callback replacement; actual deferred/ready/fade travel; separate-process persistence; and preserved full extraction, death, loot, companions, inventory, cameras and UI.

Zero-kill XP is a calculation boundary test. Normal middle checkpoint integration uses actual local combat deaths; it is not presented as a zero-kill expedition.

Retained assertion-count changes:

- `smoke_test` 837 → 841 (+4) — Unchanged recursive resource walker loads 4 new runtime scripts and 0 new directories; every original gameplay assertion remains.

## Rejected development attempts and corrections

These diagnostics are excluded from accepted totals; exact copied source and logs remain available.

- Initial preflight rejected an inferred `tracking` local in AbyssLevel. An explicit `bool` annotation corrected only typing; startup/runtime did not run after that parse failure.
- The first 32-mode diagnostic passed 21 modes and rejected 11. Native admission incorrectly asked the player capsule to occupy the solid chest center. It now validates the genuine front approach 1.75 m from the existing anchor, preserving the chest collider, other native paths and LOS checks. Twenty-eight actual populated-chest/blocker/restoration checks were added across seven modules.
- That same diagnostic independently caught four null-to-bool errors in the restart writer when a real boss lacked an ordinary-enemy dispatch property. Printed PASS assertions did not make that process valid. Typed ordinary dispatch and explicit validated success/denial dictionaries now fail closed. Explicit Enemy/Rootwarden/issued-boss range protocols and nonfinite rejection were additional source-review hardening, not a separately observed conversion error.
- The corrective 12-mode diagnostic passed 10 modes but exposed two standalone fixture problems. The travel test attempted to mutate the immutable scene table after a valid partial Take; later attempts then reused the still-active old world and depleted the same cache. The safety test lacked its required living archer and later eligibility checks continued from that failed setup. Test-only corrections retained the actual reward assertions: legal temporary PackedScene cache injection restores the original scene, and actual combat/trap searches restore the checkpoint pose. Fresh-generation prerequisites prevent stale-world cascades.
- The repaired travel fixture exposed a genuine candidate-ready recovery defect. Sanctuary simulation remained disabled while its default collision bodies were removed from physics, so the unchanged native floor proof correctly rejected arrival. A direct copied-source trace measured the missing native ray hit. A separate control using the existing collision-preservation helper retained disabled simulation, restored the native hit and passed the unchanged direct case. The narrow production correction preserves all floor and ownership checks.
- The first full gate stopped after 58 clean modes when retained `depth_dungeon_test` preloaded Abyss before autoload initialization. The new checkpoint component's direct singleton symbol made that existing compile contract fail. Runtime lookup now preserves that existing compile contract and its unchanged assertions.

The recovery correction passed a fresh four-mode retry of 760 checks. The runtime Session lookup then passed 1,577 targeted checks, including both unchanged pre-autoload consumers and actual early-return transactions/travel. Because production changed, the complete 171-mode gate reran from the beginning; the rejected 58-mode prefix is not reused as acceptance. Development counts are never added to the final total.


## Changed files and evidence

16 semantic files were added, 20 modified and no functioning system was removed. The machine report enumerates every path. Major changes are checkpoint planning/source proof and native admission; legacy hazard/ordinary dispatch observations; Session early-return transaction and private identity; Game travel/recovery; existing HUD/prompt measurement; spring presentation/cache placement; and focused fixtures. The original five Rootwarden controller/data/visual/scene/resource files remain byte-identical.

Accepted semantic source: `0b05e5dc7432cdc7562a564902a2121d8ad7695e171a6c9c3d450cbbabde54a6` (910 files). Export configuration: `322dee7b83448040ddc9fac77560cb985855feed11c402291633564a7dd18690`. Evidence: `/workspace/scratch/vaultbound-7d4-validation/final-qlvmuxi7`. New imported UID sidecars are retained without overwriting existing IDs. Explicit restart fixtures, including the physical nonsymlink demo-exchange path, are copied and hashed separately from normal player saves.

## Limits and Android testing

No physical Android device, rendered screenshot/video, GPU profile, APK export, live multiplayer authority, authenticated persistence, hosting or payment integration was tested. Native meshes remain prototypes pending rendered review. Local source guards and versioned offline saves are not a secure online backend.

Current hostile archers use single-hit projectiles. Future hostile splash/multi-target impact dispatch requires additional checkpoint observation before enabling that content. Dungeon sessions still do not resume after process restart; only secured profile progress persists.

Follow [the Return spring guide](dungeon-return-springs.md) and [Android testing instructions](milestone-7-android.md). On a real device verify the two camera views, nearby Search/Return selection with partial/full bags, prompt readability at all UI scales, R/E discovery, failed-arrival retry, focus loss, companion follow, and long-floor frame pacing at Low/Medium/High. Measure 30/60 FPS goals on supported hardware; this headless gate establishes no device-performance result.

Additional biomes, Ancient encounters, expanded recruits, genetics, Veilgarden, Bloodfall and real ranked infrastructure remain later stages.
