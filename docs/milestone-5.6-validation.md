# Milestone 5.6 validation

## Checkpoint 1 — owned loadouts and safe save foundation

Validated on 2026-10-31 using **Godot 4.6.3 stable, Linux headless, Compatibility**. This checkpoint extends the existing Milestone 5.5 game; it does not complete the later Milestone 5.6 catalog, loot, character or UI overhaul stages. The staged scope and preservation rules are recorded in [the implementation plan](milestone-5.6-plan.md).

The checkpoint adds two saved owned weapon assignments, circular primary/secondary HUD controls, active selection, existing family icons, a short weapon presentation cue and a shared 0.32-second switch lock. Sword/shield and staff continue to use the existing actor, attack resources, damage rules, target lock and ability cooldowns. Only the active weapon contributes statistics. Empty slots do not display invented equipment. The original unassigned practice controller remains available.

Version-three profiles add the new equipment fields and active loadout without discarding the original shield or accessory assignments. Existing version-one and version-two saves migrate without resetting currency, equipment instances, modifiers, talents, companions, discoveries, displays or expedition statistics. The first migrated write preserves the exact old bytes as `profile.json.pre-v3.bak`; the verified rotating backup and atomic replacement path remain in use. Failure to preserve the migration backup blocks replacement. Future-version and damaged records remain protected from empty-default overwrite.

### Automated gate

**All 1,990 assertions passed across 28 engine invocations.** Each listed final game-test log was inspected for runtime/script errors, warnings and leaked resources and was clean. Counts include separate-process persistence readers/writers once each; exploratory probes and repeated debugging runs are excluded. This is the checkpoint regression gate, not a claim that every later-stage feature is complete.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `loadout_integration_test.gd`, runtime/read | 78 + 10 | Owned assignment/activation, inactive weapon statistics, models/abilities, switch guards, preserved cooldowns and attack IDs, both-camera joystick/touch use, one-hit damage, failed-save rollback and independent restart |
| `loadout_migration_test.gd`, main/write/read | 50 + 2 + 3 | Exact legacy backup bytes, strict version-three ownership/slots, protected failed writes and separate-process loadout persistence |
| `loadout_ui_test.gd` | 87 | Circular button geometry, icon/selection data, tap/release/cancel/drag behavior and equipment assignment interface |
| `combat_test.gd` | 177 | Shared sword/staff attacks, abilities, health/stamina, enemies, travel and death |
| `character_progression_test.gd` | 69 | Thirty levels, talents, real player statistics, weapon-family gating and prevention of free equipment healing |
| `rpg_integration_test.gd` | 117 | Existing services, trusted economy quotes, player/party equipment, Collection Hall, dungeon rewards, extraction and later wipe |
| `rpg_ui_test.gd` | 62 | Existing mobile menus/confirmations, equipment preview, modal switch recovery and unchanged paused gameplay clocks |
| `smoke_test.gd` | 321 | Every game resource, startup, movement, cameras, touch routing and original portal transitions |
| `expedition_test.gd` | 114 | Generated encounters, awareness, hazards, treasure, boss reward, extraction and later death |
| `rootwarden_test.gd` | 53 | Boss attacks, telegraphs, phase/modifiers, obstruction, hit deduplication and death |
| `visual_integration_test.gd` | 61 | Both cameras/all graphics tiers, portal occlusion, seeds 7/23/81, room visibility, Hall and preserved progression |
| `ui_layout_test.gd` | 247 | Combat geometry, multitouch ownership, cancellation and focus behavior |
| `party_ui_test.gd` | 137 | Tavern recruitment, commands, companion pause, downed/revive touch input |
| `expedition_ui_test.gd` | 19 | Minimap, inventory/results, notices and modal isolation |
| `visual_settings_test.gd` | 54 | Graphics presets, frame targets, separate preferences and touch confirmation |
| `inventory_economy_test.gd` | 114 | Forty-slot inventory, unique instances, recipes, protected ownership, equipment, costs and transaction rejection |
| `loot_persistence_test.gd` | 47 | Existing seeded loot, rarities, atomic saves, backup recovery and precision |
| `party_persistence_test.gd`, main/write/read | 70 + 5 + 8 | Companion migration, progression, extraction-only XP and separate-process recruited roster persistence |
| `save_migration_test.gd`, main/write/read | 42 + 3 + 19 | Original RPG save compatibility, reserves, recovery, enhanced/protected gear, talents, companions, trophies and displayed ownership after restart |
| `persistence_restart_test.gd`, write/read | 8 + 13 | Extracted rewards survive another engine process and subsequent dungeon death |

Tests use disposable `/tmp` profiles and isolated XDG user-data/config/cache directories. The two sequential checkpoint runners recorded **912 assertions in seven invocations** and **144 in eight invocations**, respectively. Save-foundation suites contributed **328 in seven**, and UI suites contributed **606 in six**.

Session evidence paths are `/tmp/vaultbound-56-checkpoint1/results.json`, `/tmp/vaultbound-56-checkpoint1-restart/results.json` and their adjacent suite logs. Additional final logs are `/tmp/vaultbound-m56-{loadout-migration,loadout-write,loadout-read,save_migration_test,inventory_economy_test,loot_persistence_test,party_persistence_test,loadout-ui,ui-layout,party-ui,expedition-ui,visual-settings,rpg-ui}.log`. These are execution-environment records, not files shipped with the game.

The final editor import exited successfully. `/tmp/vaultbound-56-a-final-import.log` contains only the environment's expected editor TCP socket/listener permission messages; it has no GDScript parse errors, missing-resource errors or warnings. Editor socket restrictions do not demonstrate Android export readiness.

### Regression found and resolved

An initial real UI test found that equipping a weapon inside a paused inventory modal started a switch lock which never expired: the player physics process was correctly paused with gameplay. The fix advances only the presentation switch timer from the existing game shell while the modal is open. It does not tick attacks, ability cooldowns, stamina or enemies. The final RPG UI test uses a real cooling ability and verifies its cooldown and stamina remain unchanged while the short switch lock expires and unequip becomes available. The gate passed after this fix; no unresolved critical regression remains in this checkpoint.

Legacy test fixture updates retain the six original occupied assignments while accepting the additional empty schema fields, and wait for the intentional short weapon lock where needed. Invalid ownership, transaction replay, save recovery and protection checks remain enforced. No capacity or combat correctness assertion was relaxed to obtain the passing gate.

### Android review still required

Use the import and controls instructions in [README](../README.md). With a backed-up existing save, verify:

1. Import the root `project.godot` in the Godot Android editor, retain Compatibility and run in landscape. Check the Sanctuary, companions, merchants and portals before entering a dungeon.
2. Secure a sword and staff through the existing game, assign primary/secondary slots in the equipment interface, and confirm their circles show the corresponding icons. Empty slots must not claim an owned weapon.
3. Hold the movement joystick while tapping either weapon circle with another finger, in both camera modes. Check active glow, model changes, ability labels, short cooldown feedback and smooth movement. Cancel a touch, drag off a circle and background/resume the application to check hardware input ownership.
4. Try switching during a charge, block, dodge and attack. The action must remain intact and the switch must be rejected. Switch away and back after a skill to confirm its original cooldown continues and no extra damage appears.
5. Change equipment inside the inventory modal, wait for the brief switch lock, then unequip. Gameplay must stay paused. Close the modal and verify combat resumes normally.
6. Restart with the secondary active and check both owned instances, active family, statistics and unrelated secured progression. For an older save, confirm the exact pre-migration backup exists before the first updated primary replaces it.
7. Complete an expedition with companions, extract, restart and then lose another expedition. Previously secured equipment, recruited companions and display references must remain intact.

**No physical Android device testing, rendered GPU visual inspection, APK export/signing, Android shader validation or measured 30/60 FPS claim is made.** Native family models/icons and procedural animation remain the available art; the switch cue is not a replacement production character rig. Later milestone checkpoints must still deliver and validate their own planned features before the full Milestone 5.6 completion report.

## Checkpoint 2 — mobile menus and accessibility

The existing UI now shares a navy, bronze/gold and turquoise presentation theme with distinct Inventory and Equipment HUD entries. Inventory sorting adds base value, lowest rarity, category and recently acquired instance order. The same-avatar equipment preview rotates on drag and requests a frame only when needed; switching tabs or closing the menu disables it. UI scale choices of 100%, 110% and 120% enlarge text and targets while inventory columns and equipment pages adapt. Reduced motion/effects choices use the separate versioned graphics preferences file and preserve gameplay saves.

**The final checkpoint gate passed 1,124 assertions across ten engine invocations from an exact Git source archive of commit `75ea869`.** All final game-test logs were clean. The nine UI/settings invocations contributed 802 assertions and the archive smoke run contributed 322. This archive gate supersedes the earlier 802-assertion working-tree gate; repeated runs are not added together.

| Suite | Passed assertions | Checkpoint coverage |
| --- | ---: | --- |
| `mobile_ui_integration_test.gd` | 152 | Three landscape canvases × three scale choices × two safe insets, HUD/party/combat separation, all equipment pages, Inventory/Equipment routing, charge/joystick cancellation, preview drag isolation, paused actors, hidden preview shutdown, sorting and touch-applied accessibility |
| `accessibility_preferences_test.gd`, main/read | 41 + 3 | Legacy graphics preferences, all new settings, verified atomic writes, separate-process restart, bounded reduced effects and malformed/truncated/future preference protection |
| `loadout_ui_test.gd` | 87 | Existing owned circles, icons, selection, cancellation and equipment assignment |
| `ui_layout_test.gd` | 247 | Existing combat control layout and multitouch/focus contracts |
| `party_ui_test.gd` | 137 | Recruitment, command/revive routing and party modal behavior |
| `expedition_ui_test.gd` | 19 | Minimap, results/notices and inventory modal isolation |
| `visual_settings_test.gd` | 54 | Existing quality/frame targets and saved preference integration |
| `rpg_ui_test.gd` | 62 | Existing commerce/crafting/equipment touch flow and correct modal pause clocks |
| `smoke_test.gd` | 322 | Exact-source resource loading, startup, movement, cameras, touch and original portals |

The focused real-game suite verifies that the secured progression file remains byte-for-byte unchanged after UI scaling, sorting, inspection and accessibility changes. It tests the existing avatar contract without depending on the later character overhaul, allowing this checkpoint to be committed and validated independently. Final archive evidence is `/tmp/vaultbound-56-c2-source-checks/results.json` and its adjacent suite logs. Earlier focused logs include `/tmp/vaultbound-m56-mobile-ui-integration.log`, the settings suite's isolated `/tmp/vaultbound-m56-accessibility/` fixtures and the retained UI suite logs named above. The exact archive imported without missing resources or script errors.

Preference review found that an empty or truncated legacy configuration could otherwise be interpreted as default settings. The final loader requires the existing quality and FPS fields before applying a legacy record, and tests verify that empty/partial records preserve the current choices. No unresolved critical checkpoint regression is recorded.

Android review must still check readable labels, long item descriptions and thumb comfort at all three scales, especially 120% on the smallest supported landscape display. Check notch/cutout safe areas, two-finger movement plus menu opening, preview dragging, tab changes, app background/resume and persistent reduced motion/effects. Headless geometry and input checks do not establish rendered glyph clipping, GPU preview quality or physical touchscreen behavior. The new theme uses original code-driven frames and existing family icons; no new production icon library is claimed.

## Checkpoint 3 — compatible character presentation

The existing procedural avatar gains rounded body surfaces, improved proportions and damped transitions for ordinary locomotion/combat poses. It retains the original controller, collision capsule, shoulder/hip pivots and sword/staff/shield grips. Dodge follows the existing complete waist-centered rotation, and essential attack cues remain immediate. Player, Guardian, Mystic and Equipment preview all instantiate the same visual script. Reduced motion/effects preferences affect optional presentation without changing attacks or movement rules.

The native avatar contains **53 mesh instances, 5,216 primitive triangles plus 38 existing cue triangles**, with 25 rounded surfaces sharing one sphere mesh. These are scene geometry counts, not a GPU timing result. Equipment tint materials remain independent per actor and preview; repeated appearance refresh does not compound coloration.

**The final exact-source archive gate passed 925 assertions across nine engine invocations** for local commit `9f2362b`, published as `fb394193`. The six focused suites below contributed 274 assertions; the archive additionally repeated combat (177), mobile UI integration (152) and smoke (322). The final archive total supersedes the earlier focused gate and does not add repeated runs together. All final game-test logs were clean.

| Suite | Passed assertions | Checkpoint coverage |
| --- | ---: | --- |
| `character_presentation_test.gd` | 21 | Shared rounded mesh budget, original grip anchors, independent/idempotent tints, finite poses, frame-rate convergence, complete dodge turn, immediate cues and reduced presentation |
| `party_character_integration_test.gd` | 35 | Actual player/Guardian/Mystic startup, unchanged capsules and collision layers, finite poses and stable grips, both camera modes, matching owned Equipment preview geometry/family/appearance and independent materials |
| `combat_presentation_test.gd` | 33 | Existing bounded combat feedback and accurate warning presentation |
| `character_progression_test.gd` | 69 | Existing actual-player equipment/stat contracts and prevention of free healing |
| `companion_behavior_test.gd` | 38 | Existing Guardian blocking, Mystic support, combat decisions and boss warnings |
| `loadout_integration_test.gd` | 78 | Owned weapon switching, model/ability updates, preserved attack/cooldown rules, touch/cameras and save rollback |

The independent real-party evidence is `/tmp/vaultbound-m56-party-character-integration.log`; final exact-source evidence is `/tmp/vaultbound-56-c3-source-checks/results.json` and adjacent logs. The avatar design, budgets and remaining art requirements are documented in [character presentation](character-presentation.md).

This is an original native-mesh/procedural-animation improvement, **not an imported production skeletal rig or an authored animation pack**. Tests establish finite transforms, preserved anchors/colliders and consistent representation; they cannot prove every rendered pose is free of clipping or that animation quality meets a final art bar. Physical Android/GPU review still needs to inspect hands, feet, armor, weapon silhouettes, animation transitions and both camera distances during movement, combat, dodge, block, damage and death. No physical-device test or frame-rate result is claimed.

## Checkpoint 4 — searchable encounter loot and Depthmarks

Registered Rootbound enemy deaths now reserve one reward source and present a searchable regular or reinforced cache. The Rootwarden owns one grand cache with its guaranteed Heart. Search opens the existing paused modal flow; selected Take, quantity controls and Take All transfer only the remaining contents into the existing unsecured expedition bag. Empty views disappear. Replayed death events, stale views, repeated confirmations and foreign/unregistered actors cannot regenerate a reward.

The existing gold balance is presented as **Depthmarks (DM)** without creating another writable currency balance or resetting a save. Configured monster ranges begin at 4–8 DM, stronger monsters at 8–18, elites at 25–50 and the boss at 120–250. Rewards become permanent through the existing verified extraction boundary. Sanctuary practice produces no bankable reward, and no quest/PvP reward system is represented as implemented. Merchant sale values and sale sorting use the actual condition/enhancement-aware quote calculation. Positive accepted reward transfers alone create bounded floating currency notifications.

Eight reusable cache views include one reserved boss view. The per-run ledger retains rewards when rooms are hidden or views are recycled; eligible nearby low-tier sources can consolidate. Floor projection and clearance checks keep visual caches approachable, and caches add no navigation collision. There is no second inventory system, multiplayer loot authority or client-controlled online reward flow.

### Automated gate and regression fixes

**The working-tree checkpoint gate passed 2,183 assertions across 30 engine invocations.** Counts include each final listed invocation once; earlier failed/debugging runs and repeated suites are excluded. All final game-test logs were inspected and clean. Local commit `a0fb2e0`, published as `4090b19`, additionally passed an exact-source archive gate of **543 assertions across five invocations**: smoke 330, Search runtime/read 149 + 14 and precision-save runtime/read 47 + 3. These repeated checks are reported separately, not added to the working-tree total. Archive evidence is `/tmp/vaultbound-56-c4-source-checks/results.json`.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `searchable_loot_integration_test.gd`, runtime/read | 149 + 14 | Real regular/elite/boss deaths across seeds 7/23/81; actual Search prompts, both cameras, quantity/Take/Take All, two-finger deduplication, canceled/dragged input, three landscape layouts, full-inventory retry, room reentry, three extractions and independent restart/later death |
| `loot_ledger_test.gd` | 44 | Stable sources, partial plans, receipts, bounded consolidation and configured encounter rewards |
| `loot_cache_world_test.gd` | 30 | Native floor/clearance checks over multiple layouts, eight-view budget, boss reservation, culling/recycling, obstruction and nonblocking models |
| `encounter_loot_test.gd` | 36 | Real basic/stronger/elite/boss hooks, alive/foreign rejection, reentrant/sequential duplicate deaths, source awareness and no practice farming |
| `session_loot_test.gd` | 75 | Real Session ownership, opaque quotes, partial currency/items, pending capacity, overflow, stale/reentrant requests, access checks and freed view/manager safety |
| `profile_roundtrip_test.gd`, main/read | 47 + 3 | Exact encoded save verification, floating-point boundaries, integer/identity protection, backups and independent restart |
| `expedition_test.gd` | 115 | Existing expedition/awareness/treasure/extraction/death rules, with boss collection adapted to real Search and Take All |
| `inventory_economy_test.gd` | 114 | Existing inventory capacity, ownership protection and atomic economy rules |
| `loot_persistence_test.gd` | 47 | Five thousand seeded chest samples, original rarity contract, save precision and recovery |
| `item_catalog_test.gd` | 348 | Existing catalog, recipes, stock, rarity/resources and acquisition contracts |
| `save_migration_test.gd`, main/write/read | 42 + 3 + 19 | Legacy progression, reserves, protected gear, displays and separate-process persistence |
| `party_persistence_test.gd`, main/write/read | 70 + 5 + 8 | Recruited companion identity/progression and separate-process persistence |
| `persistence_restart_test.gd`, write/read | 8 + 13 | Existing extracted ownership survives restart and later loss |
| `rpg_integration_test.gd` | 117 | Existing merchants, Blacksmith, Hall, equipped player/companions, extraction and wipe |
| `party_test.gd` | 88 | Existing recruitment, commands, rescue/wipe, combat and extraction |
| `companion_navigation_test.gd` | 26 | Physical companion traversal across seeds 7/23/81 |
| `ui_layout_test.gd` | 247 | Existing touch geometry/ownership and focus handling |
| `loadout_ui_test.gd` | 87 | Existing owned-weapon controls and equipment assignment |
| `rpg_ui_test.gd` | 66 | Existing transaction UI plus real sale-price sorting, matching trusted quote values and one sale from two fingers |
| `party_ui_test.gd` | 137 | Existing recruitment/commands/revive touch flow |
| `expedition_ui_test.gd` | 19 | Existing dungeon HUD/results and modal isolation |
| `visual_settings_test.gd` | 54 | Existing graphics/preferences behavior |
| `mobile_ui_integration_test.gd` | 152 | Existing scale/safe-area geometry, separate menus, inspection and accessibility |

The live Search test uses controlled lethal hits and positions, not a balanced human playthrough. Its capacity exercise injects disposable filler into its isolated test profile, then frees space through real consumable use and verifies partial retry. Only that injected filler is removed afterward. The death reader checks exact owned instances and the existing eight-point equipped-item durability loss; it does not incorrectly require death to leave condition unchanged.

A critical save regression surfaced during the second actual extraction: Godot's JSON parser selected an adjacent floating-point representation for a valid full-precision elapsed time (`0.9583029999999999` became `0.958303`). The previous exact comparison against the pre-encoding binary value rejected the healthy temporary file. The fix verifies the exact emitted bytes, validates the decoded representation of that same encoded intent and preserves exact discrete values recursively. It does not introduce approximate currency/count comparisons or reset saves. The failed extraction retained the existing primary and retryable bag; the corrected gate completes all three extractions, independent restart and later death.

Source review also removed the Rootwarden Heart from all four non-boss chest tables. Its former tiny probability now uses the existing Legendary Ancient Shard. This preserves the original five-rarity common-chest assertion while keeping the boss trophy tied to its completed encounter; the assertion was not weakened.

Evidence paths include `/tmp/vaultbound-56-checkpoint4-regression/results.json` (988 assertions across 16 final invocations), `/tmp/vaultbound-m56-search-{integration,read,expedition}.log`, `/tmp/vaultbound-m56-{loot-ledger,loot-world,session-loot,profile-roundtrip}.log` and `/tmp/vaultbound-stage4-*.log`. Additional focused independent-reader output was checked during the same session. No unresolved critical regression remains in this working-tree gate.

### Android review and limits

On a physical Android device, defeat a normal enemy, elite and Rootwarden, inspect cache placement/rarity cues from both cameras and verify Search/Take controls with two fingers. Fill the inventory, try Take All, collect only DM, use supplies to free space and retry the remaining items. Leave and revisit the room, extract, restart and lose a subsequent expedition; verify secured ownership survives. Check scrolling, canceled touches, app focus changes, modal pause, merchant sell-value previews and reduced-motion/effects behavior. Cache and currency feedback must stay readable without obscuring combat or causing visible frame stalls.

The prototype remains offline. Unsecured expedition rewards follow the existing run lifecycle and are lost on death/abandonment; this is not a mid-expedition application-crash resume system. Local save files are not an online security boundary. Shared family art and native cache geometry remain the available visual assets. No physical Android touch, rendered GPU placement, sustained frame-rate, thermal, APK export or multiplayer validation is claimed.

## Checkpoint 5 — functional starter catalog and rarity language

The native item registry now contains **40 functional noncurrency starter definitions plus the preserved currency record**, with every original ID retained. Four pieces fill the existing new gloves, leg armor, necklace and ring slots without displacing legacy accessories. Two higher-rarity weapons use the implemented sword/staff rules. Five new materials and four recipes extend the Blacksmith to twelve recipes. Elite fragments and Rootwarden essence require their completed encounters; the Heart remains boss-only. Future unavailable definitions cannot enter either direct inventory grants or the Session reward path.

Rarity presentation adds readable I–VII markers and full labels alongside colors, including dual turquoise/gold accents for Ancient Relics. Inventory/loot inspection exposes honest family-art and source information. This checkpoint does not claim the later 350-item expansion, +10 enhancement implementation, new weapon mechanics or unique production models. See [starter catalog](starter-item-catalog.md) for source paths and art status.

**The working-tree gate passed 2,506 assertions across 21 engine invocations.** The independent preservation runner contributed 1,355 assertions in fourteen invocations, the five catalog/economy/runtime/UI suites contributed 1,014, rarity presentation contributed 32 and the new real-game starter suite contributed 105. Repeated RPG UI runs are counted once. All final logs were inspected for errors, warnings and leaked resources and were clean; no unresolved critical regression remains. The committed source archive for `d0e727c` additionally passed **781 assertions across four invocations**: smoke 353, source eligibility 291, actual starter integration 105 and rarity UI 32. Archive evidence is `/tmp/vaultbound-56-c5-source-checks/results.json`; these repeated checks are not added to the working-tree total.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `starter_items_integration_test.gd` | 105 | Real player stat deltas, no free healing/resources, all four new equipment slots, legacy accessory coexistence, matching preview materials, active-only weapon bonuses, unavailable reward rollback, real seed-42 basic/elite/Rootwarden deaths, Search/Take/extraction, four recipe chains, level/material gates, exact costs, replay rejection and saved final state |
| `starter_sources_test.gd` | 291 | Forty-item starter boundary, all original IDs, exact source eligibility/reachability, earned elite/boss gates, seeded encounter samples, future-content rejection and legacy preservation |
| `item_catalog_test.gd` | 483 | Registry/resources, seven rarity definitions, stock, twelve recipes and acquisition contracts |
| `inventory_economy_test.gd` | 138 | Forty-slot capacity, instance ownership, real recipe ingredients and atomic transactions |
| `encounter_loot_test.gd` | 36 | Actual registered encounter hooks and duplicate/foreign death protection |
| `rarity_ui_test.gd` | 32 | Text/symbol/color rarity agreement, Ancient dual accents, honest art/source notes and unsupported-equipment actions |
| `rpg_ui_test.gd` | 66 | Real touch transactions, equipment/crafting and sale quote/value agreement with a bounded representative inventory |
| `smoke_test.gd` | 353 | All resources, startup, movement, cameras, touch and original portals |
| `combat_test.gd` | 177 | Existing shared combat, abilities, attacks and all three enemy archetypes |
| `character_progression_test.gd` | 69 | Existing player stats, equipment and progression contracts |
| `loadout_integration_test.gd`, runtime/read | 78 + 10 | Owned loadouts, combat restrictions, both cameras/touch and independent restart |
| `searchable_loot_integration_test.gd`, runtime/read | 149 + 14 | Three generated layouts, real Search/Take, capacity/reentry, extraction, restart and later death |
| `expedition_test.gd` | 115 | Existing dungeon, awareness, treasure, boss and extraction behavior |
| `loot_persistence_test.gd` | 47 | Seeded treasure, preserved rarity contract and save recovery |
| `save_migration_test.gd` | 42 | Existing progression migration and ownership protection |
| `party_persistence_test.gd` | 70 | Existing companion identity, progression and persistence |
| `rpg_integration_test.gd` | 117 | Merchants, Blacksmith, Hall, equipment, extraction and wipe |
| `party_test.gd` | 88 | Recruitment, commands, combat, rescue/wipe and extraction |
| `companion_navigation_test.gd` | 26 | Physical companion navigation across multiple generated layouts |

The new integration suite uses controlled levels and supplements legitimately defined crafting materials to exercise exact recipe boundaries; it does not claim a human level-fifteen playthrough or balanced acquisition rates. Its separate real encounter path proves that an elite and Rootwarden actually produce their gated materials, that the Search window transfers them and that extraction saves them. It then proves that a missing final boss essence prevents crafting without charging currency or consuming other ingredients. Preview checks establish matching equipment records and independent tint materials, not rendered armor-fit quality.

Evidence is `/tmp/vaultbound-56-checkpoint5-regression/results.json` and its fourteen adjacent logs, `/tmp/vaultbound-m56-starter-integration.log`, `/tmp/vaultbound-m56-stage5-live-{starter_sources,item_catalog,inventory_economy,encounter_loot}.log` and `/tmp/vaultbound-stage5-rarity-{ui,rpg-ui}.log`. The original catalog-sized RPG UI fixture was deliberately replaced by a representative 35-item fixture with authored stack limits; the inventory capacity and original touch/transaction assertions were retained.

Android review must buy/equip each new slot piece, compare stats and preview against gameplay in both cameras, inspect I–VII rarity labels at every UI scale, earn and search elite/boss materials, extract/restart and try both valid and blocked recipes at the Blacksmith. Check touch scrolling with a full inventory, icon clarity, armor/weapon clipping and protected legacy equipment. Native family display geometry and SVG icons remain explicit asset placeholders; no physical-device, rendered GPU, sustained FPS, thermal or APK result is claimed.

## Checkpoint 6 — enhancement, bounded equipment effects and save version 4

The Blacksmith now uses one native enhancement policy for deterministic prices, material requirements and rarity caps. Common through Legendary supported equipment stops at +5; Mythic and Ancient Relic equipment reaches +10. Existing accessories remain eligible, preserving their historical upgrades. Trophies, materials and unsupported weapons cannot be enhanced. The five original base-stat bonuses scale linearly by 8% per rank; new proc effects never scale with enhancement. The touch preview shows current/next ranks and statistics, exact DM/material costs and the applicable cap.

Four reusable equipment effects are functional: bounded critical chance, small confirmed-damage lifesteal, block strength and ability cooldown reduction. Critical chance caps at 20% with a 1.5× multiplier, lifesteal caps at 4% with one shared four-health budget per attack, block strength caps at 20% and ability cooldown reduction caps at 15%. An attack captures its effects once at the active edge. Later projectile impacts retain that snapshot through camera/loadout changes, and duplicate delivery cannot grant extra damage or healing. Ability reduction preserves original attack phases and stamina costs. Unsupported fire, frost and poison resistance effects are not rolled or represented as functional.

Version 4 preserves original instance identities, old modifiers/enhancements, both loadouts, protected gear, displays and companion progression. Legacy versions retain their original stricter boundaries; new caps and modifier keys are accepted only by the current format. Migration preserves exact backups. Missing, unavailable or unsupported owned content makes a save read-only instead of replacing it with empty defaults or silently selecting an older fallback. See [enhancement policy](enhancement-policy.md) and [equipment effects](equipment-effects.md) for the authored balance and limitations.

**Corrected checkpoint evidence: 2,828 passed assertions across 28 invocations, plus the separate 711-assertion committed-source gate.** Development originally recorded 3,152 across 29 invocations, but the 324-assertion starter-source run predated the final known-unavailable-content guard. A later audit of the committed checkpoint found one outdated fixture assertion in that suite, so its earlier pass is excluded rather than represented as final-source evidence. The independent preservation runner contributed 1,241 assertions in twelve runs and the enhancement writer/reader contributed 190. Local commit `dbd4018`, published as `c198ec5`, passed **711 assertions across six exact-source invocations**: smoke 358, schema 84, enhancement runtime/read 170 + 20, actual effects 40 and enhancement UI 39. Evidence is `/tmp/vaultbound-56-c6-source-checks/results.json`; repeated archive checks are not added to the working-tree total.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `enhancement_integration_test.gd`, runtime/read | 170 + 20 | Actual nearby Blacksmith, full common +5/Mythic +10/Ancient +10 chains, legacy accessory +6, independent expected costs/materials, protected ingredients, stale/replayed/read-only failures, same UIDs/modifiers, active-only stats, preview, cameras, separate-process restart, actual boss Search/extraction and later party wipe |
| `equipment_effects_integration_test.gd` | 40 | Real saved modifier-bearing equipment, actual staff critical projectile in flight across camera/loadout switches, original lifesteal rate, duplicate-impact rejection, actual shortened ability clock and shield block/stamina |
| `enhancement_policy_test.gd` | 54 | Authored price/material matrix, seven rarity caps, supported equipment eligibility, guaranteed transactions and inaccessible content restrictions |
| `equipment_effects_test.gd` | 49 | Seeded roll boundaries, nine modifier families, aggregate caps, actual armor/overkill/ward eligibility, four-health shared budget, bounded source-bound contexts, walls, duplicate sweep/projectile commits and interrupted windups |
| `enhancement_ui_test.gd` | 39 | Real upgrade previews, current/next stats/caps, touch confirmation deduplication, scrolling effect statistics and reduced presentation preferences |
| `profile_v4_test.gd` | 84 | Exact migration backups, preserved pre-v3 backup, strict legacy/current fields, unavailable/unsupported-content recovery and stale-writer protections |
| `loadout_migration_test.gd` | 50 | Existing owned loadouts, unique assignments and legacy progression migration |
| `profile_roundtrip_test.gd`, runtime/read | 55 + 3 | Nine modifier boundaries, exact encoded/discrete save verification, original precision regression and independent restart |
| `starter_sources_test.gd` | 324 earlier; excluded | Development run preceded the final availability guard; its stale legacy-reserve assertion is corrected and rerun in checkpoint 7a |
| `item_catalog_test.gd` | 483 | Existing forty-item registry, resources, rarity, recipes and source contracts |
| `starter_items_integration_test.gd` | 107 | Actual four-slot equipment, elite/boss materials, Search/extraction, recipes and rejection of unavailable or unsupported rewards before either bag or ledger mutation |
| `inventory_economy_test.gd` | 138 | Exact authored new uncommon-upgrade cost/material debit plus original capacity and transaction protections |
| `rpg_integration_test.gd` | 117 | Existing merchants, crafting, Blacksmith, Collection Hall, companions, extraction and wipe |
| `combat_test.gd` | 177 | Existing attack/combo/weapon rules and all enemy archetypes |
| `character_progression_test.gd` | 69 | Existing equipment statistics, progression and no free healing |
| `companion_behavior_test.gd` | 38 | Existing Guardian/Mystic combat and support behavior |
| `loadout_integration_test.gd` | 78 | Existing owned switching, shared cooldown/damage state, touch and both cameras |
| `rpg_ui_test.gd` | 66 | Existing commerce, equipment and crafting touch flows |
| `mobile_ui_integration_test.gd` | 152 | Existing safe-area/scale layouts, inspection, modal behavior and accessibility |
| `smoke_test.gd` | 358 | Resources, startup, movement, both cameras, touch and original portals |
| `searchable_loot_integration_test.gd`, runtime/read | 149 + 14 | Existing Search across three generated layouts, capacity/reentry, extraction, restart and later death |
| `expedition_test.gd` | 115 | Existing generation, awareness, boss, treasure and extraction |
| `save_migration_test.gd` | 42 | Legacy progression and protected ownership after the availability guard |
| `loot_persistence_test.gd` | 47 | Seeded chest contract, save precision and recovery |
| `party_test.gd` | 88 | Recruitment, commands, rescue/wipe, combat and extraction |
| `companion_navigation_test.gd` | 26 | Physical navigation through multiple generated layouts |

The new upgrade fixture supplies controlled levels, funds and currently obtainable materials to test every supported rank. It does not claim natural economy pacing or a human +10 progression playthrough. The separate restart reader verifies exact enhanced instances through extraction and death, allowing only the existing two-point extraction/eight-point death wear on equipped items. The real effect fixture uses bounded saved modifiers and a reproducible session seed; it does not replace attack methods or force an already committed effect context.

The real enhanced Equipment preview exposed a runtime formatter error: Godot does not support `%g`. The UI now renders those values through supported concise formatting, and both the actual upgrade/inspection suite and focused UI gate are clean. Two new test-fixture issues were also corrected without loosening gameplay rules: independent JSON expectations now pass through the same strict profile normalizer before exact comparison, and rejected loot registration is checked through its documented `ok: false` result. Neither correction changed production saving or reward behavior.

The later committed-source audit (`/tmp/vaultbound-c6-source-audit.log`) found that the starter-source fixture still expected a temporarily disabled legacy sword in playable inventory. The final availability guard correctly preserved that ownership in the legacy reserve. This was a missed fixture assertion, not production ownership loss. Checkpoint 7a now requires the exact preserved reserve and reruns the 324-assertion suite. The historical report does not claim that all 29 development invocations were clean on the final checkpoint-6 tree.

Evidence is `/tmp/vaultbound-56-checkpoint6-regression/results.json` and adjacent logs, `/tmp/vaultbound-m56-enhancement-{integration,read}.log`, `/tmp/vaultbound-m56-enhancement.log`, `/tmp/vaultbound-m56-effects-*.log`, `/tmp/vaultbound-m56-profile-v4.log`, `/tmp/vaultbound-m56-v4-*.log`, `/tmp/vaultbound-m56-stage6-{starter_sources,item_catalog}.log` and `/tmp/vaultbound-stage6-{enhancement-ui,rpg-ui,mobile-ui}.log`. The independent precision reader was also checked in its own engine process.

On Android, inspect every upgrade cost and current/next stat at all UI scales, cancel and confirm upgrades with multiple fingers, restart with +10 gear and verify both loadouts and Hall exhibits. Check critical/lifesteal feedback during moving combat in both cameras, projectile impacts while switching weapons, shield stamina and ability recovery. Confirm reduced motion/effects remains readable and menus scroll comfortably. Balanced drop rates, long-term upgrade affordability, rendered effects, sustained FPS, thermal behavior and physical touchscreen operation still require device play-testing; no physical Android/GPU or APK validation is claimed.

## Checkpoint 7a — weapon catalog batch

The first catalog batch adds 43 weapon definitions, bringing the registry to **83 noncurrency items plus the preserved currency record**. Its 50 weapon definitions comprise 24 usable swords/staffs and 26 explicitly unavailable future-family entries. The seventeen new usable weapons share existing combat mechanics and have authored acquisition paths. Unsupported greatswords, dual blades, spears, bows, scythes and magical gauntlets have no playable grant path, mechanics or completed unique artwork claimed.

Existing loot row weights remain unchanged. Supported additions together receive 10% of the previous weight within their authored source/rarity tier; this is a weight allocation, not a guaranteed ten-percent drop chance. Normal, stronger, elite and completed-boss sources retain their eligibility restrictions. Six supported weapons enter merchant stock. See [catalog batches](catalog-batches.md) for the exact enabled/disabled split and placeholder art policy. The full 350-item target remains pending subsequent batches.

**The frozen-batch gate passed 2,581 assertions across fourteen invocations.** Four focused catalog/source/economy invocations contributed 1,625, the independent preservation gate contributed 920 across nine invocations and the new representative runtime suite contributed 36. No full old combat replay was needed for this data-only batch. Local commit `210dab9`, published as `1e38569`, additionally passed **1,070 assertions across four exact-source invocations**: corrected starter sources 324, weapon batch 308, representative runtime 36 and smoke 402. Opening/closing semantic source manifests matched each other and the frozen working gate (`c74956026635fe87da5498ad3784b371526b25fbed89a2af590974529b850fb8`). Evidence is `/tmp/vaultbound-56-c7a-source-checks/results.json` and its source manifests. Repeated archive checks are reported separately. Final logs were clean, with no unresolved runtime regression.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_weapon_batch_test.gd` | 308 | Fifty weapon definitions, supported/future-family split, source eligibility, new usable gear ownership/equipment/save/upgrade contracts and bounded weight allocation |
| `item_catalog_test.gd` | 855 | Expanded native registry, resources, rarity, recipes and acquisition contracts |
| `starter_sources_test.gd` | 324 | Original starter sources, earned materials, effect metadata and exact reserved ownership for unavailable legacy content |
| `inventory_economy_test.gd` | 138 | Existing forty-slot and atomic transaction contracts against the expanded registry |
| `catalog_runtime_integration_test.gd` | 36 | Actual Lanternwatch Blade/Sporewood Focus assignment, independent stat expectations, real circular HUD icons, matching preview, held-joystick switching in both cameras, attack-time rejection and native disabled-greatsword reward/equip/upgrade safeguards |
| `smoke_test.gd` | 402 | Resource loading, startup, movement, both cameras, touch and original portals |
| `starter_items_integration_test.gd` | 107 | Existing gear/source/crafting chain and rejected unavailable or unsupported Session rewards |
| `loadout_integration_test.gd`, runtime/read | 78 + 10 | Existing owned weapon rules, touch/cameras and independent restart |
| `equipment_effects_integration_test.gd` | 40 | Existing actual modifier-driven projectile, ability and defensive behavior |
| `encounter_loot_test.gd` | 36 | Actual enemy/boss source registration and duplicate/foreign death rejection |
| `searchable_loot_integration_test.gd`, runtime/read | 149 + 14 | Changed reward tables through real Search, capacity/reentry, three generated seeds, extraction, restart and later death |
| `profile_v4_test.gd` | 84 | Versioned ownership and unavailable/unsupported-content recovery guards |

This batch also corrects the missed checkpoint-6 source-fixture expectation discovered by the committed-source audit: unavailable historical gear remains owned in the legacy reserve, alongside unknown legacy items. The new assertion checks that exact preserved ownership instead of expecting disabled equipment to remain playable. No production ownership rule was relaxed. The checkpoint-6 development aggregate above has been corrected to exclude its stale earlier source-suite pass.

The new runtime fixture owns a small representative set at a controlled level, clears only that fixture's random modifiers and compares the real actor with independently authored bonuses. It does not stand in for natural acquisition pacing or a production model review. Its touch gestures wait for the HUD's published availability after the actor cooldown, consistent with the existing input contract. The disabled native greatsword is tested through rejected grants, actual Session reward/equipment requests and strict forged-candidate validation; it never enters a saved playable inventory.

Evidence is `/tmp/vaultbound-56-checkpoint7a-regression/results.json` and adjacent logs, `/tmp/vaultbound-m56-catalog-runtime.log` and `/tmp/vaultbound-m56-weapons-{starter_sources,item_catalog,catalog_weapon_batch,inventory_economy}.log`. A post-gate semantic-source manifest is recorded at `/tmp/vaultbound-56-checkpoint7a-regression/source-manifest.json`; generated UID/import sidecars are excluded. Future gates record both opening and closing source manifests, and publication verifies the committed archive separately.

On Android, acquire the new sword/staff representatives, inspect their real family icons and item names, switch with a second finger while moving in both cameras, and confirm attacks still prevent invalid switches. Check menu readability, material/stat tooltips, Search rewards and later extraction/restart. Unsupported future families must remain unobtainable and unequippable. Shared sword/staff geometry and the generic future-catalog icon remain explicit placeholders; this batch does not add new weapon animations or physical-device performance evidence.

## Checkpoint 7b — armor catalog batch

This batch adds 75 armor definitions, reaching **158 noncurrency items plus the preserved currency record**, including 85 armor pieces. Existing weapon definitions, enabled/disabled families, original row weights and shared gameplay rules are preserved. Supported armor uses existing slots, statistics, protections and rarity-based enhancement caps. New source additions use the same bounded per-tier weight allocation as the weapon batch. These remain shared family visuals, not 75 newly modeled armor assets.

**The frozen-batch gate passed 3,861 assertions across ten invocations.** Catalog/source/economy suites contributed 3,086; five independent runtime/save/resource invocations contributed 775. Local commit `09028c4`, published as `0075413`, additionally passed **1,617 assertions across four exact-source invocations**: equipment batch 759, representative runtime 56, corrected starter sources 324 and smoke 478. Opening/closing archive manifests matched each other and the frozen working gate (`e1c0d77f8d96f9882a80754309ad51e39ab886fdd5d8e75b70f2dbb3a05e3287`). Evidence is `/tmp/vaultbound-56-c7b-source-checks/results.json` and its source manifests. Repeated archive checks are reported separately; all final logs were clean, with no runtime regression remaining.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_equipment_batch_test.gd` | 759 | Seventy-five new pieces, real acquisition paths, supported slots, stat bounds, protection/cap rules, exact first-upgrade costs and saved six-slot ownership |
| `item_catalog_test.gd` | 1,557 | Full 159-record registry, original IDs, resources, rarity, recipes and acquisition contracts |
| `catalog_weapon_batch_test.gd` | 308 | Preserved supported/future weapon split and original weapon source/equipment rules |
| `starter_sources_test.gd` | 324 | Original starter/material sources, effect metadata and exact unavailable legacy reserves |
| `inventory_economy_test.gd` | 138 | Existing forty-slot inventory and atomic commerce/crafting/enhancement behavior |
| `catalog_runtime_integration_test.gd` | 56 | Actual six-slot armor/shield equip, independently authored stat totals, no free healing/stamina, matching owned preview records and independent materials, sword-only shield visibility/bonuses, moving touch switches in both cameras and future-family rejection |
| `starter_items_integration_test.gd` | 107 | Preserved starter gear, real elite/boss sources, Search/extraction and recipe chain |
| `profile_v4_test.gd` | 84 | Current/legacy save validation and unavailable-content preservation |
| `loadout_migration_test.gd` | 50 | Preserved saved loadouts, unique assignments and existing progression |
| `smoke_test.gd` | 478 | Expanded resources, startup, movement, touch, cameras and original portals |

The runtime suite equips Wickwatch Cap, Lanternbound Coat, Flintkeeper Gloves, Watchpath Breeches, Evening Round Boots and Lamplighter Buckler alongside the prior sword/staff representatives. It checks the actual actor against independent authored bonuses and verifies that switching to the staff excludes the buckler's shield bonuses. Both inspected and gameplay equipment records match; chest color is checked through the existing torso material and other slots through their existing surface materials. The first draft incorrectly assumed that chest armor also used the per-slot surface map; correcting that fixture did not alter production visuals or weaken the owned appearance comparison.

Evidence is `/tmp/vaultbound-56-checkpoint7b-regression/results.json`, adjacent logs and `source-{opening,closing}.json`, plus `/tmp/vaultbound-m56-armor-{starter_sources,item_catalog,catalog_weapon_batch,catalog_equipment_batch,inventory_economy}.log`. The final five-suite independent gate was rerun after the fixture correction under one unchanged source manifest; earlier failed runs are not counted. No full generation/combat repeat was needed for this data-only category; those remain part of the final milestone gate.

On Android, obtain the representative equipment, meet its displayed level requirements, equip each slot and check health/stamina/armor statistics without gaining free current resources. Inspect the same pieces in the character preview, rotate it, and compare sword/shield and staff presentation in both cameras. Verify protected sales, enhancement previews, item labels and touch scrolling with a full inventory. Native family tints/models do not establish unique armor art, perfect clipping or physical-device performance; those checks remain manual.

## Checkpoint 7c — accessory catalog batch

Thirty new accessory definitions bring the registry to **188 noncurrency items plus the preserved currency record**, including 35 accessories. The batch adds ten rings, ten necklaces and ten legacy-slot charms. Existing Amber Ring, Emerald Pendant and Sealed Reliquary definitions and assignments remain intact. Source eligibility, existing loot row weights, the bounded addition policy and the forty-slot inventory are preserved.

**The frozen-batch gate passed 4,466 assertions across ten invocations.** Five catalog/source/economy suites contributed 3,649; the independent runtime/save/resource gate contributed 817. Local commit `b9b8131`, published as `b639bf3`, additionally passed **1,963 assertions across four exact-source invocations**: equipment batch 1,063, representative runtime 67, starter sources 324 and smoke 509. Opening and closing semantic source manifests matched each other and the frozen gate (`8b9ae3b664b4276d88f3b3b902f41ef0e5f8ee136048c2d617e59202b1ff0074`). Evidence is `/tmp/vaultbound-56-c7c-source-checks/`, including per-suite results and both manifests. Repeated archive checks are reported separately. All game-test logs were clean, with no failure or production regression; fresh editor import exited successfully with only the known sandbox socket and absent Android build-tools notices.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_equipment_batch_test.gd` | 1,063 | All new armor/accessory definitions, source/slot/stat/protection/cap rules, exact upgrade costs and nine saved gear-slot examples |
| `item_catalog_test.gd` | 1,816 | Full 189-record registry, original IDs, resources, rarity, recipes and acquisition paths |
| `catalog_weapon_batch_test.gd` | 308 | Preserved supported and disabled weapon families |
| `starter_sources_test.gd` | 324 | Original starter and earned-material sources, effects and exact legacy reserves |
| `inventory_economy_test.gd` | 138 | Original inventory capacity and atomic transaction protections |
| `catalog_runtime_integration_test.gd` | 67 | Actual ring/necklace/legacy-charm coexistence, independent expected statistics and saved assignments, matching per-slot preview materials, all six prior armor/shield checks, moving camera/touch switches and future-family rejection |
| `starter_items_integration_test.gd` | 107 | Original equipment/source/crafting path with actual Search and extraction |
| `profile_v4_test.gd` | 84 | Versioned ownership and unavailable/unsupported-content preservation |
| `loadout_migration_test.gd` | 50 | Preserved loadouts, assignments and existing progression |
| `smoke_test.gd` | 509 | Expanded resources, startup, movement, touch, cameras and original portals |

The representative runtime test equips Surveyor Copper Band, Waywatch Cord and Pilgrim's Knot together, verifies their independent ring/necklace/accessory UIDs, and checks that all three retain their actual saved slots. It preserves the six armor representatives and both weapon loadouts, compares the real actor with independently authored bonuses and checks the same appearance in the character preview. Controlled fixture levels and ownership do not claim natural acquisition pacing or additional unique 3D art.

Evidence is `/tmp/vaultbound-56-checkpoint7c-regression/results.json`, adjacent logs and `source-{opening,closing}.json`, plus `/tmp/vaultbound-m56-accessories-{starter_sources,item_catalog,catalog_weapon_batch,catalog_equipment_batch,inventory_economy}.log`. No broad combat or procedural generation replay was needed for this data-only category; the final milestone gate retains those regression checks.

On Android, equip the representative ring, necklace and charm simultaneously, inspect their labels/stat changes/preview, switch both weapon families and restart to confirm independent assignments. Check locked/favorited sale protection and the existing accessory slot on an older save. Shared family visuals, natural economy balance, rendered clipping and physical-device responsiveness remain manual review items; no device testing is claimed.

## Checkpoint 7d — valuable catalog batch

Eighty collectible trade goods bring the registry to **268 noncurrency items plus the preserved currency record**. Eight families each receive ten distinct authored finds, using the existing bounded stacks, merchant sale rules and owned Collection Hall references. None adds equipment bonuses or a second currency balance. Existing source rows and weights remain unchanged; additions share the established 10% pre-batch rarity-weight allocation. The relic family icon and model remain shared placeholders.

**The frozen-batch gate passed 5,339 assertions across eleven invocations.** Seven catalog/source/economy suites contributed 4,621; the independent category/save/resource gate contributed 718. Local commit `b437c21`, published as `98d42a8`, additionally passed **1,476 assertions across five exact-source invocations**: stackable batch 518, category runtime/read 32 + 12, starter sources 324 and smoke 590. Opening and closing semantic source manifests matched each other and the frozen gate (`c51ff3c3485e65b21463f3eb5eac2f397c6ff93a1ba2a11b35f9ce781703dd0d`); the focused gate's source records match that same semantic source. Archive evidence is `/tmp/vaultbound-56-c7d-source-checks/`. Repeated publication checks are reported separately, and all final game-test logs were clean.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_stackable_batch_test.gd` | 518 | Eighty authored valuable definitions, exact native source tags, unchanged existing rows/weights, bounded rarity additions, noncombat metadata and honest family art |
| `item_catalog_test.gd` | 2,216 | Full 269-record registry, original IDs, resources, rarity and acquisition contracts |
| `catalog_equipment_batch_test.gd` | 1,063 | Preserved armor/accessory source, equipment, enhancement and saved-instance contracts |
| `catalog_weapon_batch_test.gd` | 308 | Preserved supported and disabled weapon definitions |
| `starter_sources_test.gd` | 324 | Original starters, earned materials and unavailable legacy ownership reserves |
| `inventory_economy_test.gd` | 138 | Existing forty-slot capacity, protected ownership and atomic transactions |
| `enhancement_policy_test.gd` | 54 | Existing guaranteed enhancement costs, rarity caps and bounded bonuses |
| `catalog_category_integration_test.gd`, runtime/read | 32 + 12 | Native valuable rolls through real chests, actual Rootwarden-authorized extraction, exact partial sale/replay protection, favorite/display protection, owned Hall model, independent restart and later actual death |
| `profile_v4_test.gd` | 84 | Versioned saved ownership and unavailable/unsupported-content preservation |
| `smoke_test.gd` | 590 | Expanded resource loading, startup, movement, touch, cameras and original portals |

The new integration fixture searches deterministic seeds in the unmodified common table for Mossworn Obol and Square Temple Copper, then opens actual chest instances and extracts their exact contents and DM. Controlled prior ownership supplies four extra obols for a partial sale: two full-condition obols produce exactly six DM, leave the same remaining stack UID and cannot replay. The temple copper's Hall display resolves its existing owned UID and model; displaying neither creates nor consumes inventory. A separate engine process reloads the exact saved profile, reconstructs the exhibit and verifies secured ownership after a later death.

The first development reader correctly failed to trigger death while the new arrival's spawn invulnerability was active. The fixture now clears the same player/combat invulnerability fields used by the existing Search reader before its controlled lethal hit. Production behavior was unchanged. Both final gates were rerun on the corrected unchanged source; the earlier development invocation is excluded from the total.

Evidence is `/tmp/vaultbound-m56-7d-focused-final/results.json` and source-before/after records, plus `/tmp/vaultbound-56-checkpoint7d-regression/results.json`, adjacent logs and source-opening/closing manifests. Fresh import succeeded with the known sandbox editor-socket and missing Android build-tools notices. A controlled source-selection and transaction fixture does not establish natural drop pacing, economy balance or a human boss playthrough.

On Android, collect valuable drops, inspect their names and stacks, extract, sell part of a stack, favorite the remainder and display a different owned valuable. Confirm protected sales, restart persistence and later expedition loss. Shared relic geometry, rendered readability, physical touch comfort and sustained performance remain manual review items; no device/GPU or APK result is claimed.

## Checkpoint 7e — material and refinement batch

Thirty-three material definitions bring the registry to **301 noncurrency items plus the preserved currency record**, including 45 materials. Twenty-five new materials are obtainable through existing Rootbound sources and have actual recipe uses. Eight future-encounter components remain explicitly unavailable. Eight refinement recipes extend the Blacksmith to twenty recipes and produce existing fibers, dust, supplies, ingots, enhancement stones, bloom and core components. No new material bypasses earned elite/boss sourcing or the forty-slot inventory.

**The frozen-batch gate passed 5,921 assertions across eleven invocations.** Seven catalog/source/economy suites contributed 5,142; the independent category/save/resource gate contributed 779. Local commit `9910b32`, published as `3ee1b34`, additionally passed **1,654 assertions across five exact-source invocations**: stackable batch 789, category runtime/read 51 + 12, economy 170 and smoke 632. Opening/closing archive manifests and both working gates cover the same unchanged semantic source (`19124290ce688f7fb8d234cf7b1936516c131e94e74c3c39ccda8b1b1f34ea44`). Archive evidence is `/tmp/vaultbound-56-c7e-source-checks/`. Repeated archive checks are separate from the working total. Final logs were clean on the first integration run, with no production or fixture fix needed.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_stackable_batch_test.gd` | 789 | Valuable/material definitions, exact source eligibility and weight preservation, real recipe uses, disabled future components and bounded stacks |
| `item_catalog_test.gd` | 2,434 | All 302 records and twenty recipes, category-appropriate disabled-art metadata and filtered native encounter-source reachability |
| `catalog_equipment_batch_test.gd` | 1,063 | Preserved armor/accessory equipment, protection, enhancement and saving |
| `catalog_weapon_batch_test.gd` | 308 | Preserved supported and disabled weapon definitions |
| `starter_sources_test.gd` | 324 | Original starters, earned-source restrictions and exact legacy reserves |
| `inventory_economy_test.gd` | 170 | Existing inventory/transaction contracts and all eight new recipe transactions |
| `enhancement_policy_test.gd` | 54 | Preserved guaranteed costs, caps and bounded modifiers |
| `catalog_category_integration_test.gd`, runtime/read | 51 + 12 | Actual new-material chest/extraction, real Blacksmith refinement, locked-input/replay guards, future-material grant/reward/Search rejection, preserved valuable trade/display and independent restart/later death |
| `profile_v4_test.gd` | 84 | Versioned saved ownership and unavailable-content preservation |
| `smoke_test.gd` | 632 | Expanded resource loading, startup, movement, touch, cameras and original portals |

The runtime extension obtains Rootbark Strip through an unmodified native chest, then uses a real nearby Blacksmith to spin six Root Fiber for eight DM and forge one Ancient Forged Core for 150 DM. Independently authored expected ingredient/output counts match the committed inventory exactly. Locked root bark prevents spending; repeated confirmations cannot apply another craft. Controlled level-thirty ownership supplies the small elite/boss ingredient fixture and does not claim natural farming or economy pacing. Active Session reward and Search registration reject the unavailable Leviathan Scale without reserving receipts or changing pending items/DM.

The catalog fixture now distinguishes unavailable weapon art from materials, whose display models are not applicable, and includes actual filtered encounter entries when auditing acquisition reachability. These changes preserve disabled-content rejection while covering the new category correctly. Existing resource definitions only gain their truthful additional crafting-source tags; previous loot rows, gameplay and stack rules remain intact.

Evidence is `/tmp/vaultbound-m56-7e-focused-final/results.json` and matching source-before/after records, plus `/tmp/vaultbound-56-checkpoint7e-regression/results.json`, adjacent logs and source-opening/closing manifests. Import completed with only the known sandbox editor-socket and Android build-tools notices.

On Android, obtain ordinary, elite and boss material representatives; inspect recipe requirements, lock an ingredient, attempt a craft, unlock it and confirm exact costs/output. Restart after crafting and verify ownership through a later loss. Future components must remain unavailable. Drop pacing, affordability, rendered readability and physical-device performance remain manual review items.

## Checkpoint 7f — consumable catalog batch

Twenty-two definitions bring the registry to **323 noncurrency items plus the preserved currency record**, including 25 consumables. Sixteen new supplies use the existing health/stamina restoration mechanics; six entries requiring unavailable resistance, antidote, return, detection or revival mechanics remain disabled. Three supported supplies enter the General Merchant. No unsupported consumable effect is represented as functional.

**The frozen-batch gate passed 4,752 assertions across seven invocations.** Four focused catalog/source/economy suites contributed 4,011; three independent runtime/read/resource invocations contributed 741. Local commit `b0c4c0a`, published as `86d5675`, additionally passed **1,699 assertions across four exact-source invocations**: stackable batch 958, category runtime/read 74 + 12 and smoke 655. Opening/closing archive manifests and both working gates match the same semantic source (`1497b0161a40da8c8c143709d97af6d138261516f1ea5fb3d5994eefb5a7fb4a`). Archive evidence is `/tmp/vaultbound-56-c7f-source-checks/`; repeated publication checks are reported separately. All final logs were clean on the first run. Preserved armor, weapon, enhancement and broad combat suites are retained for the complete final milestone gate.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_stackable_batch_test.gd` | 958 | All authored stackable categories, supported restoration bounds, actual merchant/chest sources, disabled future supplies, existing source rows and bounded additions |
| `item_catalog_test.gd` | 2,559 | Full 324-record registry, category totals, resources, recipes and source eligibility |
| `starter_sources_test.gd` | 324 | Original starter and earned-material contracts |
| `inventory_economy_test.gd` | 170 | Existing capacity, protection, crafting and exact transaction rules |
| `catalog_category_integration_test.gd`, runtime/read | 74 + 12 | Actual new-supply purchases and chest/extraction, authored actor restoration, single-unit use, replay/full-resource rejection, disabled antidote reward/grant guards and independent ownership restart |
| `smoke_test.gd` | 655 | Expanded resource loading, startup, movement, touch, cameras and original portals |

The runtime extension buys Lanternleaf Tea and Reedwater Flask through a real merchant, acquires Ambermoss Salve through an unmodified native chest and uses all three on the actual player. Their independent expected effects are respectively 20 health/10 stamina, 25 stamina and 25 health. Each saved use consumes exactly one unit without changing DM; repeated confirmation and use at full health/stamina cannot waste another supply. Bitterroot Antidote remains unavailable, with no substitute restoration effect; active Session reward and Search registration reject it without creating items, receipts or currency. The separate reader verifies the resulting supplies and crafted/valuable ownership through restart and later death.

Evidence is `/tmp/vaultbound-m56-7f-focused-final/results.json` and matching source-before/after records, plus `/tmp/vaultbound-56-checkpoint7f-regression/results.json`, logs and source-opening/closing manifests. Fresh import succeeded with only known editor-socket and Android build-tools environment notices. The fixture establishes current effects and transactions, not balanced supply pricing or natural progression pacing.

On Android, buy and collect these supplies, compare their descriptions with actual restoration, test full-resource rejection and restart after use. Future effect entries must remain unobtainable. Physical touch comfort, rendered feedback and device performance remain manual review items.

## Checkpoint 7g — trophy artifacts and completed catalog

Twenty-seven trophy artifacts complete **350 noncurrency definitions plus the preserved currency record**. The final catalog has 50 weapons, 85 armor pieces, 35 accessories, 80 valuables, 45 materials, 25 consumables and 30 trophy artifacts. **300 noncurrency definitions are currently obtainable; 50 future definitions are explicitly unavailable**: 26 unsupported weapons, eight future materials, six supplies requiring unimplemented mechanics and ten artifacts tied to unavailable encounters.

Seventeen new artifacts use existing Ancient Chest or completed Rootwarden sources. The other ten have no acquisition path and cannot enter playable inventory or rewards. Their catalog artwork may truthfully reuse the existing relic family icon/model; shared placeholder art does not imply an implemented encounter. The existing Rootwarden Heart remains tied to the real boss reward and retains its singular ownership path.

**The frozen-batch gate passed 5,155 assertions across seven invocations.** Four focused catalog/source/economy suites contributed 4,372; three independent runtime/read/resource invocations contributed 783. Both gates and their opening/closing manifests match the unchanged semantic source (`4a9d89c22f15910887d570dab07f40b874288da02ba8160356ca9e6b8b8e8345`). All final logs were clean on the first run. Committed-source checks and the complete milestone regression remain separate.

| Suite | Passed assertions | Coverage |
| --- | ---: | --- |
| `catalog_stackable_batch_test.gd` | 1,174 | All authored stackable/trophy categories, exact active/disabled split, current source restrictions, existing rows and bounded weight additions |
| `item_catalog_test.gd` | 2,704 | Complete 351-record registry, exact seven group totals, resources, recipes, native sources and honest disabled-art metadata |
| `starter_sources_test.gd` | 324 | Original starters, earned-material and unavailable legacy-ownership contracts |
| `inventory_economy_test.gd` | 170 | Preserved forty-slot inventory, protection and atomic transactions |
| `catalog_category_integration_test.gd`, runtime/read | 87 + 13 | Native artifact chest/extraction, actual owned trophy display without stat/ownership changes, protected sale, future-boss artifact rejection, two independently restarted exhibits and later death |
| `smoke_test.gd` | 683 | All expanded resources, startup, movement, touch, cameras and original portals |

The runtime extension selects Singing Stone Idol from the unmodified Ancient Chest table, opens a real chest and extracts the artifact through the existing boss-authorized boundary. Its Hall pedestal resolves that exact owned UID without consuming inventory or changing equipped statistics. The independent reader reconstructs both the valuable and trophy exhibits and confirms their saved references survive a later death. Hollow King's Crown is checked as an actual unavailable catalog definition: neither direct inventory grant nor active Session reward/Search registration can mint its ownership, DM or receipt. No missing boss is spawned or represented as playable.

Evidence is `/tmp/vaultbound-m56-7g-focused-final/results.json` and matching source-before/after records, plus `/tmp/vaultbound-56-checkpoint7g-regression/results.json`, logs and source-opening/closing manifests. Fresh import succeeded with only the known sandbox editor-socket and absent Android build-tools notices. Native family visuals remain shared placeholders; source eligibility and controlled acquisition do not establish unique artwork or balanced natural drop rates.

On Android, acquire an existing-source artifact, extract it, assign its owned reference, restart and confirm later expedition loss preserves the exhibit. Future encounter artifacts must remain unavailable. Inspect labels, family models and collection readability; rendered appearance, physical input and performance remain manual checks.
