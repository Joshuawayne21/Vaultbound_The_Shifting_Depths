# Living Sanctuary integration plan — Milestone 6A

Baseline: local `d77e4d658a8e64bf3a742f58d7c8e40cfdeceb52`, published as `0dc61f8e2a61c757501ef6a3e67bd7d6273cbd24`. Godot 4.6.3, GDScript, Compatibility, Android landscape. This expands the existing game; it does not create a second project, inventory, character controller or currency. See the [inspection](living-sanctuary-inspection.md), [map](living-sanctuary-map.svg) and [validation record](living-sanctuary-validation.md).

## Existing contracts to preserve

- `project.godot` remains at repository root. The persistent game shell retains one player, camera rig, HUD and party while replacing only a world scene.
- Preserve all five destination IDs, four Sanctuary arrival IDs/transforms, existing portal signals, dungeon generation validation and safe transition/return behavior.
- Preserve Sword/Shield and Staff combat, owned loadouts, attack timing and effects, both cameras, touch ownership and modal pause behavior.
- Preserve all 351 registry IDs (350 noncurrency definitions), forty-slot inventory, eleven equipment assignments, twelve display references, enhancement caps and modifiers. Depthmarks continues to use the existing `gold` balance and `gold_coin` compatibility ID.
- Preserve existing v1–v4 progression, item UIDs, exact upgrade/roll values, companions, talents, discoveries, stock history and immutable migration backups. No save change is needed for city geometry.
- Existing authored dungeon modules, connectors, spawn clearance, encounter rules and extraction authority remain the source of gameplay truth. Cosmetic decoration uses its own seed and must not advance generation or encounter RNGs.

## Master layout

The proposed footprint is a **90 m diameter** circular enclosure, replacing the old 27 × 29 m rectangle (about eight times its ground area). The central Ring Exchange has a **16 m radius** gathering plaza and a **6 m wide circulation road centred at radius 19 m**. Eight broad radial approaches connect districts centred about **33 m** from the heart. Normal service entrances remain roughly six to eight seconds from the ring at ordinary movement speed; this is a design estimate, not a timed play-test result.

Keep the existing central arrival pads and floating crystal sightline. Build the crystal above a shallow ornamental fountain, with circulation around it and protected space for party formations. Counters, benches, gardens and low walls occupy wedges beside the routes. Architectural upper rings/balconies provide silhouettes; walkable upper terraces have actual ramps and collision, rather than invisible stairs. Use simple native geometry, shared materials and spatial static batching.

| District | Direction / approximate centre (x,z) | Working 6B interaction | Later connection |
| --- | --- | --- | --- |
| A — Portal Promenade | North (0,-33) | Existing Rootbound and practice portals; source-bound information and explicit Enter | Party readiness; authorized matchmaking only with a real backend |
| B — Combat Coliseum | Northeast (23,-23) | Existing practice target and Proving Grounds portal | Training challenges; consensual duels require separate authority rules |
| C — Merchant Terraces | East (33,0) | Existing General Merchant, Equipment Trader and Relic Appraiser | Existing completed-expedition stock cycles |
| D — Trophy Hall & Relic Gallery | Southeast (23,23) | Existing Collection Hall portal and owned exhibits | Expanded collection metadata; unknown legacy discovery dates stay unknown |
| E — Master Forge | South (0,33) | Existing Blacksmith upgrade/repair/salvage/craft services | Existing +5/+10 policy; no alternate economy implementation |
| F — Cosmetic Pavilion | Southwest (-23,23) | Existing rotatable equipment/appearance preview and showroom information | Separate cosmetic-only demo catalog in 6H; billing gated in 6I |
| G — Spiritweaving Conservatory | West (-33,0) | Conservatory guide, navigation and collection information | Earned pet acquisition, recipes and journal in 6E |
| H — Tavern & Recruitment | Northwest (-23,-23) | Existing AI recruitment and party board | Social board; bank/storage must be an explicit future ownership feature, never fake extra inventory |
| Ring Exchange | Centre (0,0) | District guide/map and destination selection | Local TEST exchange in 6F, real authority gate in 6G |

The Forge and Tavern have accessible **0.8 m terraces** with broad gentle ramps. Ground-level public routes stay continuous. The old navigator explicitly rejects raised floors, so these terraces require an opt-in city navigation extension: authored ring/spoke/ramp waypoints plus local grounded capsule sweeps. Generated dungeons keep the current flat-floor implementation. No teleport is used to pass a traversal test.

District labels, a readable hub map, restrained destination markers and directional signs share one layout definition. Services get explicit approach anchors; tests and UI resolve those anchors instead of maintaining another set of hardcoded coordinates. A chosen map destination is a waypoint, not permission to interact from a distance. Fast travel is optional and is not needed to make the initial city walkable.

## Implementation and verification order

### 6A — inspection and plan

Record the actual architecture, offline authority boundary, save contracts, map, budget and risks. Verify the untouched baseline with isolated import/startup/smoke; retain the previously recorded complete 5.6 gate separately. Commit this plan before runtime changes.

### 6B — connected city and interactions

Add a reusable layout resource, city construction modules and district terminals while reusing the existing Sanctuary scene/script entry point, architecture palette and service scenes. Relocate existing services deliberately; retain their identities and authority checks. Expose map/waypoint state separately from the dungeon minimap. Use the existing exclusive modal/input owner for map and portal cards. Revalidate portal source, current world, proximity, line of sight and destination before explicit Enter. Preserve repeated-tap/fade guards and obvious mobile interaction controls.

Extend navigation only for an explicitly declared terraced Sanctuary. Broad ramps and bounded intermediate route goals must support actual follower motion in both directions; cliff edges and inaccessible upper decorations remain rejected. Keep central arrivals, camera-only occluders and open core combat-fixture space. Sanctuary has no hostile player combat or networked duels; practice targets retain their existing rules.

Gate: native resource import, each district reachable on foot, service/portal access, actual player and two-companion ramp traversal, both cameras, source-bound interaction expiry, three mobile canvas sizes/scales/insets, unchanged secured profile bytes for presentation-only actions, existing combat/loot/economy/save regressions. Update coordinate-dependent fixtures to shared approach contracts without removing the behavior they checked. Commit only after critical regressions are resolved.

### 6C — landscape, ambience and dungeon decoration

Add original procedural gardens, layered distant forest/cliffs/ruins/water silhouettes, city landmarks, a bounded day/night presentation cycle, ambient NPC/animal motion and pooled/instanced butterflies. Keep high-contrast interaction and combat silhouettes. Use existing water/material/environment/quality systems. Decorative effects have explicit Low/Medium/High ceilings, distance culling and reduced-motion/effects behavior; no hundreds of active NPCs, lights or simulated fauna.

Rootbound is the only playable biome. Improve its existing seeded room motifs without altering rooms, connectors, spawns or encounters. The other requested biome names may receive data-only art direction definitions, explicitly unavailable; do not advertise new playable biomes or synchronization before they exist. Gate reproducibility, budgets, physics clearance, all 100 structural seeds, existing AI/combat/camera behavior and extraction. Rendered screenshots/video are supplied only if an actual supported rendering environment is available.

### 6D — social presentation and chat boundary

Add a visual-only emote layer with cancellation on movement/combat/damage/travel, a touch wheel and truthful actor interaction cards. Route a compact transcript and native text composer through the existing modal owner so Android keyboard input cannot also move/attack. LOCAL/WORLD/PARTY interfaces must state offline/local demo status until transport and authentication exist. No invented global population or human messages. Bound history, message length and local rate limits; define server-side identity/channel/moderation requirements independently of client controls.

### 6E — earned cosmetic pets

Create separate data-driven pet definitions/recipes and ownership, one active noncolliding cosmetic follower, bounded reactions and a collection journal. Acquisition uses actual completed Rootbound discoveries/encounters and explicitly earned ingredients; no nonexistent biome/boss unlocks. Save via an explicit versioned migration preserving the old profile and immutable backups. Pets never change stats, targeting, loot, currency generation, inventory size, access or AI party slots. Test ingredient/receipt replay protection, exact saves/restarts, extraction/death rules, follow/recovery and transitions.

### 6F — local TEST exchange and backend contracts

Implement direct-trade and buy/sell order interfaces against an isolated test adapter using the real catalog but synthetic test identities/assets/DM. Both sides lock and finally confirm; changes invalidate locks. Support order escrow, compatible matching, partial fills, cancel/expiry, receipts, bounded history and explicit reset semantics inside that adapter. Every screen says **DEMO / NOT LIVE**. No demo action mutates `ExpeditionSession.profile`, secured inventory, actual Depthmarks or a future online account.

Define authenticated API/data contracts, globally unique asset/trade/order IDs, authoritative eligibility and channel checks, database transaction boundaries, idempotency, disconnect/recovery behavior, escrow and moderation/retention requirements. Tests must prove isolation from real progression as well as conservation and replay rejection inside the demo model.

### 6G — separately reviewed online authority

Reassess concrete backend availability and authorization after 6F. Current inspection finds no account service, authoritative multiplayer server, persistent online database or configured credentials. Do not relabel a local adapter as a live market. New internet-accessible hosting or external service configuration requires the user's explicit approval before deployment or costs. Present the finished contract, required setup and test plan at that gate. Two authenticated clients, account/channel isolation, persistent escrow, offline order fills and interrupted trades must be tested before claiming an online build. Existing editable offline ownership cannot silently become trusted online assets.

### 6H / 6I — cosmetics and billing

6H follows the online-authority decision in the requested order: separate appearance/entitlement data, try-on preview, owned status, UTC schedule configuration and a clearly labeled local test catalog. Demo unlocks are not purchases and never enter tradable inventory. All cosmetic choices remain statistically neutral. 6I requires store account/billing setup, secure token verification, idempotent entitlements, refunds/revocation/restore and official test purchases. Do not collect card data, buy paid assets or process real payments without the stated approvals. The current project has none of that infrastructure.

### 6J — integrated acceptance

Run every available automated suite, new stage tests and independent restart readers on frozen source; report every unresolved failure. Recheck original portals, combat, loadouts, companions, generation, boss, loot/extraction, transactions and saves. Record structural budgets and scoped host measurements separately from physical Android evidence. Stable 30 FPS and optional 60 FPS, Android keyboard/cutouts/touch, visual polish, audio and thermal behavior require actual devices. Stop at a required external authorization boundary and report concrete completed work and blockers.

## Initial mobile budgets and honest asset scope

- Preserve one environment and one main directional light per world; no new volumetric rendering or per-lamp realtime lights.
- Spatially batch static native geometry; cull optional decorative groups by existing quality distance. Keep routes, service hotspots and collision invariant across presets.
- Cap new ambient actors and butterflies explicitly; prefer shared meshes/instances and throttled updates. Existing enemy (six), companion (two), loot-view (eight) and item-spark (4/8/12) budgets remain intact.
- Use original procedural/native geometry and shared family art. No imported professional rigs, unique trophy sculptures or paid asset purchases are implied.
- Keep the full existing save as the migration source of truth. New fields must be allowlisted and validated; unknown prior discovery dates remain unknown. Local demo data has a distinct namespace and cannot be promoted into real balances.
