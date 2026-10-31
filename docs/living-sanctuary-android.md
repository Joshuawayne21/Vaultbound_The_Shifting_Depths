# Living Sanctuary — Android review

No physical Android test has been performed for this expansion. Headless Godot checks verify scripts, resources, physics and simulated input; they do not establish touch comfort, keyboard behavior, shader appearance, sound quality, battery use or sustained frame rate. The 6B city, 6C scenery/accessibility and 6D social presentation stages have passed their automated gates. Use the checklist below on a verified checkpoint; those automated results do not replace device testing.

## Import without losing progression

1. Back up your existing `user://vaultbound/profile.json`, its `.bak` and any `.pre-v*` migration backups using your editor/device's available file-access tools. `user://` is Godot's application-data location, not a folder to create inside the repository. Retain copies of `visual_settings.cfg` and, if present, `social_settings.cfg` too.
2. Extract the complete checkpoint into a folder accessible to the official Godot Android editor. Import the root `project.godot` using **Godot 4.6.3 standard/GDScript**, Compatibility rendering and landscape orientation. Allow resource import to finish.
3. Run the main project (`scenes/main.tscn`). Start at **Medium / 30 FPS**, normal UI scale, with reduced effects if your device needs them. These are targets, not measured performance guarantees.
4. Verify your previous Depthmarks, item-instance quantities, enhancements, loadouts, talents, companion roster and Collection Hall assignments before making transactions. Do not delete a save or replace it with defaults to resolve a loading error.

The progression profile remains v4 through 6D. The 6C preferences migration affects the separate graphics file only. Opening an old preferences file must preserve its prior choices and must not rewrite it merely because it was loaded. 6D chat display choices use a separate version-one `social_settings.cfg`; no chat transcript or draft is saved there.

Running in the Android editor needs no APK export. The ARM64 export preset requires matching templates, SDK/build tools and your own signing configuration for an exported build. No signing keys, APK, account service, live trading or billing are supplied by these stages.

## Walk the city and use every destination

- Open the top-right hub map, choose each district and follow its waypoint. Walk the full central ring and each radial path. The map selects a destination; it must not remotely open shops or teleport the player.
- Recruit Rowan and Lyra at **H, northwest Tavern**. Walk together to all eight districts and across the city from **C to G**. Ascend and descend both the **E Forge** and **H Tavern** ramps. Try Follow, Hold and Retreat; companions should use the ramps and remain grounded.
- At **A, north Portal Promenade**, approach each gate and use the visible **ENTER** control. Review the card, cancel once, then reopen and confirm. Repeated taps or two fingers must produce one transition. The open card pauses movement; joystick input must not move the character behind it. Cancel, walk away and verify that a delayed touch release does not enter. Debug source/range-expiry cases are covered by the automated suite.
- Visit the **B Coliseum** training target and Proving Grounds gate; test existing sword/shield and staff actions in the arena. Return through its original portal.
- Use all three vendors at **C, east Merchant Terraces**, the **E Forge**, recruitment at **H**, and the owned-equipment preview at **F, southwest Pavilion**. Check the displayed costs before confirming any real transaction.
- Enter the Collection Hall through **D, southeast Gallery**, inspect an existing exhibit and return. Verify an assignment continues to reference the same owned item. **G, west Conservatory**, remains a guide in 6B; pet acquisition belongs to a later stage.
- Switch between third person and isometric while moving beside walls, arches, terrace edges and the central crystal. Inspect the view at each district entrance and from both ends of each ramp. Watch for opaque scenery crossing the near plane, unreadable combat space or visibility through walls.

## 6C scenery and accessibility review

- Compare Low, Medium and High from the central plaza, ring road, perimeter and Forge/Tavern terraces. Distant cliffs, forest and ruins should form a continuous backdrop while roads, entrances and signs remain readable. Check water edges, flowerbeds and silhouettes for floating or intersecting geometry.
- In **GRAPHICS → AMBIENCE**, try ambient density **0%, 50% and 100%**. Zero should remove decorative motes and butterflies without hiding enemies, loot, interaction prompts or boss warnings. Counts should remain bounded as you travel between rooms or return to Sanctuary.
- Enable **reduced motion**. Check foliage, water, portal runes, butterfly wings/flight and ambient residents. Decorative shader motion may settle immediately into a static pose when this option changes. Portal proximity feedback must still update. Combat damage windows and hazard telegraphs must continue normally.
- Test **high-contrast prompts** beside lanterns, crystals and the portal veil, and in a dark dungeon. Check both the world prompt and touch button, disabled-entry explanation and revive prompt.
- Test UI scales **100%, 110% and 120%**, including the device's cutout/system-bar areas. Graphics tabs, Apply, Close and new options must remain separate, readable and easy to tap. Cancel a touch by dragging away or interrupting it with an application pause; it must not activate on return.
- Ambient sound starts **off**. Enable it at a low device volume, then disable it. The original generated wind/water loop is prototype audio. Listen for loop clicks, harsh frequencies, repeated playback layers and audio continuing after the world unloads. Check both speakers and headphones if available.
- Observe the local day/night presentation long enough to assess the darker phase. It must retain readable paths and characters. This cycle is local decoration, not an online world clock or an event announcement.

## 6D chat, emotes and inspection review

These checks require the 6D checkpoint. Chat is **DEMO / NOT LIVE**; no message should reach another device, appear from a fictional player, or be described as queued for delivery.

- Open CHAT in each camera view. Tap the composer and type ordinary text, emoji and text using an Android IME with composition. Confirm the keyboard leaves the current tab, composer and action readable. LOCAL's **PREVIEW · DEMO** should add one self-preview row. WORLD and PARTY can keep separate drafts but cannot send.
- Change tabs and return; drafts should survive for this running session. Try rapid double taps and pressing the keyboard's submit action at the same time as Preview. A preview must appear only once; rate-limited text should remain editable.
- Try Back while the keyboard is visible, then Back again. The first action should dismiss typing; the next should close chat. Test app background/resume, orientation/system-bar changes, closing while a finger is held, opening emotes from chat and traveling after closure. Late releases must not send a message, attack, rotate the camera or activate an old button.
- With an attached keyboard, hold a movement or combat key while typing and close chat. Gameplay must wait for held typing keys to be released. Fresh touch controls must still work. This is distinct from soft-keyboard IME testing.
- In DISPLAY, try all three font sizes, timestamps and compact transcript visibility. Apply and restart. Only display choices should persist; drafts and preview history should not. A hidden transcript must leave a usable CHAT launcher. Repeat with each global UI scale and the device cutout/safe-area configuration.
- Open the emote wheel and try all nine actions with sword/shield and staff, in both camera views. Camera switching should keep the pose running; movement, an attack, dodge, weapon switching or accepted damage should cancel it. Check that weapons remain attached and that sit/bow poses do not visibly penetrate the ground. These are procedural animation placeholders awaiting visual review.
- Enable reduced motion and repeat emotes: poses should settle instead of cycling and still expire. Confirm combat timing, damage, stamina, targeting and cooldowns remain normal.
- Recruit both companions and inspect each from its party entry. The card must say **LOCAL AI COMPANION** and show that member's actual state. Online player actions must explain their unavailable status. Closing inspection must restore gameplay; dismissal/travel must not leave a card referring to an old actor.

Record keyboard vendor/version, IME language, system navigation mode and whether the keyboard overlays or resizes the game when reporting an input problem. Do not include private message contents.

## Preserve the expedition loop

Repeat expeditions with at least three recorded seeds, including a layout with a secret branch. The HUD displays the seed; the main scene's **Debug Expedition Seed** can reproduce it. Record the engine/build version with the seed.

1. Enter with both AI companions. Traverse several room connections in both camera views; check that decorations do not cover doors, enemies, treasure or hazards.
2. Use both weapon loadouts and their abilities. Confirm attack recovery, dodge, blocking and target lock still behave as before. Camera switching must not duplicate damage or reset a fight.
3. Defeat enemies, search their caches and take rewards. Defeat the Rootwarden, search its grand cache and interact with the extraction point. Verify the results and newly secured rewards in Sanctuary.
4. Restart the project and verify those secured rewards, equipment and companion progression remain. Separately test a failed expedition: only its unsecured loot should be lost; previously secured equipment must remain.
5. Revisit a known seed with different quality, density and motion preferences. Room connections, initial spawns and loot rules should remain the same; only presentation may change.

Keep the [5.6 Android checklist](milestone-5.6-android.md) for detailed inventory, enhancement, crafting, equipment and Collection Hall checks.

## Record evidence

Record only the information needed to reproduce a problem: checkpoint/commit, device model, Android and Godot versions, display size/orientation, quality/FPS target, UI scale, density/motion settings, location and expedition seed. Do not include payment details, account secrets or device serial identifiers.

Measure at least a ten-minute route through Sanctuary and a representative dungeon, including combat, menu opening and repeated transitions. Use the existing metrics display and a profiler where available. Record frame-time spikes and sustained behavior, not just an initial FPS reading. Compare a cold start with warmed-up play and note thermal throttling. A software-rendered desktop screenshot is useful visual evidence but cannot validate Android GPU performance.

| Device / build | Preset / target | Route / seed | Duration | Frame-time / FPS observation | Touch / heat / visual issues |
| --- | --- | --- | --- | --- | --- |
| Not yet tested | — | — | — | No device measurement | Pending |

Attach a screenshot or short recording showing the problem and its reproduction steps. Actual **30 FPS** and optional **60 FPS** acceptance remain open until these measurements are collected on supported hardware.
