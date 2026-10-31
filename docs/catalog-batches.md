# Milestone 5.6 catalog batches

The original forty functional items and stable Depthmarks currency definition remain the independently tested starter set. Catalog growth is committed in separate, gated data batches. The target is **350 noncurrency definitions**, plus the preserved `gold_coin` record; this page reports only integrated content.

## Batch 7a: weapon definitions

The project currently has **84 total definitions**: 83 noncurrency items and one currency record. Weapons now total **50**, comprising 24 usable swords/staffs and 26 explicitly unavailable future weapon definitions. No additional combat family was implemented.

| Catalog group | Integrated | Final target |
| --- | ---: | ---: |
| Weapons | 50 | 50 |
| Armor | 10 | 85 |
| Accessories | 5 | 35 |
| Valuables | 0 | 80 |
| Materials | 12 | 45 |
| Consumables | 3 | 25 |
| Trophy artifacts | 3 | 30 |

The weapon batch adds seventeen supported items with distinct names, descriptions, lore and modest stat combinations. Six are acquired through the existing Equipment Trader and its three completed-expedition rotations. Two belong to common/basic rewards, two to reinforced/stronger rewards, three to ancient/cursed/elite rewards, and four to completed Rootwarden rewards. Required levels range from 1 to 27. No new recipe or material is needed for this batch.

Existing native loot rows and their weights remain unchanged, including the common chest's Ancient Shard weight of 0.02. Added rows share a budget equal to 10% of their table's pre-batch total weight for that rarity. This limits how much an expanded family changes the overall reward mix rather than assigning every new definition the full weight of an existing item. Each definition lists its exact real chest, encounter or merchant acquisition tags.

The twenty-six unavailable definitions cover greatswords, dual blades, spears, bows, scythes and magical gauntlets. They have no acquisition sources, no usable weapon style, no visual model, and `obtainable = false` / `combat_supported = false`. A generic archive icon is explicitly labeled catalog artwork. Trusted reward grants, equip, enhancement and merchant/loot source checks reject these definitions. Future models, animations and combat mechanics remain unfinished.

Supported items reuse the original sword/staff family icons and primitive display scenes. These are shared placeholders, not fifty unique completed models. Authored critical chance, lifesteal and ability cooldown effects use the already tested bounded equipment system; enhancement does not multiply those effects.

## Batch validation

`starter_sources_test.gd` retains the immutable 41-record starter audit while checking the current full manifest count. `item_catalog_test.gd` checks every integrated definition, explicit group totals, all active sources and all inactive definitions. `catalog_weapon_batch_test.gd` checks all 43 additions, exact source membership, unsupported-family rejection, each supported weapon's equip/stat/enhancement transaction, and byte-exact encoded save/reload intent. The real player/camera/HUD regression remains separate in `catalog_runtime_integration_test.gd`.

On Android, buy Lanternwatch Blade and Sporewood Focus from the Equipment Trader, assign both loadouts, inspect their shared family previews, and switch while moving in both cameras. Try the new dungeon weapon drops, secure them through extraction, upgrade them and restart. Confirm the normal inventory still has forty slots. Physical-device performance and touch behavior require manual testing; catalog test results are not device measurements.
