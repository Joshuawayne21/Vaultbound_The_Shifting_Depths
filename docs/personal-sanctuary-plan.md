# Prismheart Sanctuary and Personal Sanctuary integration

Status: inspection and staged implementation, 2026-11-09. This is an extension of Vaultbound, not a replacement game. The supplied written layout is the current design reference; no Prismheart blueprint attachment was available for visual comparison. Architectural placement remains provisional until that reference is available.

## Preserved baseline

The accepted starting point is local commit `2344dea9985242b45add601345fe798ac5b5ea10`, published as `f26fce0d99abb31307e1f090f77593e385ec9523`. Both have tree `e38ff352164d87a1d616cd24f03759de8aac0a9f`. Its existing 7D.7 validation is recorded in [the immutable report](milestone-7d7-validation.md). The interrupted, unaccepted 7D.8 shrine changes remain in the original worktree, outside this feature branch.

Before changes, a Git bundle and a verified archive of all 1,667 tracked/untracked, nonignored project files were created at `/workspace/backups/vaultbound-before-personal-sanctuary-2026-11-09`. The backup includes a binary patch, per-file SHA-256 manifest and bundle verification. No default local player save files were found in this environment; this does not back up saves on a player's Android device. No player saves are needed or copied into Git.

Work takes place in the same repository's `feature/personal-sanctuary` worktree. Do not reset the original worktree or incorporate the failed shrine candidate as verified content. Each implemented stage requires its own validation and commit.

## Inspected systems

| System | Existing implementation and integration boundary |
| --- | --- |
| Engine/rendering | Godot 4.6.3, GDScript, GL Compatibility, Android landscape. Root `project.godot` remains in place. No volumetrics or mandatory desktop plugins. |
| Sanctuary | `sanctuary.gd` builds an eight-district town using `SanctuaryLayout`: 45 m radius, 16 m central exchange, 19 m ring road, 8 m radial paths, two 0.8 m terraces. The shared layout also supplies service approaches and companion routes. |
| Player/cameras | Persistent `Game` owns one player, party, HUD and switchable third-person/isometric camera. Travel replaces the level, preserving the gameplay shell. The camera resolves world and camera-only collision. |
| Travel | `Game.LEVELS`, source-bound travel callbacks and prevalidated destination scenes own transitions. Existing portals expose an explicit touch entry card in the city. Four Sanctuary spawn transforms are compatibility contracts. |
| Dungeon progression | Existing Rootbound depth ladder, deterministic three-theme dungeon content, boss objectives and extraction remain untouched by the home portal work. Depth unlocks require the existing successful completion rules. |
| Trading/merchants | Three working NPC merchants and Blacksmith use validated inventory transactions. Ring Exchange has a separate synthetic TEST economy. It is not a live player marketplace. All six planned booths must use that same adapter, not six inventories/economies. |
| Inventory/equipment | Existing item instances, favorites, locks, loadouts and Depthmarks remain authoritative within the offline prototype. `gold` is a legacy internal field; changing its key is unnecessary for this work. |
| Trophies | Existing Collection Hall has eight equipment stands, four relic pedestals, journals and a Rootwarden trophy. Saved display IDs reference inventory UIDs. They do not transfer or duplicate ownership. |
| Pets | Existing eight-pet Spiritweaving catalog, earned ingredients, owned records and one cosmetic follower are retained. Habitat displays must reference those records and have a bounded active count. |
| Companions | Guardian/Mystic roster and three-member party persist independently of world scenes. Navigation currently supports a ground height field and terraced city routes; stacked foyer floors need additional, verified handling. |
| Persistence | `VaultProfileStore` v7 validates whole profiles, preserves exact pre-migration backups and verifies temporary writes before replacement. A home extension must participate in that validation; unknown fields are otherwise omitted during normalization. |
| Environment | Original procedural architecture, shared materials, static mesh batching, ambient wildlife, inexpensive water and local daylight presentation exist. Low/Medium/High presets, reduced motion/effects, density controls and optional 30/60 FPS targets are available. |
| Assets | Baseline contains 408 GDScript files, 110 scenes, 583 resources and 19 SVGs; no GLB/GLTF models or raster textures. Existing procedural models are reusable prototype art, not imported premium character/building assets. |
| Unimplemented services | No authenticated online backend, bank/storage system, guild creation, visiting permissions or real cosmetic billing. Existing documents propose a backend; they do not provide one. Do not display these as functioning online services. |

## Architectural direction

The written city plan keeps the circular exchange and six shared-service booths at the center. The Portal Nexus lies north, Merchant Bazaar and Grand Vault east, Cosmetic Atelier south, and guild/recruitment facilities west. Preserve legacy destination IDs, safe spawns, return routes and saved collection IDs while updating presentation and route maps in the city architecture stage.

The Personal Sanctuary replaces the city Trophy Room portal's destination. Its first arrival is the Grand Foyer. The existing Collection Hall remains a separate loaded room behind a foyer entrance, retaining its runtime location and transaction guards. Home-origin Hall visits return to the foyer; legacy direct Hall visits retain their Sanctuary return. This permits an incremental visual expansion without resetting trophies.

The foyer's ground floor connects Trophy Hall, Pet Conservatory, Armory, Companion Hall and Relic Library. The upper floor connects Personal Chamber, Wardrobe and Rooftop Garden. Maintain compact routes despite monumental ceiling heights. Use sealed architectural space for future Aquarium, Vault, Workshop, Alchemy, Secret Chamber and Achievement Gallery; no unfinished functional menus.

## Ordered milestones and gates

1. **Audit and backup:** inspect systems, preserve accepted and unfinished work, inventory assets, rerun a focused accepted-build baseline and record risks. No claims of new gameplay.
2. **Personal Sanctuary portal:** new safe home entrance/return; preserve city portal review, all legacy destinations and collection ownership. Add a stable offline home identity through validated persistence. Test actual interaction, travel, repeated entry, reload, write failure, stale callbacks and both camera modes. The initial arrival room is explicitly a foundation, not the complete Grand Foyer.
3. **Grand Foyer:** two-story architecture, twin stairs, balcony, chandelier, House Sigil, management and destination doors. Add verified multi-level navigation rather than silently routing companions through ceilings. Test floor/rail collision, all routes, camera sweeps, mobile menus, save/reload and reduced-motion behavior.
4. **Trophy and pet rooms:** retain display IDs and inventory ownership; expand actual matching 3D displays and bounded cosmetic pet habitats. Test owned-only assignment, removal, restart, missing/future content and no duplicate grants.
5. **Other home rooms:** Armory, Companion Hall, Library, Chamber, Wardrobe and Rooftop. Add data-driven, achievable unlocks, themes and decorations. Unimplemented Ancient/guild achievements cannot be mandatory unlocks. Appearance never changes combat stats.
6. **City architecture:** six shared exchange booths, north/east/south/west wings, tall walls/towers, accessible entrances and pathways. Route every existing merchant, recruiter and portal through its current authority. New bank and contract services need their own validated models; online guild/PvP services remain unavailable without infrastructure.
7. **Landscaping:** original modular trees, gardens, water and district identities. Keep roads, interaction areas and camera paths clear across quality settings.
8. **Distant world and sky:** reuse local presentation time; add lightweight distant geography, day/sunset/night and occasional celestial effects. Do not relocate the capital or imply distant scenery is traversable.
9. **Atmosphere:** living Prismheart, limited NPC ambience, licensed/original sounds and coherent detail. No fabricated online players, world events or conversations.
10. **Integration/performance:** run relevant automated regression suites, visual checks where available and document real-device testing. Target 30 FPS with optional 60 FPS, without claiming measurements not collected.

## Save and ownership rules

- Extend the existing versioned profile; do not create a second inventory or currency.
- Preserve original bytes before schema migration and preserve future/unknown saved content through read-only failure behavior.
- Create a home identity once through a successful guarded save. Normalization must never generate random identities or mutate disk.
- Persist themes, sigils, room unlocks and display references; keep owned gear, trophies and pets in their existing records.
- Revalidate ownership, scene/service context and revision at every home mutation. Failures leave in-memory and on-disk progression unchanged.
- A local home is owned by the current offline profile. Networked visits and permissions require authenticated infrastructure and separate validation.

## Current risks and evidence limits

The isometric camera's nominal position is approximately 14 m above the player's floor. Low opaque ceilings, chandeliers or overlapping balconies can obstruct it. Camera collision must remain enabled; geometric clearance and appropriate apertures must be tested. Companion floor sampling currently assumes one height per horizontal point, so a true two-story foyer is a navigation change, not only scenery.

Existing tests intentionally assert the original five destination registry entries, Collection Hall portal and profile schema. Update only assertions superseded by the requested portal/schema change; retain legacy travel, display and save coverage. An interrupted test process is never a pass.

Physical Android performance, notch/keyboard behavior, thermals and touch comfort require real-device testing. No physical Android test, premium imported model, live marketplace, guild backend, bank, payment or visiting system is claimed by this plan.
