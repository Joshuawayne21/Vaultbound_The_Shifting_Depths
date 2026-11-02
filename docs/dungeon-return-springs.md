# Return springs on longer expeditions

This guide describes the accepted **7D.4 Return spring batch**, covered by [headless validation](milestone-7d4-validation.md). Physical Android play-testing and rendered art review remain pending.

Return springs offer a shorter expedition: secure what you have collected, return to Sanctuary and leave the depth incomplete. The existing boss-gated extraction spring remains the route to full completion and the next depth.

## Placement and discovery

Content-v4 plans reserve one Return spring when the generated floor has 10–15 rooms, and two with 16–24 rooms. Shorter floors retain the existing final extraction. These thresholds use the actual generated room count, not a promise that every selected depth always has the same number of rooms.

Normal long routes place two separated springs along the route before the boss. The generator's bounded short-route fallback instead places a middle-route spring and a distant, reachable nonhidden branch spring. That second location is an exploration return point, not a mandatory objective. Existing room types, native modules, topology, enemy packs, treasure and required boss locations remain intact.

Springs use a low water seal and open return glyph. They add no collider, healing zone or damage immunity. Both promised positions must pass native floor, body, route and camera checks before admission; missing ground cannot be patched with a synthetic platform. Optional Champion, hive, horde and typed hazard placements avoid their reserved rooms. Ordinary enemies and the native initial trap opportunity remain.

The minimap marks discovered springs with **R**, distinct from the final **E** extraction. Undiscovered return locations remain hidden. A sealed or unsafe marker communicates availability but never authorizes a save.

## Interaction and safety

Approach a spring and use the existing mobile interaction button. An eligible blocked spring explains the reason. There is no held channel or safety modal. Authoritative checks run again at the actual interaction; the player remains vulnerable until a valid save commits and normal scene travel begins.

A room's original enemies must have real, verified deaths. Missing or paused enemies do not count as defeated. Its initial trap opportunity must have resolved normally; an expired, cancelled or harmlessly omitted opportunity is not described as a successful attack. Springs do not rearm old traps or cancel an existing warning to make an exit available.

Local active warnings, damage dispatch, relevant nearby hostiles and incoming unblocked projectiles prevent return. An unassigned awareness queue, a dormant source in another room or a distant event cannot permanently lock a clear spring. Threat queries remain bounded; advisory prompt status may be cached, while saving always performs fresh source and safety checks.

Loot cache **views** use bounded native placement around the spring's footprint. Their reward records, items, quantities and receipts remain unchanged. Walking nearer a cache selects Search; walking nearer the seal selects Return. Partial collection or a full bag must not force Take All or hide the return action. If no valid cache view can be placed, the original ledger keeps its reward available for later placement. Body and route probes also include the existing stationary hive obstacle layer; ground probes keep their original world-floor layer.

## What early return saves

| Result | Early return | Full boss extraction |
| --- | --- | --- |
| Already collected items and Depthmarks | Secured once | Secured once |
| Pending eligible pet findings and encounter discoveries | Secured once | Secured once |
| Unsearched or untaken cache contents | Left behind | Left behind |
| Actual monster kill credit and discoveries | Retained | Retained |
| Character XP before frozen floor scaling | 20 per credited kill | 250 plus 20 per credited kill |
| Recruited companion XP before existing eligibility/caps/scaling | 10 per credited kill | 150 plus 10 per credited kill |
| Existing equipment wear | 2 | 2 |
| Completed-floor count and next-depth unlock | Unchanged | Updated |
| Fastest full-clear time and last completed seed | Unchanged | Updated |
| Completion-based merchant rotation | Unchanged | Updated through existing completion count |

Zero credited kills means zero early-return XP. Optional hive/horde credit retains its existing actual-member rules; the hive shell grants no monster kill credit. Reward and XP scaling use the admitted floor policy once. Early return grants no full-clear bonus or Ancient encounter eligibility.

The result screen says **LOOT SECURED · DEPTH INCOMPLETE**. Collected rewards are labelled secured, not lost. After the required boss is defeated, use its ordinary final extraction spring; early return is no longer available for that run.

## Save-before-travel and retries

The existing profile-v7 shape and ownership remain intact. A source-bound synchronous transaction validates the real checkpoint, builds one detached candidate and verifies the save before publishing results or requesting travel. It never sweeps generated cache contents into inventory.

If saving fails, the current bag and run remain retryable. If saving succeeds but Sanctuary loading fails, the same spring offers **Loot secured · Return to Sanctuary** as a travel-only retry. It cannot award XP, items, currency or wear again.

The accepted return binds the actual source, world and run generation. Game checks that identity during deferred travel and across scene-transition waits, including the final fade. A callback-created replacement run cannot be cleared or redirected by an older return. The old closed expedition may be retained briefly for identity verification; it is never reopened as an active expedition.

These are offline prototype consistency guarantees, not authenticated multiplayer security. Current runs still have no resumable dungeon save. Previously secured items, recruits, currencies, progression and collections remain governed by the existing persistence system.

## Validation and device review

The accepted stage report records deterministic checkpoint counts across configured and forced fallback layouts; native floor/route/camera admission with actual populated chest approaches; real room-clear and incoming-damage denial; partial loot, capacity failures and save retries; callback/replacement-run safety; travel-only retry; both cameras; unchanged full extraction/death; and separate-process persistence. It retains the complete prior regression and corrected pet observer. Safety evaluation requires an explicit valid success result; missing or malformed results cannot authorize a return.

Android review must still check glyph/marker readability, nearby Search and Return selection, touch comfort, long-floor frame pacing and scene-transition recovery on physical hardware. Native geometry and headless tests cannot establish mobile FPS or finished visual quality.
