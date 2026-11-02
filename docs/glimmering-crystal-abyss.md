# Glimmering Crystal Abyss

This guide describes the accepted **7D.5 Crystal theme batch**, covered by [headless validation](milestone-7d5-validation.md). Physical Android play-testing and rendered art review remain pending.

## Entering the theme

Crystal is a theme within the existing Rootbound depth ladder. Depths 1–5 remain Rootbound. At Depth 6 and beyond, a dedicated seeded draw chooses Rootbound with weight 60 or Crystal with weight 40. The portal shows eligible themes and possible bosses before entry; the actual admitted theme and boss are shown afterward. There is no independent Crystal unlock ladder, caller-selected boss or fallback to another theme when content is invalid.

Fourteen native room modules retain the existing room roles, 24 m grid, doors, spawn points and interaction anchors. New mineral shelves, geodes, broken lenses, prism blooms and obelisks replace Rootbound dressing. These are original Godot mesh prototype assets. They are not finished imported character rigs or painted environment artwork, and their appearance still needs rendered review.

## Encounters

| Encounter | Behavior |
|---|---|
| Prism Conductor | Two ground-lane stages, each with its own full warning and a harmless gap. The Refracted variant changes the later cross pattern while retaining a central escape opening. |
| Geode Colossus | A frontal cone and two separately warned ground slams. Exposed windows make positioning and interruption useful. |
| Shard Wraith | Separate attacks offer visible grounded relocation, two short-lived non-splash bolts, and an exposed close-range cast. It does not teleport or pass through walls. |
| Crystal Lancekeeper | An optional off-route encounter using a planted, narrow lance thrust. It is not required for floor completion. |

Required-boss weights are 34/33/33 in the order above. The Conductor has a one-in-four conditional chance of its Refracted variant. The variant grants one base reward, not an additional boss cache. Optional encounter admission still requires a suitable native room.

Ordinary encounters reuse the functioning skeleton, archer and golem archetypes with bounded Crystal appearance changes, theme-specific source IDs and a 45/35/20 composition weighting. They retain shared combat, reaction, targeting and damage rules. Guardian and Mystic remain the two supported adventurers.

The **resonance lane** gives a full warning before up to three spaced pulse attempts. Crossing between pulses is safe; a delayed frame cannot cause a catch-up burst. Initial traps and awareness events use the same registered hazard implementation. Existing Rootbound roots, spores, hives and hordes remain in Rootbound; this batch adds no Crystal hive or horde.

## Rewards and returning

Crystal sources use seven configured reward tables: three ordinary tiers, three required bosses and the optional Lancekeeper. They reuse twenty existing obtainable item definitions, including mineral crafting materials, supported equipment, consumables and valuables. The catalog size, item IDs, enhancement rules and Depthmarks remain unchanged.

Base ordinary rewards are 4–8, 8–18 or 25–50 DM according to the actual source tier. Required bosses use 120–250 DM and the optional encounter uses 25–50 DM, before the existing floor factor. Required and optional named rewards include one common enhancement stone. Weighted draws are independent opportunities, not guaranteed rare equipment.

The existing Legendary material `ancient_shard` has a small weight in eligible tables. Its name does not imply an Ancient Boss, an Ancient Relic equipment guarantee or an unlocked future encounter. Rootwarden-exclusive rewards, Rootbound elite fragments, craft-only high enhancement components and unfinished boss items remain excluded.

Search caches and take rewards through the existing loot window. Final extraction requires the actual required boss defeat and completes the depth. A safe [Return spring](dungeon-return-springs.md) secures collected rewards and kill-only XP while leaving the floor incomplete. Untaken rewards stay behind. Failed saves remain retryable; death or abandonment loses only unsecured progress.

Named, secured encounter records can discover this theme in the existing journal. Entry and ordinary kills do not invent boss history. This batch grants no Crystal pet eggs, essences, memories or new trophies. Previously owned pets and secured discoveries remain available.

## Compatibility and testing limits

Profile version 7, the existing depth-policy identity, equipment, companions, pets, camera switching and the Sanctuary return flow remain the integration boundaries. Content plan version 5 freezes the selected theme, source set, room presentation, native arena metadata and reward profiles. Local source checks are for offline correctness; they are not an authenticated multiplayer authority.

The accepted gate retains all 171 previous runtime modes and adds actual room, boss, hazard, reward, companion, camera, touch-layout and restart checks. Exact counts and any corrected development failures are in the stage report. Run those checks against isolated profiles; never replace a personal save with a test fixture. Physical Android testing must still assess readable warnings, both camera views, thumb reach, phone safe areas, thermal behavior and sustained frame times on Low/Medium/High presets. No Android device results, GPU measurements or live server results are claimed here.
