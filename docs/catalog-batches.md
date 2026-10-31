# Milestone 5.6 catalog batches

The original forty functional items and stable Depthmarks currency definition remain the independently tested starter set. Catalog growth is committed in separate, gated data batches. The target is **350 noncurrency definitions**, plus the preserved `gold_coin` record; this page reports only integrated content. The current total after batches 7a–7g is **351 definitions: 300 available noncurrency items, 50 unavailable future definitions and one currency record**.

## Batch 7a: weapon definitions

Batch 7a brought the project to **84 total definitions**: 83 noncurrency items and one currency record. Weapons now total **50**, comprising 24 usable swords/staffs and 26 explicitly unavailable future weapon definitions. No additional combat family was implemented.

| Catalog group | Integrated | Final target |
| --- | ---: | ---: |
| Weapons | 50 | 50 |
| Armor | 85 | 85 |
| Accessories | 35 | 35 |
| Valuables | 80 | 80 |
| Materials | 45 | 45 |
| Consumables | 25 | 25 |
| Trophy artifacts | 30 | 30 |

The weapon batch adds seventeen supported items with distinct names, descriptions, lore and modest stat combinations. Six are acquired through the existing Equipment Trader and its three completed-expedition rotations. Two belong to common/basic rewards, two to reinforced/stronger rewards, three to ancient/cursed/elite rewards, and four to completed Rootwarden rewards. Required levels range from 1 to 27. No new recipe or material is needed for this batch.

Existing native loot rows and their weights remain unchanged, including the common chest's Ancient Shard weight of 0.02. Added rows share a budget equal to 10% of their table's pre-batch total weight for that rarity. This limits how much an expanded family changes the overall reward mix rather than assigning every new definition the full weight of an existing item. Each definition lists its exact real chest, encounter or merchant acquisition tags.

The twenty-six unavailable definitions cover greatswords, dual blades, spears, bows, scythes and magical gauntlets. They have no acquisition sources, no usable weapon style, no visual model, and `obtainable = false` / `combat_supported = false`. A generic archive icon is explicitly labeled catalog artwork. Trusted reward grants, equip, enhancement and merchant/loot source checks reject these definitions. Future models, animations and combat mechanics remain unfinished.

Supported items reuse the original sword/staff family icons and primitive display scenes. These are shared placeholders, not fifty unique completed models. Authored critical chance, lifesteal and ability cooldown effects use the already tested bounded equipment system; enhancement does not multiply those effects.

## Batch 7b: armor definitions

Seventy-five supported armor definitions bring the armor catalog to **85**. Twelve named visual themes cover helmet, chest armor, gloves, leg armor, boots and off-hand shield, with three additional Ancient Relic pieces. Themes are descriptive families; no set bonus is implied or implemented. All pieces have their own authored identity, lore, modest bonuses, level requirement and salvage outputs using existing materials.

Fifteen pieces use existing Equipment Trader stock/rotations. Five enter common/basic rewards, twenty reinforced/stronger rewards, twenty-six ancient/cursed/elite rewards and nine completed Rootwarden rewards. The same 10% pre-batch rarity-weight budget applies; every previous row and weight stays intact. Shields use the sword family and retain its equipment rules. New armor reuses the existing family icons, display primitives and avatar appearance system; item-specific fitted meshes remain unavailable.

## Batch 7c: accessory definitions

Batch 7c adds thirty supported accessories: ten rings, ten necklaces and ten charms for the original accessory slot. The accessory catalog now totals **35**. Existing Amber Ring, Emerald Pendant and Sealed Reliquary assignments remain unchanged. Three new pieces use Equipment Trader stock, four common/basic rewards, six reinforced/stronger rewards, eleven ancient/cursed/elite rewards and six completed Rootwarden rewards. Existing row weights stay intact; new rows share the same small per-rarity budget. All pieces reuse family art and support the current bounded statistics and enhancement policy.

## Batch 7d: valuable definitions

Eighty collectible trade goods add ten authored finds in each of eight families: ancient coins, crown fragments, gemstones, statuettes, fossils, ceremonial antiques, lost expedition finds and monster remnants. Every definition has its own name, physical description, lore and value. Existing inventory stacks hold five, ten or twenty depending on the family and rarity. The existing merchant sale and owned Collection Hall display rules apply.

Twenty-four Common, twenty-four Uncommon, twenty Rare, eight Epic and four Legendary valuables use existing Rootbound chest and encounter sources. Each definition lists its exact acquisition paths; the native chest tables and filtered encounter tables retain those distinctions. All previous rows and weights remain intact, with new rows sharing 10% of each table's pre-batch rarity weight. Valuables reuse the existing relic family icon and display mesh, with no equipment statistics or new restorative effects.

## Batch 7e: material definitions and refinement recipes

Thirty-three material definitions bring the material catalog to **45**. Twenty-five new Rootbound ingredients have real chest or encounter sources and appear in eight executable refinement recipes. Twelve use common/basic rewards, seven reinforced/stronger rewards, four ancient/cursed/elite rewards, Guardian Bark Flake uses completed Rootwarden rewards, and Dense Corruption Knot comes only from defeated elites. All previous source rows and weights remain unchanged; new rows share the same 10% per-rarity budget.

The recipes produce existing Root Fiber, Emerald Dust, Mooncap Tonic, Stamina Draught, Tempered Ingot, Common Enhancement Stone, Aurora Bloom and Ancient Forged Core through the existing Blacksmith transaction flow. Their output definitions gain one additional craft-source tag each; every other pre-existing item field is preserved. The recipe catalog now has twenty recipes. Every new available ingredient has a current crafting use, and all ingredients use the existing material icon without claiming a display model.

Eight records for future boss components remain unavailable with empty acquisition sources and no executable crafting use. Their absent models are marked not applicable for the ingredient category. They cannot enter owned inventory or current loot, stock or recipes.

## Batch 7f: consumable definitions

Twenty-two consumable definitions bring the supply catalog to **25**. Sixteen new available supplies use the existing health and stamina restoration actions. Three are stocked by the General Merchant: Lanternleaf Tea at 18 DM, Reedwater Flask at 12 DM and Heartwood Broth at 33 DM, with six units of each per existing stock cycle. Two supplies use common/basic rewards, four reinforced/stronger rewards, six ancient chests and one completed Rootwarden reward source.

All previous item definitions, merchant offers and stock rotations remain intact. New loot rows share the same 10% pre-batch rarity budget. Authored stacks range from three to ten, and the existing consumable transaction handles restoration, quantity, protection and replay checks. The supplies reuse the existing potion family icon; no unique bottle model is claimed.

Six future resistance and utility supplies remain unavailable, with empty sources, zero restoration and no active special effects. Planned resistance/antidote, revival, return and detection mechanics are clearly marked as unavailable. At this checkpoint, the forty disabled definitions comprise twenty-six future weapons, eight future materials and these six future supplies.

## Batch 7g: trophy artifact definitions

Twenty-seven trophy artifacts complete the **30-item trophy catalog** and the **350 noncurrency definition target**. Seventeen new trophies have existing Rootbound acquisition paths: thirteen come from ancient chests and four from completed Rootwarden chest/encounter rewards. Each has its own authored identity and lore, one item per inventory stack, and bounded display configuration for the existing Collection Hall. Existing ownership, exhibition protection and journal rules apply.

Ten trophy records tied to future encounters remain unavailable with empty sources. Their honest shared relic-family icon and model metadata describe the existing generic artwork; ownership grants and acquisition remain blocked. The final unavailable total is fifty: twenty-six future weapons, eight future materials, six future resistance/utility supplies and ten future trophies. All prior definitions and source rows remain unchanged, and new rows use the same 10% rarity-weight budget. No additional encounter, combat mechanic or item-specific model is represented as implemented.

## Batch validation

`catalog_contracts.gd` holds explicit reviewed totals independently of resource data. `starter_sources_test.gd` retains the immutable 41-record starter audit. `item_catalog_test.gd` checks every integrated definition, group totals, active sources and inactive definitions. `catalog_weapon_batch_test.gd` preserves all 43 weapon checks. The reusable `catalog_equipment_batch_test.gd` verifies each armor and accessory definition's actual source, slot, stat bounds, protected ownership, enhancement cost and unchanged rolled instance properties; enhanced examples from each slot survive byte-exact encoded save/reload. `catalog_stackable_batch_test.gd` verifies authored valuable, material, consumable and trophy metadata, exact live acquisition tags, current material recipe uses, rejected future components/supplies/trophies, preserved prior merchant and source rows and the bounded rarity-weight additions. Oversized catalog rewards still fail atomically at forty inventory slots. The real player/camera/HUD regression remains separate in `catalog_runtime_integration_test.gd`.

On Android, buy Lanternwatch Blade and Sporewood Focus from the Equipment Trader, assign both loadouts, inspect their shared family previews, and switch while moving in both cameras. Try the new dungeon weapon drops, secure them through extraction, upgrade them and restart. Confirm the normal inventory still has forty slots. Physical-device performance and touch behavior require manual testing; catalog test results are not device measurements.
