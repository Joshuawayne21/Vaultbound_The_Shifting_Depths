# Vaultbound: The Shifting Depths

**Milestone 5.6 — Loot and equipment overhaul, staged implementation.** A Godot 4 / GDScript-only, offline fantasy expedition prototype for Android landscape. The existing Sanctuary, Collection Hall and Rootbound Abyss now share slate-and-bronze architecture, turquoise magic, mossy ruins, living foliage and flowing water. Recruit companions, explore, fight, extract treasure and develop the character through the preserved RPG systems.

The verified foundation adds owned primary/secondary weapon loadouts and version-four save migration. Mobile menus share an enchanted navy, bronze and turquoise theme, with distinct Inventory and Equipment entries, rotatable inspection and saved accessibility settings. Rootbound enemies now leave searchable loot caches, and currency is displayed as Depthmarks (DM). Follow the [implementation plan](docs/milestone-5.6-plan.md) and [checkpoint validation](docs/milestone-5.6-validation.md) for completed versus pending work.

The Sanctuary, practice dungeon and arena, player movement, sword/shield and staff combat, touch controls, both smoothly switchable cameras, procedural dungeons, treasure, boss encounters and secured progression from Milestones 1–5 remain available. `project.godot` stays at the repository root. The active party supports one human leader and up to two local AI companions. No online multiplayer, player-to-player trading, guilds or additional biomes are implemented.

## Import and play on Android

1. Install the official **Godot Android editor**, standard GDScript edition. Use **Godot 4.6.3**, the validated engine for this visual pass. Older Godot releases have not been validated with the new depth-fog and presentation settings.
2. Download/extract the full repository or source ZIP into storage the editor can access. Grant the editor file access if requested.
3. Choose **Import**, select the root `project.godot`, then open it with the **Compatibility** renderer. Wait for resource import to finish.
4. Keep the device in landscape and choose **Run Project**. The main scene is `scenes/main.tscn`.
5. In Sanctuary, visit the **Tavern on the west side** and tap **USE** to recruit the Guardian and Mystic. Recruitment is optional; solo play remains available. The **east-facing Rootbound Abyss archway** begins an expedition, and the northern arch still leads to the original practice dungeon and arena.
6. Open the entrance supply chest, follow the discovered-room minimap, explore branches, and approach whispering vine walls to reveal hidden rooms. Walk through open doorways; rooms connect continuously.
7. Defeated enemies leave searchable caches. Approach one, tap **USE**, then choose a quantity and **TAKE**, or **TAKE ALL**. Defeat the Rootwarden and search its grand cache, then find the **extraction spring in the connected chamber beyond the boss**. Tap **USE** to secure the collected rewards and return to Sanctuary.
8. Review the results screen, then open **INVENTORY**. Select an owned item to compare and equip it, mark it as a favorite or lock it. The **EQUIPMENT** tab shows all eleven assignments and a rotatable character preview; **CHARACTER** shows XP and talent allocation.
9. Visit the four merchants/workbenches along the **south side of Sanctuary**: General Merchant, Blacksmith, Equipment Trader and Relic Appraiser. Review the displayed costs before confirming purchases, sales, crafts or improvements.
10. Use the **northwestern Collection Hall passage** to assign owned equipment and relics to displays and view the discovery journals. Its return arch leads safely back to Sanctuary.
11. Tap **GRAPHICS** to select **Low, Medium or High** and a **30 or 60 FPS target**, then **APPLY & SAVE**. Start with the default **Medium / 30 FPS**. Use Low if sustained play shows frame-time spikes; 60 FPS is an optional target for capable devices, not a measured guarantee.

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

Inventory supports name, rarity, level, value, lowest-rarity, equipment category and recent-acquisition sorting. Equipment inspection reuses the gameplay avatar and active loadout; drag only within its preview to rotate it. Hidden previews do not continuously render. In GRAPHICS, choose 100%, 110% or 120% UI size, reduced motion and reduced effects. Larger text and touch targets reflow inside the safe area. These settings are saved separately from progression.

Assign owned swords or staffs to PRIMARY / SECONDARY in the inventory equipment actions. Empty loadout buttons are disabled and show no weapon icon. The unassigned practice controller still supports R until a weapon is assigned. Switching requires recovery from the current action, takes 0.32 seconds and preserves ability cooldowns, targeting and current resources. The shield and legacy accessory remain separate equipment slots.

The shared character now uses rounded native meshes and smoother procedural pose transitions, with unchanged weapon anchors and gameplay timing. Player, companions and inspection share this avatar. These remain original prototype visuals; production skinned models, fitted item-specific armor and authored clips are still missing. See [character presentation and asset requirements](docs/character-presentation.md).

Sword/shield retains its three-hit combo, charged heavy, Shield Bash and Cleave. Staff retains bolts, charged splash, Arcane Burst and Frost Nova. Both use identical damage, costs, cooldowns, range and targeting in either camera view. Charge, block and joystick touches cancel safely on focus loss, Android pause, travel and modal opening.

Inventory, Equipment, GRAPHICS, merchant/workbench/Collection Hall screens, party/recruitment menus and expedition results pause the local player, companions and active world. Closing them restores input without resuming stale held buttons. Basic movement is grounded; jumping is intentionally omitted. The elevated tactical camera uses a narrow perspective lens for a continuous transition rather than a strict orthographic projection.

## Party and companions

Visit the west-side Sanctuary Tavern to recruit or dismiss either companion. The roster is saved before it changes; dismissal preserves earned progression. Party records distinguish human and AI members instead of reserving permanent AI-only replacements for future human slots. This is a local party model, not a network implementation.

- **Rowan — Guardian / Steadfast:** sword and shield, nearby threat interception, protection of injured allies, three-hit melee attacks, directional blocking and major-telegraph avoidance.
- **Lyra — Mystic / Careful:** staff projectiles, ranged spacing, retreat from melee pressure, cooldown-limited healing and safe revive attempts.

Both reuse the player's weapon timing, stamina costs, damage rules and obstruction checks. Decisions run at configurable intervals with reaction jitter and imperfect ranged accuracy. They do not read camera mode or call external AI services. Health, combat state and navigation remain individual; changing cameras does not recreate the party.

The **PARTY** menu provides **Follow Me**, **Attack My Target**, **Hold Position**, **Retreat** and **Revive Teammate**. Lock a visible enemy within the companions' pursuit range (12 m by default) before issuing the attack command. Orders can be delayed by valid safety constraints such as a major ground warning, an unreachable target or an interrupted revive. Feedback explains rejected orders. Companions do not open chests or consume the player's collected treasure.

The leader and companions can be downed while a teammate remains able to help. A revive requires line of sight, a distance of at most 2.4 m and a 3-second uninterrupted channel, restoring 35% health by default. Damage, separation and new combat actions interrupt it. Each member can be revived twice per expedition; a 30-second bleedout ends rescue eligibility. These values are configurable on the party component. If no active member remains, the expedition ends under the existing death rules: unsecured loot is lost, secured possessions remain, and recruited companions return to Sanctuary. If the human leader bleeds out, this offline prototype also ends the expedition so the player cannot remain stranded watching AI indefinitely. Solo lethal damage retains immediate Sanctuary recovery.

Recruitment, name, role, personality trait, level, experience and combat proficiency persist in the local profile. Successful extraction awards each recruited companion 150 experience plus 10 per defeated enemy through the same verified save transaction as loot. Cumulative level thresholds begin at 100 experience for level 2 and 300 for level 3; progression caps at level 20. Combat proficiency rises with level and modestly improves ranged accuracy; weapon damage and stamina costs still use the shared weapon data. Failed, abandoned or unsaved expeditions award no experience. There is no companion gear or talent tree in this milestone.

Companion navigation uses the existing modular room graph, bounded local A* and cached world collision for flat authored floors. Paths normally refresh every 0.65 seconds; moved goals are limited to four replans per second. Formation spacing, obstacle and hazard avoidance, and safe recovery handle separation. Companions do not teleport to keep up during active combat. Party state and commands are separate from presentation so authority can move to a server in a later milestone.

## The expedition

The biome combines giant roots, emerald and turquoise mushrooms, magical flowers, crystals, ruined temple columns, streams, waterfalls and low-cost mist. Fourteen reusable 24 × 24 m room modules cover entrance groves/temples, root and stream corridors, four combat chambers, two treasure chambers, thorn traps, secret hollows, the boss heart and extraction spring.

`DungeonGenerator` uses a dedicated seeded `RandomNumberGenerator`. It builds a guaranteed main route followed by optional branches, then validates room count, unique cells, reciprocal adjacent connections, matching doorways, required roles and reachability **before the player is moved**. The main route ends at the boss and extraction; secret rooms are optional. Geometry is selected from PackedScenes rather than generated as arbitrary meshes during play.

The same seed reproduces layout, room selection, initial encounters, chest contents and the boss modifier. Awareness timing and combat outcomes still depend on player actions. The HUD always shows the expedition seed and floor (this prototype has one floor).

To reproduce a seed on Android: open `scenes/main.tscn`, select the **Vaultbound** root, set **Debug Expedition Seed** in the Inspector to the displayed number, save, and run. Set it back to `-1` for a new seed each expedition. On desktop:

```sh
godot4 --path . -- --expedition-seed=42
```

Existing skeletons, archers and golems form deterministic groups with modest depth scaling and occasional slower-telegraph elites. Enemy positions use validated module markers away from doorway arrivals. Dormant rooms preserve enemy health and defeat state, so revisiting does not respawn rewards. Awareness patrols use distant, unoccupied markers.

## Treasure, inventory and saving

Common, Reinforced, Ancient and Cursed chests share one chest implementation. Item definitions and weighted `.tres` loot tables provide Depthmarks (DM), crafting materials, equipment, healing consumables and collectibles across **Common, Uncommon, Rare, Epic, Legendary, Mythic and Ancient Relic** rarities. The original **40 functional noncurrency starter items** remain intact. The integrated catalog now contains **301 noncurrency definitions: 267 available and 34 unavailable future definitions**, plus the preserved currency record (**302 total**). Shared definition resources remain separate from unique owned equipment instances. The boss chest has its own table and a guaranteed **Heart of the Rootwarden** collectible. Chests can be claimed only once per expedition. Rarity labels and I–VII markers supplement color, and source gates prevent unfinished content from being granted. See the [catalog batch status](docs/catalog-batches.md) and [starter catalog](docs/starter-item-catalog.md) for integrated counts, acquisition chains and honest family-art limitations.

- **Unsecured pack:** loot collected this run. It is not saved until extraction. Tonics in the pack can be consumed immediately.
- **Secured inventory:** forty slots for owned stacks and individual equipment. Worn gear stays in those slots; each equipment instance keeps its unique ID, rolled modifiers, enhancement, condition and protection flags. Item-specific stack limits apply to materials and consumables. Both original sword/shield and staff combat families remain available.
- **Successful extraction:** requires boss defeat. Depthmarks, unique gear/stacks, discoveries, character and companion experience, completion/kill/time statistics and seed are written and verified before travel occurs. Chest collection checks space for all pending rewards before claiming a chest; a rejected chest remains available.
- **Death or retreat:** returns to the Sanctuary and discards only the current unsecured bag. Previously secured equipment, items and Depthmarks remain. A results screen explains the outcome.
- **Closing the app during a run:** abandons its in-memory unsecured loot. Mid-expedition resume is not implemented. Previously secured progress loads on restart.

The **version-four** offline profile lives at `user://vaultbound/profile.json` with a previous valid `.bak`. Version-one, version-two and version-three saves migrate in memory without rewriting the original on load. Before the first migrated write, the exact original bytes are retained in `.pre-v4.bak`, leaving any earlier `.pre-v3` snapshots untouched; a separately restored legacy record receives its own content-addressed snapshot. The loadout migration adds secondary weapon, gloves, leg armor, necklace, ring and active loadout fields while preserving original shield/accessory assignments. Version four admits the new rarity enhancement caps and bounded effects while validating older records against their original limits. Existing instance IDs, enhancements and rolls are never rerolled during migration. Existing gold, counts, equipped selection, companions, discoveries and expedition statistics are preserved; equipment receives stable instance IDs. If an old inventory exceeds forty slots, its remaining quantities stay in a **legacy reserve**. Select the inventory reserve filter to claim supported items as space becomes available; unknown legacy IDs remain preserved rather than discarded. Writes use a temporary file, validation/read-back and atomic rename. A failed extraction write leaves the run and its loot available for retry. Corrupt saves use a valid backup where possible. Newer-format saves and structurally valid records containing unavailable owned content become read-only instead of being replaced with an older backup. Existing files remain intact with an on-screen warning. Never delete the profile to fix an import problem. Android stores `user://` in app-specific storage; its exact path depends on whether you run from the editor or an exported app.

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

The Blacksmith provides guaranteed enhancement up to **+5 for Common through Legendary**, and **+10 for Mythic and Ancient Relic** equipment, including existing accessories. It also provides condition repairs, salvage and twelve authored recipes, including the original eight equipment/consumable recipes, Ancient Forged Cores, Ancient Heartstones, Verdant Oathblade and Vaultheart Staff. Upgrades preview the next statistics and exact materials/DM before confirmation. Each rank increases the original five base bonuses by 8%; rolled modifiers and critical/lifesteal/block/cooldown effects do not multiply with enhancement. See the [enhancement policy](docs/enhancement-policy.md) for all prices and earned components. There are no random upgrade failures. Recipes use obtainable dungeon or merchant materials. Protected materials must be unlocked/unfavorited before they can be consumed. Successful extraction wears equipped gear by 2 condition; defeat wears it by 8. Broken gear remains owned and retains its base combat family, but its equipment bonuses stop applying until repaired.

Equipment can provide bounded critical chance, lifesteal, block strength and ability cooldown reduction. One committed attack retains its effect snapshot across camera/loadout switches; lifesteal uses actual enemy health lost and shares a 4 HP limit across that attack. Training targets and rejected hits grant no healing. Existing instances retain their rolls; newly acquired gear uses authored rarity ranges. Elemental resistance mechanics are not implemented. See [equipment effects](docs/equipment-effects.md) for limits and validation.

Character progression uses an explicit thirty-level table. Extraction grants **250 XP plus 20 per defeated normal enemy**; failed or abandoned runs grant none. Level 2 requires 200 cumulative XP and level 30 caps at 46,400. Each level grants one talent point after level 1. The small **Offense, Defense and Utility** branches allow up to ten ranks each, improve modest statistics, and require confirmation before spending a point. Talent respec is not included in this milestone. A separate normalized-stat resolver prepares for later PvP work; no PvP or online authority is implemented.

## Collection Hall

The Hall is a separate underground castle chamber reached from the Sanctuary's northwestern arch. It contains **eight equipment stands, four relic pedestals, a Rootwarden trophy wall, a monster journal and an item journal**. Interact with a stand, choose an eligible owned item and confirm the display. An assignment references the original inventory instance; it never creates a second item or removes ownership, and the same instance cannot occupy multiple stands. Clear a display before selling or salvaging its item. The trophy unlocks from the existing Rootwarden discovery, and successful extraction records monster discoveries. Assignments and journals persist across travel and restart.

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

Abyss mote batches additionally cap at twelve per room and follow existing room visibility. Essential geometry, interactables and combat warnings do not disappear on Low. The frame target changes rendering pacing; physics remains 60 Hz. Preferences live separately at `user://vaultbound/visual_settings.cfg`, without changing the progression profile. Invalid graphics files retain current settings; an explicit successful change writes verified replacement preferences.

The 30 FPS midrange Android goal and optional 60 FPS target require physical-device verification. Native primitives do not include authored mesh LOD chains; the tier's general LOD threshold prepares for compatible future assets, while current savings come from batching, shadow policy, visibility and bounded decoration/effects. See the [visual style guide](docs/visual-style-guide.md), [initial baseline](docs/milestone-5.5-baseline.md) and [performance report](docs/milestone-5.5-performance.md) for the measured scope and limitations.

## Project organization and mobile budget

- `scripts/systems/`: persistent game shell, one input vocabulary and transitions.
- `scripts/player/`, `scripts/combat/`, `resources/weapons/`: preserved movement and combat components.
- `scripts/enemies/`, `resources/enemies/`: three original archetypes and Rootwarden data/AI.
- `scripts/party/`, `resources/companions/`, `scenes/party/`: party lifecycle, AI decisions, navigation, companion data and Tavern recruitment.
- `scenes/rooms/`, `scenes/props/`, `resources/materials/`: authored reusable Abyss geometry and materials.
- `scripts/visual/`, `resources/environments/`, `resources/shaders/`, `resources/textures/`: shared style, cosmetic batching, ambient/combat presentation and independent device preferences.
- `scripts/expedition/`: pure layout generation, room activation, encounters, pooled hazards, awareness, secrets and extraction.
- `scripts/progression/`, `resources/items/`, `resources/loot/`, `resources/recipes/`, `resources/progression/`: definitions, instance inventory, transaction rules, recipes, character tables, transient loot and versioned local saves.
- `scripts/ui/`: original combat/party controls, expedition HUD, discovery map and touch-scrollable RPG inventory/service panels.
- `scenes/world/collection_hall.tscn`, `scripts/world/`: Sanctuary services, Hall exhibits/journals and existing travel destinations.
- `tests/`, `docs/`: automated checks, archived milestone information and Android manual review.

Each level uses one shared environment and one directional light, with shadows controlled by graphics quality, shared materials and native primitive collision. Far rooms stop rendering/simulating while their floor and boundary collision stay valid. Normal encounters cap at **six active enemies**; the boss encounter suspends them. Two environmental hazards and four boss warning meshes are reused. Paving and repeated cosmetic detail use MultiMesh batches, and eligible opaque static architecture is conservatively combined by material. Animated water reuses three foam strips; it has no fluid simulation. Emissive decoration does not add realtime point lights. The metrics overlay shows FPS, active foes and draw calls.

## Validation

Current staged results are recorded in [Milestone 5.6 validation](docs/milestone-5.6-validation.md), including the real Search/extraction/restart gate and its resolved save-precision regression. The archived Milestone 5.5 pass recorded **3,025 assertions across 33 engine invocations**. Counts from repeated checkpoint runs are not added together.

Run these desktop/cloud checks from the repository root; substitute `godot` if that is your installed executable. Isolate test user data from normal play:

```sh
export XDG_DATA_HOME=/tmp/vaultbound-checks/data
export XDG_CONFIG_HOME=/tmp/vaultbound-checks/config
export XDG_CACHE_HOME=/tmp/vaultbound-checks/cache
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/smoke_test.gd
godot4 --headless --path . --script res://tests/combat_test.gd
godot4 --headless --path . --script res://tests/ui_layout_test.gd
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
```

Import first to index global GDScript classes. Assertions exit nonzero on failure; inspect logs for runtime errors too. Restricted Linux runners may need writable `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`. Android SDK/build-tools warnings affect APK export setup, not scene resources.

See [Milestone 5.6 validation](docs/milestone-5.6-validation.md) for current checkpoint results and Android review steps, [Milestone 5.5 validation](docs/milestone-5.5-validation.md) for the archived environment pass, [Milestone 5 validation](docs/milestone-5-validation.md) for the RPG baseline, and [the Android test plan](docs/test-plan.md) for the broader manual checklist. The [Milestone 4 report](docs/milestone-4-validation.md), [Milestone 3 report](docs/milestone-3-validation.md) and [Milestone 2 guide](docs/milestone-2-guide.md) retain the companion, expedition and combat baselines. The original GitHub roadmap is [archived separately](docs/original-github-roadmap.md) and describes future ideas, not shipped functionality.

## Remaining limits

This is a complete expedition loop prototype, not a finished commercial game. Large talent trees, talent respec, additional floors/biomes, expedition resume, arbitrary stairs or multilevel navigation, companion gear/talents and additional classes are outside this milestone. Inventory capacity is forty active slots; the recoverable reserve preserves old saves and is not unlimited storage for new rewards. Companion pathfinding targets the authored flat modular floors; enemy steering remains intended for the open room modules. Characters retain their native low-poly proportions, procedural animation and synthesized sound placeholders. The Tavern interior is an open decorated bar; bridge/stair details stay on the existing flat navigable floor. A simulated wildlife system, detailed character art and new vertical cave navigation are not implemented.

**No physical Android testing is claimed.** Rendered visual review, touchscreen comfort, APK export/signing, audio output, frame pacing, heat and battery use still need device verification. Headless checks establish logic and resource validity; they do not compile shaders on an Android GPU or establish final appearance, game feel or mobile frame rate.

Work is limited to the staged Milestone 5.6 plan and stops after its final review build. Online multiplayer, player-to-player trading, guilds, additional companion classes and later milestones are not implemented.
