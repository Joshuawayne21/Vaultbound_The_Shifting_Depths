# Functional starter catalog checkpoint

Milestone 5.6 checkpoint 5 retains every original item ID and adds eleven definitions: **40 noncurrency starter items plus the stable `gold_coin` currency record**, displayed as Depthmarks. This page records that independently tested starter subset. Subsequent [catalog batches](catalog-batches.md) reach 350 noncurrency definitions while preserving these items.

## Shared data and ownership

`resources/catalogs/items.tres` is the export-safe native registry. Each ID resolves to its authored `resources/items/<id>.tres` resource. `VaultLootTable.catalog()`, `item_for()` and the compatibility `ITEM_IDS` accessor remain available; callers receive a copied ID array. Inventory instances still own UID, quantity, modifiers, enhancement, durability and protections. Shared resources never hold player ownership.

`catalog_group` describes weapon, armor, accessory, valuable, material, consumable, trophy or currency without changing legacy inventory categories. Legacy `amber_ring`, `emerald_pendant` and `sealed_reliquary` remain assigned to the original `accessory` slot. New necklace and ring pieces use their separate slots.

Definitions declare `weapon_family`, `combat_supported`, `obtainable`, lore, exact acquisition source tags, family-art status, display motion and aura profile. `can_equip()` permits only implemented equipment. `allows_source()` gates authored chest, encounter, merchant and recipe sources. Future mechanics must not be enabled merely by labeling a definition with a new family.

## New functional equipment

| Item | Slot/family | Existing behavior | Acquisition |
| --- | --- | --- | --- |
| Trailgrip Gloves | Gloves | Small stamina and armor bonuses | Equipment Trader |
| Expedition Trousers | Leg Armor | Small health and armor bonuses | Equipment Trader |
| Wayfarer Necklace | Necklace | Small health and stamina bonuses | Equipment Trader |
| Sentinel Ring | Ring | Small armor and stamina bonuses | Equipment Trader |
| Verdant Oathblade | Sword, Mythic | Existing sword/shield attacks; health and damage bonuses | Completed Rootwarden reward or earned-component recipe |
| Vaultheart Staff | Staff, Ancient Relic | Existing staff attacks; stamina and damage bonuses | Completed Rootwarden reward or earned-component recipe |

The high-rarity weapons require levels 10 and 15 respectively. They do not introduce a new weapon mechanic. Checkpoint 6 adds the shared [enhancement policy](enhancement-policy.md) and [bounded equipment effects](equipment-effects.md), preserving existing instance rolls.

## Earned material chain

- Common Enhancement Stones appear in current chest/monster tables and General Merchant supplies.
- Elite Monster Fragments are guaranteed only after a completed elite encounter. They are absent from ordinary ancient chests.
- Rootwarden Essence is guaranteed with the existing Rootwarden Heart only after the completed Rootwarden encounter. Neither appears in ordinary chest tables or merchant stock.
- Ancient Forged Cores consume elite fragments, Rootwarden essence and tempered ingots at the Blacksmith.
- Ancient Heartstones consume a forged core, additional earned Rootwarden essence and ancient shards.

Two further recipes create the high-rarity sword/staff from these earned components. All twelve current recipes have independent acquisition paths for every ingredient. No future boss component is enabled. Monster currency remains controlled by the separate 4–8, 8–18, 25–50 and 120–250 DM encounter bands; currency items cannot silently increase those ranges.

## Art status

Icons are original vector family icons, including four new gloves, leg armor, necklace and ring symbols. Display models remain inexpensive native primitive family placeholders. `icon_art_status` and `model_art_status` expose that distinction; no unique sculpted item, rigged armor or high-quality character asset is claimed. The new models have no collision or real-time lights and fit the existing display bounds. The integrated [presentation system](item-presentation.md) applies their bounded display animation and aura configuration.

## Validation and Android review

`starter_sources_test.gd` checks the forty-item boundary, all original IDs, live source equality and acyclic ingredient reachability, boss/elite restrictions, deterministic rewards, unchanged encounter currency bands, copied metadata, compatible loadouts and the four new gear slots. Existing catalog, inventory/economy, encounter and mobile-menu tests remain part of the gate. UI fixtures use a representative 35-item set so a larger catalog cannot silently increase the forty-slot inventory.

On Android, buy and equip the four new slot pieces, check bonuses and both cameras, defeat an elite and the Rootwarden, search their caches, extract, restart, then craft the earned-component recipes. Confirm protected old gear and companion progression remain intact. Check family icon clarity and preview clipping at supported UI scales. These instructions are manual requirements, not a claim of physical device testing.

Source gates are an offline configuration boundary, not multiplayer security. Future online grants and transactions must be authorized by a trusted server.
