# Echoes Stage 5b — Android play-test route

**Manual checklist; not a device test result.** Verified source `0.7.0-nexus5b` / Android export code **33** passed 19,776 native checks across 142 modes and 120 suites, including seventeen independent restart readers, plus import, 62 strict loads and 120 startup frames. Follow this route after obtaining that verified build. No rendered acceptance, physical Android test, APK or phone installation is claimed. See [native evidence](nexus-stage5b-validation.md).

## Preserve and import

1. Back up the actual phone profile and all its backup files. Update using the same package/application/user-data identity; do not uninstall or clear data. A fresh source folder does not move a profile between editor and exported applications.
2. After verified publication, obtain [GitHub main](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths) through **Code → Download ZIP**, extract into a clearly named folder, and check its root `project.godot` version. Import with the standard GDScript **Godot 4.6.3 Android editor**, Compatibility renderer, landscape, and **Run Project**. Source ZIPs are not APKs.
3. Record device/OS/Godot/build, graphics preset, resolution/UI scale and actual results. Note secured DM, equipment UIDs/upgrades, pets, party, depth clears, home identity/displays and Beastwilds records before migrating. Profile 13/activity 2 must retain them, and the first successful write must preserve the prior bytes in `.pre-v13.bak`.

## Admission and five waves

1. Recruit Guardian and Mystic at the southern Tavern if desired, then enter the city's northern **NEXUS OF REALMS** gate. In the Ascension gallery, inspect **Echoes of Eternity**. Without a verified Depth 3 clear/extraction and with TEST ACCESS off, confirm the clear requirement is shown and entry is denied. Inspecting a card must not grant progress. Use the existing saved TEST ACCESS switch for offline early testing if needed.
2. Enter and confirm the southern arrival, trial shrine, five-cache alcove and return source are reachable. Switch third-person/isometric while walking the inner court, near low walls and around obelisks. Verify AI companions follow without teleport loops; the pet must not obstruct prompts or spawning.
3. Tap the shrine and **START WAVE 1**. Observe at least two seconds of warning and safe spacing. Occupy a warning area and check that the wave waits/retries instead of forcing an enemy onto the party. Move into clear space and confirm it can proceed.
4. Play waves 1–5: two skeletons; skeleton/archer; two skeletons/archer; golem/skeleton/archer; solo Rootwarden echo. Verify attacks, dodges, blocking/casting, telegraphs, target lock and weapon switching with both cameras. No more than three ordinary enemies or one boss should be active. A normal enemy must actually die before being credited.
5. Every break waits for **CONTINUE**. After waves 2 and 4, test both available choices across repeated visits: **+6% damage** or **+12% stamina regeneration**. Verify no health/stamina refill or cooldown reset, one accepted choice per break, capped stacking, and retained selection during camera switching. Close, drag off, hold a finger across reopening, use simultaneous touches and background/restore the app while a panel is open; these actions must not advance/choose twice.

## Search, return and restart

1. Search each earned cache through the normal prompt. Test individual Take, Take All, repeated taps and a nearly full inventory. Rejected contents must stay searchable. Leaving a cache unsearched must not add its contents to the bag.
2. Before wave 5 completes, inspect **ABANDON & RETURN**, cancel once, then confirm on a separate visit. Unsecured loot is lost; secured inventory/equipment/pets/home and dungeon clears remain intact. Temporary boons must be absent afterward.
3. On a complete run, search the desired caches and review **SECURE & RETURN**. Check the unclaimed-cache warning when applicable. Return to the Nexus with precisely the taken DM/materials, local wave/score/time result, and no XP, Rootbound clear, Rootwarden trophy, mask, pet grant or merchant-rotation increment. Repeat taps must not duplicate the result.
4. Restart the app and compare the secured state and both activity records. On a disposable test profile, close the app during a later unfinished Echoes visit: live enemies, temporary choices and pending loot must not resume as secured rewards. Entering Beastwilds afterward must retire the interrupted Echoes ticket against Echoes, without altering the older Beast record.
5. Test a real party wipe in a separate visit. Existing death/return rules must lose only unsecured rewards and leave temporary boons inactive. Use automated fault fixtures for write failures; do not corrupt a personal save to simulate them.

## Regression and device comfort

Revisit Abyssal Descent, Bloodspire NPC practice, auxiliary Sunken Vault and [Beastwilds](nexus-stage5a-android.md). Recheck the western [Personal Sanctuary and displays](personal-sanctuary-android.md), city merchants/crafting, inventory, both weapon loadouts and party commands. The remaining six major activity cards must stay unavailable even with TEST ACCESS. Masks remain user-deferred; no online co-op or rankings should be advertised.

Review Low/Medium/High, reduced motion, UI scaling and high-contrast prompts. Ensure warning areas, health/stamina, boss bar, wave count, cache prompts and boon buttons remain legible without covering controls or notches. Check real Android lifecycle interruptions, frame pacing, thermal behavior and memory over multiple five-wave visits. Record measured results; stable 30 FPS and optional 60 FPS remain targets until device measurements exist.
