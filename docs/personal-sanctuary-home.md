# Personal Sanctuary — Grand Foyer

Build `0.7.0-home3` implements the functional Grand Foyer checkpoint in Stage 3 of the [Sanctuary and home plan](personal-sanctuary-plan.md). Its scoped validation passed **6,081 checks across 60 runtime modes**, including native navigation, cameras, touch UI and restart. The [Stage 3 report](personal-sanctuary-m3-validation.md) records the exact scope. Rendered art composition and physical Android acceptance remain pending; the entire city/home overhaul is not complete.

## Route and architecture

Use the southeast **Personal Sanctuary** gate in district D of the existing city. Review its local destination card and confirm **ENTER**. Its position, internal `CollectionHallGate` node and `collection_hall` map POI remain stable. The city has not yet been rearranged to the supplied Prismheart blueprint.

The authored foyer occupies 30 × 32 m. Ivory stone, royal-blue cloth and gold inlays frame a tall vaulted atrium, twin sweeping stairways, a 3.4 m upper gallery, arched window reliefs, a floating crystal chandelier and central translucent House Sigil. Original native meshes are prototype artwork, not imported premium castle assets. Stair art uses horizontal treads over continuous collision ramps. Galleries sit on closed solid plinths; there is no traversable lower room beneath them. The construction deliberately fits the existing navigation model. Small overlaps between internal turn-collision wedges prevent coincident-edge floor-ray misses without opening a new route.

- **TROPHY HALL · YOUR COLLECTION** opens the existing Collection Hall. That visit's return arch leads back home.
- **RETURN TO SANCTUARY** returns to the existing city return spawn.
- The **Home Management** lectern near the central aisle opens the appearance and room-milestone menu. Its available Trophy Hall and city routes use the existing travel system.

A legacy direct Collection Hall visit still returns to the city. Loaded Hall instances keep their own return context. The persistent player, both cameras, Guardian/Mystic and selected cosmetic pet continue using their existing controllers. Destination admission checks floor support and clearance before retiring the previous world; obstruction should retain the previous location and restore controls. The foyer integration resolves companion formation on the leader's walkable level and advances cosmetic pets through sampled stair crests with the existing capsule-clearance/query limits. Native tests exercised the complete route with both companions and ground/flying pets without recovery relocation.

## Home Management

Approach the lectern and use the normal interaction control. **APPEARANCE** shows theme and sigil choices with their actual secured-progress requirements. **RECORD EARNED UNLOCKS** reviews already-earned styles and room milestones; **CONFIRM & SAVE** records them. Then select an unlocked theme/sigil, choose **REVIEW APPEARANCE**, and confirm the save. Previewing or cancelling does not recolor the world or alter saved progress. Applying the already-selected appearance performs no new save. Choices are free cosmetic changes; they grant no items, currency or combat benefits.

| Theme | Paired sigil | Requirement |
| --- | --- | --- |
| Royal Azure | Vault Diamond | Enter your Personal Sanctuary |
| Enchanted Forest | Root Crown | Own one Spiritweaving pet |
| Runic Obsidian | Runic Seal | Complete one expedition |
| Celestial Violet | Crystal Star | Clear dungeon depth three |

Unlocked themes and sigils can be mixed. Claimed milestones remain recorded permanently. Theme changes affect home-local materials, not shared equipment or city materials. Reduced motion pauses ornamental motion; reduced effects lowers the Sigil intensity.

**ROOM MILESTONES** distinguishes earned progression from content availability. Only the Foyer and existing Trophy Hall are open in this checkpoint. Sealed future doorways show requirements; recording their milestone does not open an unfinished room or create a destination.

| Room | Requirement | Current access |
| --- | --- | --- |
| Grand Foyer | Personal home | Open |
| Trophy Hall | Personal home | Existing Hall open |
| Pet Conservatory | Own one Spiritweaving pet | Not open |
| Armory | Character level 3 | Not open |
| Companion Hall | Recruit one adventurer | Not open |
| Relic Library | Complete one expedition | Not open |
| Personal Chamber | Character level 5 | Not open |
| Wardrobe | Earn Abyss Explorer through three completed expeditions | Not open |
| Rooftop Garden | Clear dungeon depth three | Not open |

## Saves and ownership

Profile v9 uses home namespace v2: `version`, `id`, `theme_id`, `sigil_id`, `unlocked_rooms` and `unlocked_styles`. Existing home IDs survive migration. A new profile receives an opaque ID only through its first valid, successfully saved city entry. Migration/loading neither invents an ID nor claims earned milestones. An identity can already be saved if subsequent physical arrival is obstructed; retry reuses it without a reward grant.

The first explicit migrated write retains exact original bytes in `.pre-v9.bak`, preserving earlier snapshots and the existing content-addressed backup behavior. Whole-profile validation, temporary-write verification and atomic replacement remain the save authority. Future or unavailable home data is protected read-only. Never delete a player profile to fix a scene/import error.

Read-only profiles cannot initialize or newly enter a home from the city. If storage becomes read-only while the player is already visiting a valid home, appearance saving is disabled, but existing Hall/home/city return routes remain usable without writing or allocating an identity. This does not allow a legacy Hall visit to create a home.

The existing eight equipment stands, four relic pedestals, journals and Rootwarden display remain in the Collection Hall. Assignments reference the original owned item UIDs in `profile.displays`; travel and decoration do not transfer or duplicate possessions. Pets, companions, loadouts, enhancements, Depthmarks, talents, depth unlocks and encounter records remain in their established profile fields.

## Limits and next stages

The foyer uses static architecture batching, one environment, one directional key and bounded ambience. Low/Medium/High, reduced motion and ambient density remain available. Native headless checks cannot establish rendered art quality, Android draw calls, touch comfort or sustained 30/60 FPS. Follow the [Android checklist](personal-sanctuary-android.md) for rendered and physical-device acceptance.

The Trophy Hall expansion, pet display habitat, Armory, other connected rooms, further decorations and city/sky/landscape overhaul remain later stages. This local profile home has no online visitors, guest permissions, bank, guild creation, live market or real billing. Ring Exchange remains **DEMO / NOT LIVE**. No new combat, loot or dungeon rules are introduced by the foyer.
