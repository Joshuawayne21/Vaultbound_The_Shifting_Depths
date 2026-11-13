# Nexus Stage 1 — Android review checklist

For **0.7.0-nexus1 / Android export code 30**. The native gate passed **9,270 checks across 38 modes and 36 suites**. This document is a manual test route, not evidence that a physical Android test has occurred or that the update has been installed on a phone. See [the accepted native report](nexus-stage1-validation.md).

Stage 1 reorganizes the existing Sanctuary into four functional wings. It does not complete the streamed Nexus, ten playable activities, live matchmaking, a bank or guild services. Masks of the Abyss integration is deferred at the user's request; existing collectibles remain. The existing Personal Sanctuary/home must remain the same owned destination.

## Install and preserve progress

1. Download the normal GitHub `main` project after the stage publication and verify `project.godot` reports `0.7.0-nexus1`. A source ZIP is not an APK. Use the compatible Godot 4.6.3 Android editor or an appropriately exported build. Keep the existing application/user-data identity when updating.
2. Preserve the current phone profile and backups before replacing a working build. Do not clear app data, reset progression or overwrite the only save with a disposable test fixture. Record secured DM, important item instance IDs, active loadout, unlocked depths, companions, pets, home identity/theme and trophy/display selections before testing.
3. Record phone model, Android/Godot versions, renderer, resolution, graphics preset, 30/60 FPS target and reduced motion/effects settings. Mark every case **pass / fail / not tested**. Keep screenshots/video and measured frame-time/thermal details where available.

## City arrival and four-wing navigation

4. Start the game normally. The new default arrival should be the southern public Grand Foyer, at the authored `(0, 0.95, 31)` route facing the Exchange. Verify the player settles on the actual floor, the joystick responds, and Guardian/Mystic plus the selected cosmetic pet have safe space. This city foyer must not replace or reset the private home's Grand Foyer.
5. Walk from the foyer to the Exchange, around its ring and across all eight arch/bridge routes. Check both sides of each ramp, rail and doorway. No invisible wall, foot snag, fall-through, forced teleport or unreachable service is acceptable. Follow/hold/retreat commands should still work on the reused raised routes.
6. Verify destination labels and map waypoints agree with the actual layout: north Nexus/activity preparation; east practical merchants/crafting; west appearance/home/pets; south social/recruitment with the entry promenade. The eight retained routes are A/B north, C/D east, E/F south and G/H west. The central Living Prismheart must remain a single existing landmark.
7. Walk the same route in third-person and isometric views, switching while moving. Rotate and pitch near walls, arches, bridge rails, stalls and the new foyer. Check camera collision, temporary obstruction recovery and service-prompt visibility. Reproduce the earlier moving-wall flicker case; native face separation alone is not a rendered device result.

## Existing interactions and returns

8. Use all six Exchange booths and the original City Guide. They must use the same clearly labelled **DEMO / NOT LIVE** account/market, never the player's earned DM/items. Check confirmation, cancel/back, rapid taps, drag-off and reopening. No fake global traders or messages should appear.
9. In the east wing, open all three existing vendors at C and the Blacksmith at D. On a backed-up or disposable profile, test one valid purchase/sale/craft/repair/upgrade where resources permit. Confirm previews and exact costs; locked/favorite/displayed items remain protected. A Bank or mask sign must not imply unsupported deposit or crafting transactions.
10. In the west wing, inspect the actual equipped character at H, open the single Spiritweaving service at G, and enter **Personal Sanctuary** at G. Verify owned pet aliases/variants/recipes remain intact. Visit the existing foyer, Trophy Hall, Pet Conservatory and available other rooms, then return. Home ID, themes, trophies, equipment-display UIDs and selected pet displays must survive relocation and restart.
11. Use the southwestern F recruiter in the south social wing to recruit/dismiss the existing Guardian and Mystic. Verify the three-person party remains intact across travel. Guild, rankings, Conquest and online-social information must state their actual availability; there must be no invented membership, ranking or remote conversation.
12. Use every existing playable portal retained at this checkpoint: progressive dungeon selection, practice dungeon, Proving Grounds and home. Test entry cancellation, failed/denied entry, repeated taps and return. Retained Sanctuary return transforms are `from_dungeon` `(0,0.15,-5.4)`, `from_abyss` `(3.5,0.15,-5.5)` and `from_hall` `(-3.5,0.15,-6.5)`, with the existing return orientations. Check actual floor/formation safety at each rather than relying on coordinates alone.
13. Complete an eligible expedition using normal combat, loot and extraction; restart and verify secured rewards/depths. Also check a disposable failed expedition loses only its unsecured findings. Existing secured gear, trophies, pets and home state must remain. TEST ACCESS may help inspect implemented content, but cannot enable unfinished activities or fabricate rewards.

## Mobile presentation and performance

14. Compare Low/Medium/High and 0/50/100% decorative density, reduced motion/effects and supported UI scales. Essential arches, floor collision and blockers must remain consistent. Check flowers/foliage do not obscure interactions or fighting visibility; decoration may reduce on lower presets.
15. Review daytime/nighttime appearance, water edges, relief, banners and distant scenery. Look for flashing coplanar surfaces, floating trim, oversaturated lighting, unreadable signage, missing materials and unreasonably long walking distances. Record failures with location and camera mode.
16. Check safe areas/notches, thumb reach, readable prompts, menu scrolling, background/resume and any keyboard-open states. Measure sustained gameplay frame times, memory and thermal behavior with quality/resolution/duration recorded. A 30/60 FPS setting is a target, not proof that the device sustains it.

No physical Android result, new activity completion or online capability is claimed by this checklist. Follow the final stage report for what was actually built and automated-tested before submitting findings.
