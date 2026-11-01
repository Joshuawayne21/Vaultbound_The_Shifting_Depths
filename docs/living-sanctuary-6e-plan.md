# Spiritweaving integration — 6E

6D is the preserved starting checkpoint: local `8de48c66252017597ed0f393ef9c5aec93bc8995`, published as `6b4c5488a596ba7222bf39b825be078552d7c030`. Its complete gate passed 12,208 assertions in 70 suites / 86 invocations. This document records the integration plan. The completed 6E source passed 13,359 assertions in 80 suites / 97 invocations; see the [validation record](living-sanctuary-6e-validation.md) for evidence and resolved failures.

## Repair expedition ownership first

Inspection found pre-existing callback boundaries where an old world can continue after a listener replaces its expedition. Reward registration must not subsequently count a kill, unlock a boss exit, bind a loot view or return through an old extraction point in the replacement run. Each generated world and its sources will retain their original run identity. Valid encounter rewards, receipts, kill/boss state and new cosmetic findings must commit together before notifications. Run cleanup must finish before callbacks; failed extraction keeps all pending rewards for retry, and failed death-stat saving must not erase a callback-created run.

Existing loot generation, placement and inventory rules remain in use. Generic model-level reward helpers do not grant pet findings. Actual chests, caches, encounters, egg discoveries, rescues and extraction admit their real current-world sources, player, distance, visibility and generation. Tests will exercise same-seed replacement runs, stale sources, reentrant callbacks, repeat signals and failed writes.

## Data and save boundary

Add eight cosmetic species: Lantern Fox, Crystal Moth, Mossdrake, Embercap Sprite, Rift Otter, Rootling Guardian, Moonveil Butterfly and Starbound Wisp. Definitions, recipes and earned source weights use fixed local resources. All acquisition comes from existing Rootbound content and recorded exploration achievements; no unfinished biome or boss becomes a reward source.

Pet vessels or eggs, Rootbound essence and creature memories use a separate bounded cosmetic collection namespace. They do not consume or create ordinary inventory slots, become Depthmarks, change combat statistics or occupy AI party slots. Findings remain unsecured until the existing extraction save succeeds; death and abandonment lose only the current run's findings.

Profile version five adds validated pet ownership, aliases, ingredients, discoveries, achievements, active selection and fixed earned mutation provenance. Version-one through version-four saves receive defaults in memory without being rewritten on load. Preserve exact original bytes before the first migrated write, retain earlier backups and protect valid unavailable content from destructive fallback. Existing item IDs, unique equipment, rolls, enhancements, balances, progression, recruited companions and displays must survive unchanged.

One specimen per species and one selected pet keep the first collection bounded. An earned luminous mutation changes presentation only. Its result is fixed by the first secured matching creature-memory source; canceling quotes, reopening menus, failed saves or unrelated equipment transactions cannot reroll it.

## Conservatory and presentation

The existing western Conservatory terminal opens a source-bound recipe/journal panel. Show owned and undiscovered species, actual ingredient costs, achievement requirements, origin, active selection and a clearly marked native-mesh preview. Creation, selection, rest and bounded naming use opaque one-use quotes tied to the current profile revision and service source. Validate and save before publishing a change. Keep the same modal pause and input ownership through naming and confirmation.

One world-owned cosmetic follower follows a bounded history of positions the player actually walked. Short floor/obstacle checks constrain visible movement; it cannot explore or reveal hidden rooms. Cosmetic recovery hides the pet before a validated reposition. The pet has no collider, combat target, health, loot interaction or navigation obstruction. Idle, sit/perch, play and player-emote responses are finite visual states. World changes remove the old presenter and rebuild only the committed selection after floor registration.

Initial art is original procedural silhouette work, with no imported production model claim. Target at most twenty mesh instances / 1,800 triangles for the active pet, no new lights or particles, a bounded 128-point trail and ten decision updates per second. Reduced motion freezes decorative reactions while retaining ordinary following. A separate preview renders only on demand and never joins gameplay groups.

## Acceptance gate

Run focused source-lifecycle, migration/backup/restart, recipe/transaction, mutation stability, follower/world, UI and native naming checks. Then freeze the complete source and rerun every previous suite and independent reader, multiple generated layouts, combat, both cameras, portal/extraction flow, companion navigation and the full 6D native chat regression. Record failures and resolve critical issues before committing 6E.

Android keyboard composition, rendered pet silhouettes and attachment-free movement, touch comfort and sustained device performance remain manual checks. No network accounts, live marketplace, pet sales, real payments or new playable biome are part of 6E.
