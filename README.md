# Vaultbound: The Shifting Depths

**Milestone 4 — Intelligent AI Adventurers.** A Godot 4 / GDScript-only, offline party expedition prototype for Android landscape. Recruit a Guardian and Mystic in the Sanctuary, lead them through a seeded 8–12-room underground jungle, fight monsters and the Rootwarden, revive fallen allies, and extract to secure your rewards.

The Sanctuary, practice dungeon and arena, player movement, sword/shield and staff combat, touch controls, both smoothly switchable cameras, procedural dungeons, treasure, boss encounters and secured progression from Milestones 1–3 remain available. `project.godot` stays at the repository root. The active party supports one human leader and up to two local AI companions. No online multiplayer, additional biomes or marketplace are implemented.

## Import and play on Android

1. Install the official **Godot Android editor**, standard GDScript edition. **Godot 4.6.3** is the validated engine; the project targets Godot 4.4+ features.
2. Download/extract the full repository or source ZIP into storage the editor can access. Grant the editor file access if requested.
3. Choose **Import**, select the root `project.godot`, then open it with the **Compatibility** renderer. Wait for resource import to finish.
4. Keep the device in landscape and choose **Run Project**. The main scene is `scenes/main.tscn`.
5. In Sanctuary, visit the **Tavern on the west side** and tap **USE** to recruit the Guardian and Mystic. Recruitment is optional; solo play remains available. The **east-facing Rootbound Abyss archway** begins an expedition, and the northern arch still leads to the original practice dungeon and arena.
6. Open the entrance supply chest, follow the discovered-room minimap, explore branches, and approach whispering vine walls to reveal hidden rooms. Walk through open doorways; rooms connect continuously.
7. Defeat the Rootwarden, claim its reward chest, then find the **extraction spring in the connected chamber beyond the boss**. Tap **USE** to save rewards and return to the Sanctuary.
8. Review the results screen and open **PACK → SECURED** to inspect saved items. Collected gear can select an existing weapon style; tonics restore health.

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
| Switch base weapon | Weapon panel | R |
| Interact / chest / extraction | USE nearby | F |
| Inventory | PACK | I |
| Healing consumable | TONIC | H |
| Performance display | METRICS inside PACK | P |
| Party commands | PARTY | B |
| Recruit / dismiss | USE at the Sanctuary Tavern | F at the Tavern |
| Revive nearby ally | REVIVE prompt | Party menu / interact |

Sword/shield retains its three-hit combo, charged heavy, Shield Bash and Cleave. Staff retains bolts, charged splash, Arcane Burst and Frost Nova. Both use identical damage, costs, cooldowns, range and targeting in either camera view. Charge, block and joystick touches cancel safely on focus loss, Android pause, travel and modal opening.

PACK, party/recruitment menus and expedition results pause the local player, companions and active world. Closing them restores input without resuming stale held buttons. Basic movement is grounded; jumping is intentionally omitted. The elevated tactical camera uses a narrow perspective lens for a continuous transition rather than a strict orthographic projection.

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

Common, Reinforced, Ancient and Cursed chests share one chest implementation. Item definitions and weighted `.tres` loot tables provide gold, crafting materials, equipment, healing consumables and collectibles across **Common, Uncommon, Rare, Epic and Legendary** rarities. The boss chest has its own table and a guaranteed **Heart of the Rootwarden** collectible. Chests can be claimed only once per expedition.

- **Unsecured pack:** loot collected this run. It is not saved until extraction. Tonics in the pack can be consumed immediately.
- **Secured inventory:** extracted gold/items/discoveries. Owned gear can select its sword or staff style; rarity does not currently add equipment stat bonuses. Both original base weapons remain available.
- **Successful extraction:** requires boss defeat. Gold, item quantities, discoveries, completion/kill/time statistics and seed are written and verified before travel occurs.
- **Death or retreat:** returns to the Sanctuary and discards only the current unsecured bag. Previously secured equipment, items and gold remain. A results screen explains the outcome.
- **Closing the app during a run:** abandons its in-memory unsecured loot. Mid-expedition resume is not implemented. Previously secured progress loads on restart.

The offline profile lives at `user://vaultbound/profile.json` with a previous valid `.bak`. Writes use a temporary file, validation/read-back and atomic rename. A failed extraction write leaves the run and its loot available for retry. Corrupt or newer unsupported saves are preserved; a valid backup is recovered where possible, otherwise progression becomes read-only with an on-screen warning. Never delete the profile to fix an import problem. Android stores `user://` in app-specific storage; its exact path depends on whether you run from the editor or an exported app.

The profile service and local combat command boundary are separated from presentation for later server-authoritative work. This does **not** implement authentication, networking, replication, anti-cheat or cloud saves.

## Rootwarden and awareness

The Rootwarden uses Root Slam, sequential Thorn Eruption patches and Vine Grasp (a brief interruption on a landed hit). Below 40% health it enters **Guardian's Fury** through a safe phase transition and gains a faster pattern with a radial burst. Ground warnings remain at least 0.9 seconds, attack windows share unique IDs, and sequential patches cannot stack multiple hits from the same cast. Dodge, shield/ward, range and wall obstruction apply normally.

A seed selects no modifier or one of two optional modifiers: **Thick Bark** increases durability with longer recovery; **Blooming Thorns** adds a spaced thorn patch with a longer warning. Modifiers never combine. The boss has a bounded arena leash and rejects out-of-arena damage. Its health bar, phase, modifier and attack telegraphs are visible; death cancels all pending attacks and unlocks the spring.

Awareness grows from kills, treasure value, cursed chests and time. Configurable thresholds (25 / 50 / 75 by default) warn before patrols, environmental roots or an elite event. Only one warning/event can be active at a time; queued thresholds wait through a minimum event gap. Safe rooms suppress encounters; boss proximity suspends regular enemies and cancels environmental hazards. Leaving a room cancels its hazards rather than resuming a nearly completed trap on re-entry.

## Project organization and mobile budget

- `scripts/systems/`: persistent game shell, one input vocabulary and transitions.
- `scripts/player/`, `scripts/combat/`, `resources/weapons/`: preserved movement and combat components.
- `scripts/enemies/`, `resources/enemies/`: three original archetypes and Rootwarden data/AI.
- `scripts/party/`, `resources/companions/`, `scenes/party/`: party lifecycle, AI decisions, navigation, companion data and Tavern recruitment.
- `scenes/rooms/`, `scenes/props/`, `resources/materials/`: authored reusable Abyss geometry and materials.
- `scripts/expedition/`: pure layout generation, room activation, encounters, pooled hazards, awareness, secrets and extraction.
- `scripts/progression/`, `resources/items/`, `resources/loot/`: item definitions, weighted loot, transient run ledger and secured local profile.
- `scripts/ui/`: original touch controls plus discovery map, inventory, results and expedition HUD.
- `tests/`, `docs/`: automated checks, archived milestone information and Android manual review.

The level uses one shared environment and shadow-casting directional light, simple shared materials and native primitive collision. Far rooms stop rendering/simulating while their floor and boundary collision stay valid. Normal encounters cap at **six active enemies**; the boss encounter suspends them. Two environmental hazards and four boss warning meshes are reused. Paving uses MultiMesh draws; animated water uses three reused foam strips rather than fluid or particle simulation. Emissive decoration does not add realtime point lights. The metrics overlay shows FPS, active foes and draw calls.

## Validation

Run from the repository root; substitute `godot` if that is your installed executable:

```sh
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
```

The persistence restart fixture uses **two separate engine processes**, with a disposable `/tmp` path on desktop/cloud (not an Android shell instruction):

```sh
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --write /tmp/vaultbound-restart/profile.json
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --read /tmp/vaultbound-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --write /tmp/vaultbound-roster-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --read /tmp/vaultbound-roster-restart/profile.json
```

Import first to index global GDScript classes. Assertions exit nonzero on failure; inspect logs for runtime errors too. Restricted Linux runners may need writable `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`. Android SDK/build-tools warnings affect APK export setup, not scene resources.

See [Milestone 4 validation](docs/milestone-4-validation.md) for current observed results and [Milestone 3 validation](docs/milestone-3-validation.md) for the archived expedition baseline and [the Android test plan](docs/test-plan.md) for the manual checklist. The [Milestone 2 guide](docs/milestone-2-guide.md) retains earlier combat details. The original GitHub roadmap is [archived separately](docs/original-github-roadmap.md) and describes future ideas, not shipped functionality.

## Remaining limits

This is a complete expedition loop prototype, not a finished commercial game. Equipment stat affixes, crafting, additional floors/biomes, expedition resume, arbitrary stairs or multilevel navigation, companion gear/talents and additional classes are outside this milestone. Companion pathfinding targets the authored flat modular floors; enemy steering remains intended for the open room modules. Geometry, procedural character animation and synthesized sounds are stylized placeholders.

**No physical Android testing is claimed.** Rendered visual review, touchscreen comfort, APK export/signing, audio output, frame pacing, heat and battery use still need device verification. Headless checks establish logic and resource validity, not final game feel or a measured mobile frame rate.

Work stops after Milestone 4 for review. Online multiplayer, additional companion classes and later milestones are not implemented.
