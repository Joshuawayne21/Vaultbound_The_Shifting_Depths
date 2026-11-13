# Offline test access

Build `0.7.0-nexus5c` (Android code 34) retains the default-OFF saved **TEST ACCESS** switch. It bypasses implemented Depth 5 Gilded admission and existing Beast/Echoes gates without granting clears or rewards. Stage 5c passed 24,722 assertions across the approved 157-mode regression matrix (131 test scripts), including eighteen independent restart readers, plus import, 52 strict loads and 120 startup frames; see [evidence](nexus-stage5c-validation.md). Five other major activities remain unavailable. This is local profile testing, not an online entitlement or remote phone switch.

## Enable once on your device

1. Back up the existing phone profile and its backup files. On the [GitHub repository](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths), choose **main → Code → Download ZIP**, or download the [main source ZIP](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths/archive/refs/heads/main.zip). Extract it into a new clearly named folder and import its root `project.godot`. Keep the same application/user-data identity; the ZIP is source, not an APK, and extracting a new folder does not migrate profiles between applications. Do not clear app data or uninstall. After verified Stage 5c publication, verify `config/version="0.7.0-nexus5c"` (Android export code **34**) before testing; an older extracted folder may lack the switch.
2. Return to the Sanctuary or your home and finish any action. Open **SETTINGS → TEST ACCESS** (the fourth tab).
3. Select **ON · TEST IMPLEMENTED CONTENT → REVIEW CHANGE → CONFIRM & SAVE**.
4. Check **SAVED TEST ACCESS: ON** and the **TEST ACCESS ON** HUD badge. Restart once to confirm the saved choice is retained. Cancelled review or a failed save does not enable it.

The switch is per saved profile, so enable it once for each profile you actually use. It cannot change during an expedition, combat action, travel, an unfocused application or a read-only/invalid save. The panel explains why a change is unavailable.

## What it opens

| Content | Test access behavior |
| --- | --- |
| Implemented home rooms | Bypasses earned room milestones; use the normal marked door or Home Management route |
| Implemented home themes/sigils | Allows previewing and applying unearned appearances without recording them as earned |
| Beastwilds discovery expedition | Allows the verified local discovery route before Depth 2 clear; still requires actual source interactions and secure return, and never grants dungeon progression |
| Echoes five-wave trial | Bypasses Depth 3 entry only; actual waves, search and secure/abandon rules still apply. Scoped native acceptance passed; device review remains |
| Gilded six-room trial | Bypasses Depth 5 entry only; physical puzzle, guardian, search and settlement remain required. Scoped native acceptance passed; device review remains |
| Dungeon depths 1–50 | Select through north Nexus → Abyssal Descent before sequential unlock; existing implemented theme pools, encounters and combat still apply |
| Owned supported equipment | Ignores its level requirement; ownership, valid slot and supported weapon-family rules remain |
| Existing crafting recipes | Ignores recipe level requirements; ordinary material and Depthmark costs still apply |
| Spiritweaving recipes | Bypasses achievement requirements only; enabled recipe, secured ingredients, creature-memory seed and existing ownership rules remain |

This bypass does not grant the underlying Spiritweaving achievement or reroll a saved appearance. A test-access Conservatory visit may be empty: the room opens, but displaying a pet still requires owning it.

This does **not** grant unowned items/pets, free currency, materials, talent points, XP, purchased cosmetics or unfinished content. Existing prices, upgrade costs/caps, inventory capacity, display ownership and earned talent points remain required. It does not enable online servers, ranked PvP or multiplayer privileges. It cannot make the unfinished Nexus activities, user-deferred mask quality rules, bank storage or guild services available. A test-only clear above your earned highest unlocked depth does not skip the permanent sequential depth ladder. Ordinary run rewards still follow the existing extraction/death/save rules.

## Turn it off safely

Use **SETTINGS → TEST ACCESS → OFF · NORMAL REQUIREMENTS → REVIEW CHANGE → CONFIRM & SAVE**. The review lists necessary cleanup before committing:

- Gear above your real character level is unequipped but remains in inventory.
- An unearned home theme/sigil returns to Royal Azure/Vault Diamond. Already-earned selections stay valid.
- Pet display references relying on an unearned Conservatory unlock are cleared; every owned pet and active-follower selection is retained.

Normal room/depth/level and Spiritweaving achievement requirements return. A normally locked room rechecks and blocks service actions after OFF; its safe return remains available. Actual levels, earned milestones, talents, currencies and owned possessions are not reset. Turning access off while inside an eligible safe home room must preserve a reliable return route; it is not an item deletion operation.

## Saving and limits

Profile v11 introduced `tester_access = {version: 1, enabled: false}`. Profile v14/activity-v3 preserves that switch and original Beast/Echoes records while adding Gilded; older saves still default to OFF without changing earned progression. The first explicit v14 migration write must preserve exact pre-upgrade bytes in `.pre-v14.bak` through the existing validated temporary-file replacement; earlier `.pre-v13.bak`, `.pre-v12.bak`, `.pre-v11.bak` and other backups remain. Unsupported tester fields are preserved through read-only recovery behavior. Do not edit or delete a real save to simulate success.

The six new home rooms are part of the Stage 5 checkpoint. Only rooms implemented in the loaded build become available; a TEST ACCESS label is not a promise that planned rooms, biomes or online services exist. Physical Android touch comfort, rendering and performance still need device testing. See [Stage 5 validation status](personal-sanctuary-m5-validation.md) and the [historical Stage A report](tester-access-validation.md).
