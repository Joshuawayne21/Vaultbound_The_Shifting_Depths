# Vaultbound: The Shifting Depths

A self-contained Godot 4, GDScript-only 3D fantasy prototype for Android landscape. The initial foundation includes a Sanctuary, small dungeon, one persistent character, two smoothly blended camera modes, touch controls, practice combat, and guarded portal transitions. No external assets, plugins, or multiplayer implementation are required.

## Import and play

Use Godot **4.4 or newer**, standard edition (validated with **4.6.3**), with the **Compatibility** renderer. Open `project.godot` and run the main scene (`scenes/main.tscn`, F6 runs only the selected scene; F5 runs the complete game). The world and character geometry are built by GDScript when run; their editor trees intentionally remain compact.

On Android, install the official Godot Android editor, extract this entire folder into accessible device storage, grant the editor file access, choose **Import**, select `project.godot`, and open it. Let resources finish importing, keep the device in landscape, then use **Run Project**. Use the standard GDScript editor rather than .NET. Connect a keyboard only if desired; all play controls are on screen. Testing inside the editor does not require exporting an APK.

The Android export preset targets ARM64 and requests no internet permission. Exporting a signed APK separately requires compatible export templates, Android SDK/build tools and your own signing configuration; no signing credentials are included. An APK is not supplied by this source milestone.

## Foundation controls

| Action | Touch | Desktop |
| --- | --- | --- |
| Move | Left joystick | WASD / arrows |
| Look in third person | Swipe open right-side space | Right mouse drag |
| Camera | Camera mode button | C / Tab |
| Attack | Attack button | J / left click in world |
| Dodge | Dodge button | Space |
| Skills | I / II (foundation placeholders) | Q / E |
| Interact | Hand button near a portal | F |

The foundation deliberately uses grounded movement and dodge, without jumping. Walk toward the illuminated archway, then Interact to enter the dungeon. Its archway returns to the Sanctuary. Practice sentinels receive hits and restore themselves; they are not enemy AI. The minimap is a labeled static schematic.

## Structure and validation

- `scenes/main.tscn`: persistent player, camera and HUD shell.
- `scripts/systems`: unified input and guarded level replacement.
- `scenes/world`, `scripts/world`: Sanctuary, dungeon, reusable architecture, portal and practice target.
- `scenes/player`, `scripts/player`: one movement/combat controller, procedural character animation, collision-aware camera rig.
- `scenes/ui`, `scripts/ui`: multitouch ownership and HUD presentation.
- `tests/smoke_test.gd`, `docs/test-plan.md`: automated checks and Android review checklist.

```sh
godot4 --headless --editor --path . --import --quit
godot4 --headless --path . --script res://tests/smoke_test.gd
godot4 --headless --path . --quit-after 180
```

On restricted Linux runners, set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to writable temporary directories. Missing Android SDK warnings concern APK export configuration, not scene loading. Headless tests cannot establish real Android touch delivery, visual quality, thermal behavior, or frame rate.

Mobile budgets use Compatibility rendering, one shadow-casting directional light, 1024-pixel directional shadows, simple shared materials, instanced paving, and no GI or fullscreen post-processing. Device performance still requires measurement. The elevated tactical view uses a narrow perspective lens for continuous transitions; it is not a strict orthographic projection.

All visuals are project-authored procedural placeholders. No third-party art or audio license is required. Milestone 1 is a foundation; further gameplay is developed only when requested.
