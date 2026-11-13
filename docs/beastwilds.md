# The Beastwilds — first discovery expedition

**Build `0.7.0-nexus5a` / Android code 32 passed 15,526 native checks across 119 modes and 98 suites**, including sixteen independent restart readers. The accepted scope is a first local discovery loop and its save/return integration. See [the validation report](nexus-stage5a-validation.md) and [Android route](nexus-stage5a-android.md). No rendered visual acceptance, physical Android test, APK or installation on a player device is claimed.

The first Beastwilds stage is a bounded, peaceful forest discovery loop. Walk four habitats around a giant tree/pool, record a creature trail, recover an egg, rescue a stranded spirit, optionally search an old forage cache, then return to secure the findings. It reuses existing Spiritweaving ingredients and memories. It does not capture a pet, add species/genetics, introduce combat encounters or grant dungeon progression.

## Build and change history

After verified publication, obtain the normal [GitHub main source](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths) using **Code → Download ZIP**, or [download the main ZIP](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths/archive/refs/heads/main.zip). Check root `project.godot` identifies `0.7.0-nexus5a` and Android export code 32. This is source for the compatible Godot editor; no APK generation, signing, phone installation or physical-device test is claimed. Preserve the same application/package/user-data identity and update without uninstalling or clearing data; source-folder extraction alone does not transfer a profile. Back up phone saves separately before migration.

The [Stage 5a change/validation record](nexus-stage5a-validation.md) tracks this discovery and save update. The previous [Nexus foundation release](nexus-foundation-validation.md) and [four-wing Sanctuary release](nexus-stage1-validation.md) remain immutable historical evidence.

## Entry and exploration

From Sanctuary, use north **NEXUS OF REALMS**, then **The Beastwilds** in the Adventure gallery. Normal entry requires **completing Depth 2 and successfully extracting**, not merely unlocking that depth. The saved offline TEST ACCESS switch can bypass that requirement for implemented local testing, while preserving actual earned depth. Entry must reserve a valid visit before publishing its world; a missing/failed save cannot silently grant a free untracked attempt.

The four habitats form a fixed, walkable circular route. The issued seed varies small discovery offsets and scenery; this is not a fully randomized biome or an open-world pet capture system. Both cameras, Guardian/Mystic and the selected existing cosmetic pet use the current controller/party systems.

| Habitat | Interaction | Required | Pending reward |
| --- | --- | --- | --- |
| Lantern Glade | Read creature trail | Yes | Objective record; no DM or pet ownership |
| Mooncap Nesting Grove | Recover mysterious egg | Yes | Existing seeded Spiritweaving ingredients/memory and 4–8 DM |
| Crystalwater Refuge | Free stranded spirit | Yes | Existing seeded Spiritweaving ingredients/memory and 6–10 DM |
| Old Explorer's Terrace | Search old forage cache | No | 2–4 existing `root_fiber` and 8–12 DM |

These initial ranges are data-driven settings, not depth-scaled guarantees. All claimed findings remain **unsecured** in the existing Session bag. Each registered source can be claimed only once for its issued visit. Source nodes display their identity; they do not supply client-selected reward tables. Inventory or counter capacity failure must leave the discovery available to retry.

Eight decorative wildlife silhouettes reuse existing native pet presentations; a rescued spirit has an additional display. They are not owned creatures, tamable combatants or new collectible models. The forest, mushrooms, water/refuge, ruin terrace, distant falls and scenery are original native-mesh prototype art pending rendered review.

## Return and results

The southern **Return spring** opens a review card. Before all three required finds, it offers **ABANDON & RETURN** and explicitly states that unsecured findings will be lost. With all three found, it offers **SECURE & RETURN**. **CLOSE** keeps the current visit running. The optional forage cache is never required to finish.

A successful secure writes the existing inventory/currency/pet findings and separate Beastwilds completion record before returning to the Nexus. It does not increment Rootbound completion, deepest cleared floor, dungeon XP, companion XP, boss/Rootwarden counters, merchant-rotation completion count or historical pet-secret achievement statistics. Existing secured pet achievements are preserved. No new owned pet is awarded; later use the original Sanctuary Spiritweaving service and its actual recipes/costs to weave an eligible pet.

If a save fails, the live sources and bag remain retryable. If the save succeeds but Nexus arrival fails, the retained Return spring offers **RETURN TO NEXUS** with the same completed proof; it must not pay the rewards again. A normal abandon also returns through the guarded Nexus route. Actual player death/party wipe uses the existing failure/Sanctuary flow and loses only the current unsecured findings. Recovery from an accidental below-world fall must retain the same visit, claims, seed, revives and health rather than issuing a new reward plan.

The HUD uses **THE BEASTWILDS**, `0 / 3 DISCOVERIES`, unsecured DM and the existing room/minimap presentation. Result text distinguishes **DISCOVERIES SECURED** from **ACTIVITY ENDED**. It must not display a fabricated Rootwarden defeat, Depth 1 completion or next-floor unlock.

## Save format and source authority

The update upgrades supported profiles from v11 to **v12**, retaining home namespace **v3**, and adds **`activities.version = 1`**. This namespace contains a monotonic `next_run_serial`, a bounded `open_run` ticket and separate Beastwilds records: entered/completed/deaths/abandoned, secured egg/rescue counts, total earned DM, best completion time and last completed serial. It is not Realm Mastery, a seal ledger or an online account service.

Admission reserves space for both its entry write and final settlement; an optional equipment/supply action cannot consume the last reserved save revision. Loading supported older data normalizes it without writing new defaults over the file. A valid migration write first preserves exact pre-v12 bytes using the existing store's migration backup; the normal verified temporary-write/backup/rename path remains. Unknown future activity fields, record kinds or tickets require preservation rather than destructive fallback. Existing item UIDs, equipment/modifiers, Depthmarks' saved `gold` field, depths, pets, companions, trophies, home identity and display references must survive unchanged.

An issued activity context has its own ID, definition version, persistent serial, seed, generation and frozen source plan. Game admits the actual canonical world only after native floor/actor/source checks. Claims and settlement recheck the real registered source, actor, controls, generation, reach and line of sight. A copied, relocated, foreign or stale source cannot become a reward authority. Rootbound's context/combat/reward helpers remain separate.

The persistent open ticket prevents a visit from being treated as a new completion after a restart; it is **not a resumable gameplay checkpoint**. Process eviction or quitting an unfinished visit loses unsecured findings. On the next admitted visit, a stale interrupted ticket is retired without granting rewards. A failed attempt may legitimately change reservation/abandonment bookkeeping while preserving secured possessions. Local checks do not make editable offline saves secure against deliberate file tampering.

## Presentation and remaining work

The authored world uses one shared directional light, no added local lights, static batching, four bounded butterfly regions and existing quality/reduced-motion preferences. Eight decorative specimen poses update at a throttled interval and stop their decorative motion under reduced motion; they have no roaming/combat AI. A separate native inventory measured 1,088 world nodes and 22,160 allocated instance-weighted triangles, with zero local lights and three enabled world process nodes; see the report for its earlier-snapshot scope proof. These are not GPU draw calls or physical Android measurements.

This stage does not include direct capture, rare-pet hunting, pet breeding/genetics, new species, enemies, bosses, activity XP, trophies, mastery, Realm Seals, masks or multiplayer. Masks of the Abyss were explicitly deferred by the user. Seven major gateways remain unavailable: Echoes of Eternity, Gilded Vault, Titan's Gate, Shattered Rift, Guild Conquest, Chaos Gate and Forbidden Gate. Existing Abyssal, Bloodspire NPC practice, auxiliary Sunken Vault, home and Sanctuary services remain separate preserved routes.
