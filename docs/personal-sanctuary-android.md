# Personal Sanctuary — Android acceptance checklist

This checklist covers the `0.7.0-home2` entrance foundation. **No physical Android test or device performance measurement has been recorded for this stage.** Record the actual device, Android version, Godot version, graphics settings and results when testing. The complete Grand Foyer and blueprint-based city overhaul are later stages.

## Import and preserve a test profile

1. Back up your existing player profile and its companion backup files using the storage access available on your device. The repository backup does not include phone saves. Keep a copy outside the test installation.
2. Import the repository's root `project.godot` in the official **Godot 4.6.3 Android editor**, standard GDScript edition. Select Compatibility rendering, let import finish and run `scenes/main.tscn` in landscape.
3. Use an existing progressed test profile if available. Note its Depthmarks, equipped loadouts, upgraded/favorited/locked items, trophy assignments, owned pets, recruits and highest unlocked depth. Also test a fresh profile without replacing the progressed one.
4. Start at **Medium / 30 FPS target**. In Accessibility, select a readable UI scale. An FPS target is a setting, not a measured guarantee.

## Home and Trophy Hall round trip

1. In the Sanctuary map, select district D, **Personal Sanctuary & Trophy Hall**. Walk to the existing southeast gate. Its visible title and destination should be Personal Sanctuary; the other gates and their destinations should remain available.
2. Approach the gate and tap **ENTER / USE**. Review the local-home card. Cancel once and confirm that movement and camera controls resume. Reopen and tap **ENTER**. A held finger or a rapid second tap must not cause a second transition.
3. In the arrival room, walk the center aisle and side area. Switch between third-person and isometric while moving, near both door arches and near walls. Check for clipping, unreadable prompts, stuck movement and unwanted camera resets.
4. If recruited, bring Guardian and Mystic. Verify that both enter, follow through the room and return with you. Select one owned cosmetic pet and verify that it appears and follows; it must not obstruct the doors or controls.
5. Approach **TROPHY HALL · YOUR COLLECTION** and use the normal interaction control. Inspect the existing stands, relics, Rootwarden display and journals. Assign an owned eligible item, remove/reassign it and confirm its inventory quantity and UID-based ownership remain unchanged.
6. Use **RETURN TO PERSONAL SANCTUARY** in the Hall. Back in the home, use **RETURN TO SANCTUARY**. You should arrive at the existing city return point with responsive controls. Repeat the route in the other camera mode.
7. Close and restart the game, then repeat the visit. Confirm that previous possessions, Hall assignments, pet collection and recruits persist. If inspecting development save files, the opaque `home.id` should stay identical between visits; do not edit it to simulate a pass.

## Preserved game regression route

- Visit existing NPC merchants and Blacksmith. Check displayed Depthmarks, owned equipment and one ordinary transaction on the backed-up test profile. The separate Ring Exchange must still say **DEMO / NOT LIVE**; its TEST balances must not become character currency.
- Use the blue dungeon portal, check locked-depth reasons and enter an eligible floor. Test movement, weapon switching, attacks, abilities, both cameras, companion following and searchable loot.
- Finish an expedition through the required boss and extraction, then revisit the home/Hall. New secured rewards and permanent progression should remain available.
- On a separate test run, collect unsecured loot and allow the expedition to fail. Previously secured equipment and home identity must remain. Existing death wear can change equipped durability; unsecured loot is intentionally lost.
- Check the authored practice dungeon and Proving Grounds return routes. The training destination is not ranked PvP.

## Touch, graphics and recovery review

Test Low, Medium and High, both available FPS targets, reduced motion, 0/50/100% ambient density, high-contrast prompts and the supported UI scales. Check screen cutouts/system bars, portal-card readability and touch controls at the device's actual landscape aspect ratio. Background/resume the app during movement and during a portal card; controls must release cleanly and transitions must not duplicate.

Inspect home lighting, material seams, floor alignment, portal appearance and camera retraction on a rendered device. Measure sustained frame times and thermals during repeated visits; report scene, quality, resolution and duration with any performance result. The ground-floor foundation has no upstairs route to test yet.

If the UI reports read-only/unsupported progress or a failed save, retain the original files and the displayed error. A read-only profile must not enter the home; a failed first-home save must leave the player in the city without overwriting progression. Keep Android tests separate from desktop `/tmp` fault-injection tests; do not corrupt a real save to exercise recovery.

## Result record

Record pass/fail for the home round trip, saved ownership, both cameras, companions, selected pet, dungeon extraction/death, touch comfort and each quality preset tested. Attach screenshots or a short video where possible, and include the exact build/commit and device details. Unchecked cases remain pending; automated headless checks do not substitute for these device observations.
