# Nexus of Realms — existing-system audit

Audit checkpoint: **2026-11-13**. This records the inspected game before the Nexus reorganization; it is not acceptance of new portal activities. The starting build is **0.7.0-home6b / Android code 29**, local commit `1c05c94fa7cb733bcc2d775db9de7874cbb7bf73`, published `main` commit `8275babeb3338e1fde049d6e9ad2138cd357e0de`. Both have tree `05a1d69b70e16579d4fe43917877b518d4c4aef5`.

The preceding Sanctuary polish passed its own 8,435-check, 33-mode native gate. That historical result does not validate a relocated city or Nexus. Its [report](personal-sanctuary-m6-1b-validation.md) and machine evidence remain unchanged.

## Recoverable baseline

Before major changes, the full source history was bundled and verified at `/workspace/backups/vaultbound-before-nexus/accepted-home6b.bundle`. SHA-256: `b5023875cfdbd8b600fedbc7da6cc799a1fe570e07665505dc2d8e397a4d35f1`. It contains the accepted local commit above. This source backup does not contain or back up a player's phone saves.

Work continues in the existing `feature/personal-sanctuary` worktree at `/workspace/vaultbound-home`. Unrelated changes in the original worktree are outside this milestone. Do not reset them, merge them as verified work, or overwrite existing profile files to simplify testing.

## Engine, city and travel

| Area | Inspected implementation and integration boundary |
| --- | --- |
| Engine | Godot **4.6.3**, GDScript, GL Compatibility, Android landscape. `project.godot` stays at the repository root. No required native or desktop-only plugin. |
| Existing city | `scripts/world/sanctuary.gd` and `scripts/sanctuary/sanctuary_layout.gd` construct an eight-district, 45 m radius city. The Exchange paving, radius-19 m ring, eight broad radial routes, courtyard wall/arches and two raised terrace routes already exist. The new four wings should organize these routes, not silently delete half of them. |
| Exchange | Six counters and the City Guide share the same registered DEMO Exchange adapter. `prismheart_visual.gd` owns the existing Living Prismheart presentation. Do not create a second economy or replace the centerpiece. |
| Gameplay shell | `scripts/systems/game.gd` retains one player, party, HUD and switchable third-person/isometric camera while loading world scenes. City services and portals recheck active world, actor state, distance and line of sight. |
| Portal destinations | Existing city entries lead to the progressive `rootbound_abyss`, `dungeon` practice scene, `combat_arena` Proving Grounds and `personal_sanctuary`. The home entry retains its legacy `collection_hall` POI identity. Existing home-room destinations remain separate from the new activity catalog. |
| Dungeon content | Progressive depths 1–50, seeded layouts, the Rootbound/Crystal/Ember themes, real boss families/variants, supported traps, Rootbound hive/horde events, searchable rewards, early returns and final extraction exist. Boss defeat plus valid completion/extraction controls the next-depth unlock. |
| Ancient encounters | **Not implemented.** `boss_registry.gd` admits the nine existing boss IDs and three supported optional minibosses. Historical Milestone 7 documentation explicitly leaves Ancient encounters at the later 7E stage. Catalog references to future trophies are not functioning Ancient bosses. |
| Rendering | Shared mobile materials, static batching, instanced scenery, bounded ambient fauna, inexpensive water and a local daylight presentation exist. Low/Medium/High, reduced motion/effects, density controls and 30/60 FPS targets are available. No device FPS claim follows from headless/native counts. |
| Art | Existing character, item and environment assets are predominantly original native-mesh/available-family prototypes. A new gateway silhouette does not establish a finished premium model, rig or activity environment. |

The current default city arrival is `(0, 0.15, 8)`. Three return contracts are `from_dungeon` at `(0, 0.15, -5.4)`, `from_abyss` at `(3.5, 0.15, -5.5)` with yaw `-PI/2`, and `from_hall` at `(-3.5, 0.15, -6.5)` with yaw `-PI/2`. Stage 1 intentionally moves only the default arrival to the southern city foyer, subject to actual floor, formation and camera validation. It must not rewrite the three return contracts.

## Services, ownership and progression

| System | Working behavior | Missing or constrained behavior |
| --- | --- | --- |
| Inventory/equipment | `inventory_model.gd` owns one 40-slot instance inventory, stable UIDs, two weapon loadouts, eleven retained slots, locks/favorites, enhancement, durability and bounded modifiers. | No replacement inventory is needed for the Nexus. Supported combat weapons remain sword/staff; catalog-only families are not automatically equippable. |
| Depthmarks | Earned currency is displayed as **DM**. Atomic offline transactions validate candidate state before saving. | The persisted internal key is still `gold`. Do not rename or duplicate the currency during this work. |
| Merchants and Blacksmith | Three vendor identities (`general`, `equipment`, `appraiser`), working buy/sell/appraisal, and Blacksmith crafting/repair/salvage/upgrades. Twenty recipes are registered. Rotation uses secured expedition counts. | Additional stalls may reuse these authorities. Their presence must not create duplicate stock allowances or separate inventories. |
| Enhancement | `enhancement_policy.gd` enforces +5 ordinary equipment and +10 Mythic/Ancient Relic, with deterministic costs/materials. | Collectibles and unavailable weapon families cannot be upgraded as equipment. |
| Bank | The older overlay's internal `bank` tab reads the existing **SECURED COLLECTION**. | **No independent bank storage, deposit or withdrawal model exists.** A labelled building cannot be represented as an implemented vault transaction system. |
| Cosmetics | Existing equipment preview, home themes/Sigil choices and wardrobe presentation are cosmetic. | No separate purchased-cosmetic catalog, entitlement store, billing or cosmetic shop checkout exists. |
| Pets | Eight Spiritweaving species, `natural`/`luminous` variants, earned ingredients/memories, recipes, naming, journal, one cosmetic follower and six home habitat display slots. | No massive genetics, parent lineage or Beastwilds capture system. Existing provenance and recipe ownership must survive any later extension. |
| Companions | Guardian/Rowan and Mystic/Lyra, persistent recruitment/XP/level/trait/proficiency, follow/combat/hold/retreat/revive behavior. | `party.gd` allows three total members and two AI. Titan's proposed four-player party is not already supported. |
| Personal Sanctuary | Stable home identity; two-story foyer; Trophy Hall, Pet Conservatory, Armory, Companion Hall, Relic Library, Personal Chamber, Wardrobe and Rooftop Garden. | City relocation must preserve the home destination and all owned-room/display data. Online visitors and permission services do not exist. |
| Trophies | Eight equipment stands, four relic pedestals, owned-instance assignments, journals and a native Rootwarden bark-head/heart presentation. | Future boss-item definitions are not earned trophies or completed boss encounters. |
| Guild/social district | Tavern recruitment and offline social presentation exist. | **No guild creation, membership, rankings, Guild War Room activity, Hall of Champions ranking service or Guild Conquest implementation.** |
| Hidden Undercroft | Appears in prior architectural plans. | **No implemented Undercroft scene or functional secret-passage system was found.** It will need new work, rather than a claim of preserving an existing playable room. |

## Masks of the Abyss — missing established rules

Production scripts, resources, scenes and tests contain **no Masks of the Abyss model, F–S condition-quality system, Abysmal rarity or established mask-drop probability table**. `scripts/progression/item_definition.gd` defines seven tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic and Ancient Relic. Inventory durability is a separate existing integer from 0–100; it is not evidence of the requested mask condition grades.

Only two mask-named catalog entries were found:

- `etched_patrol_mask_piece`: an obtainable Rare sellable collectible with no equipment slot or powers.
- `forgotten_monarchs_mask`: an unobtainable Mythic trophy reserved for a future boss; no active acquisition source.

Preserve both IDs and their data. The user's established mask definitions, quality ranges, probabilities and Abysmal rules are required before integrating those mechanics. Do not invent those values, silently reinterpret existing durability, add a new rarity to unrelated items, or claim that the established system has been migrated. City architecture and portal routing can proceed independently of this missing specification.

## Persistence and service contracts

`VaultProfileStore` is **version 11**, at the existing `user://vaultbound/profile.json` location. It validates complete candidates, verifies temporary writes, retains backups, preserves exact pre-migration bytes and refuses to overwrite unsupported/corrupt data with empty defaults. Home data uses **namespace version 3**. Relevant saved data includes item instances/equipment/loadouts, legacy reserves, display UIDs, transaction receipts, merchant purchases, character XP/talents, companions, pets, discoveries, dungeon statistics, depth progression, encounter records, home identity/styles/rooms/pet displays and the default-OFF TEST ACCESS setting.

Normalization rebuilds admitted fields. Adding mastery, renown, seals, mask qualities or new companion/pet schemas without a deliberate versioned migration can lose or reject data. Layout-only work should leave the save schema unchanged. New activity settlement must have its own admitted completion source, receipt and reward validation; it cannot masquerade as an existing Rootbound encounter or extraction.

Service relocation should preserve these contracts:

- `ExpeditionSession.open_service`, `quote_action` and `commit_action` own commerce and revalidate service kind, vendor, actor readiness, range, line of sight, revision, costs and one-use confirmations.
- `systems/game.gd::_on_city_terminal` routes the existing equipment preview, shared DEMO Exchange and Spiritweaving interfaces.
- `_pet_source_valid` requires the registered direct child **`ConservatoryCityTerminal`**, its existing script, `conservatory` kind/ID and the active Sanctuary. Relocate this existing source rather than duplicating it.
- Home services validate their world's registered source, owned home identity, room and actor. Moving the city home entrance does not require replacing home scenes or saved display assignments.
- Keep stable POI identities: `rootbound_abyss`, `dungeon`, `combat_arena`, `training_target`, `merchant_appraiser`, `merchant_general`, `merchant_equipment`, `collection_hall`, `blacksmith`, `equipment`, `conservatory`, `tavern`, `map`, plus the six Exchange booth IDs. Presentation labels and positions can change through the shared layout.

## Online limits and verification boundary

`offline_social_adapter.gd` explicitly provides no authenticated transport or remote delivery. LOCAL supports a clearly labelled local preview; WORLD/PARTY sending is unavailable. No production RPC, multiplayer peer, HTTP or WebSocket transport was found. The Exchange's persisted synthetic TEST economy is isolated from earned progression. The existing [backend proposal](living-sanctuary-backend-proposal.md) and [server contract](living-sanctuary-server-contract.md) are designs, not deployed services.

Live ranked PvP, matchmaking, spectators, guild competition, team extraction, remote achievements and leaderboards therefore need separately authorized authenticated infrastructure and actual multi-client tests. No paid hosting, public deployment or payments are authorized by merely documenting these dependencies.

Existing regression coverage includes Sanctuary navigation/cameras/UI, inventory/economy/enhancement, `profile_*`, `pet_*`, home/display/room-service restart tests, social tests, DEMO Exchange custody/restart/isolation, portals, depth travel and extraction. Each new stage must run relevant checks against its final source; historical totals are not substitutes. Rendered composition, Android keyboard/notch behavior, wall-motion appearance, touch comfort and sustained performance remain device-review work.

See [the ordered Nexus plan](nexus-realms-plan.md) for the implementation boundary and stop conditions.
