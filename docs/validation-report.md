# Milestone 2 validation

Validation uses Godot **4.6.3** in the cloud workspace. The milestone 1 baseline is preserved in `milestone-1-validation.md`.

## Automated result

All **546 assertions passed** across three reusable suites. Each process exited successfully; final suite logs contain no GDScript errors, runtime errors or warnings. Editor resource import and a 180-frame main-scene startup also completed successfully; startup logged no errors or warnings.

| Suite | Checks passed | Purpose |
| --- | ---: | --- |
| `tests/smoke_test.gd` | 122 | Resource, movement, camera, touch routing and portal regression |
| `tests/combat_test.gd` | 177 | Weapons, combat timing, defense, abilities, projectiles, enemy AI, arena reset and death recovery |
| `tests/ui_layout_test.gd` | 247 | Landscape control geometry and held/canceled input |

The combat review found and fixed a stale-reference boundary in target validation: a freed selected target could previously fail a typed helper call before `is_instance_valid` ran. A regression now frees a selected target and verifies safe combat/HUD cleanup. Cleave's per-target line-of-sight validation, charged projectile splash obstruction, safe offset projectile muzzles, level-owned visual effects, opaque portal camera obstruction and paused held-input cancellation also have focused regressions.

## Limits

- Headless tests exercise scene loading, physics, state transitions and synthetic input. They do not verify rendered appearance or physical Android gestures.
- No Android hardware, APK signing/export or device performance measurement was available. Android SDK build-tools are absent in this runner.
- The cloud runner denies a local editor debug listener. This environment warning is separate from game parser/resource/runtime failures.
- GPU visual review remains pending: the cloud socket policy prevents starting a local virtual display. No APK export or signing was attempted.
- Multiplayer has not been implemented or tested. Combat command boundaries and local attack IDs are only a foundation for possible later work.

Use `docs/test-plan.md` for the manual Android review before beginning another milestone.
