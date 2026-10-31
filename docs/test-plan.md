# Milestone 1 review checklist

The automated smoke test exercises the actual persistent game shell, physics, input hub, player, cameras, practice targets and portal signals. It does not establish device performance or replace a real multitouch playtest.

From the project directory, with Godot 4 installed:

```sh
godot4 --headless --editor --path . --quit
godot4 --headless --path . --script res://tests/smoke_test.gd
```

The second command exits nonzero on failed assertions and prints `VAULTBOUND CHECKS PASSED` on success. Also inspect both command logs for parser, resource and runtime errors. The editor import must precede the test so global script classes are indexed.

## Automated coverage

- Every game scene and GDScript resource loads.
- Initial Sanctuary load, floor collision and enabled controls.
- Movement before, during and after switching to the elevated view.
- One player instance and unchanged health/stamina during camera toggles.
- Shared attack damage, stamina costs, cooldown, target persistence, dodge and brief invulnerability.
- Camera retraction and collision volume while transitioning beside a deliberate blocker.
- Virtual input reset and disabled-input suppression.
- Application focus loss/resume clears virtual movement; placeholder skill feedback does not spend resources.
- Synthetic three-finger joystick, camera swipe and attack input; independent release, touch cancellation and shared reset. This checks the router logic, not Android hardware delivery.
- Invalid destination rejection without losing the current world.
- Portal interaction, repeated-interaction guard, dungeon loading, valid arrival, health preservation and return to Sanctuary.
- Stale scene targets/interactables do not accumulate after travel.
- Lethal damage recovers through the guarded scene transition system.

## Required manual review on Android

Use the Godot Android editor in landscape, then run the project. Device model, Android version, Godot version, renderer and observed frame rate should be recorded with the review.

- Hold the movement joystick while swiping the right side and tapping attack with another finger. Each finger must retain its own role.
- Release fingers in different orders. No movement or look input should remain held.
- Toggle the camera repeatedly while walking, attacking and dodging. Resources, target highlight and ongoing actions should remain consistent.
- Walk along the outside walls, pillars, planters and dungeon cover. Rotate the third-person camera into them, then toggle views; verify the camera stays in front of walls and the player remains readable.
- Enter the blue Sanctuary portal using Interact, then return through the dungeon archway. Tap Interact repeatedly during fade; only one transition should occur.
- Confirm skill buttons clearly communicate that they are placeholders, and the minimap is labeled as a schematic.
- Background and resume the app while holding the joystick. Verify touches are released and control resumes normally.
- Test narrow and wide landscape screens, navigation bars, cutouts and touch target sizes. Verify health, stamina, camera indicator and all controls remain legible.
- Play for ten minutes, including several round trips, checking frame pacing, heat and battery behavior. Mobile performance settings are a starting budget, not measured device results.

No Android device, APK signing or device performance result is implied by the headless tests. Multiplayer is outside this milestone and has no implementation.
