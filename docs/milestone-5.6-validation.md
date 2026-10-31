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

**The frozen-batch gate passed 2,581 assertions across fourteen invocations.** Four focused catalog/source/economy invocations contributed 1,625, the independent preservation gate contributed 920 across nine invocations and the new representative runtime suite contributed 36. No full old combat replay was needed for this data-only batch. Final logs were clean, with no unresolved runtime regression. The committed-source publication gate remains separate.

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
