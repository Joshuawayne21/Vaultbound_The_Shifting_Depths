# Milestone 2 review checklist

These tests run the actual persistent game shell, physics, input hub, actor scenes, combat data, projectiles and portal signals. They do not establish device performance or replace real Android multitouch and visual review. The milestone 1 results remain archived in `milestone-1-validation.md`.

## Automated checks

From the project directory, with Godot 4 installed:

```sh
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/smoke_test.gd
godot4 --headless --path . --script res://tests/combat_test.gd
godot4 --headless --path . --script res://tests/ui_layout_test.gd
```

Each test exits nonzero on failed assertions and prints its named `CHECKS PASSED` result on success. Also inspect every log for `SCRIPT ERROR`, `ERROR` and `WARNING`: Godot can log a script exception without changing the process exit status. Import first so global script classes and resources are indexed.

In a restricted runner where the default user-data directory is not writable, point `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` at writable temporary directories for the commands. A normal Android editor installation does not need this workaround.

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

Android device testing, APK export/signing, GPU visual review and device performance measurement remain pending. Multiplayer networking is outside this milestone; local attack IDs and a shared damage service do not implement multiplayer.
