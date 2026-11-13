# Vaultbound: The Shifting Depths

**Sanctuary — enclosed Exchange and landscape polish, version 0.7.0-home6b.** A Godot 4 / GDScript-only, offline fantasy expedition prototype for Android landscape. The existing 90-metre city, eight connected districts, broad radial paths and Forge/Tavern terraces remain the gameplay framework. Recruit companions, explore, fight, extract treasure and develop the character through the preserved RPG systems.

Stage 6.1b responds to the user's request for smaller walls and a more vibrant central gathering place. The update lowers the perimeter to 4.6–5.8 m and exterior towers to 9–12 m, separates conflicting wall/trim surfaces, and encloses the spacious Exchange with eight arch-and-bridge connections to the existing districts. Six flat routes gain low bridge decks/ramps; Forge and Tavern retain their existing ascent. Bounded garden blooms and distant canopy variation add color without new gameplay systems. All six booths still share the **DEMO / NOT LIVE** exchange. **Stage 6.1b passed 8,435 checks across 33 runtime modes and 31 suites**, plus fresh import, 22 strict loads and 120 startup frames. All eight bridge routes were observed with the player, Guardian and Mystic. Rendered and physical Android review remain pending. See [scope](docs/personal-sanctuary-m6-1b-plan.md), [validation status](docs/personal-sanctuary-m6-1b-validation.md) and [device review](docs/personal-sanctuary-m6-1b-android.md).

Historical Stage 6.1 (`0.7.0-home6a`) introduced the shared booths, animated Prismheart and the earlier 22–30 m perimeter/35–45 m tower treatment. It passed 8,250 checks across 32 modes and 30 suites; [its report](docs/personal-sanctuary-m6-1-validation.md) remains unchanged. That evidence is a prior checkpoint, not acceptance of the new courtyard geometry. The full cardinal-wing/Nexus relocation, Bank/Guild/Undercroft and broader sky stages remain later work.

The southeastern **PERSONAL SANCTUARY** gate leads to the reviewed Grand Foyer and its preserved Trophy Hall/Pet Conservatory. Stage 5 adds six separately loaded rooms behind the existing doors: Armory, Companion Hall, Relic Library, Personal Chamber, Wardrobe and Rooftop Garden. They reuse owned equipment, real companion records, existing journals and the active cosmetic pet. Stage 5 passed 5,313 checks across 40 runtime modes. Rendered and physical Android review remain pending. Profile v11/home namespace v3 and the saved default-OFF tester switch remain. The blueprint-based city redesign is still unfinished. See the [home guide](docs/personal-sanctuary-home.md), [ordered plan](docs/personal-sanctuary-plan.md), [Stage 5 validation](docs/personal-sanctuary-m5-validation.md) and [Android checklist](docs/personal-sanctuary-android.md).

**TEST ACCESS** adds reversible access to implemented content for your current local profile. It is OFF by default. In a safe area, use **SETTINGS → TEST ACCESS → ON → REVIEW CHANGE → CONFIRM & SAVE** once on your device, then check the **TEST ACCESS ON** badge. It bypasses home/style/depth and supported owned-equipment/recipe level requirements while retaining ownership, costs, materials and earned talent points. It does not unlock unfinished content or grant online account permissions. Stage 5 also bypasses Spiritweaving recipe achievement gates while retaining required ingredients, enabled recipes, secured creature-memory provenance and existing ownership. It does not grant the achievement. The preceding Stage A validation passed **3,562 checks across 38 modes**; the Stage 5 extension passed its own scoped gate. See [instructions](docs/tester-access.md) and [validation evidence](docs/tester-access-validation.md).

Historical checkpoints: 7A preserved and audited the existing game. 7B raised the original perimeter into varied 3.2–4.2 m walls and 5.6–8 m towers, adds four distinctive giant-tree silhouettes, distant cascades and floating stones, and gives the existing blue Rootbound and gold Hall gates original crests. Roads, services, arrival points and navigation retain their working footprints. The new distant landmark layer contains nineteen combined meshes and 8,671 triangles, with no added simulation or lights. These are original native-mesh prototype assets; rendered visual review and Android performance testing remain pending. See the [ordered Milestone 7 plan](docs/milestone-7-plan.md), [7B validation](docs/milestone-7b-validation.md) and [Android acceptance route](docs/milestone-7-android.md). 7C adds permanent sequential depths 1–50, an eligibility-aware selector on the existing blue portal card, configured 6–24-room layouts and bounded encounter DM/XP and combat scaling. Boss defeat plus successful extraction unlocks the next depth in the same verified save as rewards. See [depth rules and migration](docs/dungeon-depths.md) and [7C validation](docs/milestone-7c-validation.md). The following 7D batches add boss families and two additional themes. Further themes, genetics, Veilgarden and Frontier remain later work.

7D.2 adds **Thornmarshal**, **Mycelial Cantor**, the **Ascendant Thornmarshal** variant and optional **Root Bark Champion** to the existing Rootbound biome. Depth 1 retains Rootwarden; deeper floors use seeded boss pools with readable attack warnings, real bounded summons and source-specific searchable rewards. Guardian/Mystic escape routes now account for boss bodies. Portal previews and the boss HUD identify the admitted encounter, while camera switching preserves combat state. Travel, rewards and saved encounter records extend the 7D.1 integration. See the [encounter guide](docs/rootbound-encounters.md), [content architecture](docs/dungeon-content.md) and [7D.2 validation](docs/milestone-7d2-validation.md). The Crystal and Ember batches below add two themes; Ancient encounters remain subsequent work.

7D.3 adds warned **spike lanes**, bounded **spore patches**, a destructible **Spore Hive** and a finite two-wave **Rootbound Horde**. Actual event actors pause and resume safely, share encounter limits and award one source-verified searchable cache. The hive blocks bodies, camera sweeps and attacks; companions can assist after it is disturbed. Event rewards and records remain unsecured until extraction. See [event mechanics and budgets](docs/rootbound-events.md) and [7D.3 validation](docs/milestone-7d3-validation.md). The Crystal and Ember batches below add resonance lanes, flame vents and arcane mines. Further trap families remain pending.

7D.4 adds **Return springs** on longer floors: one at 10–15 generated rooms, two at 16–24. Clear the local threats and use the existing interaction button to secure collected loot, discoveries and kill-only XP. The result is **LOOT SECURED · DEPTH INCOMPLETE**: no full-clear bonus or next-depth unlock. Required-boss victory still uses final extraction. Saves commit before travel; a failed arrival can retry travel without granting rewards again. See [Return spring rules](docs/dungeon-return-springs.md) and [7D.4 validation](docs/milestone-7d4-validation.md).

7D.5 adds **Glimmering Crystal Abyss**, selected from Depth 6 within the existing depth ladder. Fourteen native room modules, mineral scenery, three required boss possibilities, a Refracted Conductor variant, an optional Lancekeeper and warned resonance lanes use the shared combat and expedition systems. Seven configured reward tables reuse existing items and Depthmarks. Guardian/Mystic, both cameras, searchable caches and early/final returns remain integrated. See the [Crystal guide](docs/glimmering-crystal-abyss.md) and [7D.5 validation](docs/milestone-7d5-validation.md). The artwork is original native-mesh prototyping; rendered polish and physical Android review remain pending.

7D.6 adds **Crimson Ember Temple** from Depth 11, with fourteen native temple modules, kiln and bronze scenery, three required boss possibilities, a Banked Backdraft variant, an optional Cinder Pikewarden, warned flame vents and one optional dormant arcane mine. Each damaging stage has its own warning; harmless cooling water and decorative grilles do not deal damage. Seven source-specific tables use existing items and Depthmarks. The existing depth ladder, Guardian/Mystic, both cameras, Return springs and final extraction remain integrated. See the [Ember guide](docs/crimson-ember-temple.md) and [7D.6 validation](docs/milestone-7d6-validation.md). Models remain original native-mesh prototypes; rendered and physical Android review are pending.

7D.7 adds a **Rootbound rolling-stone trap**: from Depth 6, an eligible Rootbound floor has one configured 25% opportunity to select a safe thorn-trap room. A full two-second warning precedes the six-metre pass; the remaining warning shrinks as the stone moves, while only its current swept contact can damage a member once. Native obstruction, lost support or an active frame longer than 0.25 seconds cancels it harmlessly. The one-attempt trap reuses existing hazard slots and grants no rewards. Rooms, chests, both cameras, Guardian/Mystic and the existing Return/extraction rules remain integrated. See the [rolling-stone guide](docs/rootbound-rolling-stone.md) and [7D.7 validation](docs/milestone-7d7-validation.md). Native prototype geometry still needs rendered and physical Android review.

The hub map supplies district waypoints. Existing shops, recruitment, equipment preview and dungeon destinations remain functional; Sanctuary portals show information and require an explicit **ENTER** tap. City navigation follows the ring, spokes and ramps while dungeons retain their existing navigation. See the [Living Sanctuary plan](docs/living-sanctuary-plan.md) and [schematic map](docs/living-sanctuary-map.svg). The city's **Spiritweaving Conservatory in district G** opens pet acquisition and the pet journal; the Pavilion opens the existing equipment preview. The new **Personal Home Pet Conservatory** displays already-owned pets and does not weave or acquire them. Live trading and purchases remain later stages.

6F adds the **Ring Exchange — DEMO / NOT LIVE** at its physical plaza terminal. Two explicitly controlled synthetic accounts can place buy/sell orders, make partial fills, collect Claims, review actual TEST sale prices and separately confirm direct trades. TEST DM, equipment and receipts use a separate save and never enter character progression. The [exchange guide](docs/living-sanctuary-exchange.md) explains the workflow and limits. The owner confirmed there is no backend; the [6G backend proposal](docs/living-sanctuary-backend-proposal.md) recommends a local authenticated test realm before separately approved hosting. No server, account service or online market has been deployed.

6D adds nine local procedural emotes, inspection of actual AI party members and a native text composer with LOCAL/WORLD/PARTY tabs. **Chat is DEMO / NOT LIVE:** LOCAL can preview a self-message on this device; WORLD and PARTY cannot send. Drafts and bounded history stay in memory. Only separate chat display preferences persist. See [social behavior, limits and the online authority boundary](docs/living-sanctuary-social.md). No authenticated human player, message delivery or networked emote is implied.

The 6C pass adds a static sky gradient, a restrained twenty-minute local daylight cycle and distinct wall reliefs in all fourteen Rootbound room motifs. Graphics preferences add ambient density, prompt contrast and optional generated wind sound. Reduced motion now reaches decorative shaders, portal ornaments, water and ambient actors. These are original prototype assets; see [presentation provenance and limits](docs/living-sanctuary-assets.md) and the [expanded Android checklist](docs/living-sanctuary-android.md). Of the five additional art-direction resources, Crystal and Ember now have executable rooms and encounters through 7D.5 and 7D.6. The other three remain unavailable concepts.

Milestone 5.6's two owned weapon loadouts, Inventory and Equipment menus, inspection and accessibility settings remain available. Existing saves migrate to profile v11, retaining the pet collection, permanent depth progression, secured encounter records, home identity and earned appearance milestones while adding six bounded owned-pet display references. Rootbound, Crystal and Ember enemies leave searchable loot caches, and earned currency remains Depthmarks (DM). The catalog retains 350 noncurrency definitions: 300 available through current content and 50 gated future entries. Guaranteed enhancements, bounded equipment effects, twenty recipes and owned-item displays use the existing progression systems. The [5.6 validation report](docs/milestone-5.6-validation.md) is a historical baseline; its [Android checklist](docs/milestone-5.6-android.md) remains applicable. Production character assets and physical-device review remain outstanding.

The Sanctuary, practice dungeon and arena, player movement, sword/shield and staff combat, touch controls, both smoothly switchable cameras, procedural dungeons, treasure, boss encounters and secured progression from Milestones 1–5 remain available. `project.godot` stays at the repository root. The active party supports one human leader and up to two local AI companions. Only the Rootbound, Crystal and Ember expedition themes are playable. Online multiplayer, player-to-player trading and guilds are not implemented.

## Import and play on Android

1. Install the official **Godot Android editor**, standard GDScript edition. Use **Godot 4.6.3**, the validated engine for this milestone. Older Godot releases have not been validated with the new depth-fog and presentation settings.
2. Open the [GitHub repository](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths), select **main → Code → Download ZIP**, or download the [main source ZIP](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths/archive/refs/heads/main.zip). Extract the fresh download into a clearly named separate folder; verify root `project.godot` says `config/version="0.7.0-home6b"` (Godot Project Settings → Application → Config → Version). The Android export version code is **29**. This source build retains TEST ACCESS and the six-room home expansion, with the new Exchange courtyard polish. Stage 5 and Stage 6.1 are accepted historical checkpoints; Stage 6.1b passed 8,435 native checks, while rendered/physical Android review remains pending. Grant editor file access if requested, and back up the existing phone profile before testing.
3. Choose **Import**, select the root `project.godot`, then open it with the **Compatibility** renderer. Wait for resource import to finish.
4. Keep the device in landscape and choose **Run Project**. The main scene is `scenes/main.tscn`.
5. Tap the top-right hub map to choose a district waypoint. Visit the **northwestern Tavern (H)** and tap **USE** to recruit the Guardian and Mystic; solo play remains available. The **northern Portal Promenade (A)** holds the Rootbound expedition and practice-dungeon gates. Approach a gate, tap **ENTER**, review its card, then confirm **ENTER**. The blue expedition card selects a depth; a new profile starts with Depth 1 only. Depths 1–5 use Rootbound; 6–10 select Rootbound/Crystal at 60/40; 11+ select Rootbound/Crystal/Ember at 45/30/25. Review the possible pools before entry and the actual theme afterward. The **northeastern Coliseum (B)** also connects directly to the existing practice arena.
6. Open the entrance supply chest, follow the discovered-room minimap, explore branches, and approach marked hidden passages to reveal secret rooms. Walk through open doorways; rooms connect continuously.
7. Defeated enemies leave searchable caches. Approach one, tap **USE**, then choose a quantity and **TAKE**, or **TAKE ALL**. Defeat the required boss shown on the HUD and optionally search its grand cache, then find the **extraction spring in the connected chamber beyond the boss**. Tap **USE** to secure the collected rewards and return to Sanctuary.
8. Review the results screen, then open **INVENTORY**. Select an owned item to compare and equip it, mark it as a favorite or lock it. The **EQUIPMENT** tab shows all eleven assignments and a rotatable character preview; **CHARACTER** shows XP and talent allocation.
9. Visit the General Merchant, Equipment Trader and Relic Appraiser in the **eastern Merchant Terraces (C)**, and the Blacksmith on the **southern Forge terrace (E)**. Review the displayed costs before confirming purchases, sales, crafts or improvements.
10. Approach the **southeastern Personal Sanctuary gate (D)**, tap **ENTER**, review the local-home card and confirm **ENTER**. Cross the arrival room to **TROPHY HALL · YOUR COLLECTION** and use the interaction control to enter the existing Hall. Assign owned equipment and relics to displays or view the journals. The Hall return arch leads to your home; **RETURN TO SANCTUARY** in the home leads back to the city. To open the new Pet Conservatory, own one Spiritweaving pet, use Home Management → **RECORD EARNED UNLOCKS** and confirm. Then use the marked east doorway or **ROOM MILESTONES → ENTER CONSERVATORY**. In **PET DISPLAYS**, select a habitat → **CHOOSE PET** → owned pet → **REVIEW DISPLAY → CONFIRM & SAVE**.
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

Recruitment, name, role, personality trait, level, experience and combat proficiency persist in the local profile. Full boss extraction awards each recruited companion 150 experience plus 10 per defeated enemy; a safe Return spring grants only 10 per credited kill, scaled once by the admitted floor reward factor, through the same verified save transaction as loot. Cumulative level thresholds begin at 100 experience for level 2 and 300 for level 3; progression caps at level 20. Combat proficiency rises with level and modestly improves ranged accuracy; weapon damage and stamina costs still use the shared weapon data. Failed, abandoned or unsaved expeditions award no experience. There is no companion gear or talent tree in this milestone.

Companion navigation uses the existing modular room graph, bounded local A* and cached world collision for flat authored dungeon floors. Sanctuary opts into grounded ring/spoke/ramp routes, checked for floor continuity, slope and capsule clearance. Paths normally refresh every 0.65 seconds; moved goals are limited to four replans per second. Formation spacing, obstacle and hazard avoidance, and safe recovery handle separation. Companions do not teleport to keep up during active combat. Party state and commands are separate from presentation so authority can move to a server in a later milestone.

## Spiritweaving and cosmetic pets

6E adds eight cosmetic species at **G — Spiritweaving Conservatory**. Earn essence from completed Rootbound encounters, find seeded eggs, rescue secret-room spirits and defeat the Rootwarden for a vessel and Rootling memory. Findings stay unsecured until final extraction or a valid Return spring succeeds. At the Conservatory, review a recipe's ingredients and achievements, confirm creation, then select, rest or name the owned pet. The journal shows discoveries, origin and a static preview. See the [pet guide](docs/living-sanctuary-pets.md).

One pet follows the player alongside the existing AI party. It has no collider, combat target, bonuses, loot action or party slot. A bounded trail of previously walked positions keeps it within the current world and discovered rooms; recovery hides the pet before a safe reposition. Sit/perch, idle, playful and emote reactions are cosmetic. Reduced motion retains following. All eight native-mesh models and procedural poses are clearly marked placeholders awaiting rendered review.

Species ownership, selection, aliases, ingredients, achievements and fixed natural/luminous variant provenance persist unchanged in profile v11. Older profiles migrate in memory; the first migrated write preserves exact original bytes in `.pre-v11.bak`, keeping existing earlier migration backups. Previously secured inventory, Depthmarks, equipment, companion progression and Hall displays remain intact. The first secured matching creature memory fixes the variant, so repeated confirmations, cancellation or failed saves cannot reroll it. Death loses only the current expedition's unsecured findings.

## The expedition

Rootbound combines giant roots, luminous plants, ruined temples and streams. Crystal uses geodes, mineral shelves and broken lenses; Ember uses basalt kilns, bronze architecture, sealed urns and cooling channels. Each theme has fourteen separate native 24 × 24 m modules covering the same entrance, corridor, combat, treasure, trap, secret, boss and extraction roles. Flat floors, six-metre doors, room connectors and safe objective approaches remain shared contracts. Decorative height does not add vertical cave navigation.

`DungeonGenerator` uses a dedicated seeded `RandomNumberGenerator`. It builds a guaranteed main route followed by optional branches, then validates room count, unique cells, reciprocal adjacent connections, matching doorways, required roles and reachability **before the player is moved**. The main route ends at the boss and extraction; secret rooms are optional. Geometry is selected from PackedScenes rather than generated as arbitrary meshes during play.

The same seed, selected depth, policy version and build reproduce the configured layout, room selection, initial encounters and boss modifier. Chest/item reward rules remain deterministic from their existing source seeds. Awareness timing and combat outcomes still depend on player actions. The HUD shows the issued expedition seed and depth; changing cameras never changes it.

To reproduce a seed on Android: open `scenes/main.tscn`, select the **Vaultbound** root, set **Debug Expedition Seed** in the Inspector to the displayed number, save, and run. Select the same unlocked depth on the portal card. Set the debug seed back to `-1` for a new seed each expedition. On desktop:

```sh
godot4 --path . -- --expedition-seed=42
```

Existing skeletons, archers and golems form deterministic groups with modest depth scaling and occasional slower-telegraph elites. Enemy positions use validated module markers away from doorway arrivals. Dormant rooms preserve enemy health and defeat state, so revisiting does not respawn rewards. Awareness patrols use distant, unoccupied markers.

## Treasure, inventory and saving

Common, Reinforced, Ancient and Cursed chests share one chest implementation. Item definitions and weighted `.tres` loot tables provide Depthmarks (DM), crafting materials, equipment, healing consumables and collectibles across **Common, Uncommon, Rare, Epic, Legendary, Mythic and Ancient Relic** rarities. The original **40 functional noncurrency starter items** remain intact. The integrated catalog now contains **350 noncurrency definitions: 300 available and 50 unavailable future definitions**, plus the preserved currency record (**351 total**). Shared definition resources remain separate from unique owned equipment instances. Each implemented boss has its own table. Only the Rootwarden table guarantees the **Heart of the Rootwarden** collectible. Chests can be claimed only once per expedition. Rarity labels and I–VII markers supplement color, and source gates prevent unfinished content from being granted. See the [catalog batch status](docs/catalog-batches.md) and [starter catalog](docs/starter-item-catalog.md) for integrated counts, acquisition chains and honest family-art limitations.

- **Unsecured pack:** loot collected this run. It is not saved until final extraction or a valid Return spring. Tonics in the pack can be consumed immediately.
- **Secured inventory:** forty slots for owned stacks and individual equipment. Worn gear stays in those slots; each equipment instance keeps its unique ID, rolled modifiers, enhancement, condition and protection flags. Item-specific stack limits apply to materials and consumables. Both original sword/shield and staff combat families remain available.
- **Full extraction:** requires boss defeat. Depthmarks, unique gear/stacks, discoveries, pet findings, character and companion experience, permanent depth unlocks, completion/kill/time statistics and seed are written and verified before travel occurs. Chest collection checks space for all pending rewards before claiming a chest; a rejected chest remains available.
- **Early Return spring:** secures only collected rewards, eligible findings and actual kill XP. It leaves the depth incomplete and preserves completion counts, depth unlocks and merchant rotation. Unsearched or untaken loot stays behind.
- **Death or ordinary retreat:** returns to the Sanctuary and discards only the current unsecured bag. Previously secured equipment, items and Depthmarks remain. A results screen explains the outcome.
- **Closing the app during a run:** abandons its in-memory unsecured loot. Mid-expedition resume is not implemented. Previously secured progress loads on restart.

The **version-eleven** offline profile lives at `user://vaultbound/profile.json` with a previous valid `.bak`. Versions one through ten migrate in memory without rewriting the original on load. Before the first migrated write, the exact original bytes are retained in `.pre-v11.bak`, leaving earlier migration snapshots untouched; a separately restored legacy record receives its own content-addressed snapshot. The loadout migration adds secondary weapon, gloves, leg armor, necklace, ring and active loadout fields while preserving original shield/accessory assignments. Version four introduced the rarity enhancement caps and bounded effects while validating older records against their original limits. Version five added validated cosmetic pet collection fields without replacing inventory/equipment data. Version six adds permanent depth unlocks and preserves supported older floor records; unrecognized apparent floor formats are protected read-only. Previous successful Rootbound extractions establish a Depth 1 clear only. Version seven adds secured encounter records; historical discoveries retain an explicit pre-tracking flag without invented counts or dates. Unknown future encounter fields are protected before backup fallback. Version eight adds `home = {version: 1, id: ""}`; loading never invents a home ID. The first permitted Sanctuary-to-home entry saves an opaque ID once, and later entries reuse it without changing progression. The identity may already be saved if native arrival is subsequently obstructed; a retry reuses that same ID and grants nothing. Unsupported home versions/fields are protected read-only before backup fallback. Version nine migrates that identity into home namespace v2, adding `theme_id`, `sigil_id`, `unlocked_rooms` and `unlocked_styles`. Loading does not claim achievements or apply a new appearance. Home Management explicitly records already-earned milestones and saves reviewed cosmetic changes; unavailable rooms remain closed even when their milestone is recorded. Unknown home appearance or milestone IDs are protected read-only. Version ten adds home namespace v3 with six `pet_displays` references. Migration starts those slots empty and preserves existing pet records, aliases, variants and active selection; it does not generate pets or new genetic traits. A display references one existing owned species ID, and the same pet cannot occupy two habitat slots. Version eleven adds an explicit `tester_access` flag, OFF for migrated/new profiles. Enabling it does not raise earned levels or milestones. Turning it OFF restores normal eligibility and previews unequipping above-level gear plus clearing unearned home appearance/display selections, retaining every owned item and pet. The home and test access are local to this profile, not an online account or an unrestricted building layout. Existing instance IDs, enhancements and rolls are never rerolled during migration. Existing gold, counts, equipped selection, companions, discoveries and expedition statistics are preserved; equipment receives stable instance IDs. If an old inventory exceeds forty slots, its remaining quantities stay in a **legacy reserve**. Select the inventory reserve filter to claim supported items as space becomes available; unknown legacy IDs remain preserved rather than discarded. Writes use a temporary file, validation/read-back and atomic rename. A failed extraction write leaves the run and its loot available for retry. Corrupt saves use a valid backup where possible. Newer-format saves and structurally valid records containing unavailable owned content become read-only instead of being replaced with an older backup. Existing files remain intact with an on-screen warning. Never delete the profile to fix an import problem. Android stores `user://` in app-specific storage; its exact path depends on whether you run from the editor or an exported app.

The profile service, transaction rules and local combat command boundary are separated from presentation for later server-authoritative work. These local saves are temporary development/offline persistence and are editable on the device; online play will require secure server-side storage and validation. This does **not** implement authentication, networking, replication, anti-cheat or cloud saves.

## Searchable loot and Depthmarks

Defeated Rootbound, Crystal and Ember enemies leave searchable caches. Approach a cache, tap **USE / Search**, select a row and **Take**, or choose **Take All**. Regular enemies, elites and implemented bosses have distinct cache presentations. Only the Rootwarden grand cache guarantees the Rootwarden Heart; new encounter tables cannot issue its exclusive rewards. Empty caches disappear. Room treasure keeps its existing interaction.

Depthmarks are dark metallic coins condensed from dungeon energy, marked with turquoise and gold Vault seals. **DM** replaces the displayed generic currency name at merchants, the Blacksmith and expedition screens. Existing balances keep their exact amount: the save and transaction fields retain their internal `gold` names for compatibility, with no second writable balance or conversion grant.

| Completed encounter | Initial DM range |
| --- | ---: |
| Skeleton / Goblin Archer | 4–8 |
| Corrupted Golem | 8–18 |
| Elite enemy | 25–50 |
| Rootwarden / Thornmarshal / Cantor | 120–250 |

These are configurable reward ranges in `resources/loot/monster_rewards.tres`; controlled depth bands can scale them. Rewards are generated once per registered death. Resettable Sanctuary/Proving Grounds practice targets grant no bankable rewards. No quest or PvP reward system is implemented.

Taking loot adds it to the existing **unsecured expedition bag**, with capacity checked against the forty-slot secured inventory plus all pending rewards. Final extraction or a valid Return spring secures it; death, ordinary retreat or quitting an unfinished run loses it. A rejected or partially collected cache retains its remaining contents. Seven nearby regular/elite views and one reserved boss view are reused; hidden-room and overflow rewards stay in the run ledger. Nearby unopened low-tier caches may consolidate without rerolling. Repeated takes, stale touches, through-wall searches and duplicate death callbacks cannot grant the same contents again. Awareness activates once per original reward source, regardless of partial takes.

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

## Bosses and awareness

The [Rootbound encounter guide](docs/rootbound-encounters.md) covers Thornmarshal, Cantor, Ascendant and the optional Champion, their depth eligibility, telegraphs, real summons and source-specific rewards. The [Crystal](docs/glimmering-crystal-abyss.md) and [Ember](docs/crimson-ember-temple.md) guides describe their separate boss pools, variants and optional encounters. These extend selected-theme combat while preserving the original Rootwarden below.

The Rootwarden uses Root Slam, sequential Thorn Eruption patches and Vine Grasp (a brief interruption on a landed hit). Below 40% health it enters **Guardian's Fury** through a safe phase transition and gains a faster pattern with a radial burst. Ground warnings remain at least 0.9 seconds, attack windows share unique IDs, and sequential patches cannot stack multiple hits from the same cast. Dodge, shield/ward, range and wall obstruction apply normally.

A seed selects no modifier or one of two optional modifiers: **Thick Bark** increases durability with longer recovery; **Blooming Thorns** adds a spaced thorn patch with a longer warning. Modifiers never combine. The boss has a bounded arena leash and rejects out-of-arena damage. Its health bar, phase, modifier and attack telegraphs are visible; death cancels all pending attacks and unlocks the spring.

Awareness grows from kills, treasure value, cursed chests and time. Configurable thresholds (25 / 50 / 75 by default) warn before patrols, theme-selected environmental hazards or an elite event. Only one warning/event can be active at a time; queued thresholds wait through a minimum event gap. Safe rooms suppress encounters; boss proximity suspends regular enemies and cancels environmental hazards. Leaving a room cancels its hazards rather than resuming a nearly completed trap on re-entry.

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
- `scripts/enemies/`, `resources/enemies/`, `resources/bosses/`: three original archetypes, Rootwarden, new boss/Champion controllers, reusable cast data and native prototype visuals.
- `scripts/party/`, `resources/companions/`, `scenes/party/`: party lifecycle, AI decisions, navigation, companion data and Tavern recruitment.
- `scenes/rooms/`, `scenes/props/`, `resources/materials/`: authored reusable Abyss geometry and materials.
- `scripts/visual/`, `resources/environments/`, `resources/shaders/`, `resources/textures/`: shared style, cosmetic batching, ambient/combat presentation and independent device preferences.
- `scripts/expedition/`: pure layout generation, room activation, encounters, pooled hazards, awareness, secrets and extraction.
- `scripts/progression/`, `resources/items/`, `resources/loot/`, `resources/recipes/`, `resources/progression/`: definitions, instance inventory, transaction rules, recipes, character tables, transient loot and versioned local saves.
- `scripts/pets/`, `resources/pets/`: cosmetic species, acquisition policy, recipes, bounded presentation and validated collection progression.
- `scripts/ui/`: original combat/party controls, expedition HUD, discovery map and touch-scrollable RPG inventory/service panels.
- `scenes/world/personal_sanctuary.tscn`, `scripts/home/`, `resources/home/`: authored foyer, floor/formation checks, Home Management, appearance catalog and Hall/return routes.
- `scenes/world/collection_hall.tscn`, `scripts/world/`: Sanctuary services, Hall exhibits/journals and existing travel destinations.
- `tests/`, `docs/`: automated checks, archived milestone information and Android manual review.

Each level uses one shared environment and one directional light, with shadows controlled by graphics quality, shared materials and native primitive collision. Far rooms stop rendering/simulating while their floor and boundary collision stay valid. Normal encounters cap at **six active enemies**; the boss encounter suspends them. Two environmental hazards and four boss warning meshes are reused. Paving and repeated cosmetic detail use MultiMesh batches, and eligible opaque static architecture is conservatively combined by material. Animated water reuses three foam strips; it has no fluid simulation. Emissive decoration does not add realtime point lights. The metrics overlay shows FPS, active foes and draw calls.

## Validation

**Stage 6.1 passed 8,250 checks across 32 runtime modes and 30 suites**, including two independent restart readers, import, 24 strict loads and 120 startup frames, on one final frozen snapshot. Root independently reviewed 35 logs and 951 unchanged protected files, with no exceptions. The actual city walk used player/Guardian/Mystic from the ordinary arrival; four spawn formations were checked separately. These are native checks, not rendered or Android performance acceptance. See [Stage 6.1 validation](docs/personal-sanctuary-m6-1-validation.md).

**Stage 5 passed 5,313 checks across 40 runtime modes and 37 suites**, including two independent restart readers, on one final frozen source snapshot. Fresh import, 36 strict script loads and 120 startup frames passed. Five new modes contributed 1,138 checks and 35 retained modes contributed 4,175. Native checks covered six rooms, actual services/party returns, 1,438 floor/capsule probes and 4,026 camera samples; these are not rendered or Android performance measurements. See [the Stage 5 report](docs/personal-sanctuary-m5-validation.md).

**Offline tester access passed 3,562 checks across 38 unique runtime modes and 31 suites**, all on one frozen source snapshot, plus import, 31 strict script loads and 120 startup frames. Five new modes cover core policy, the actual session, independent restart and native Settings input; 33 retained modes cover related gameplay/save integration. Six independent readers are included. Earlier home checkpoint counts below remain historical. See [tester-access validation](docs/tester-access-validation.md); no rendered or physical Android acceptance is claimed.

**Home Stage 4 passed 4,928 checks across 50 unique runtime modes, 39 suites and seven independent restart readers**, plus import, 39 strict script loads and 120 startup frames. The accepted evidence combines 19 modes and 31 modes from two frozen chunks: only a retained leaf test expectation changed between them; all production and the other 1,177 semantic files are byte-identical. This is not a claim of a single 50-mode snapshot or a repeat of the entire historical regression. See [Stage 4 evidence and limits](docs/personal-sanctuary-m4-validation.md). Rendered visual and physical Android acceptance remain pending.

**Home Stage 3 passed 6,081 automated checks across 46 suites and 60 runtime modes**, including nine independent restart readers, isolated import, 35 strict script loads and a 120-frame startup. This scoped gate covers the foyer changes and relevant retained systems; it does not repeat the entire historical Stage 2 gate. Native tests cover both stair circuits with Guardian/Mystic and ground/flying pets, both cameras at Low/Medium/High, Home Management touch input, migration and save/restart. See [Stage 3 validation and limits](docs/personal-sanctuary-m3-validation.md). Rendered composition and physical Android acceptance remain pending.

**Home Stage 2 passed 46,230 automated checks across 198 suites and 234 runtime processes**, including 23 independent restart readers, isolated import, 34 strict script loads and a 120-frame startup. The final run retains all 229 prior modes and adds five home modes. Native home checks cover actual touch travel, companion following without recovery relocation and 1,344 camera-transition frames. See the [Stage 2 validation report](docs/personal-sanctuary-m2-validation.md) and [per-process results](docs/personal-sanctuary-m2-test-results.json). Physical Android and rendered visual acceptance remain pending.

The historical **7D.7 full gate passed 45,807 assertions across 194 suites and 229 separate test processes**, including 22 independent restart readers, plus isolated script preflight, import and startup. Its 1133 semantic files retain all 221 prior runtime modes. The eight new checks cover rolling selection, native floor and sphere admission, source lifetime, swept timing and shield-facing damage, actual companion responses, native visuals and both cameras, and unchanged progression/Return behavior. See [7D.7 validation](docs/milestone-7d7-validation.md) and [per-process results](docs/milestone-7d7-test-results.json) for actual commands, hashes, corrected failures and evidence limits. Development and diagnostic runs are excluded from this aggregate. [7D.6](docs/milestone-7d6-validation.md), [7D.5](docs/milestone-7d5-validation.md), [7D.4](docs/milestone-7d4-validation.md), [7D.3](docs/milestone-7d3-validation.md), [7D.2](docs/milestone-7d2-validation.md), [7D.1](docs/milestone-7d1-validation.md) and [7C](docs/milestone-7c-validation.md) remain historical checkpoints. Headless tests do not establish rendered visual quality, physical Android input, sustained device FPS or finished artwork.

The [6F full regression](docs/living-sanctuary-6f-validation.md), [7A audit](docs/milestone-7-plan.md) and [7B visual checks](docs/milestone-7b-validation.md) remain historical checkpoints. Physical Android keyboard, visual and performance acceptance remain pending; no headless result establishes device FPS or finished artwork.

Run these desktop/cloud checks from the repository root; substitute `godot` if that is your installed executable. Isolate test user data from normal play:

```sh
export XDG_DATA_HOME=/tmp/vaultbound-checks/data
export XDG_CONFIG_HOME=/tmp/vaultbound-checks/config
export XDG_CACHE_HOME=/tmp/vaultbound-checks/cache
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/profile_v10_home_test.gd
godot4 --headless --path . --script res://tests/home_displays_test.gd
godot4 --headless --path . --script res://tests/home_display_ui_test.gd
godot4 --headless --path . --script res://tests/home_displays_restart_test.gd -- --write /tmp/vaultbound-home-displays-restart/profile.json
godot4 --headless --path . --script res://tests/home_displays_restart_test.gd -- --read /tmp/vaultbound-home-displays-restart/profile.json
godot4 --headless --path . --script res://tests/trophy_hall_world_test.gd
godot4 --headless --path . --script res://tests/conservatory_world_test.gd
godot4 --headless --path . --script res://tests/home_rooms_integration_test.gd
godot4 --headless --path . --script res://tests/home_rooms_camera_test.gd
godot4 --headless --path . --script res://tests/home_rooms_camera_test.gd -- --low
godot4 --headless --path . --script res://tests/home_rooms_camera_test.gd -- --high
godot4 --headless --path . --script res://tests/profile_v9_home_test.gd
godot4 --headless --path . --script res://tests/home_management_test.gd
godot4 --headless --path . --script res://tests/home_management_ui_test.gd
godot4 --headless --path . --script res://tests/home_management_restart_test.gd -- --write /tmp/vaultbound-home-management-restart/profile.json
godot4 --headless --path . --script res://tests/home_management_restart_test.gd -- --read /tmp/vaultbound-home-management-restart/profile.json
godot4 --headless --path . --script res://tests/foyer_surfaces_test.gd
godot4 --headless --path . --script res://tests/foyer_navigation_test.gd
godot4 --headless --path . --script res://tests/foyer_navigation_test.gd -- --fly
godot4 --headless --path . --script res://tests/foyer_camera_test.gd
godot4 --headless --path . --script res://tests/foyer_camera_test.gd -- --low
godot4 --headless --path . --script res://tests/foyer_camera_test.gd -- --high
godot4 --headless --path . --script res://tests/profile_v8_home_test.gd
godot4 --headless --path . --script res://tests/home_session_test.gd
godot4 --headless --path . --script res://tests/home_world_test.gd
godot4 --headless --path . --script res://tests/home_restart_test.gd -- --write /tmp/vaultbound-home-restart/profile.json
godot4 --headless --path . --script res://tests/home_restart_test.gd -- --read /tmp/vaultbound-home-restart/profile.json
godot4 --headless --path . --script res://tests/rolling_content_test.gd
godot4 --headless --path . --script res://tests/rolling_source_admission_test.gd
godot4 --headless --path . --script res://tests/rolling_lifecycle_test.gd
godot4 --headless --path . --script res://tests/rolling_stone_runtime_test.gd
godot4 --headless --path . --script res://tests/rolling_stone_geometry_test.gd
godot4 --headless --path . --script res://tests/rolling_stone_visual_test.gd
godot4 --headless --path . --script res://tests/rolling_companion_test.gd
godot4 --headless --path . --script res://tests/rolling_progression_test.gd
godot4 --headless --path . --script res://tests/ember_content_test.gd
godot4 --headless --path . --script res://tests/ember_presentation_test.gd
godot4 --headless --path . --script res://tests/ember_rewards_test.gd
godot4 --headless --path . --script res://tests/ember_environment_test.gd
godot4 --headless --path . --script res://tests/ember_actor_visual_test.gd
godot4 --headless --path . --script res://tests/ember_world_test.gd
godot4 --headless --path . --script res://tests/ember_mine_lifecycle_test.gd
godot4 --headless --path . --script res://tests/ember_support_scheduler_test.gd
godot4 --headless --path . --script res://tests/ember_boss_controller_test.gd
godot4 --headless --path . --script res://tests/ember_boss_sequence_test.gd
godot4 --headless --path . --script res://tests/ember_boss_summon_test.gd
godot4 --headless --path . --script res://tests/ember_miniboss_test.gd
godot4 --headless --path . --script res://tests/ember_hazard_runtime_test.gd -- --hazard=vent
godot4 --headless --path . --script res://tests/ember_hazard_runtime_test.gd -- --hazard=mine
godot4 --headless --path . --script res://tests/ember_rewards_integration_test.gd
godot4 --headless --path . --script res://tests/ember_rewards_restart_test.gd -- --write /tmp/vaultbound-7d6-checks/ember_rewards_restart_test/fixture-1/profile.json
godot4 --headless --path . --script res://tests/ember_rewards_restart_test.gd -- --read /tmp/vaultbound-7d6-checks/ember_rewards_restart_test/fixture-1/profile.json
godot4 --headless --path . --script res://tests/ember_boss_ui_test.gd
godot4 --headless --path . --script res://tests/ember_boss_companion_test.gd -- --family=furnace
godot4 --headless --path . --script res://tests/ember_boss_companion_test.gd -- --family=liturgist
godot4 --headless --path . --script res://tests/ember_boss_companion_test.gd -- --family=sealkeeper
godot4 --headless --path . --script res://tests/ember_boss_companion_test.gd -- --family=pikewarden
godot4 --headless --path . --script res://tests/ember_hazard_companion_test.gd -- --hazard=vent
godot4 --headless --path . --script res://tests/ember_hazard_companion_test.gd -- --hazard=mine
godot4 --headless --path . --script res://tests/ember_return_ui_test.gd
godot4 --headless --path . --script res://tests/crystal_content_test.gd
godot4 --headless --path . --script res://tests/crystal_presentation_test.gd
godot4 --headless --path . --script res://tests/crystal_rewards_test.gd
godot4 --headless --path . --script res://tests/crystal_journal_test.gd
godot4 --headless --path . --script res://tests/crystal_environment_test.gd
godot4 --headless --path . --script res://tests/crystal_actor_visual_test.gd
godot4 --headless --path . --script res://tests/crystal_boss_controller_test.gd
godot4 --headless --path . --script res://tests/crystal_boss_sequence_test.gd
godot4 --headless --path . --script res://tests/crystal_boss_projectile_test.gd
godot4 --headless --path . --script res://tests/crystal_miniboss_test.gd
godot4 --headless --path . --script res://tests/crystal_hazard_runtime_test.gd
godot4 --headless --path . --script res://tests/crystal_world_test.gd
godot4 --headless --path . --script res://tests/crystal_environment_lifecycle_test.gd
godot4 --headless --path . --script res://tests/typed_hazard_admission_test.gd
godot4 --headless --path . --script res://tests/crystal_rewards_integration_test.gd
godot4 --headless --path . --script res://tests/crystal_rewards_restart_test.gd -- --write /tmp/vaultbound-7d5-crystal-restart/profile.json
godot4 --headless --path . --script res://tests/crystal_rewards_restart_test.gd -- --read /tmp/vaultbound-7d5-crystal-restart/profile.json
godot4 --headless --path . --script res://tests/crystal_boss_ui_test.gd
godot4 --headless --path . --script res://tests/crystal_boss_companion_test.gd -- --family=conductor
godot4 --headless --path . --script res://tests/crystal_boss_companion_test.gd -- --family=colossus
godot4 --headless --path . --script res://tests/crystal_boss_companion_test.gd -- --family=wraith
godot4 --headless --path . --script res://tests/crystal_boss_companion_test.gd -- --family=lancekeeper
godot4 --headless --path . --script res://tests/crystal_hazard_companion_test.gd
godot4 --headless --path . --script res://tests/crystal_hazard_companion_test.gd -- --active-edge
godot4 --headless --path . --script res://tests/crystal_return_ui_test.gd
godot4 --headless --path . --script res://tests/checkpoint_content_test.gd
godot4 --headless --path . --script res://tests/return_spring_visual_test.gd
godot4 --headless --path . --script res://tests/legacy_hazard_evidence_test.gd
godot4 --headless --path . --script res://tests/return_spring_geometry_test.gd
godot4 --headless --path . --script res://tests/checkpoint_safety_test.gd
godot4 --headless --path . --script res://tests/checkpoint_loot_placement_test.gd
godot4 --headless --path . --script res://tests/early_return_transaction_test.gd
godot4 --headless --path . --script res://tests/early_return_reentrancy_test.gd
godot4 --headless --path . --script res://tests/early_return_travel_test.gd
godot4 --headless --path . --script res://tests/early_return_ui_test.gd
godot4 --headless --path . --script res://tests/early_return_restart_test.gd -- --write /tmp/vaultbound-early-return/profile.json
godot4 --headless --path . --script res://tests/early_return_restart_test.gd -- --read /tmp/vaultbound-early-return/profile.json
godot4 --headless --path . --script res://tests/hazard_definition_test.gd
godot4 --headless --path . --script res://tests/event_rewards_test.gd
godot4 --headless --path . --script res://tests/event_journal_test.gd
godot4 --headless --path . --script res://tests/event_source_record_test.gd
godot4 --headless --path . --script res://tests/event_content_test.gd
godot4 --headless --path . --script res://tests/rootbound_event_visual_test.gd
godot4 --headless --path . --script res://tests/rootbound_event_geometry_test.gd
godot4 --headless --path . --script res://tests/rootbound_hazard_runtime_test.gd
godot4 --headless --path . --script res://tests/event_lifecycle_test.gd
godot4 --headless --path . --script res://tests/event_rewards_integration_test.gd
godot4 --headless --path . --script res://tests/stationary_blocker_navigation_test.gd
godot4 --headless --path . --script res://tests/rootbound_event_companion_test.gd
godot4 --headless --path . --script res://tests/rootbound_event_ui_test.gd
godot4 --headless --path . --script res://tests/event_rewards_restart_test.gd -- --write /tmp/vaultbound-event-rewards/profile.json
godot4 --headless --path . --script res://tests/event_rewards_restart_test.gd -- --read /tmp/vaultbound-event-rewards/profile.json
godot4 --headless --path . --script res://tests/rootbound_rewards_test.gd
godot4 --headless --path . --script res://tests/variant_journal_test.gd
godot4 --headless --path . --script res://tests/rootbound_content_test.gd
godot4 --headless --path . --script res://tests/rootbound_room_structure_test.gd
godot4 --headless --path . --script res://tests/rootbound_boss_visual_test.gd
godot4 --headless --path . --script res://tests/rootbound_boss_controller_test.gd
godot4 --headless --path . --script res://tests/boss_spawn_scheduler_test.gd
godot4 --headless --path . --script res://tests/boss_summon_lifecycle_test.gd
godot4 --headless --path . --script res://tests/rootbound_miniboss_test.gd
godot4 --headless --path . --script res://tests/rootbound_rewards_integration_test.gd
godot4 --headless --path . --script res://tests/rootbound_boss_companion_test.gd
godot4 --headless --path . --script res://tests/rootbound_boss_ui_test.gd
godot4 --headless --path . --script res://tests/rootbound_rewards_restart_test.gd -- --write /tmp/vaultbound-rootbound-restart/profile.json
godot4 --headless --path . --script res://tests/rootbound_rewards_restart_test.gd -- --read /tmp/vaultbound-rootbound-restart/profile.json
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

See the [Personal Sanctuary Android checklist](docs/personal-sanctuary-android.md) for the new home route and manual acceptance items. [7D.7 validation](docs/milestone-7d7-validation.md) records the preceding accepted full gate, [7C validation](docs/milestone-7c-validation.md) for the depth checkpoint, [7B validation](docs/milestone-7b-validation.md) for the prior visual checkpoint, and [Milestone 7 Android checks](docs/milestone-7-android.md). The [6F full regression](docs/living-sanctuary-6f-validation.md), [Living Sanctuary Android checklist](docs/living-sanctuary-android.md), and [5.6 Android checklist](docs/milestone-5.6-android.md) cover the preserved systems. On a device, additionally walk the complete ring and all eight districts with both companions, ascend and descend the Forge and Tavern ramps, switch both cameras beside buildings, use each relocated service, and enter/return through all four Sanctuary gates. Check chat, pet naming and exchange fields with the actual Android keyboard, both synthetic trade participants, all nine emotes, AI inspection, Spiritweaving/following, the map and explicit Enter card at your UI scale and screen cutouts. [Milestone 5.6](docs/milestone-5.6-validation.md), [Milestone 5.5](docs/milestone-5.5-validation.md), [Milestone 5](docs/milestone-5-validation.md), [Milestone 4](docs/milestone-4-validation.md), [Milestone 3](docs/milestone-3-validation.md) and [Milestone 2](docs/milestone-2-guide.md) preserve earlier validation. The original GitHub roadmap is [archived separately](docs/original-github-roadmap.md) and describes future ideas, not shipped functionality.

## Remaining limits

This is an expedition loop prototype with a functionally verified Grand Foyer, redesigned Trophy Hall and six-display Pet Conservatory. It is not a finished commercial game. The conservatory presents up to six owned cosmetic pets through existing visual families; it is not the future genetics/roaming habitat expansion. Armory and other home rooms, additional decorations, large Prismheart city reconstruction and its new sky/landscaping remain unfinished. Large talent trees, talent respec, depths beyond 50, further themes beyond Rootbound/Crystal/Ember, expedition resume, arbitrary stairs, companion gear/talents and additional classes remain outside this stage. Inventory capacity is forty active slots; the recoverable reserve preserves old saves and is not unlimited storage for new rewards. City navigation supports its authored terraces and gentle ramps; the foyer adds a natively tested two-level route with solid upper-floor plinths. It is not general stacked-floor navigation. Dungeon navigation and enemy steering retain their existing flat module constraints. Characters and city architecture use original native meshes and procedural animation. Production rigs, detailed character art, large wildlife simulation and vertical cave navigation are not implemented. Several city dimensions are authored together; arbitrary layout-resource resizing needs a fresh geometry/navigation review.

**No physical Android testing is claimed.** Rendered visual review, touchscreen comfort, APK export/signing, audio output, frame pacing, heat and battery use still need device verification. Headless checks establish logic and resource validity; they do not compile shaders on an Android GPU or establish final appearance, game feel or mobile frame rate.

The Living Sanctuary expansion proceeds through the documented stage gates. Online multiplayer, live player trading, bank storage and purchases are not implemented in 6F. The social prototype has no online delivery or authenticated recipients. The exchange is a bounded, local single-process demonstration, not a database transaction service or editable-save security system. The [6G proposal](docs/living-sanctuary-backend-proposal.md) and [server contract](docs/living-sanctuary-server-contract.md) define the remaining authority and two-client tests. Hosting and real billing retain separate approval/setup gates; 6H–6J have not been skipped or claimed complete. Natural drop pacing, economy balance, visual polish and actual menu responsiveness still require play-testing. Host measurements are not Android menu latency or frame rate.
