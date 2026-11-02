# Vaultbound: The Shifting Depths

**Milestone 2 — combat prototype.** A self-contained Godot 4 / GDScript 3D fantasy game foundation for Android landscape. The Sanctuary, dungeon, persistent character, smooth third-person / elevated tactical cameras, multitouch controls, HUD and portal transitions from Milestone 1 are preserved. A connected arena adds two weapon styles and three enemy archetypes. This is a single-player prototype; no multiplayer is implemented.

## Import and run on Android

1. Install the official **Godot Android editor**, standard GDScript edition. Use **Godot 4.4 or newer**; automated validation here uses **4.6.3**.
2. Extract the entire project folder into storage accessible to the editor. Grant the editor file access when requested.
3. In the Project Manager, choose **Import**, select `project.godot`, and open it. Keep the **Compatibility** renderer selected and wait for imports to finish.
4. Turn the device to landscape and choose **Run Project**. The main scene is `scenes/main.tscn`. World geometry and character models are assembled by GDScript at runtime, so their editor trees intentionally remain compact.
5. Move to the Sanctuary's illuminated archway and tap **USE**. In the Sunken Vault, the northern arch leads to **The Proving Grounds**, while the southern arch returns to the Sanctuary.
6. Approach one encounter at a time: skeleton on the left, archer on the right, golem at the far end. The crystal near the entrance heals you, restores stamina and resets encounters through a guarded reload. The entrance arch returns to the dungeon. Death returns you to the Sanctuary with full resources.

A keyboard is optional. On desktop, import the same file and press F5 to run the full game. F6 runs only the selected scene, which may omit the persistent shell.

Testing inside the Android editor requires no APK export. The included Android preset targets ARM64 and requests no internet permission. Exporting an APK separately requires matching Godot export templates, Android SDK/build tools, and your own signing setup. No APK or signing credentials are included; exporting from a desktop Godot installation is the fallback if your Android editor version lacks export support.

## Controls

| Action | Touch | Keyboard / mouse |
| --- | --- | --- |
| Move / strafe | Left joystick | WASD / arrows |
| Look in third person | Swipe open right-side space | Right mouse drag |
| Camera | Camera mode panel | C / Tab |
| Light attack / sword combo | Tap STRIKE; tap again to buffer one next strike | J / left click in world |
| Charged heavy attack | Hold HEAVY, release to strike | Hold / release K |
| Dodge roll | DODGE | Space |
| Shield block / staff ward | Hold BLOCK / WARD | Hold L |
| Ability I / II | Weapon-specific ability buttons | Q / E |
| Target lock / release | LOCK | T |
| Equip other weapon | Weapon panel below health/stamina | R |
| Interact | USE when nearby | F |

The joystick, camera swipe and action fingers have independent ownership. Dragging a held button does not turn it into another action. Canceling a charge, leaving the app, or starting a transition releases held controls without firing a late heavy attack. Switching weapons requires an idle combat state. The camera can switch during any combat action without replacing the player or altering attack IDs, damage, cooldowns or enemy state.

## Combat implemented

| Weapon | Basic / charged | Defense | Abilities |
| --- | --- | --- | --- |
| Sword & Shield | Three-hit combo: 22 / 25 / 35 base damage. Heavy: 34–61.2 base damage over a 0.9 s charge. | Frontal shield reduces damage by 75%; drains stamina while held and on impact. | **Shield Bash:** short-range damage and strong stagger. **Cleave:** wide melee sweep. |
| Magic Staff | Arcane Bolt projectile. Charged Comet scales to 60.8 base direct damage and splashes nearby visible targets. | Ward reduces damage by 50% from any direction, with a higher stamina cost. | **Arcane Burst:** targeted area spell. **Frost Nova:** nearby damage plus a 60% movement slow for 3 s. |

These are tunable prototype values before armor. Each attack has configurable windup, active time, recovery, cooldown, range, movement factor and stamina cost in `resources/weapons/`. Damage commits once at the active edge; repeated input buffers only one subsequent light attack. Costs are paid at attack start, so interruption does not refund stamina. Light attacks allow reduced-speed movement. Dodge can cancel charging, windup and recovery, but not an active strike or hit stun. Default dodge costs 24 stamina, moves for 0.32 s, and grants 0.24 s of invulnerability. Stamina regenerates at 23/s after a short delay; charging, guarding and dodging suppress regeneration.

Target assistance uses facing, distance and world line of sight, independent of camera perspective. Locking retains a target through temporary obstruction but cannot cause damage through walls. Target death, excessive distance and travel clear the lock. Projectiles sweep their movement each physics frame; melee, area spells and enemy attacks also check world obstruction.

| Encounter | Behavior |
| --- | --- |
| Skeleton Warrior | 90 HP; mobile melee pressure with a readable sword windup and recovery. |
| Goblin Archer | 70 HP; retreats at close range and fires dodgeable projectiles at the position selected during windup. |
| Corrupted Golem | 240 HP, 15% armor; slow pursuit and a long, clearly marked radial slam. Strong attacks interrupt its poise. |

All three share idle, patrol, detection, chase, windup, attack, recovery, hit reaction, death and leash-return behavior. Dead enemies remain defeated until the arena reloads. Their detection and leash radii keep the encounters separated. Practice sentinels in the original rooms remain passive and self-restoring.

## Structure and extending the prototype

- `scenes/main.tscn`, `scripts/systems/game.gd`: persistent gameplay shell and guarded level replacement.
- `scripts/systems/input_hub.gd`: one input vocabulary, held actions and reset behavior.
- `scripts/player/`: existing movement facade, procedural avatar animation, collision-aware camera rig.
- `scripts/combat/`: reusable health/stamina components, weapon/attack data, combat state machine, damage dispatch, swept projectiles, lightweight effects and synthesized sound placeholders.
- `resources/weapons/`: editable `.tres` definitions for the two weapons.
- `scripts/enemies/`, `resources/enemies/`, `scenes/enemies/`: shared AI plus three data-driven archetypes and distinct models.
- `scenes/world/`, `scripts/world/`: preserved rooms, portals, reusable architecture, arena and reset station.
- `scripts/ui/`: responsive touch ownership, smooth health/stamina bars, charge, combo, cooldown, weapon and lock feedback.
- `tests/`, `docs/`: regression/combat/UI validation and Android review instructions.

To add an attack, create an `AttackData` resource and reference it from a `WeaponData` resource. To add an enemy, create an `EnemyData` resource and a scene using the shared enemy script. The current weapon selector intentionally exposes only the two prototype weapons. Runtime geometry and animations are project-authored placeholders intended to be replaced independently of gameplay logic.

`CombatRules` is the local damage dispatch boundary. Attack IDs and per-recipient receipts prevent duplicate damage. Simulation does not depend on HUD or camera state. This separation is useful for later server-authoritative work, but IDs are process-local and there is no transport, replication, prediction, authority enforcement or anti-cheat implementation.

## Automated validation

Run from the project directory with Godot installed (use `godot` instead of `godot4` if that is your executable):

```sh
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/smoke_test.gd
godot4 --headless --path . --script res://tests/combat_test.gd
godot4 --headless --path . --script res://tests/ui_layout_test.gd
godot4 --headless --path . --quit-after 180
```

The import indexes global script classes before the tests run. Test failures exit nonzero. Inspect logs for parser, resource and runtime errors as well. On restricted Linux runners, set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to writable temporary directories. Missing Android SDK warnings affect export setup, not project resource validity.

See [the validation report](validation-report.md) for observed results and [the Android test plan](test-plan.md) for manual steps. **No Android device testing is claimed.**

## Known limits and performance budget

- Enemy movement uses collision-aware steering in the controlled arena; it is not a general dungeon pathfinding system.
- The elevated tactical camera uses a narrow perspective lens for continuous transitions, rather than strict orthographic projection.
- The minimap remains a clearly labeled static schematic. There is no inventory, progression, save system, procedural dungeon generation or multiplayer.
- The art, procedural animations, effects and synthesized combat tones are lightweight placeholders. There are no licensed external art/audio dependencies.
- Compatibility rendering, one directional shadow light per level, 1024-pixel shadows, shared simple materials and instanced paving limit cost. No GI, heavy post-processing or simulated particle systems are required.
- APK export/signing, real-device touch delivery, visual readability, audio output, frame pacing, thermal behavior and battery use still require device review. Cloud headless checks establish behavior, not hardware performance or final game feel.

Milestone 1 is preserved in Git history as `7c05fc9`. Work stops at Milestone 2 for combat playtesting and approval; Milestone 3 is not implemented.
