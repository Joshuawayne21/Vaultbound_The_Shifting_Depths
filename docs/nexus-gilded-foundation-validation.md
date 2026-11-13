# Gilded Vault — unreleased data foundation

This internal Stage 5c checkpoint adds deterministic plans and profile14/activity3 migration. It does not release the Gilded gateway or claim native Gilded gameplay. The published playable baseline is Echoes `0.7.0-nexus5b`.

The baseline is local commit `07fac227c17e17afd0412a8edc6ffda5aff37eb5`, published as `3c629286046a604a006fbd3c620e4b606339916a`, with matching tree `a6831acf1443d11d5d2fcce0fec75189040633c4`. No existing item definitions, Beast/Echoes plans, player/combat code, room scenes, or Game routes changed in this checkpoint.

The new plan assembles six connected existing room modules using four mirrored/branch layouts and six rune orders. Rewards use existing Depthmarks/material/valuable IDs. Save migration preserves genuine version13 Beast or Echoes tickets, their serials and records, secured possessions, and earlier backups; it adds only an empty Gilded record. Loading alone does not write a profile. The first migration write retains exact prior bytes in a pre-v14 backup. Future data remains protected.

Godot 4.6.3 native validation passed import, 24 strict loads, 120 startup frames and **6,415 assertions in 22 modes**. The plan test covers 96 seeds and all four topology/six rune-order variants. Original Beast/Echoes plan, migration and session guards, historical profile migrations, tester access, save/loadout, party and inventory consumers passed. This focused gate is not the complete release regression suite.

- Frozen semantic source: `77051a2c037303d131b4601370beacd53e05551f9406a19c977a2d7f3151d773` (1,298 files).
- Run: `/workspace/scratch/vaultbound-nexus-gilded-validation/focused-y6zdb0e_`.
- Summary SHA-256: `f8e0fd6db885f6fe46c2b687227b838f656ff6d218051dea7966eeb6dcbb1553`.
- Independent review verified source/log hashes and 1,145 unchanged protected files outside four scoped changes: ActivityCatalog, ActivityProgression, ProfileStore, and the inventory's two version-admission lines.
- Four new script UIDs come from the accepted isolated import. Four old home/tester assertions follow the current profile version; their historical inputs and ownership/backup checks remain intact.

Room assembly, physical plate edges, guardian combat, trapped-cache timing, actual search/return, continuous companion navigation, and the Gilded UI still require integration and native tests. No rendered quality, Android device performance, online services, masks, or completed Gilded activity is claimed. Diagnostic counts from this checkpoint must not be added to a later full release total.
