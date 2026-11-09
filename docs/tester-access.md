# Offline test access

Build `0.7.0-test1` adds a saved **TEST ACCESS** switch for the current offline profile. It starts **OFF**. The scoped validation passed 3,562 checks across 38 runtime modes; rendered and physical Android review remain pending. It is not an online account entitlement, and it cannot be enabled on your phone remotely from the cloud.

## Enable once on your device

1. Back up the existing phone profile and its backup files. Import the matching published build from `feature/personal-sanctuary`, using a new clearly named folder. Verify root `project.godot` shows `config/version="0.7.0-test1"` before testing; an older extraction/default branch lacks this switch.
2. Return to the Sanctuary or your home and finish any action. Open **SETTINGS → TEST ACCESS** (the fourth tab).
3. Select **ON · TEST IMPLEMENTED CONTENT → REVIEW CHANGE → CONFIRM & SAVE**.
4. Check **SAVED TEST ACCESS: ON** and the **TEST ACCESS ON** HUD badge. Restart once to confirm the saved choice is retained. Cancelled review or a failed save does not enable it.

The switch is per saved profile, so enable it once for each profile you actually use. It cannot change during an expedition, combat action, travel, an unfocused application or a read-only/invalid save. The panel explains why a change is unavailable.

## What it opens

| Content | Test access behavior |
| --- | --- |
| Implemented home rooms | Bypasses earned room milestones; use the normal marked door or Home Management route |
| Implemented home themes/sigils | Allows previewing and applying unearned appearances without recording them as earned |
| Dungeon depths 1–50 | Allows selection before sequential unlock; existing implemented theme pools, encounters and combat still apply |
| Owned supported equipment | Ignores its level requirement; ownership, valid slot and supported weapon-family rules remain |
| Existing crafting recipes | Ignores recipe level requirements; ordinary material and Depthmark costs still apply |

Spiritweaving achievement requirements are not bypassed in this checkpoint. A test-access Conservatory visit may be empty: the room opens, but displaying a pet still requires owning it.

This does **not** grant unowned items/pets, free currency, materials, talent points, XP, purchased cosmetics or unfinished content. Existing Spiritweaving pet-achievement requirements are not bypassed in this checkpoint. Existing prices, upgrade costs/caps, inventory capacity, display ownership and earned talent points remain required. It does not enable online servers, ranked PvP or multiplayer privileges. A test-only clear above your earned highest unlocked depth does not skip the permanent sequential depth ladder. Ordinary run rewards still follow the existing extraction/death/save rules.

## Turn it off safely

Use **SETTINGS → TEST ACCESS → OFF · NORMAL REQUIREMENTS → REVIEW CHANGE → CONFIRM & SAVE**. The review lists necessary cleanup before committing:

- Gear above your real character level is unequipped but remains in inventory.
- An unearned home theme/sigil returns to Royal Azure/Vault Diamond. Already-earned selections stay valid.
- Pet display references relying on an unearned Conservatory unlock are cleared; every owned pet and active-follower selection is retained.

Normal room/depth/level requirements return. Actual levels, earned milestones, talents, currencies and owned possessions are not reset. Turning access off while inside an eligible safe home room must preserve a reliable return route; it is not an item deletion operation.

## Saving and limits

Profile v11 adds `tester_access = {version: 1, enabled: false}`. Older saves default to OFF and keep existing progression. The first explicit migrated write uses the existing exact `.pre-v11.bak` backup and validated temporary-file replacement; earlier backups remain. Unsupported tester fields are preserved through read-only recovery behavior. Do not edit or delete a real save to simulate success.

The next Sanctuary/home-room checkpoint is separate work. Only rooms implemented in the loaded build become available; a TEST ACCESS label is not a promise that planned rooms, biomes or online services exist. Physical Android touch comfort, rendering and performance still need device testing. See [validation status](tester-access-validation.md).
