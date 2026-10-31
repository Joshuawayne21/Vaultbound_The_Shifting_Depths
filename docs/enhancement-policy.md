# Equipment enhancement policy

Milestone 5.6 checkpoint 6 uses one policy for the Blacksmith, inventory validation and stat previews. The native tuning resource is `resources/progression/enhancement_policy.tres`; `VaultEnhancementPolicy.cap_for()` and `quote()` expose it without depending on the inventory or save implementation.

Supported equipment, including the original accessory slot, stops at **+5** for Common through Legendary and **+10** for Mythic and Ancient Relic. Trophies, materials, consumables, unreleased equipment and unsupported combat families have no enhancement ranks. Owned equipment must be identified and have remaining durability before the Blacksmith can enhance it. Existing locked/favorite/equipped/displayed gear can be improved without losing those protections or assignments; protected material stacks cannot be spent.

Upgrades are guaranteed. Each rank adds 8% of the item's original health, stamina, damage, armor and stamina-regeneration bonuses: +5 is 1.40× these base stats and +10 is 1.80×. Critical chance, lifesteal, block strength and ability cooldown reduction do not scale with enhancement. Rolls are preserved and are not multiplied again by enhancement. Runtime balance limits and the separate future stat-normalization policy remain in force. There are no random failures, new weapon mechanics or multiplayer transactions.

| New rank | Base DM price | Materials |
| --- | ---: | --- |
| +1 | 30 | 2 Common Enhancement Stones, 2 Root Fiber |
| +2 | 70 | 4 Common Enhancement Stones, 4 Root Fiber |
| +3 | 150 | 6 Common Enhancement Stones, 4 Emerald Dust |
| +4 | 300 | 3 Elite Monster Fragments, 6 Emerald Dust |
| +5 | 600 | 2 Rootwarden Essence, 4 Elite Monster Fragments |
| +6 | 1,000 | 3 Ancient Shards, 3 Rootwarden Essence |
| +7 | 1,700 | 5 Ancient Shards, 4 Rootwarden Essence |
| +8 | 2,800 | 2 Ancient Forged Cores, 4 Rootwarden Essence |
| +9 | 4,500 | 3 Ancient Forged Cores, 2 Aurora Blooms, 10 Emerald Dust |
| +10 | 7,500 | 1 Ancient Heartstone, 8 Rootwarden Essence |

The final DM price is the base price times the rarity multiplier, rounded up once. Multipliers are Common 1.00×, Uncommon 1.10×, Rare 1.25×, Epic 1.50×, Legendary 1.75×, Mythic 2.00× and Ancient Relic 2.50×. They are stored as integer percentages and validated within 1–4×. For example, the uncommon Temple Blade's first upgrade costs 33 DM; a rare item's first upgrade costs 38 DM. Ranks +6–+10 are available only to the two highest rarities.

Every component is already obtainable in the prototype. Elite fragments come only from completed elite encounters, and Rootwarden Essence only from the defeated Rootwarden. Existing Blacksmith recipes turn those components and current materials into Ancient Forged Cores and Ancient Heartstones. No unfinished boss or biome provides a required drop. This is an initial economy curve requiring play-testing, not a finalized long-term balance promise.

The existing transaction boundary validates the owned instance, materials, DM balance, inventory revision and one-use request receipt. It computes a copied candidate, preserves the instance UID/modifiers/assignments and saves before publishing state. Failed capacity/material/DM/save checks leave the original profile unchanged. UI previews show the current and next item even when the upgrade is unaffordable; they cannot grant items or change policy data.

`tests/enhancement_policy_test.gd` covers all seven tier caps and rank prices, acquisition-compatible materials, exact resource conservation through complete +5/+10 chains, immutable previews, duplicate/stale requests, protected materials, unidentified/broken equipment and full inventory behavior. Separate integration and save-migration tests exercise the actual Blacksmith and persistence.

On Android, review an upgrade at the Sanctuary Blacksmith, compare both rank/stat previews, then confirm once and verify the DM/material deductions. Try a capped item, a missing component and a protected material stack. Enhance both loadouts, switch cameras/weapons, restart and inspect the same equipment and Collection Hall assignments. Repeat with reduced motion/effects and all graphics presets. Touch comfort, final appearance and device performance require physical-device testing; none is claimed by the headless policy checks.
