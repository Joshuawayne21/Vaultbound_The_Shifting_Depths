# Personal Sanctuary — Android acceptance checklist

This checklist covers the functionally verified `0.7.0-home3` Grand Foyer checkpoint. Its headless scoped gate passed, but **no physical Android test or device performance measurement is claimed**. Record device, Android version, Godot version, build/commit, settings and actual results. The other home rooms and blueprint-based city overhaul remain later stages.

## Import and preserve a test profile

1. Back up the existing player profile and companion backup files through the device's supported storage access. Keep a copy outside the test installation; the repository backup does not include phone saves.
2. Import the root `project.godot` in the official **Godot 4.6.3 Android editor**, standard GDScript edition. Use Compatibility rendering, finish import and run `scenes/main.tscn` in landscape.
3. On a progressed test profile, record Depthmarks, loadouts, upgraded/favorited/locked items, trophy assignments, pets, recruits and highest unlocked depth. Test a fresh profile separately without replacing the progressed record.
4. Begin at **Medium / 30 FPS target** with a readable UI scale. An FPS target is a setting, not a measured performance result.

## Home entry and both floor levels

1. Select district D, **Personal Sanctuary & Trophy Hall**, on the city map. Walk to the existing southeast gate. Confirm its Personal Sanctuary title and preservation of the other gates.
2. Tap **ENTER / USE**, inspect the local-home card, cancel and check controls. Reopen and confirm **ENTER**. Holding or rapidly retapping must not duplicate travel.
3. In the foyer, walk the central aisle, Home Management approach and both existing door approaches. Switch cameras during movement and near walls. The floor, decorative inlays and upper-level stonework must align; the arrival must not place anyone inside architecture.
4. Recruit Guardian and Mystic and select an owned ground pet. Walk up the east staircase, around its turn, across the rear upper gallery and down the west staircase. Repeat in reverse and with a flying pet. Followers should walk the route, stay on supported surfaces and regroup without visible recovery jumps or permanent disappearance.
5. Stop on each turn and stair slope, change direction, and switch third-person/isometric cameras. Inspect railings, floor seams, the chandelier and window walls for obstruction or clipping. Rails must prevent accidental falls. Check the upper doors without attempting to enter unavailable rooms.
6. Test **Hold** upstairs, descend, then **Follow** to reunite the party. Stand near the lower face of the rear gallery and turn so followers form behind you; they should regroup on your floor rather than oscillating against the plinth.
7. In reduced-motion mode, inspect the central House Sigil, chandelier and ambient decoration. Motion should reduce without hiding navigation, prompts or essential geometry.

## Home Management and persistence

1. Approach the central lectern and tap **USE**. Open **APPEARANCE** and **ROOM MILESTONES**. Lists and detail text should scroll; touch targets must remain usable at the device's aspect ratio and chosen UI scale.
2. Inspect actual requirements: Forest needs one owned pet, Obsidian one completed expedition, Violet a Depth 3 clear. Royal Azure/Vault Diamond are initially available. Locked choices must explain the requirement and cannot be applied.
3. When milestones are earned, tap **RECORD EARNED UNLOCKS**, review, cancel once, then review and **CONFIRM & SAVE**. Confirmed records should persist. A recorded future room still says **ROOM NOT OPEN** and has no travel action.
4. Select an unlocked theme and sigil. Preview without confirming, then close: world appearance must remain unchanged. Reopen, **REVIEW APPEARANCE**, then **CONFIRM & SAVE**. The foyer should update while the inventory, character stats, Depthmarks and shared city appearance remain unchanged.
5. Try a rapid double tap, drag off the confirm button, two simultaneous fingers, screen rotation/resizing where supported, and background/resume. A held touch must not commit a second change or accidentally use a portal after the panel closes.
6. Use **ENTER TROPHY HALL** from the room tab, return home, then use **RETURN TO SANCTUARY** from the lectern. Repeat using the physical doors. Check that controls resume after each transition and both companions/pet remain correct.
7. Restart and verify the same home identity, selected theme/sigil, recorded milestones and preexisting possessions. Do not edit saved values to simulate a passing result.

## Trophy Hall and preserved game route

- In the existing Hall, inspect stands, relics, Rootwarden display and journals. Assign an owned eligible item, remove/reassign it and confirm its quantity and UID ownership remain unchanged. Hall expansions and new pet display rooms are not present yet.
- Return **Hall → Personal Sanctuary → Sanctuary** in both camera modes. A legacy direct Hall visit retains its city return.
- Visit existing merchants/Blacksmith and perform one ordinary transaction on the backed-up test profile. Ring Exchange must remain **DEMO / NOT LIVE**, with separate TEST balances.
- Enter an eligible dungeon depth and test movement, weapon switching, attacks, abilities, both cameras, companion following and searchable loot. Complete the boss/extraction route, then revisit home. New secured rewards and permanent progression must remain available.
- On a separate run, collect unsecured loot and fail the expedition. Previously secured equipment, home identity and recorded appearance/milestones must remain. Existing death wear can change equipped durability; unsecured loot is intentionally lost.
- Check authored practice dungeon and Proving Grounds returns. Training is not ranked PvP. Online guilds, banking and visiting are not implemented by this update.

## Graphics, recovery and reporting

Test Low/Medium/High, optional 30/60 FPS targets, reduced motion, 0/50/100% ambient density, prompt contrast and supported UI scales. Check notches/system bars and portal/lectern readability. Inspect rendered material seams, true stair silhouettes, themes, light balance and camera retraction. Record sustained frame times and thermals with scene, quality, resolution and duration; headless host timing is not Android performance.

If progress becomes read-only, retain the original files and error message. A read-only city profile cannot create or newly enter a home. If the player is already in a valid home and writing becomes unavailable, appearance saves must fail safely while the existing Hall/home/city escape routes remain available. Do not corrupt real phone saves to test recovery; use disposable desktop fixtures for fault injection.

Record each case as pass/fail/not tested, including companions, pets, both floor levels, camera presets, touchscreen comfort, save/reload, extraction/death and return routes. Attach screenshots/video where possible. No unchecked case is accepted by inference from automated tests.
