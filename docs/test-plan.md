# Milestone 5.6 review checklist and archived regressions

Use the [Milestone 5.6 Android checklist](milestone-5.6-android.md) for current manual acceptance and the [README validation commands](../README.md#validation) for the complete current automated suite, including new checkpoint tests and separate-process persistence runs. [Milestone 5.6 validation](milestone-5.6-validation.md) records completed gates; the [implementation plan](milestone-5.6-plan.md) and [catalog batches](catalog-batches.md) distinguish delivered work from pending targets. No Android device, rendered GPU or sustained frame-rate result is implied by a headless pass.

The sections below preserve the Milestone 1–5.5 test descriptions and command inventory as historical regression evidence. References to exactly thirty definitions, six equipment slots, eight recipes, +5-only upgrades, PACK or a boss reliquary describe those earlier builds. They are not current Milestone 5.6 acceptance criteria: current saves are version four, Equipment exposes eleven slots, Mythic/Ancient Relic upgrades can reach +10, and the Rootwarden reward uses a searchable grand cache. Use the current catalog/report for definition and recipe counts; do not weaken present tests to match archived counts.

These tests exercise the persistent game shell, physics, input hub, actor scenes, combat data, modular dungeon, treasure ledger and portal signals. They do not establish device performance or replace physical Android multitouch and visual review. Archived visual-pass results are in [Milestone 5.5 validation](milestone-5.5-validation.md), with structural budgets in [its performance report](milestone-5.5-performance.md). The RPG baseline remains in [Milestone 5 validation](milestone-5-validation.md). Earlier results remain archived in `milestone-1-validation.md`, `validation-report.md`, `milestone-3-validation.md` and `milestone-4-validation.md`.

## Archived automated command inventory — through Milestone 5.5

The original commands are retained below. This is not the complete Milestone 5.6 gate; use the current README command list linked above when validating the latest source. Test implementations may have evolved since these historical scope descriptions were written.

From the project directory, with Godot 4.6.3 installed:

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
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --write /tmp/vaultbound-m3-restart/profile.json
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --read /tmp/vaultbound-m3-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --write /tmp/vaultbound-m4-roster-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --read /tmp/vaultbound-m4-roster-restart/profile.json
godot4 --headless --path . --script res://tests/save_migration_test.gd -- --write /tmp/vaultbound-m5-rpg-restart/profile.json
godot4 --headless --path . --script res://tests/save_migration_test.gd -- --read /tmp/vaultbound-m5-rpg-restart/profile.json
```

Each test exits nonzero on failed assertions and prints a named success summary (usually `CHECKS PASSED`; the expedition UI suite prints its passed/failure counts). Also inspect every log for `SCRIPT ERROR`, `ERROR` and `WARNING`: Godot can log a script exception without changing the process exit status. Import first so global script classes and resources are indexed.

In a restricted runner where the default user-data directory is not writable, point `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` at writable temporary directories for the commands. A normal Android editor installation does not need this workaround.

The persistence and expedition fixtures intentionally use isolated `/tmp/` paths on the Linux runner. Run the writer and reader as separate engine invocations in the shown order; the reader checks data created by the previous process. These tests never delete or alter the normal `user://vaultbound/profile.json` save.

### Archived Milestone 5.5 visual-pass scope

- Load shared materials, original procedural textures, three environment presets and bounded ambient/water resources. Verify immutable material sharing and independent environments.
- Exercise all fourteen cosmetic room motifs, deterministic separate art seeds, bounded batches, quality density and unchanged connectors/collision. Check real generated layouts with the existing 100-seed structural suite.
- Validate impact budgets and cleanup, presentation-only sword/spell/dodge feedback and accurate Rootwarden warning footprints. Retain the full focused combat/boss behavior suites.
- Apply Low/Medium/High and 30/60 targets, save/reload independent preferences, reject invalid/read-only writes, apply settings to newly loaded scenes and confirm progression remains unchanged.
- Route synthetic graphics-menu taps, cancellation and simultaneous fingers through the existing modal input owner at three landscape sizes.
- Sweep the real camera around Sanctuary services/heart/portal veils, generated entrances for seeds 7/23/81, and the Hall, in both perspectives and all quality tiers. Preserve room visibility, discovery and return travel.
- Validate conservative static architecture batching: geometry/UVs/normals and collision identities/transforms stay unchanged; dynamic/shader/display geometry and nonuniform/reflected transforms remain excluded.

These are logical and structural checks. The headless backend does not validate GPU shader compilation, rendered fog/alpha sorting, lighting exposure or sustained mobile performance.

### Archived Milestone 5 RPG scope

- Load exactly thirty item definitions and all seven rarities with usable icons, models, stat data, stack limits, acquisition paths and the original twelve stable IDs.
- Validate forty-slot capacity, bounded stacks, unique equipment identities, deterministic rolled modifiers, valid quantities and protection flags.
- Migrate complete version-one saves without rewriting their original bytes on load; preserve counts, equipped ownership, companions, discoveries and statistics, including huge/unknown legacy reserves.
- Reject incomplete version-two sections, duplicate IDs, forged references, inconsistent aggregate counts, invalid enhancement/condition, XP/level mismatch and overspent talents. Recover a valid backup rather than replacing damaged progress with empty defaults.
- Exercise all six equipment slots, actual player statistics, both existing weapon families and equipment comparison; verify unequip keeps ownership and repeated equip/unequip cannot heal.
- Check every character level threshold through thirty, talent budgets/caps, modest bonuses and a separate future normalization policy without claiming online PvP.
- Use real Sanctuary merchant/workbench interactions for purchases, protected sales, appraisal, repair, salvage, deterministic upgrades and crafting. Check exact costs, stock limits, capacity and save failure protection.
- Confirm stale or repeated transaction IDs and simultaneous touchscreen confirmation fingers cannot duplicate purchases or crafts. Caller-edited price/quantity fields cannot change a previously issued local quote.
- Use all eight configured recipes and verify each consumes obtainable materials and creates only its specified result; test upgrades through +5.
- Enter the Collection Hall with the same party, validate eight equipment stands/four relic pedestals, Rootwarden trophy and journals, assign an owned instance without copying it, and reconstruct the same exhibit on return/restart.
- Collect a real generated chest, extract accepted loot/character XP/monster discovery, then wipe a later party without erasing secured gear, talent allocations, displays or companion progression.
- Route scrolling, canceled gestures, filters/sorts, item selection, character/equipment tabs, buying/crafting confirmations and Hall selection through the real touch overlay. Check three landscape canvases, hidden-preview shutdown and both actual journal lecterns; reject display changes from journal-only service access.
- Run separate engine writer/reader processes to verify enhanced/locked/favorite equipment, condition, modifiers, talents, active companions, journal/trophy state and display assignments remain loaded in the actual player/Hall scenes.

### Archived Milestone 4 party scope

- Recruit and dismiss the two starting companions through the saved roster, reject duplicates/unknown identities, preserve the human leader and cap active AI members at two.
- Follow in formation, honor direct commands and share the existing sword/staff simulation without depending on camera mode.
- Validate actual movement through multiple room connections across several generated seeds, obstacle detours, closed/revealed secret passages, hazard avoidance, throttled planning and floor-safe recovery.
- Exercise autonomous Guardian blocking and Mystic cooldown healing, attack assistance, major telegraph reactions and ordinary enemy party targeting.
- Down and revive party members, require reach and line of sight, interrupt channels on damage, enforce finite revive resources/bleedout and end a wiped expedition once.
- Enter and extract with the same party, preserve recruited progression on return and retain secured inventory on a later party wipe.
- Migrate a pre-companion profile without changing gold, items, equipment, discoveries or statistics; verify roster saves and extraction experience through the existing atomic storage boundary.
- Route synthetic party/recruitment/revive touch events through the real overlay, test minimum target geometry and ensure modals do not leak attacks or stale held input.

The test report records which of these checks actually passed. Controlled fixture positioning and damage isolate lifecycle/combat contracts; they do not establish the quality of a human-led full dungeon playthrough.

### Archived Milestone 3 dungeon and expedition scope

- Generate and validate 100 seeds, including deterministic reproduction, every room count from 8–12, connected nonoverlapping grid cells, a guaranteed entrance/boss/extraction route, all 14 module variants and optional secret branches.
- Reject overlapping/disconnected layouts, missing or extra doors, invalid role references and out-of-range route IDs.
- Instantiate all 14 native modules and check authored enemy spawn floors/clearance, open center paths and closed unused doors with the physics server.
- Sample 5,000 deterministic loot rolls across all chest categories; verify all seven rarities, item categories, weighted data validity and guaranteed boss discovery.
- Verify atomic secured-profile saves, full-precision expedition times, backup recovery, rejected negative data, unsupported versions and preservation of unreadable primary/backup files.
- Exercise Root Slam, Thorn Eruption, Vine Grasp, Guardian's Fury, readable warning windows, recovery, dodge/cover avoidance, one hit per cast, modifiers, deactivation safety, leash limits and boss death.
- Use real chest interactions in a generated run, including one-time receipts, cursed awareness, consumable use, secret discovery and persistent encounter damage/death across room culling.
- Check bounded enemy reinforcements, two pooled hazards, hazard warning/impact/reset and suppression of regular encounters during the boss fight.
- Verify all awareness thresholds, separate warning periods, event gaps, safe-room deferral and prevention of repeated threshold floods.
- Complete the automated progression path through boss reward, save-failure retry, extraction, results, secured equipment selection and a second expedition's death without losing secured possessions.
- Launch a separate engine process to verify extracted gold, items, discoveries and expedition statistics survive restart, followed by another death preserving the bank on disk.
- Verify discovery-only minimap data, inventory/results modal routing, bounded treasure notifications and pack pause/resume without stale held input.

Runtime progression fixtures reposition the player to exercise room activation and inject controlled damage to finish the boss. They establish system behavior, not a human-completed balanced expedition or a frame-rate result.

### Archived core regression scope

- Every game scene, script and data resource loads.
- Startup Sanctuary, valid floor collision and enabled controls.
- Movement before, during and after smooth camera transitions on one persistent player.
- Camera toggles preserve resources, attack identity, targeting and dodge state.
- Camera sphere retraction beside a deliberate obstruction, including a mode transition.
- Opaque portal veils retract the camera without blocking player movement, including at the dungeon arrival point.
- Synthetic simultaneous joystick, camera swipe and primary attack; independent releases and touch cancellation.
- Input disable/reset and application focus loss/resume clear virtual movement.
- Invalid destinations keep the current playable world.
- Sanctuary/dungeon portal round trip; repeated interaction cannot duplicate the level; health is preserved and stale scene targets are cleared.

### Archived Milestone 2 combat scope

- Weapon/attack/enemy data contracts and all three sword combo stages.
- Windup, active damage, recovery, stamina costs and unique attack IDs.
- Bounded combo buffering, explicit target lock and dodge cancellation of a pending hit.
- Sword charged heavy damage; directional shield reduction, stamina drain and guard break.
- Shield Bash cooldown, cooldown persistence across weapon swaps, and multi-target Cleave with wall obstruction.
- Staff projectile travel, single-impact cleanup, thin-wall collision, charged damage and splash obstruction.
- Offset projectile muzzles are kept on the source side of walls, including tangential shots.
- Arcane Burst area damage and impact-center visibility; Frost Nova damage, wall visibility, enemy stagger and slow expiration.
- Staff omnidirectional ward, exhaustion, regeneration, healing bounds and dodge invulnerability.
- Damage deduplication, rejected invalid hit commands, and safe cleanup of a freed selected target.
- Skeleton, archer and golem detection, wall visibility, telegraph, attack, recovery, damage, camera independence, leash return, strong stagger and death.
- Dungeon/arena portal round trip, exactly three enemy archetypes, effect/projectile/enemy cleanup, rest-station encounter reset, and lethal player damage returning safely to Sanctuary.

### Archived core UI scope

- Control geometry at three landscape canvas sizes.
- Held heavy/defense input, final-owner release with multiple fingers, cancellation and reset.
- Focus and Android pause/resume changes, disabled input, late releases and keyboard action routing.
- Dynamic weapon/ability labels and HUD feedback.

The touch suites inject Godot input events into the actual router. They verify logical ownership and cancellation, not touchscreen hardware delivery, platform gesture handling or physical touch target comfort.

## Archived manual Android review — core, expedition and party

Retain these earlier scenarios as regression coverage, using the current controls and acceptance criteria in the Milestone 5.6 guide above. Their original terminology is preserved; listing a scenario does not claim it was performed on hardware.

Run in the Godot Android editor in landscape. Record device model, Android version, Godot version, renderer and observed frame rate with the review.

1. In Sanctuary, walk while swiping the right side and striking the practice sentinel. Toggle camera while moving, during each combo stage, during a charged heavy, during block and during dodge. Verify no state resets or duplicate damage.
2. Try both weapons. Hold and release the heavy button; cancel a held action by backgrounding the app. Confirm resume does not release an unwanted attack or leave defense held.
3. Test at least three simultaneous fingers. Release fingers in different orders, slide held fingers off their buttons and use two fingers on one held control. Only the final release should end that held action.
4. Deplete stamina through attacks and defense. Verify action rejection, delayed regeneration, guard break and readable feedback. Confirm skill cooldown indicators match availability and survive weapon switching.
5. Enter the dungeon and the combat arena. Test sword combos, Shield Bash, Cleave, staff bolts, charged splash, Arcane Burst and Frost Nova against all three enemy types in both camera views.
6. Observe each enemy's idle/patrol, approach, telegraph, attack, recovery, damage reaction and death. Dodge the golem slam and move behind cover during archer shots. Test that attacks and spells do not damage through cover.
7. Move beyond an enemy's leash and watch it return. Test the arena recovery/reset interaction and verify the room can be replayed. Allow player health to reach zero; confirm safe Sanctuary recovery.
8. Walk beside walls, columns, planters and cover while rotating or changing cameras. Verify the camera remains outside geometry and the character, telegraphs and targets stay readable.
9. Use the portals repeatedly, including rapid repeated taps during the fade. Confirm one active room, no stale projectiles, and no held input after travel.
10. Test wide and narrow landscape displays, cutouts and navigation bars. Review HUD overlap, text legibility, action button comfort, animation clarity, effect visibility and sound volume.
11. Play for ten minutes with several arena resets and round trips. Record frame pacing, heat and battery behavior. Mobile settings are a starting budget, not measured performance results.

Then review the complete Rootbound Abyss expedition:

1. Enter the new Abyss portal from Sanctuary and record the seed shown on screen. To reproduce it, set the main scene's `debug_expedition_seed` in the inspector before running. Confirm the original dungeon and combat arena routes still work.
2. Follow the generated route in each camera perspective. Inspect root arches, mushrooms, flowers, temple pieces, crystals, stream/waterfall animation and mist on the actual renderer. Watch for visual seams, occlusion, doorway collisions and camera clipping.
3. Explore optional branches and reveal a whispering-root passage. Confirm the map reveals visited rooms and does not disclose undiscovered secrets. Test backtracking after enemies have been wounded or defeated.
4. Open common, reinforced, ancient and cursed chests across repeated seeds. Confirm rewards enter the unsecured bag, duplicate taps do not repeat rewards, and curse/value messages match awareness changes.
5. Open the pack while moving, charging or guarding. Confirm gameplay pauses, equipment and consumables are readable, only secured equipment can be selected, and closing the pack does not release an unintended attack.
6. Reach each awareness warning, move out of marked hazard ground and enter a safe room during a warning. Verify warning clarity, manageable patrol density and no ordinary encounter stacking during Rootwarden combat.
7. Fight the Rootwarden normally with both weapons and cameras. Confirm each ground warning is readable, Vine Grasp can be avoided, Fury appears below 40% health, modifiers remain fair, and defeat cancels pending attacks.
8. Claim the boss reliquary and interact with extraction. Check results, secured gold, item quantities, discovery and statistics. Close and restart the Android editor/game; inspect the secured pack again.
9. Start another run, collect more loot, then die. Confirm only the current unsecured loot is lost, secured gear remains equipped/owned, and normal Sanctuary controls resume after closing results. Also test retreat and closing the app mid-expedition; the in-memory unsecured bag is not a save.
10. Toggle the metrics display and record FPS, active enemies and draw calls across 8-room and 12-room expeditions, boss combat, treasure effects and several returns. Review heat, battery use, audio volume and touch comfort over a sustained session. No target FPS is established by cloud headless checks.

Then review the new party expedition on the physical Android device:

1. At the west-side Sanctuary Tavern, recruit Rowan and Lyra. Check names, portraits, role icons and health bars. Dismiss one, re-recruit, close/restart the game and confirm the saved roster and progression remain. Repeat solo and with one companion.
2. Use PARTY while moving, charging and guarding. Confirm the world and companions pause, all five commands are readable, and closing does not replay stale input. Test the menu beside PACK/results, system gestures and Android focus loss.
3. Walk slowly and run through Sanctuary props, the practice vault and arena. Check formation spacing, turns, doorway passage and follower catch-up. Hold Position, leave and return; companions should stay near the assigned positions except for clearly required safety responses. Retreat should bring them toward the leader without pursuing foes.
4. Play at least three different displayed Abyss seeds, recording each seed. Lead companions through several main-route rooms, optional branches, backtracking and a revealed secret passage. Watch for repeated direction oscillation, obstacle trapping, followers entering unrevealed secret rooms or unsafe recovery placement.
5. Lock a visible enemy and issue Attack My Target. Inspect Guardian interception/blocking and Mystic ranged spacing. Stand behind walls to verify neither arrows, spells nor melee hit through cover. Check target death/unreachability feedback and use Retreat to disengage.
6. Injure allies and observe Mystic healing: approach, cast, stamina cost and cooldown. Move out of reach or take damage during a rescue/channel and verify interruption. Companions should react after a delay, occasionally miss and remain subject to ordinary stamina and health rules.
7. Observe companions in thorn traps and each Rootwarden telegraph, including Fury. Check that hazards remain readable under their effects, avoidance does not depend on camera mode, and no regular encounter crowd overwhelms the boss fight.
8. Down the leader with a companion still active. Verify the surviving team keeps fighting/attempts a safe rescue rather than freezing the encounter. Down a companion and approach to revive manually. Repeat revives until the configured limit/bleedout applies; no infinite rescue chain should occur.
9. Allow all active party members to fall. Verify one wipe outcome, loss of only unsecured loot, safe Sanctuary return, restored recruited companions and preservation of banked equipment. Repeat without companions to verify the original solo recovery path.
10. Complete a boss/extraction run with companions. Confirm they return, the roster stays recruited, secured loot belongs to the player, and extraction XP/level/proficiency survives a restart. Test extraction while an ally is downed or separated and confirm the whole roster returns safely.
11. Switch cameras during companion attacks, projectile flight, blocking, healing, dodge and revive. Check that health, target, cooldowns and attack counts do not reset or duplicate. Verify party cards, boss bar, minimap, prompts and commands remain legible in both views.
12. Record FPS/draw calls, frame pacing, heat and battery with two companions and the maximum active enemy encounter, over repeated expeditions and app suspend/resume. Compare against the solo baseline. Cloud tests do not establish an Android frame-rate target.

## Archived Milestone 5 physical Android review

Use the normal Android import/run instructions in README. Back up an existing development profile before manually testing migration; do not delete an old save merely to make a test pass. Record device model, Android/Godot versions, renderer and the dungeon seed used.

1. Open a copy of an existing Milestone 4 profile. Confirm gold, secured items, equipped weapon, companions and expedition history remain. Check the reserve filter if old holdings exceed forty active slots.
2. Open PACK while moving and while a charge is held. Swipe the inventory with one finger; confirm no item action fires during scrolling or cancellation, and gameplay input returns cleanly on close.
3. Select, compare, favorite and lock several rarity tiers. Check tooltip legibility, rarity borders and all six equipment slots in landscape on the device. Review the avatar preview for clipping, reversed weapons, scale or floating armor and compare it to the world character.
4. Equip/unequip health and stamina gear while wounded. Confirm current health never increases from repeated swaps, and sword/staff family changes do not apply incompatible weapon or shield bonuses.
5. At the General Merchant, buy a small stack, cancel another purchase and deliberately tap Confirm with two fingers. Gold, inventory and remaining stock should change only once. Confirm the merchant cannot be used from a distant location or dungeon.
6. At the Equipment Trader, buy and sell an unprotected spare. Try selling a locked, favorite, worn or displayed item; it should remain owned. Complete an expedition and verify stock rotation changes through that controlled trigger, not after changing the device clock.
7. At the Blacksmith, preview/confirm upgrades through +5, repair worn gear, salvage an expendable item and craft a weapon, tonic and utility item. Check ingredient/gold totals and the disabled/rejected state when requirements are missing. Repeat a confirmation touch and verify no duplicate result.
8. Obtain a sealed artifact and visit the Relic Appraiser. Confirm unknown properties stay hidden until the quoted fee is paid, then verify the same item can be equipped without a second appraisal charge.
9. Earn character XP through extraction, allocate a talent point after reviewing its effect, restart the game and confirm level/XP/spent points remain. Review level-up feedback and all three branches for readable requirements.
10. Visit the Hall. Inspect warm lighting, stone/gold materials, crystals and camera obstruction in both perspectives. Assign several equipment stands/relic pedestals, clear one, revisit and restart. Inventory quantities and instance IDs must not change from displaying an item.
11. Check item and monster journal filters and the Rootwarden trophy after a successful expedition. Confirm downed/separated companions still return through extraction and can accompany the Hall visit.
12. Fill inventory near capacity and open a dungeon chest. If its full reward cannot fit, the chest must remain unclaimed and existing belongings unchanged. Extract valid loot, then lose a later expedition and verify secured equipment, enhancements, talents, displays and companions remain.
13. Background/resume the editor during inventory scrolling, purchase confirmation and character preview. Check that no stale release buys or crafts an item. Review cutouts, system gestures, frame pacing, touch latency, sound, heat and battery use on the physical device.

No physical Android result is claimed by the headless suites. The RPG save is local development/offline data; server-side persistence and validation remain required before online play.

Android device testing, APK export/signing, GPU visual review and device performance measurement remain pending. Multiplayer networking is outside this milestone; local attack IDs and a shared damage service do not implement multiplayer.

## Archived Milestone 5.5 physical Android visual review

Use Godot 4.6.3 with Compatibility. Preserve a backup of the existing profile and record the device model, Android version, screen resolution, graphics tier, FPS target, seed and party composition. The baseline and report contain structural counts, not device FPS measurements.

1. Import the full source, run from the root main scene and verify no missing textures/materials or shader errors in the Android debugger. Confirm existing inventory, gold, equipment, talents, discoveries, displays and recruited companions remain loaded.
2. Start at Medium / 30 FPS. Review the crystal heart, bronze/slate edges, wall springs, portal surface, Tavern back bar, each merchant and the forge from the normal third-person arrival. Switch to isometric while moving and inspect the same locations.
3. Orbit close to columns, the heart, Tavern canopy, all four stall canopies, Hall niches and portal veils. Check camera retraction, near-plane clipping, unwanted view obstruction and invisible blockers. Confirm walls/closed doors remain opaque in both views and on every quality tier.
4. Approach every service, recruit/dismiss a companion, buy/sell, craft/upgrade, equip and assign a Hall display. Walk the old arrival and portal lanes; foliage and decorative slabs must not add unreachable areas or new navigation obstacles.
5. Play displayed dungeon seeds 7, 23 and 81, then another seed chosen on-device. Review all available room themes, main-route connectors, optional branches and a secret passage. Verify roots, corner plants and reliefs vary without changing connectivity, chest locations or encounter rules.
6. Examine creek banks, pools and falls from low and elevated angles. Check floating water, exposed seams, z-fighting, reversed flow, stretched highlights and alpha sorting on foam. Confirm floor movement and companion travel remain grounded.
7. Inspect foliage/motes against dark stone and through entrances. Check shimmer, visible batching/culling pops, clipped sway, excessive repetition and effects that reveal enemies or hidden rooms through walls. Low should reduce cosmetic detail while keeping landmarks and gameplay geometry intact.
8. Fight each monster and the Rootwarden with both weapon families and two companions. Switch cameras mid-swing, during projectile flight, dodge and boss windup. Damage/cooldowns must remain unchanged; bright impacts, spell wakes and foliage must not obscure warning boundaries or targets.
9. Open GRAPHICS while moving, charging and after an app resume. Change each tier/target, cancel a touch, swipe over Apply, and confirm with two fingers. Gameplay should pause cleanly, one completed confirmation should apply once, and held input must not resume on close. Restart and verify preferences persist independently of progression.
10. Complete an extraction, view saved rewards, return through the Hall and restart. Lose a later run and verify secured equipment and displays survive. Observe companion corridor movement, rescue and return behavior in the decorated scenes.
11. For performance, run the same route at each tier with two companions and the maximum normal encounter, then the boss. Warm up first; record a sustained 15-minute sample of FPS/frame-time spikes, draw calls, thermal throttling, battery change and memory where device tooling allows. Capture the same viewpoints rather than comparing unrelated encounters. Repeat suspend/resume and several scene transitions to look for growing memory or effects.
12. Evaluate the 30 FPS goal before trying 60 FPS on a capable device. Record failures and reduce quality if needed; do not label a tier/device supported from a short idle measurement. Review touch comfort, system gestures/cutouts, audio and battery separately from frame rate.

No Android hardware measurement, GPU-rendered visual approval or APK export/signing result is claimed until that review is actually performed. Do not begin multiplayer work as part of this visual milestone.
