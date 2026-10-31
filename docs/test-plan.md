# Milestone 4 review checklist

These tests run the persistent game shell, physics, input hub, actor scenes, combat data, modular dungeon, treasure ledger and portal signals. They do not establish device performance or replace real Android multitouch and visual review. Earlier results remain archived in `milestone-1-validation.md` and `validation-report.md`; the expedition baseline is archived in `milestone-3-validation.md`, and current results are in `milestone-4-validation.md`.

## Automated checks

From the project directory, with Godot 4 installed:

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
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --write /tmp/vaultbound-m3-restart/profile.json
godot4 --headless --path . --script res://tests/persistence_restart_test.gd -- --read /tmp/vaultbound-m3-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --write /tmp/vaultbound-m4-roster-restart/profile.json
godot4 --headless --path . --script res://tests/party_persistence_test.gd -- --read /tmp/vaultbound-m4-roster-restart/profile.json
```

Each test exits nonzero on failed assertions and prints its named `CHECKS PASSED` result on success. Also inspect every log for `SCRIPT ERROR`, `ERROR` and `WARNING`: Godot can log a script exception without changing the process exit status. Import first so global script classes and resources are indexed.

In a restricted runner where the default user-data directory is not writable, point `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` at writable temporary directories for the commands. A normal Android editor installation does not need this workaround.

The persistence and expedition fixtures intentionally use isolated `/tmp/` paths on the Linux runner. Run the writer and reader as separate engine invocations in the shown order; the reader checks data created by the previous process. These tests never delete or alter the normal `user://vaultbound/profile.json` save.

### Party suites

- Recruit and dismiss the two starting companions through the saved roster, reject duplicates/unknown identities, preserve the human leader and cap active AI members at two.
- Follow in formation, honor direct commands and share the existing sword/staff simulation without depending on camera mode.
- Validate actual movement through multiple room connections across several generated seeds, obstacle detours, closed/revealed secret passages, hazard avoidance, throttled planning and floor-safe recovery.
- Exercise autonomous Guardian blocking and Mystic cooldown healing, attack assistance, major telegraph reactions and ordinary enemy party targeting.
- Down and revive party members, require reach and line of sight, interrupt channels on damage, enforce finite revive resources/bleedout and end a wiped expedition once.
- Enter and extract with the same party, preserve recruited progression on return and retain secured inventory on a later party wipe.
- Migrate a pre-companion profile without changing gold, items, equipment, discoveries or statistics; verify roster saves and extraction experience through the existing atomic storage boundary.
- Route synthetic party/recruitment/revive touch events through the real overlay, test minimum target geometry and ensure modals do not leak attacks or stale held input.

The test report records which of these checks actually passed. Controlled fixture positioning and damage isolate lifecycle/combat contracts; they do not establish the quality of a human-led full dungeon playthrough.

### Dungeon and expedition suites

- Generate and validate 100 seeds, including deterministic reproduction, every room count from 8–12, connected nonoverlapping grid cells, a guaranteed entrance/boss/extraction route, all 14 module variants and optional secret branches.
- Reject overlapping/disconnected layouts, missing or extra doors, invalid role references and out-of-range route IDs.
- Instantiate all 14 native modules and check authored enemy spawn floors/clearance, open center paths and closed unused doors with the physics server.
- Sample 5,000 deterministic loot rolls across all chest categories; verify five rarities, item categories, weighted data validity and guaranteed boss discovery.
- Verify atomic secured-profile saves, full-precision expedition times, backup recovery, rejected negative data, unsupported versions and preservation of unreadable primary/backup files.
- Exercise Root Slam, Thorn Eruption, Vine Grasp, Guardian's Fury, readable warning windows, recovery, dodge/cover avoidance, one hit per cast, modifiers, deactivation safety, leash limits and boss death.
- Use real chest interactions in a generated run, including one-time receipts, cursed awareness, consumable use, secret discovery and persistent encounter damage/death across room culling.
- Check bounded enemy reinforcements, two pooled hazards, hazard warning/impact/reset and suppression of regular encounters during the boss fight.
- Verify all awareness thresholds, separate warning periods, event gaps, safe-room deferral and prevention of repeated threshold floods.
- Complete the automated progression path through boss reward, save-failure retry, extraction, results, secured equipment selection and a second expedition's death without losing secured possessions.
- Launch a separate engine process to verify extracted gold, items, discoveries and expedition statistics survive restart, followed by another death preserving the bank on disk.
- Verify discovery-only minimap data, inventory/results modal routing, bounded treasure notifications and pack pause/resume without stale held input.

Runtime progression fixtures reposition the player to exercise room activation and inject controlled damage to finish the boss. They establish system behavior, not a human-completed balanced expedition or a frame-rate result.

### Regression suite

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

### Combat suite

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

### UI suite

- Control geometry at three landscape canvas sizes.
- Held heavy/defense input, final-owner release with multiple fingers, cancellation and reset.
- Focus and Android pause/resume changes, disabled input, late releases and keyboard action routing.
- Dynamic weapon/ability labels and HUD feedback.

The touch suites inject Godot input events into the actual router. They verify logical ownership and cancellation, not touchscreen hardware delivery, platform gesture handling or physical touch target comfort.

## Required manual Android review

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

Android device testing, APK export/signing, GPU visual review and device performance measurement remain pending. Multiplayer networking is outside this milestone; local attack IDs and a shared damage service do not implement multiplayer.
