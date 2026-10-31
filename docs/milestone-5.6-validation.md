# Milestone 5.6 validation

## Checkpoint 1 — owned loadouts and safe save foundation

Validated on 2026-10-31 using **Godot 4.6.3 stable, Linux headless, Compatibility**. This checkpoint extends the existing Milestone 5.5 game; it does not complete the later Milestone 5.6 catalog, loot, character or UI overhaul stages. The staged scope and preservation rules are recorded in [the implementation plan](milestone-5.6-plan.md).

The checkpoint adds two saved owned weapon assignments, circular primary/secondary HUD controls, active selection, existing family icons, a short weapon presentation cue and a shared 0.32-second switch lock. Sword/shield and staff continue to use the existing actor, attack resources, damage rules, target lock and ability cooldowns. Only the active weapon contributes statistics. Empty slots do not display invented equipment. The original unassigned practice controller remains available.

Version-three profiles add the new equipment fields and active loadout without discarding the original shield or accessory assignments. Existing version-one and version-two saves migrate without resetting currency, equipment instances, modifiers, talents, companions, discoveries, displays or expedition statistics. The first migrated write preserves the exact old bytes as `profile.json.pre-v3.bak`; the verified rotating backup and atomic replacement path remain in use. Failure to preserve the migration backup blocks replacement. Future-version and damaged records remain protected from empty-default overwrite.

### Automated gate

**All 1,990 assertions passed across 28 engine invocations.** Each listed final game-test log was inspected for runtime/script errors, warnings and leaked resources and was clean. Counts include separate-process persistence readers/writers once each; exploratory probes and repeated debugging runs are excluded. This is the checkpoint regression gate, not a claim that every later-stage feature is complete.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `loadout_integration_test.gd`, runtime/read | 78 + 10 | Owned assignment/activation, inactive weapon statistics, models/abilities, switch guards, preserved cooldowns and attack IDs, both-camera joystick/touch use, one-hit damage, failed-save rollback and independent restart |
| `loadout_migration_test.gd`, main/write/read | 50 + 2 + 3 | Exact legacy backup bytes, strict version-three ownership/slots, protected failed writes and separate-process loadout persistence |
| `loadout_ui_test.gd` | 87 | Circular button geometry, icon/selection data, tap/release/cancel/drag behavior and equipment assignment interface |
| `combat_test.gd` | 177 | Shared sword/staff attacks, abilities, health/stamina, enemies, travel and death |
| `character_progression_test.gd` | 69 | Thirty levels, talents, real player statistics, weapon-family gating and prevention of free equipment healing |
| `rpg_integration_test.gd` | 117 | Existing services, trusted economy quotes, player/party equipment, Collection Hall, dungeon rewards, extraction and later wipe |
| `rpg_ui_test.gd` | 62 | Existing mobile menus/confirmations, equipment preview, modal switch recovery and unchanged paused gameplay clocks |
| `smoke_test.gd` | 321 | Every game resource, startup, movement, cameras, touch routing and original portal transitions |
| `expedition_test.gd` | 114 | Generated encounters, awareness, hazards, treasure, boss reward, extraction and later death |
| `rootwarden_test.gd` | 53 | Boss attacks, telegraphs, phase/modifiers, obstruction, hit deduplication and death |
| `visual_integration_test.gd` | 61 | Both cameras/all graphics tiers, portal occlusion, seeds 7/23/81, room visibility, Hall and preserved progression |
| `ui_layout_test.gd` | 247 | Combat geometry, multitouch ownership, cancellation and focus behavior |
| `party_ui_test.gd` | 137 | Tavern recruitment, commands, companion pause, downed/revive touch input |
| `expedition_ui_test.gd` | 19 | Minimap, inventory/results, notices and modal isolation |
| `visual_settings_test.gd` | 54 | Graphics presets, frame targets, separate preferences and touch confirmation |
| `inventory_economy_test.gd` | 114 | Forty-slot inventory, unique instances, recipes, protected ownership, equipment, costs and transaction rejection |
| `loot_persistence_test.gd` | 47 | Existing seeded loot, rarities, atomic saves, backup recovery and precision |
| `party_persistence_test.gd`, main/write/read | 70 + 5 + 8 | Companion migration, progression, extraction-only XP and separate-process recruited roster persistence |
| `save_migration_test.gd`, main/write/read | 42 + 3 + 19 | Original RPG save compatibility, reserves, recovery, enhanced/protected gear, talents, companions, trophies and displayed ownership after restart |
| `persistence_restart_test.gd`, write/read | 8 + 13 | Extracted rewards survive another engine process and subsequent dungeon death |

Tests use disposable `/tmp` profiles and isolated XDG user-data/config/cache directories. The two sequential checkpoint runners recorded **912 assertions in seven invocations** and **144 in eight invocations**, respectively. Save-foundation suites contributed **328 in seven**, and UI suites contributed **606 in six**.

Session evidence paths are `/tmp/vaultbound-56-checkpoint1/results.json`, `/tmp/vaultbound-56-checkpoint1-restart/results.json` and their adjacent suite logs. Additional final logs are `/tmp/vaultbound-m56-{loadout-migration,loadout-write,loadout-read,save_migration_test,inventory_economy_test,loot_persistence_test,party_persistence_test,loadout-ui,ui-layout,party-ui,expedition-ui,visual-settings,rpg-ui}.log`. These are execution-environment records, not files shipped with the game.

The final editor import exited successfully. `/tmp/vaultbound-56-a-final-import.log` contains only the environment's expected editor TCP socket/listener permission messages; it has no GDScript parse errors, missing-resource errors or warnings. Editor socket restrictions do not demonstrate Android export readiness.

### Regression found and resolved

An initial real UI test found that equipping a weapon inside a paused inventory modal started a switch lock which never expired: the player physics process was correctly paused with gameplay. The fix advances only the presentation switch timer from the existing game shell while the modal is open. It does not tick attacks, ability cooldowns, stamina or enemies. The final RPG UI test uses a real cooling ability and verifies its cooldown and stamina remain unchanged while the short switch lock expires and unequip becomes available. The gate passed after this fix; no unresolved critical regression remains in this checkpoint.

Legacy test fixture updates retain the six original occupied assignments while accepting the additional empty schema fields, and wait for the intentional short weapon lock where needed. Invalid ownership, transaction replay, save recovery and protection checks remain enforced. No capacity or combat correctness assertion was relaxed to obtain the passing gate.

### Android review still required

Use the import and controls instructions in [README](../README.md). With a backed-up existing save, verify:

1. Import the root `project.godot` in the Godot Android editor, retain Compatibility and run in landscape. Check the Sanctuary, companions, merchants and portals before entering a dungeon.
2. Secure a sword and staff through the existing game, assign primary/secondary slots in the equipment interface, and confirm their circles show the corresponding icons. Empty slots must not claim an owned weapon.
3. Hold the movement joystick while tapping either weapon circle with another finger, in both camera modes. Check active glow, model changes, ability labels, short cooldown feedback and smooth movement. Cancel a touch, drag off a circle and background/resume the application to check hardware input ownership.
4. Try switching during a charge, block, dodge and attack. The action must remain intact and the switch must be rejected. Switch away and back after a skill to confirm its original cooldown continues and no extra damage appears.
5. Change equipment inside the inventory modal, wait for the brief switch lock, then unequip. Gameplay must stay paused. Close the modal and verify combat resumes normally.
6. Restart with the secondary active and check both owned instances, active family, statistics and unrelated secured progression. For an older save, confirm the exact pre-migration backup exists before the first updated primary replaces it.
7. Complete an expedition with companions, extract, restart and then lose another expedition. Previously secured equipment, recruited companions and display references must remain intact.

**No physical Android device testing, rendered GPU visual inspection, APK export/signing, Android shader validation or measured 30/60 FPS claim is made.** Native family models/icons and procedural animation remain the available art; the switch cue is not a replacement production character rig. Later milestone checkpoints must still deliver and validate their own planned features before the full Milestone 5.6 completion report.
