# Milestone 7 — Infinite Depths integration plan

This is a staged extension of the existing game, not a replacement project. The starting checkpoint is Living Sanctuary 6F. Stages are implemented and validated in order; later rows below describe planned work, not available features. Public hosting, payments and real ranked play remain separately gated. The owner has confirmed there is no existing backend; the [backend proposal](living-sanctuary-backend-proposal.md) remains a proposal.

## 7A — inspected and preserved baseline

Inspection on 2026-11-01 found a clean local commit `7018f685f9bad3b7f00dc95bd4f8880a1c814a9a`, published as `7d6bf8692bf9252f0654edd5fa1aa1fc2dc184bd`. Both commits have tree `f75ba4d55f23afb1d7c088a8784fd4e9ed1b01f6`. The preserved 6F source ZIP and Git history remain intact. No normal player save was opened or overwritten by the audit.

Fresh isolated import, 120-frame startup and **760 smoke assertions passed**. The copied baseline contains 775 semantic files with SHA256 `5687d40205e9b32f875d2e492f0933b11c17221fddf1b35f5a727c2de32ec478`, exactly matching the accepted 6F source. It contains 219 GDScripts, 59 scenes, 466 resources, seven shaders and nineteen SVGs. The previous full **17,741-assertion / 89-suite / 108-process** result remains historical evidence; it was not rerun for this documentation-only audit. [7A baseline results](milestone-7a-test-results.json) contain commands, hashes and limitations.

| System | Current implementation and preservation boundary |
| --- | --- |
| Engine/platform | Godot 4.6.3 standard, GDScript, GL Compatibility, Android landscape; root `project.godot`; Low/Medium/High and 30/60 targets |
| Sanctuary | 90 m circular enclosure, Ring Exchange, eight districts, broad roads, Forge/Tavern ramps, exact service POIs and original arrival transforms |
| Presentation | Native original mesh families, one light/environment per world, 20-minute local daylight cycle, distant panorama, bounded residents/hares/butterflies; no production imported rigs |
| Player/combat | One controller and shared rules; sword/shield and staff, abilities, dodge, health/stamina, targeting and both smoothly switchable camera compositions |
| RPG | Depthmarks displayed as DM; preserved internal `gold`/`gold_coin`; 350 noncurrency definitions, 40-slot inventory, exact instance IDs, two loadouts, guaranteed enhancement, merchants/crafting/talents |
| Expedition | Rootbound Abyss, fourteen handcrafted native room modules, seeded 8–12-room layouts, three enemy archetypes, Rootwarden, hazards/awareness, searchable caches, secured extraction and loss of only unsecured loot on death |
| AI party | Human leader plus up to two recruited local Guardian/Mystic companions; commands, follow/navigation, combat, downed/revive and saved progression |
| Pets/collections | Eight earned cosmetic pet species, one follower, original native placeholders, fixed natural/luminous variants, Spiritweaving, collection journal and owned-item Hall displays |
| Persistence | Profile v5, copied-candidate validation, verified temporary replacement, rotating backup and immutable pre-migration snapshots; no write on migration load |
| Social/economy demo | Local emotes and AI inspection; LOCAL self-preview only, WORLD/PARTY cannot send; isolated TEST exchange with synthetic accounts, escrow, trades and receipts |
| Online/ranked | No authentication, trusted session server, persistent online database, live chat/market, leaderboard, billing or authoritative combat. Android Internet permission remains disabled |

The managed environment reports no configured backend secrets, runtime variables or outbound identities. Its network capability is separate from an implemented game server. No infrastructure, account or payment service was provisioned.

## Main risks and non-negotiable contracts

- The generator's `rooms[].depth` is **BFS distance from the entrance**, not dungeon-floor progression. Add a separate expedition-depth configuration; preserve the existing field and legacy seeded generation API where practical.
- Profile normalization rebuilds an allowlisted dictionary. New progression, recruits, genes and trophies require explicit schema validation/migration. `VaultInventory` also gates source schema versions; raising only `ProfileStore.VERSION` would reject otherwise valid equipment.
- Keep every item ID, UID, roll, enhancement, loadout, discovery, achievement, companion, pet and secured balance. Old floor fields, if supported by an explicit legacy migration, must be validated and retained. Repeated historical completions do not imply that many different floors were cleared.
- Source authority binds encounters, discoveries, chests and extraction to an immutable world/run generation. Depth, boss selection, new events and rewards must join that identity. Save before publishing a completion/unlock/reward; never install state from a stale world callback.
- Current runs are in memory and are not resumable. Seed-only Ancient rolls cannot prevent reload rerolls. Persist a once-only outcome/ticket tied to an eligible secured completion. Offline anti-replay is not protection against edited saves or a substitute for server authority.
- The Sanctuary is authored at radius 45 m with 8 m roads and two 0.8 m terraces. Do not globally rescale it or open a perimeter gap beyond its floor. Existing navigation supports these authored ramps; dungeon routing uses a flat 24 m room grid and bounded obstacle checks, not arbitrary vertical navmeshes.
- Camera collision sweeps a sphere against world and camera-only layers after smoothing. New opaque nearby geometry needs matching collision or verified clearance. Essential silhouettes and obstacles must not disappear on Low quality.
- Preserve one modal/input owner, native keyboard capture/release quarantine, explicit portal review/ENTER and source/scene-generation guards. New screens reuse those paths rather than adding competing touch handlers.
- Pet ownership currently keys by species; genetics needs a real instance model plus compatibility adapters for preview/following/naming. Preserve old appearance deterministically. Parent pets remain owned.
- Current party admission instantiates AI in every supported world. Future competitive admission must explicitly reject AI; a scene label is insufficient. Character level currently stops at 30, so 40+ ranked brackets are unavailable until separately implemented.

## Ordered stages and acceptance gates

| Stage | Intended implementation | Gate / availability boundary |
| --- | --- | --- |
| 7A | Repository/source/save-contract audit and preserved baseline | Complete; documentation-only commit before runtime changes |
| 7B | Taller varied perimeter, landmark towers, distinctive giant trees, distant water/rock silhouettes and improved existing portal ornament | Preserve all road/service/spawn footprints; actual camera/physics/nav checks, graphics limits and current portals; no fake purple/red destinations |
| 7C | Data-driven depth bands through 50, selection/eligibility, permanently secured unlocks and bounded scaling | Depth 2 locked initially; boss/objective plus successful completion unlocks next once; legacy-save/restart/death/retry checks |
| 7D | Configurable 6–24-room generation, biome room presentation, fair hazards, hives/hordes and boss pools | Connected routes, valid spawn/arena/extraction, deterministic separate decor RNG, active-enemy caps and clear telegraphs; unimplemented content remains unavailable |
| 7E | Once-only Ancient completion rolls, optional encounter admission, exclusive source-eligible rewards and chronicle | Configurable 0/0.25/0.5/0.75% bands, deterministic development hook, persisted outcomes and no duplicate grants; no online-security claim |
| 7F | Unlockable recruit tiers/classes, barracks, progression/gear and compact tactical commands | Preserve Guardian/Mystic roster and three-member capacity; no unsupported weapon mechanics presented as working; no AI in competitive ranked |
| 7G | Owned 3D trophy displays, boss remains gallery and collection records | Correct models/origin, persistent selections without consuming or duplicating ownership; unknown old discovery dates remain unknown |
| 7H | Constrained modular genes, unique pet instances, hybrid recipes, odds and lineage | Exact old appearance migration, deterministic genes, parent preservation, save/reload and preview/follower consistency; cosmetic only |
| 7I | Purple portal and separate Veilgarden with bounded collection residents | Trusted Spiritweaving source registration, safe arrival/return, active-pet cap, complete collection paged separately |
| 7J | Red portal and Bloodfall Frontier landscape/local unranked practice | Safe spawn/return, camera-readable cover, objective practice and honest offline labels |
| 7K | Solo/team ranked UI, eligibility/normalization rules, records and server contracts | DEMO/UNAVAILABLE until actual authority exists; no fictional queue, human players, scores or leaderboard claims |
| 7L | Real authenticated authoritative ranked service | **Blocked until infrastructure/design and deployment scope are authorized and tested.** No public hosting/costs or payments without approval |
| 7M | Integration, mobile UI/performance polish and device evidence | Headless source/logic tests first; physical Android GPU/IME/touch/thermal/FPS acceptance requires actual devices |

Each completed stage gets a reviewable commit, relevant regression checks, changed-file summary and documented limitations. A failed critical gate stops dependent work until corrected. The new request authorizes this Milestone 7 sequence; it does not imply completion of the still-unimplemented 6G online service or 6H/6I cosmetic storefront/billing.

## 7B concrete visual plan

Current boundary consists of 64 repeated **1.4 m** walls at radius 44.6 m and sixteen 2.8/3.8 m columns. Increase selected wall courses to **3.2/3.7/4.2 m** while retaining their X/Z collision footprints. Give existing column sites varied 5.6–8 m tower silhouettes and elevated ornament. New trim stays outside the road/service envelope. No decorative arch is advertised as a walkable exit through missing terrain.

Add four recognizable giant-tree landmarks around radius 70 m, approximately 22–30 m tall, with different trunks, branches and crowns. Their complete geometry bounds remain outside radius 56 m, beyond the town/camera envelope. Add restrained distant waterfalls and floating stone forms in the same bounded layer. Keep the existing panorama and fauna allocator; the new landmark layer targets at most twenty additional geometry batches and 12,000 triangles, no extra gameplay physics/navigation and no per-frame simulation.

Preserve the existing daylight cycle, fog, single key light, quality settings and reduced-motion policy. Use original shared material families and world-owned accent variants; no volumetrics, extra light farm or shared-resource mutation. Blue Rootbound and gold Hall presentation may improve now without changing routes or interaction dimensions. Purple/red functional gateways wait for their actual scenes in 7I/7J.

Relevant checks include import/startup, resource smoke, Sanctuary world/UI, actual city/companion traversal, surface continuity, camera sweeps, pet following, source-bound portal/market entry, graphics preferences and unchanged save contracts. New structural checks must inspect native mesh bounds or captured authored transforms rather than unreliable headless MultiMesh transform readback. Existing full-suite evidence stays separate from newly run focused checks.

## Visual and device evidence limits

The [6C performance record](living-sanctuary-6c-performance.md) is a historical host baseline, not a new Android measurement. The existing source uses original native placeholders; thousands of possible pet combinations would describe combinations, not thousands of finished models. No production model, physical Android test, GPU frame rate, rendered screenshot or APK export is claimed by 7A. Any later visual capture must be identified by its actual renderer/platform. The [Android checklist](living-sanctuary-android.md) remains applicable and will gain stage-specific routes and checks.
