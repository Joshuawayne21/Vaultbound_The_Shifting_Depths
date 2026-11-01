# Milestone 7 — Android acceptance checklist

Use a committed, validated stage checkpoint. No physical Android, GPU or sustained frame-rate result is claimed by this checklist. Keep the existing [Living Sanctuary checks](living-sanctuary-android.md) for combat, touch, equipment, companions, pets, portals and safe save handling.

## Import and preserve progress

1. Back up your existing `user://vaultbound` data, including the profile, rotating/migration backups and separate visual/social settings. Retain the isolated TEST exchange file if you want its demonstration history.
2. Import the repository-root `project.godot` using the standard GDScript **Godot 4.6.3 Android editor**, Compatibility renderer, landscape. Running in the editor does not require an APK export or signing key.
3. Start at Medium / 30 FPS and verify earned Depthmarks, inventory quantities/UIDs, loadouts, enhancements, talents, recruited companions, pets and Hall displays before testing new content. Never delete an existing profile to resolve a load error.
4. Record the exact stage/commit, device, Android/Godot versions, resolution, UI scale and quality settings. Do not include account secrets, private chat or device serial numbers in reports.

## 7B Sanctuary presentation

- Walk the entire ring road, all eight radial roads and both Forge/Tavern ramps. Recruit Guardian/Mystic and select a pet; confirm all three follow and that service approaches remain usable.
- Inspect the larger perimeter walls and distinct tower/giant-tree silhouettes from the plaza, district entrances and perimeter. Check for floating parts, overlapping trim, abruptly clipped crowns, excessive fog and unreadable dark masonry. Distant scenic bridges/landmarks are not promised as traversable paths.
- Sweep the third-person camera at low and high pitch near walls, towers, gate crests and terrace corners. Switch smoothly to isometric while moving. Watch for the lens entering opaque meshes, severe occlusion, flicker or camera pull-in that makes walking difficult.
- Approach the blue Rootbound and gold Hall gates. Confirm the destination label, large ENTER control, explicit review and return placement. Practice gates must remain clearly labeled practice. Do not expect purple/red routes before the Veilgarden/Frontier stages actually add them.
- Revisit all merchants, Forge, Tavern, Conservatory and the physical Ring Exchange terminal. Use the city map without remotely opening a service. TEST exchange and chat labels must remain honest about their offline status.
- Compare Low/Medium/High, reduced motion, reduced effects, ambient density zero and high-contrast prompts. Essential walls/portal obstructions must remain consistent across quality; reduced decoration must not hide enemies, loot or interactables. Observe daytime and the darker phase of the existing local daylight cycle.
- Enter/return from Rootbound, practice dungeon, Proving Grounds and Collection Hall in both camera views. Record a dungeon seed and verify that the visual pass has not altered its route, pickups or gameplay.

## 7C dungeon depth progression

Use a validated 7C checkpoint for these checks. Keep a separate disposable profile for fresh-player tests; do not reset a real profile.

1. On a new profile, approach the blue gate and inspect Depth 2: it must explain that Depth 1 needs to be completed. Changing the selection must not start travel. Cancel and verify movement, camera and combat touches resume correctly.
2. At every supported UI scale, select Depth 1 and confirm ENTER. Check that the card, dungeon HUD and results show the same floor. Switch cameras during movement, attacks and companion combat; no state or rewards should reset.
3. Defeat the boss and extract. Verify Depth 2 unlocks, then fully close/reopen the game and confirm the unlock remains. Replaying Depth 1 must not remove it. On a separate failed run, confirm secured equipment, DM, pets and unlocks remain.
4. With an existing pre-depth save, verify all owned records before and after migration. A previous successful Rootbound extraction should unlock Depth 2, irrespective of the number of earlier repeats. Keep the migration backup. Report an unsupported-format message without deleting data.
5. Check portal selection with simultaneous joystick/camera touches, a held ENTER press, selector changes, Android pause/resume and Back. An old press must not enter a newly selected floor, and a closed card must not change an active expedition.
6. As depths become available, record seed, depth and build. Check room bands, longer-route companion following, loot visibility, boss/extraction reachability and readable warnings. Test the longest available floors for memory use, sustained frame time and acceptable session length. The early-extraction feature is a later stage.

See [depth rules and save compatibility](dungeon-depths.md). Source/logic validation does not establish difficulty balance or a comfortable mobile session length; those need real play-throughs.

## 7D.1 registered encounter integration

Apply these checks only to a validated 7D.1 checkpoint. This integration batch still enables the existing Rootbound theme and Rootwarden; reserved content interfaces do not add new playable biomes or bosses.

1. Back up a pre-v7 profile, enter Rootbound, defeat ordinary enemies and the Rootwarden, search their caches and extract. Compare owned equipment, exact enhancements, DM, companions, pets, Hall selections and depth unlocks with the backup. Verify the new encounter records survive a complete restart. Historical discoveries must not acquire invented old dates or kill totals.
2. Repeat with Guardian, Mystic and an active pet. Switch cameras while enemies attack, while avoiding root warnings and while entering the boss arena. Check readable warnings, reliable companion reactions, uninterrupted attacks and the existing active-enemy limits.
3. Cross room boundaries during awareness warnings. Canceled events must warn again before becoming dangerous. A safe room or boss arena must not inherit an almost-finished environmental attack.
4. Enter and return repeatedly from the blue portal, including Android pause/resume during each fade. Watch for duplicate pets, stranded companions, controls remaining disabled, a dark transition overlay or an extra results screen. Verify every service and practice portal still works after returning.
5. Measure peak memory and frame-time spikes during travel on Low, Medium and High. The previous world is briefly retained until final content admission; headless tests cannot establish this overlap's device memory cost.

The [content integration guide](dungeon-content.md) describes source-bound rewards, save compatibility and the shared event budget. New explicit hazard shapes and guarded boss projectiles require their later encounter producers before players can exercise those new mechanics in ordinary play.

## Capture performance and visual evidence

Record at least ten minutes covering plaza/perimeter traversal, crowded district views, portals, combat and a representative dungeon. Compare cold start and warmed-up play; note frame-time spikes, thermal throttling, touch comfort and battery drain. Use the metrics display/profiler where available. Native mesh counts and cloud CPU timings cannot establish device FPS.

| Device / stage | Quality / target | Route / seed | Duration | Frame-time / thermal observations | Input / visual issues |
| --- | --- | --- | --- | --- | --- |
| Not yet tested | — | — | — | No physical measurements | Pending |

Attach actual screenshots or a short recording for visual issues. Label any desktop software-rendered capture accurately; it is not Android evidence. **30 FPS** and optional **60 FPS** remain device goals until verified.

Run only the checks applicable to the downloaded checkpoint. New biomes/bosses/recruits, genetics, Veilgarden and Frontier require their own stage-specific tests when implemented. Their presence in the [plan](milestone-7-plan.md) does not make them available in 7B, 7C or 7D.1.
