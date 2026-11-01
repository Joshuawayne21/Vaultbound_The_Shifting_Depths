# Vaultbound: The Shifting Depths

**Infinite Depths — Milestone 7D.1, version 0.7.0-7d1.** A Godot 4 / GDScript-only, offline fantasy expedition prototype for Android landscape. The Sanctuary has a 90-metre circular enclosure, a central Ring Exchange, eight connected districts, broad radial paths and accessible Forge and Tavern terraces. Recruit companions, explore, fight, extract treasure and develop the character through the preserved RPG systems.

7A preserved and audited the existing game. 7B raises the original perimeter into varied 3.2–4.2 m walls and 5.6–8 m towers, adds four distinctive giant-tree silhouettes, distant cascades and floating stones, and gives the existing blue Rootbound and gold Hall gates original crests. Roads, services, arrival points and navigation retain their working footprints. The new distant landmark layer contains nineteen combined meshes and 8,671 triangles, with no added simulation or lights. These are original native-mesh prototype assets; rendered visual review and Android performance testing remain pending. See the [ordered Milestone 7 plan](docs/milestone-7-plan.md), [7B validation](docs/milestone-7b-validation.md) and [Android acceptance route](docs/milestone-7-android.md). 7C adds permanent sequential depths 1–50, an eligibility-aware selector on the existing blue portal card, configured 6–24-room layouts and bounded encounter DM/XP and combat scaling. Boss defeat plus successful extraction unlocks the next depth in the same verified save as rewards. See [depth rules and migration](docs/dungeon-depths.md) and [7C validation](docs/milestone-7c-validation.md). New biomes/bosses, genetics, Veilgarden and Frontier remain later stages.

7D.1 adds registered encounter identities, a shared event-capacity scheduler, source-bound boss rewards and secured encounter records. It preserves the existing Rootbound theme and Rootwarden while preparing tested interfaces for later bosses and environments. It does **not** enable new biomes, bosses, hives or hordes. Travel checks the complete admitted content through the final fade, and failed admission restores a safe prior scene. See the [content integration guide](docs/dungeon-content.md) and [7D.1 validation](docs/milestone-7d1-validation.md).

The hub map supplies district waypoints. Existing shops, recruitment, equipment preview and dungeon destinations remain functional; Sanctuary portals show information and require an explicit **ENTER** tap. City navigation follows the ring, spokes and ramps while dungeons retain their existing navigation. See the [Living Sanctuary plan](docs/living-sanctuary-plan.md) and [schematic map](docs/living-sanctuary-map.svg). The Conservatory opens Spiritweaving and the pet journal; the Pavilion opens the existing equipment preview. Live trading and purchases remain later stages.

6F adds the **Ring Exchange — DEMO / NOT LIVE** at its physical plaza terminal. Two explicitly controlled synthetic accounts can place buy/sell orders, make partial fills, collect Claims, review actual TEST sale prices and separately confirm direct trades. TEST DM, equipment and receipts use a separate save and never enter character progression. The [exchange guide](docs/living-sanctuary-exchange.md) explains the workflow and limits. The owner confirmed there is no backend; the [6G backend proposal](docs/living-sanctuary-backend-proposal.md) recommends a local authenticated test realm before separately approved hosting. No server, account service or online market has been deployed.

6D adds nine local procedural emotes, inspection of actual AI party members and a native text composer with LOCAL/WORLD/PARTY tabs. **Chat is DEMO / NOT LIVE:** LOCAL can preview a self-message on this device; WORLD and PARTY cannot send. Drafts and bounded history stay in memory. Only separate chat display preferences persist. See [social behavior, limits and the online authority boundary](docs/living-sanctuary-social.md). No authenticated human player, message delivery or networked emote is implied.

The 6C pass adds a static sky gradient, a restrained twenty-minute local daylight cycle and distinct wall reliefs in all fourteen Rootbound room motifs. Graphics preferences add ambient density, prompt contrast and optional generated wind sound. Reduced motion now reaches decorative shaders, portal ornaments, water and ambient actors. These are original prototype assets; see [presentation provenance and limits](docs/living-sanctuary-assets.md) and the [expanded Android checklist](docs/living-sanctuary-android.md). Five other biome art-direction resources are explicitly unavailable concepts, with no additional playable dungeons.

Milestone 5.6's two owned weapon loadouts, Inventory and Equipment menus, inspection and accessibility settings remain available. Existing saves migrate to profile v7, retaining the pet collection and permanent depth progression while adding secured encounter records. Rootbound enemies leave searchable loot caches, and earned currency remains Depthmarks (DM). The catalog retains 350 noncurrency definitions: 300 available through current content and 50 gated future entries. Guaranteed enhancements, bounded equipment effects, twenty recipes and owned-item displays use the existing progression systems. The [5.6 validation report](docs/milestone-5.6-validation.md) is a historical baseline; its [Android checklist](docs/milestone-5.6-android.md) remains applicable. Production character assets and physical-device review remain outstanding.

The Sanctuary, practice dungeon and arena, player movement, sword/shield and staff combat, touch controls, both smoothly switchable cameras, procedural dungeons, treasure, boss encounters and secured progression from Milestones 1–5 remain available. `project.godot` stays at the repository root. The active party supports one human leader and up to two local AI companions. No online multiplayer, player-to-player trading, guilds or additional biomes are implemented.

## Import and play on Android

1. Install the official **Godot Android editor**, standard GDScript edition. Use **Godot 4.6.3**, the validated engine for this milestone. Older Godot releases have not been validated with the new depth-fog and presentation settings.
2. Download/extract the full repository or source ZIP into storage the editor can access. Grant the editor file access if requested.
3. Choose **Import**, select the root `project.godot`, then open it with the **Compatibility** renderer. Wait for resource import to finish.
4. Keep the device in landscape and choose **Run Project**. The main scene is `scenes/main.tscn`.
5. Tap the top-right hub map to choose a district waypoint. Visit the **northwestern Tavern (H)** and tap **USE** to recruit the Guardian and Mystic; solo play remains available. The **northern Portal Promenade (A)** holds the Rootbound expedition and practice-dungeon gates. Approach a gate, tap **ENTER**, review its card, then confirm **ENTER**. The blue Rootbound card selects a depth; a new profile starts with Depth 1 only. The **northeastern Coliseum (B)** also connects directly to the existing practice arena.
6. Open the entrance supply chest, follow the discovered-room minimap, explore branches, and approach whispering vine walls to reveal hidden rooms. Walk through open doorways; rooms connect continuously.
7. Defeated enemies leave searchable caches. Approach one, tap **USE**, then choose a quantity and **TAKE**, or **TAKE ALL**. Defeat the Rootwarden and search its grand cache, then find the **extraction spring in the connected chamber beyond the boss**. Tap **USE** to secure the collected rewards and return to Sanctuary.
8. Review the results screen, then open **INVENTORY**. Select an owned item to compare and equip it, mark it as a favorite or lock it. The **EQUIPMENT** tab shows all eleven assignments and a rotatable character preview; **CHARACTER** shows XP and talent allocation.
9. Visit the General Merchant, Equipment Trader and Relic Appraiser in the **eastern Merchant Terraces (C)**, and the Blacksmith on the **southern Forge terrace (E)**. Review the displayed costs before confirming purchases, sales, crafts or improvements.
10. Use the **southeastern Collection Hall passage (D)** to assign owned equipment and relics to displays and view the discovery journals. Its return arch leads safely back to Sanctuary.
11. Tap **GRAPHICS** to select **Low, Medium or High** and a **30 or 60 FPS target**, then **APPLY & SAVE**. Start with the default **Medium / 30 FPS**. **ACCESSIBILITY** contains UI scale, reduced motion/effects and high-contrast prompts. **AMBIENCE** contains 0/50/100% ambient density and optional sound, initially off. Use Low if sustained play shows frame-time spikes; 60 FPS is a target for capable devices, not a measured guarantee.
12. Visit **G — Spiritweaving Conservatory** after securing pet findings. Inspect recipes, achievements and previews; create an eligible species, select it and optionally name it. Findings from the current run appear separately until extraction.
13. Approach the central **Ring Exchange** guide terminal for the isolated TEST exchange. Operate DEMO A and B deliberately; no remote or automatic trader is present. Try the partial-fill and direct-trade examples in the guide, then verify your earned Depthmarks and gear are unchanged.
14. Tap **CHAT** for the offline composer, **EMOTES** for the local wheel, or an AI companion's party entry for inspection. LOCAL's **PREVIEW · DEMO** creates only a self-preview. The Android keyboard and device input checklist remain manual acceptance work.

On desktop, open the same project and press F5. F6 runs only the selected scene and may omit the persistent shell. The original Sanctuary and character models are assembled at runtime; Abyss room geometry is authored in reusable native `.tscn` scenes.

Running inside the Android editor requires no APK export. The included ARM64 export preset requests no internet permission. APK export requires matching export templates, Android SDK/build tools and your own signing setup. No APK or signing keys are included. Use a desktop Godot installation for export if your Android editor version does not support it.

## Controls

| Action | Android | Keyboard / mouse |
| --- | --- | --- |
| Move | Left joystick | WASD / arrows |
| Third-person look | Swipe open right-side space | Right mouse drag |
| Camera | Camera mode panel | C / Tab |
| Light attack / sword combo | Tap STRIKE, tap again to buffer one strike | J / world left click |
| Heavy attack | Hold HEAVY, release | Hold / release K |
| Dodge roll | DODGE | Space |
| Shield / staff ward | Hold BLOCK / WARD | Hold L |
| Abilities | Two weapon-specific buttons | Q / E |
| Target lock | LOCK | T |
| Select owned loadout | Two circular weapon buttons | 1 / 2; R cycles assigned weapons |
| Interact / chest / extraction | USE nearby | F |
| Collect searched loot | TAKE / TAKE ALL in Search | Click the same Search controls |
| Inventory | INVENTORY | I |
| Equipment / rotate preview | EQUIPMENT, drag the character | O, mouse drag inside the preview |
| Healing consumable | TONIC | H |
| Performance display | METRICS inside Inventory | P |
| Graphics / UI scale / reduced motion and effects | GRAPHICS | F10 |
| Party commands | PARTY | B |
| Recruit / dismiss | USE at the Sanctuary Tavern | F at the Tavern |
| Revive nearby ally | REVIVE prompt | Party menu / interact |
| Local chat demo | CHAT | Enter |
| Local emotes | EMOTES | G |
| Inspect AI companion | Tap its party entry | Click its party entry |

Inventory supports name, rarity, level, value, lowest-rarity, equipment category and recent-acquisition sorting. Equipment inspection reuses the gameplay avatar and active loadout; drag only within its preview to rotate it. Hidden previews do not continuously render. In GRAPHICS, choose 100%, 110% or 120% UI size, reduced motion/effects and high-contrast prompts. Larger text and touch targets reflow inside the safe area. Ambient density controls motes and butterflies; it does not hide combat warnings. Reduced-motion shaders settle into a static pose, while CPU ornaments freeze in place. Preferences use their own v3 file, preserving older graphics choices independently of the versioned progression profile.

Assign owned swords or staffs to PRIMARY / SECONDARY in the inventory equipment actions. Empty loadout buttons are disabled and show no weapon icon. The unassigned practice controller still supports R until a weapon is assigned. Switching requires recovery from the current action, takes 0.32 seconds and preserves ability cooldowns, targeting and current resources. The shield and legacy accessory remain separate equipment slots.

The shared character now uses rounded native meshes and smoother procedural pose transitions, with unchanged weapon anchors and gameplay timing. Player, companions and inspection share this avatar. These remain original prototype visuals; production skinned models, fitted item-specific armor and authored clips are still missing. See [character presentation and asset requirements](docs/character-presentation.md).

Sword/shield retains its three-hit combo, charged heavy, Shield Bash and Cleave. Staff retains bolts, charged splash, Arcane Burst and Frost Nova. Both use identical damage, costs, cooldowns, range and targeting in either camera view. Charge, block and joystick touches cancel safely on focus loss, Android pause, travel and modal opening.

Inventory, Equipment, GRAPHICS, merchant/workbench/Collection Hall screens, social/chat screens, Spiritweaving/naming, party/recruitment menus and expedition results pause the local player, companions and active world. Closing them restores input without resuming stale held buttons. Held typing keys must be released before keyboard gameplay resumes; fresh touch input can resume immediately. Basic movement is grounded; jumping is intentionally omitted. The elevated tactical camera uses a narrow perspective lens for a continuous transition rather than a strict orthographic projection.

## Party and companions

Visit the northwestern Sanctuary Tavern (H) to recruit or dismiss either companion. The roster is saved before it changes; dismissal preserves earned progression. Party records distinguish human and AI members instead of reserving permanent AI-only replacements for future human slots. This is a local party model, not a network implementation.

- **Rowan — Guardian / Steadfast:** sword and shield, nearby threat interception, protection of injured allies, three-hit melee attacks, directional blocking and major-telegraph avoidance.
- **Lyra — Mystic / Careful:** staff projectiles, ranged spacing, retreat from melee pressure, cooldown-limited healing and safe revive attempts.

Both reuse the player's weapon timing, stamina costs, damage rules and obstruction checks. Decisions run at configurable intervals with reaction jitter and imperfect ranged accuracy. They do not read camera mode or call external AI services. Health, combat state and navigation remain individual; changing cameras does not recreate the party.

The **PARTY** menu provides **Follow Me**, **Attack My Target**, **Hold Position**, **Retreat** and **Revive Teammate**. Lock a visible enemy within the companions' pursuit range (12 m by default) before issuing the attack command. Orders can be delayed by valid safety constraints such as a major ground warning, an unreachable target or an interrupted revive. Feedback explains rejected orders. Companions do not open chests or consume the player's collected treasure.

The leader and companions can be downed while a teammate remains able to help. A revive requires line of sight, a distance of at most 2.4 m and a 3-second uninterrupted channel, restoring 35% health by default. Damage, separation and new combat actions interrupt it. Each member can be revived twice per expedition; a 30-second bleedout ends rescue eligibility. These values are configurable on the party component. If no active member remains, the expedition ends under the existing death rules: unsecured loot is lost, secured possessions remain, and recruited companions return to Sanctuary. If the human leader bleeds out, this offline prototype also ends the expedition so the player cannot remain stranded watching AI indefinitely. Solo lethal damage retains immediate Sanctuary recovery.

Recruitment, name, role, personality trait, level, experience and combat proficiency persist in the local profile. Successful extraction awards each recruited companion 150 experience plus 10 per defeated enemy, scaled once by the admitted floor reward factor, through the same verified save transaction as loot. Cumulative level thresholds begin at 100 experience for level 2 and 300 for level 3; progression caps at level 20. Combat proficiency rises with level and modestly improves ranged accuracy; weapon damage and stamina costs still use the shared weapon data. Failed, abandoned or unsaved expeditions award no experience. There is no companion gear or talent tree in this milestone.

Companion navigation uses the existing modular room graph, bounded local A* and cached world collision for flat authored dungeon floors. Sanctuary opts into grounded ring/spoke/ramp routes, checked for floor continuity, slope and capsule clearance. Paths normally refresh every 0.65 seconds; moved goals are limited to four replans per second. Formation spacing, obstacle and hazard avoidance, and safe recovery handle separation. Companions do not teleport to keep up during active combat. Party state and commands are separate from presentation so authority can move to a server in a later milestone.

## Spiritweaving and cosmetic pets

6E adds eight cosmetic species at **G — Spiritweaving Conservatory**. Earn essence from completed Rootbound encounters, find seeded eggs, rescue secret-room spirits and defeat the Rootwarden for a vessel and Rootling memory. Findings stay unsecured until extraction succeeds. At the Conservatory, review a recipe's ingredients and achievements, confirm creation, then select, rest or name the owned pet. The journal shows discoveries, origin and a static preview. See the [pet guide](docs/living-sanctuary-pets.md).

One pet follows the player alongside the existing AI party. It has no collider, combat target, bonuses, loot action or party slot. A bounded trail of previously walked positions keeps it within the current world and discovered rooms; recovery hides the pet before a safe reposition. Sit/perch, idle, playful and emote reactions are cosmetic. Reduced motion retains following. All eight native-mesh models and procedural poses are clearly marked placeholders awaiting rendered review.

Species ownership, selection, aliases, ingredients, achievements and fixed natural/luminous variant provenance persist in profile v7. Older profiles migrate in memory; the first migrated write preserves exact original bytes in `.pre-v7.bak`, keeping existing earlier migration backups. Previously secured inventory, Depthmarks, equipment, companion progression and Hall displays remain intact. The first secured matching creature memory fixes the variant, so repeated confirmations, cancellation or failed saves cannot reroll it. Death loses only the current expedition's unsecured findings.

## The expedition

The biome combines giant roots, emerald and turquoise mushrooms, magical flowers, crystals, ruined temple columns, streams, waterfalls and low-cost mist. Fourteen reusable 24 × 24 m room modules cover entrance groves/temples, root and stream corridors, four combat chambers, two treasure chambers, thorn traps, secret hollows, the boss heart and extraction spring.

`DungeonGenerator` uses a dedicated seeded `RandomNumberGenerator`. It builds a guaranteed main route followed by optional branches, then validates room count, unique cells, reciprocal adjacent connections, matching doorways, required roles and reachability **before the player is moved**. The main route ends at the boss and extraction; secret rooms are optional. Geometry is selected from PackedScenes rather than generated as arbitrary meshes during play.

The same seed, selected depth, policy version and build reproduce the configured layout, room selection, initial encounters and boss modifier. Chest/item reward rules remain deterministic from their existing source seeds. Awareness timing and combat outcomes still depend on player actions. The HUD shows the issued expedition seed and depth; changing cameras never changes it.

To reproduce a seed on Android: open `scenes/main.tscn`, select the **Vaultbound** root, set **Debug Expedition Seed** in the Inspector to the displayed number, save, and run. Select the same unlocked depth on the portal card. Set the debug seed back to `-1` for a new seed each expedition. On desktop:

```sh
godot4 --path . -- --expedition-seed=42
```

Existing skeletons, archers and golems form deterministic groups with modest depth scaling and occasional slower-telegraph elites. Enemy positions use validated module markers away from doorway arrivals. Dormant rooms preserve enemy health and defeat state, so revisiting does not respawn rewards. Awareness patrols use distant, unoccupied markers.

## Treasure, inventory and saving

Common, Reinforced, Ancient and Cursed chests share one chest implementation. Item definitions and weighted `.tres` loot tables provide Depthmarks (DM), crafting materials, equipment, healing consumables and collectibles across **Common, Uncommon, Rare, Epic, Legendary, Mythic and Ancient Relic** rarities. The original **40 functional noncurrency starter items** remain intact. The integrated catalog now contains **350 noncurrency definitions: 300 available and 50 unavailable future definitions**, plus the preserved currency record (**351 total**). Shared definition resources remain separate from unique owned equipment instances. The boss chest has its own table and a guaranteed **Heart of the Rootwarden** collectible. Chests can be claimed only once per expedition. Rarity labels and I–VII markers supplement color, and source gates prevent unfinished content from being granted. See the [catalog batch status](docs/catalog-batches.md) and [starter catalog](docs/starter-item-catalog.md) for integrated counts, acquisition chains and honest family-art limitations.

- **Unsecured pack:** loot collected this run. It is not saved until extraction. Tonics in the pack can be consumed immediately.
- **Secured inventory:** forty slots for owned stacks and individual equipment. Worn gear stays in those slots; each equipment instance keeps its unique ID, rolled modifiers, enhancement, condition and protection flags. Item-specific stack limits apply to materials and consumables. Both original sword/shield and staff combat families remain available.
- **Successful extraction:** requires boss defeat. Depthmarks, unique gear/stacks, discoveries, pet findings, character and companion experience, permanent depth unlocks, completion/kill/time statistics and seed are written and verified before travel occurs. Chest collection checks space for all pending rewards before claiming a chest; a rejected chest remains available.
- **Death or retreat:** returns to the Sanctuary and discards only the current unsecured bag. Previously secured equipment, items and Depthmarks remain. A results screen explains the outcome.
- **Closing the app during a run:** abandons its in-memory unsecured loot. Mid-expedition resume is not implemented. Previously secured progress loads on restart.

The **version-seven** offline profile lives at `user://vaultbound/profile.json` with a previous valid `.bak`. Versions one through six migrate in memory without rewriting the original on load. Before the first migrated write, the exact original bytes are retained in `.pre-v7.bak`, leaving earlier `.pre-v3` through `.pre-v6` snapshots untouched; a separately restored legacy record receives its own content-addressed snapshot. The loadout migration adds secondary weapon, gloves, leg armor, necklace, ring and active loadout fields while preserving original shield/accessory assignments. Version four introduced the rarity enhancement caps and bounded effects while validating older records against their original limits. Version five added validated cosmetic pet collection fields without replacing inventory/equipment data. Version six adds permanent depth unlocks and preserves supported older floor records; unrecognized apparent floor formats are protected read-only. Previous successful Rootbound extractions establish a Depth 1 clear only. Version seven adds secured encounter records; historical discoveries retain an explicit pre-tracking flag without invented counts or dates. Unknown future encounter fields are protected before backup fallback. Existing instance IDs, enhancements and rolls are never rerolled during migration. Existing gold, counts, equipped selection, companions, discoveries and expedition statistics are preserved; equipment receives stable instance IDs. If an old inventory exceeds forty slots, its remaining quantities stay in a **legacy reserve**. Select the inventory reserve filter to claim supported items as space becomes available; unknown legacy IDs remain preserved rather than discarded. Writes use a temporary file, validation/read-back and atomic rename. A failed extraction write leaves the run and its loot available for retry. Corrupt saves use a valid backup where possible. Newer-format saves and structurally valid records containing unavailable owned content become read-only instead of being replaced with an older backup. Existing files remain intact with an on-screen warning. Never delete the profile to fix an import problem. Android stores `user://` in app-specific storage; its exact path depends on whether you run from the editor or an exported app.

The profile service, transaction rules and local combat command boundary are separated from presentation for later server-authoritative work. These local saves are temporary development/offline persistence and are editable on the device; online play will require secure server-side storage and validation. This does **not** implement authentication, networking, replication, anti-cheat or cloud saves.

## Searchable loot and Depthmarks

Defeated Rootbound Abyss enemies leave searchable caches. Approach a cache, tap **USE / Search**, select a row and **Take**, or choose **Take All**. Regular enemies, elites and the Rootwarden have distinct cache presentations. The grand boss cache retains the guaranteed Rootwarden Heart. Empty caches disappear. Room treasure keeps its existing interaction.

Depthmarks are dark metallic coins condensed from dungeon energy, marked with turquoise and gold Vault seals. **DM** replaces the displayed generic currency name at merchants, the Blacksmith and expedition screens. Existing balances keep their exact amount: the save and transaction fields retain their internal `gold` names for compatibility, with no second writable balance or conversion grant.

| Completed encounter | Initial DM range |
| --- | ---: |
| Skeleton / Goblin Archer | 4–8 |
| Corrupted Golem | 8–18 |
| Elite enemy | 25–50 |
| Rootwarden | 120–250 |

These are configurable reward ranges in `resources/loot/monster_rewards.tres`; controlled depth bands can scale them. Rewards are generated once per registered death. Resettable Sanctuary/Proving Grounds practice targets grant no bankable rewards. No quest or PvP reward system is implemented.

Taking loot adds it to the existing **unsecured expedition bag**, with capacity checked against the forty-slot secured inventory plus all pending rewards. Extraction secures it; death, retreat or quitting an unfinished run loses it. A rejected or partially collected cache retains its remaining contents. Seven nearby regular/elite views and one reserved boss view are reused; hidden-room and overflow rewards stay in the run ledger. Nearby unopened low-tier caches may consolidate without rerolling. Repeated takes, stale touches, through-wall searches and duplicate death callbacks cannot grant the same contents again. Awareness activates once per original reward source, regardless of partial takes.

## Equipment, merchants, crafting and character growth

Equipment slots are **Main Weapon, Secondary Weapon, Shield, Helmet, Chest Armor, Gloves, Leg Armor, Boots, Necklace, Ring and Charm**. Shield and Charm preserve the original off-hand and accessory assignments. Gloves, leg armor, necklace and ring gear are available from the Equipment Trader. Source-gated elite and Rootwarden materials support earned high-rarity sword/staff recipes. Item selection shows requirements, condition, enhancement, modifiers and a comparison against current equipment. Category/favorite/lock filters and name/rarity/level sorting support the touch-scrollable inventory. Selling and salvaging reject equipped, displayed, favorite or locked items. Unidentified artifacts cannot be equipped. Each confirmation is tied to one saved revision and transaction receipt, so stale or repeated touchscreen confirmations cannot duplicate a purchase or craft.

Equipped bonuses affect real player health/stamina limits, damage, protection and stamina recovery. Changing gear clamps current resources instead of healing the player for free. Main-weapon and shield bonuses apply only to their compatible active weapon family; switching the original base sword/staff family does not grant a sword's bonuses to a staff. Existing avatar parts receive restrained appearance changes without attaching unscaled armor models. The equipment screen renders the same avatar in an isolated preview viewport that stops updating when hidden.

The General Merchant sells consumables/materials, the Equipment Trader carries a small rotating selection, and the Relic Appraiser reveals the properties of mysterious equipment for a fee. Stock rotations use **successfully completed expedition counts**, never device time. Buying verifies Depthmarks, remaining stock and inventory space before saving. Sales remove only the selected owned instance or quantity.

The Blacksmith provides guaranteed enhancement up to **+5 for Common through Legendary**, and **+10 for Mythic and Ancient Relic** equipment, including existing accessories. It also provides condition repairs, salvage and twenty authored recipes, including the original eight equipment/consumable recipes, Ancient Forged Cores, Ancient Heartstones, Verdant Oathblade and Vaultheart Staff. Upgrades preview the next statistics and exact materials/DM before confirmation. Each rank increases the original five base bonuses by 8%; rolled modifiers and critical/lifesteal/block/cooldown effects do not multiply with enhancement. See the [enhancement policy](docs/enhancement-policy.md) for all prices and earned components. There are no random upgrade failures. Recipes use obtainable dungeon or merchant materials. Protected materials must be unlocked/unfavorited before they can be consumed. Successful extraction wears equipped gear by 2 condition; defeat wears it by 8. Broken gear remains owned and retains its base combat family, but its equipment bonuses stop applying until repaired.

Equipment can provide bounded critical chance, lifesteal, block strength and ability cooldown reduction. One committed attack retains its effect snapshot across camera/loadout switches; lifesteal uses actual enemy health lost and shares a 4 HP limit across that attack. Training targets and rejected hits grant no healing. Existing instances retain their rolls; newly acquired gear uses authored rarity ranges. Elemental resistance mechanics are not implemented. See [equipment effects](docs/equipment-effects.md) for limits and validation.

Character progression uses an explicit thirty-level table. Extraction grants **250 XP plus 20 per defeated normal enemy**, scaled once by the admitted floor reward factor; failed or abandoned runs grant none. Level 2 requires 200 cumulative XP and level 30 caps at 46,400. Each level grants one talent point after level 1. The small **Offense, Defense and Utility** branches allow up to ten ranks each, improve modest statistics, and require confirmation before spending a point. Talent respec is not included in this milestone. A separate normalized-stat resolver prepares for later PvP work; no PvP or online authority is implemented.

## Collection Hall

The Hall is a separate underground castle chamber reached from the Sanctuary's southeastern district (D). It contains **eight equipment stands, four relic pedestals, a Rootwarden trophy wall, a monster journal and an item journal**. Interact with a stand, choose an eligible owned item and confirm the display. An assignment references the original inventory instance; it never creates a second item or removes ownership, and the same instance cannot occupy multiple stands. Clear a display before selling or salvaging its item. The trophy unlocks from the existing Rootwarden discovery, and successful extraction records monster discoveries. Assignments and journals persist across travel and restart.

Occupied stands add bounded rotation, floating motion and rarity rune accents around the shared family models. **INSPECT** opens an item viewport with drag rotation, lore, ownership origin and truthful artwork status. Character and item previews render only when changed. Collection completion counts the 300 obtainable definitions; future records remain visible as unavailable catalog entries. Rare-or-better accepted loot shows a short **UNSECURED — Extract to keep** notification without granting additional rewards. See [item presentation](docs/item-presentation.md) and the [mobile UI guide](docs/milestone-5.6-ui.md).

## Rootwarden and awareness

The Rootwarden uses Root Slam, sequential Thorn Eruption patches and Vine Grasp (a brief interruption on a landed hit). Below 40% health it enters **Guardian's Fury** through a safe phase transition and gains a faster pattern with a radial burst. Ground warnings remain at least 0.9 seconds, attack windows share unique IDs, and sequential patches cannot stack multiple hits from the same cast. Dodge, shield/ward, range and wall obstruction apply normally.

A seed selects no modifier or one of two optional modifiers: **Thick Bark** increases durability with longer recovery; **Blooming Thorns** adds a spaced thorn patch with a longer warning. Modifiers never combine. The boss has a bounded arena leash and rejects out-of-arena damage. Its health bar, phase, modifier and attack telegraphs are visible; death cancels all pending attacks and unlocks the spring.

Awareness grows from kills, treasure value, cursed chests and time. Configurable thresholds (25 / 50 / 75 by default) warn before patrols, environmental roots or an elite event. Only one warning/event can be active at a time; queued thresholds wait through a minimum event gap. Safe rooms suppress encounters; boss proximity suspends regular enemies and cancels environmental hazards. Leaving a room cancels its hazards rather than resuming a nearly completed trap on re-entry.

## Visual presentation and graphics settings

The Sanctuary adds a suspended crystal heart, carved bronze trim, wall springs, richer planters, a decorated open Tavern bar and distinct merchant/forge details. The Hall retains its twelve owned-item displays and adds niches, inlays and trophy carving. Fourteen existing Abyss modules gain seeded cosmetic variations, wall roots and moss, layered foliage, guardian/prism reliefs and shallow bridge dressing. Room connectors, floor collision, NPC/service locations and loot anchors remain tied to the original gameplay layout.

Shared native materials use two original 128×128 procedural grain textures, restrained emission and one directional key light per world. Conventional depth fog adds distance atmosphere. Opaque water animates ripples without screen/depth-buffer sampling; small foam ribbons, anchored foliage sway and bounded firefly/mote batches add movement. Sword trails, spell wakes, hit sparks, dodge ribbons and Rootwarden warning borders improve presentation while the existing damage windows and radii remain authoritative. No paid or third-party asset pack was downloaded.

| Setting | Low | Medium (default) | High |
| --- | --- | --- | --- |
| Optional plant density | 50% | 75% | 100% |
| Small decoration range | 24 m | 34 m | 44 m |
| Directional shadows | Off | 1024, 34 m | 2048, 44 m |
| 3D antialiasing | Off | Off | 2× MSAA |
| Ambient motes per batch | 8 | 16 | 24 |
| Simultaneous impact bursts | 8 | 14 | 20 |
| Active item sparks across nearby displays/weapons | 4 | 8 | 12 |

Abyss mote batches additionally cap at twelve per room and follow existing room visibility. Essential geometry, interactables and combat warnings do not disappear on Low. The frame target changes rendering pacing; physics remains 60 Hz. Preferences live separately at `user://vaultbound/visual_settings.cfg`, without changing the progression profile. Invalid graphics files retain current settings; an explicit successful change writes verified replacement preferences.

The 30 FPS midrange Android goal and optional 60 FPS target require physical-device verification. Native primitives do not include authored mesh LOD chains; the tier's general LOD threshold prepares for compatible future assets, while current savings come from batching, shadow policy, visibility and bounded decoration/effects. Item spark limits describe active instances, not all reserved mesh storage; reduced effects removes them and reduced motion freezes decorative movement. New butterflies have one active budget per world, normally 4/8/12 across Low/Medium/High, with lower counts under reduced density/effects. Their regional buffers and existing room motes are counted separately. See [6C structure and host measurements](docs/living-sanctuary-6c-performance.md), the [historical 5.6 CPU/resource report](docs/milestone-5.6-performance.md), [asset register](docs/milestone-5.6-assets.md) and [visual style guide](docs/visual-style-guide.md).

## Project organization and mobile budget

- `scripts/systems/`: persistent game shell, one input vocabulary and transitions.
- `scripts/player/`, `scripts/combat/`, `resources/weapons/`: preserved movement and combat components.
- `scripts/enemies/`, `resources/enemies/`: three original archetypes and Rootwarden data/AI.
- `scripts/party/`, `resources/companions/`, `scenes/party/`: party lifecycle, AI decisions, navigation, companion data and Tavern recruitment.
- `scenes/rooms/`, `scenes/props/`, `resources/materials/`: authored reusable Abyss geometry and materials.
- `scripts/visual/`, `resources/environments/`, `resources/shaders/`, `resources/textures/`: shared style, cosmetic batching, ambient/combat presentation and independent device preferences.
- `scripts/expedition/`: pure layout generation, room activation, encounters, pooled hazards, awareness, secrets and extraction.
- `scripts/progression/`, `resources/items/`, `resources/loot/`, `resources/recipes/`, `resources/progression/`: definitions, instance inventory, transaction rules, recipes, character tables, transient loot and versioned local saves.
- `scripts/pets/`, `resources/pets/`: cosmetic species, acquisition policy, recipes, bounded presentation and validated collection progression.
- `scripts/ui/`: original combat/party controls, expedition HUD, discovery map and touch-scrollable RPG inventory/service panels.
- `scenes/world/collection_hall.tscn`, `scripts/world/`: Sanctuary services, Hall exhibits/journals and existing travel destinations.
- `tests/`, `docs/`: automated checks, archived milestone information and Android manual review.

Each level uses one shared environment and one directional light, with shadows controlled by graphics quality, shared materials and native primitive collision. Far rooms stop rendering/simulating while their floor and boundary collision stay valid. Normal encounters cap at **six active enemies**; the boss encounter suspends them. Two environmental hazards and four boss warning meshes are reused. Paving and repeated cosmetic detail use MultiMesh batches, and eligible opaque static architecture is conservatively combined by material. Animated water reuses three foam strips; it has no fluid simulation. Emissive decoration does not add realtime point lights. The metrics overlay shows FPS, active foes and draw calls.

## Validation

The **7D.1 full gate passed 21,102 assertions across 109 suites and 130 separate test processes**, plus isolated script preflight, import and startup. The accepted source contains 822 semantic files. It includes the preserved 7C suite and new content identities, material snapshots, scheduler limits, analytic hazard geometry, actual companion navigation, guarded projectiles, migration, extraction records and travel rollback checks. See [7D.1 validation](docs/milestone-7d1-validation.md) and [per-process results](docs/milestone-7d1-test-results.json) for exact commands, hashes, failures corrected and evidence limits. Earlier failed, focused and diagnostic runs are separate from the accepted aggregate. The [7C full gate](docs/milestone-7c-validation.md) remains the historical depth-progression checkpoint. No headless test establishes rendered visual quality, physical Android input, sustained device FPS or finished artwork.

The [6F full regression](docs/living-sanctuary-6f-validation.md), [7A audit](docs/milestone-7-plan.md) and [7B visual checks](docs/milestone-7b-validation.md) remain historical checkpoints. Physical Android keyboard, visual and performance acceptance remain pending; no headless result establishes device FPS or finished artwork.

Run these desktop/cloud checks from the repository root; substitute `godot` if that is your installed executable. Isolate test user data from normal play:

```sh
export XDG_DATA_HOME=/tmp/vaultbound-checks/data
export XDG_CONFIG_HOME=/tmp/vaultbound-checks/config
export XDG_CACHE_HOME=/tmp/vaultbound-checks/cache
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/boss_definition_test.gd
godot4 --headless --path . --script res://tests/biome_presentation_test.gd
godot4 --headless --path . --script res://tests/content_registry_test.gd
godot4 --headless --path . --script res://tests/encounter_progression_test.gd
godot4 --headless --path . --script res://tests/profile_v7_test.gd
godot4 --headless --path . --script res://tests/danger_geometry_test.gd
godot4 --headless --path . --script res://tests/projectile_cast_token_test.gd
godot4 --headless --path . --script res://tests/content_session_test.gd
godot4 --headless --path . --script res://tests/content_world_test.gd
godot4 --headless --path . --script res://tests/content_travel_guard_test.gd
godot4 --headless --path . --script res://tests/companion_danger_shapes_test.gd
godot4 --headless --path . --script res://tests/content_restart_test.gd -- --write /tmp/vaultbound-content-restart/profile.json
godot4 --headless --path . --script res://tests/content_restart_test.gd -- --read /tmp/vaultbound-content-restart/profile.json
godot4 --headless --path . --script res://tests/smoke_test.gd
godot4 --headless --path . --script res://tests/sanctuary_capital_test.gd
godot4 --headless --path . --script res://tests/depth_policy_test.gd
godot4 --headless --path . --script res://tests/profile_v6_test.gd
godot4 --headless --path . --script res://tests/depth_session_test.gd
godot4 --headless --path . --script res://tests/depth_dungeon_test.gd
godot4 --headless --path . --script res://tests/depth_portal_ui_test.gd
godot4 --headless --path . --script res://tests/depth_travel_guard_test.gd
godot4 --headless --path . --script res://tests/combat_test.gd
godot4 --headless --path . --script res://tests/ui_layout_test.gd
godot4 --headless --path . --script res://tests/sanctuary_world_test.gd
godot4 --headless --path . --script res://tests/sanctuary_ui_test.gd
godot4 --headless --path . --script res://tests/emote_presentation_test.gd
godot4 --headless --path . --script res://tests/social_session_test.gd
godot4 --headless --path . --script res://tests/social_preferences_test.gd
godot4 --headless --path . --script res://tests/social_ui_test.gd
godot4 --headless --path . --script res://tests/native_chat_input_test.gd
godot4 --headless --path . --script res://tests/pet_catalog_test.gd
godot4 --headless --path . --script res://tests/pet_progression_test.gd
godot4 --headless --path . --script res://tests/profile_v5_test.gd
godot4 --headless --path . --script res://tests/pet_session_test.gd
godot4 --headless --path . --script res://tests/pet_world_sources_test.gd
godot4 --headless --path . --script res://tests/pet_presentation_test.gd
godot4 --headless --path . --script res://tests/pet_follow_test.gd
godot4 --headless --path . --script res://tests/pet_ui_test.gd
godot4 --headless --path . --script res://tests/native_pet_name_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_eligibility_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_model_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_sales_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_store_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_controller_test.gd
godot4 --headless --path . --script res://tests/demo_exchange_ui_test.gd
godot4 --headless --path . --script res://tests/native_exchange_input_test.gd
godot4 --headless --path . --script res://tests/exchange_isolation_test.gd
godot4 --headless --path . --script res://tests/exchange_isolation_test.gd -- --read
godot4 --headless --path . --script res://tests/city_surface_test.gd
godot4 --headless --path . --script res://tests/city_navigation_test.gd
godot4 --headless --path . --script res://tests/city_scenery_test.gd
godot4 --headless --path . --script res://tests/biome_art_direction_test.gd
godot4 --headless --path . --script res://tests/visual_accessibility_test.gd
godot4 --headless --path . --script res://tests/visual_accessibility_test.gd -- --read
godot4 --headless --path . --script res://tests/dungeon_layout_test.gd
godot4 --headless --path . --script res://tests/loot_persistence_test.gd
godot4 --headless --path . --script res://tests/rootwarden_test.gd
godot4 --headless --path . --script res://tests/expedition_test.gd
godot4 --headless --path . --script res://tests/expedition_ui_test.gd
godot4 --headless --path . --script res://tests/party_test.gd
godot4 --headless --path . --script res://tests/party_ui_test.gd
godot4 --headless --path . --script res://tests/companion_behavior_test.gd
godot4 --headless --path . --script res://tests/party_targeting_test.gd
godot4 --headless --path . --script res://tests/companion_navigation_test.gd
godot4 --headless --path . --script res://tests/party_persistence_test.gd
godot4 --headless --path . --script res://tests/item_catalog_test.gd
godot4 --headless --path . --script res://tests/inventory_economy_test.gd
godot4 --headless --path . --script res://tests/character_progression_test.gd
godot4 --headless --path . --script res://tests/collection_world_test.gd
godot4 --headless --path . --script res://tests/save_migration_test.gd
godot4 --headless --path . --script res://tests/rpg_integration_test.gd
godot4 --headless --path . --script res://tests/rpg_ui_test.gd
godot4 --headless --path . --script res://tests/visual_style_test.gd
godot4 --headless --path . --script res://tests/abyss_visual_test.gd
godot4 --headless --path . --script res://tests/combat_presentation_test.gd
godot4 --headless --path . --script res://tests/visual_settings_test.gd
godot4 --headless --path . --script res://tests/visual_integration_test.gd
godot4 --headless --path . --script res://tests/static_visual_batcher_test.gd
```

The new Milestone 5.6 checkpoint suites use disposable `/tmp` fixtures on desktop/cloud. Run them with isolated user-data/config/cache directories as described below. Each reader must follow its writer in a separate Godot process:

```sh
godot4 --headless --path . --script res://tests/loadout_migration_test.gd
godot4 --headless --path . --script res://tests/loadout_ui_test.gd
godot4 --headless --path . --script res://tests/loadout_integration_test.gd
godot4 --headless --path . --script res://tests/loadout_integration_test.gd -- --read
godot4 --headless --path . --script res://tests/accessibility_preferences_test.gd
godot4 --headless --path . --script res://tests/accessibility_preferences_test.gd -- --read
godot4 --headless --path . --script res://tests/mobile_ui_integration_test.gd
godot4 --headless --path . --script res://tests/character_presentation_test.gd
godot4 --headless --path . --script res://tests/party_character_integration_test.gd
godot4 --headless --path . --script res://tests/loot_ledger_test.gd
godot4 --headless --path . --script res://tests/loot_cache_world_test.gd
godot4 --headless --path . --script res://tests/encounter_loot_test.gd
godot4 --headless --path . --script res://tests/session_loot_test.gd
godot4 --headless --path . --script res://tests/profile_roundtrip_test.gd
godot4 --headless --path . --script res://tests/profile_roundtrip_test.gd -- --read
godot4 --headless --path . --script res://tests/searchable_loot_integration_test.gd
godot4 --headless --path . --script res://tests/searchable_loot_integration_test.gd -- --read
godot4 --headless --path . --script res://tests/starter_sources_test.gd
godot4 --headless --path . --script res://tests/rarity_ui_test.gd
godot4 --headless --path . --script res://tests/starter_items_integration_test.gd
godot4 --headless --path . --script res://tests/enhancement_policy_test.gd
godot4 --headless --path . --script res://tests/profile_v4_test.gd
godot4 --headless --path . --script res://tests/equipment_effects_test.gd
godot4 --headless --path . --script res://tests/enhancement_ui_test.gd
godot4 --headless --path . --script res://tests/enhancement_integration_test.gd
godot4 --headless --path . --script res://tests/enhancement_integration_test.gd -- --read
godot4 --headless --path . --script res://tests/equipment_effects_integration_test.gd
godot4 --headless --path . --script res://tests/catalog_weapon_batch_test.gd
godot4 --headless --path . --script res://tests/catalog_equipment_batch_test.gd
godot4 --headless --path . --script res://tests/catalog_runtime_integration_test.gd
godot4 --headless --path . --script res://tests/catalog_stackable_batch_test.gd
godot4 --headless --path . --script res://tests/catalog_category_integration_test.gd
godot4 --headless --path . --script res://tests/catalog_category_integration_test.gd -- --read
godot4 --headless --path . --script res://tests/item_presentation_test.gd
godot4 --headless --path . --script res://tests/hall_inspection_ui_test.gd
godot4 --headless --path . --script res://tests/rare_discovery_test.gd
```

The persistence restart fixture uses **two separate engine processes**, with a disposable `/tmp` path on desktop/cloud (not an Android shell instruction):

```sh
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --write /tmp/vaultbound-restart/profile.json
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --read /tmp/vaultbound-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --write /tmp/vaultbound-roster-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --read /tmp/vaultbound-roster-restart/profile.json
godot4 --headless --path . --script res://tests/save_migration_test.gd -- --write /tmp/vaultbound-rpg-restart/profile.json
godot4 --headless --path . --script res://tests/save_migration_test.gd -- --read /tmp/vaultbound-rpg-restart/profile.json
godot4 --headless --path . --script res://tests/loadout_migration_test.gd -- --write /tmp/vaultbound-loadout-restart/profile.json
godot4 --headless --path . --script res://tests/loadout_migration_test.gd -- --read /tmp/vaultbound-loadout-restart/profile.json
godot4 --headless --path . --script res://tests/social_preferences_test.gd -- --write /tmp/vaultbound-social-restart/social_settings.cfg
godot4 --headless --path . --script res://tests/social_preferences_test.gd -- --read /tmp/vaultbound-social-restart/social_settings.cfg
godot4 --headless --path . --script res://tests/pet_restart_test.gd -- --write /tmp/vaultbound-pet-restart/profile.json
godot4 --headless --path . --script res://tests/pet_restart_test.gd -- --read /tmp/vaultbound-pet-restart/profile.json
godot4 --headless --path . --script res://tests/demo_exchange_restart_test.gd -- --write /tmp/vaultbound-6f-exchange-restart
godot4 --headless --path . --script res://tests/demo_exchange_restart_test.gd -- --read /tmp/vaultbound-6f-exchange-restart
godot4 --headless --path . --script res://tests/depth_restart_test.gd -- --write /tmp/vaultbound-depth-restart/profile.json
godot4 --headless --path . --script res://tests/depth_restart_test.gd -- --read /tmp/vaultbound-depth-restart/profile.json
```

Import first to index global GDScript classes. Assertions exit nonzero on failure; inspect logs for runtime errors too. Restricted Linux runners may need writable `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`. Android SDK/build-tools warnings affect APK export setup, not scene resources.

See [7D.1 validation](docs/milestone-7d1-validation.md) for current results, [7C validation](docs/milestone-7c-validation.md) for the depth checkpoint, [7B validation](docs/milestone-7b-validation.md) for the prior visual checkpoint, and [Milestone 7 Android checks](docs/milestone-7-android.md). The [6F full regression](docs/living-sanctuary-6f-validation.md), [Living Sanctuary Android checklist](docs/living-sanctuary-android.md), and [5.6 Android checklist](docs/milestone-5.6-android.md) cover the preserved systems. On a device, additionally walk the complete ring and all eight districts with both companions, ascend and descend the Forge and Tavern ramps, switch both cameras beside buildings, use each relocated service, and enter/return through all four Sanctuary gates. Check chat, pet naming and exchange fields with the actual Android keyboard, both synthetic trade participants, all nine emotes, AI inspection, Spiritweaving/following, the map and explicit Enter card at your UI scale and screen cutouts. [Milestone 5.6](docs/milestone-5.6-validation.md), [Milestone 5.5](docs/milestone-5.5-validation.md), [Milestone 5](docs/milestone-5-validation.md), [Milestone 4](docs/milestone-4-validation.md), [Milestone 3](docs/milestone-3-validation.md) and [Milestone 2](docs/milestone-2-guide.md) preserve earlier validation. The original GitHub roadmap is [archived separately](docs/original-github-roadmap.md) and describes future ideas, not shipped functionality.

## Remaining limits

This is a complete expedition loop prototype, not a finished commercial game. Large talent trees, talent respec, depths beyond 50, additional biomes, expedition resume, arbitrary stairs, companion gear/talents and additional classes remain outside this stage. Inventory capacity is forty active slots; the recoverable reserve preserves old saves and is not unlimited storage for new rewards. City navigation supports its authored terraces and gentle ramps; dungeon navigation and enemy steering retain their existing flat module constraints. Characters and city architecture use original native meshes and procedural animation. Production rigs, detailed character art, large wildlife simulation and vertical cave navigation are not implemented. Several city dimensions are authored together; arbitrary layout-resource resizing needs a fresh geometry/navigation review.

**No physical Android testing is claimed.** Rendered visual review, touchscreen comfort, APK export/signing, audio output, frame pacing, heat and battery use still need device verification. Headless checks establish logic and resource validity; they do not compile shaders on an Android GPU or establish final appearance, game feel or mobile frame rate.

The Living Sanctuary expansion proceeds through the documented stage gates. Online multiplayer, live player trading, bank storage and purchases are not implemented in 6F. The social prototype has no online delivery or authenticated recipients. The exchange is a bounded, local single-process demonstration, not a database transaction service or editable-save security system. The [6G proposal](docs/living-sanctuary-backend-proposal.md) and [server contract](docs/living-sanctuary-server-contract.md) define the remaining authority and two-client tests. Hosting and real billing retain separate approval/setup gates; 6H–6J have not been skipped or claimed complete. Natural drop pacing, economy balance, visual polish and actual menu responsiveness still require play-testing. Host measurements are not Android menu latency or frame rate.
