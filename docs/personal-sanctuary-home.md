# Personal Sanctuary — Trophy Hall and Pet Conservatory

Build `0.7.0-home4` expands the Trophy Hall and adds a separate Pet Conservatory while preserving the reviewed Grand Foyer. Stage 4 passed **4,928 checks across 50 unique modes in two frozen validation chunks**, including native room travel, cameras, touch display controls and restart. The [Stage 4 report](personal-sanctuary-m4-validation.md) explains the source bridge and exact scope; rendered and physical Android acceptance remain pending. The user liked the delivered foyer, but their device/renderer were unspecified, so this is not physical Android verification. The entire city/home overhaul remains unfinished.

## Route and architecture

When importing, select `feature/personal-sanctuary` or the matching published `vaultbound-personal-sanctuary-m4.zip`, and verify `config/version="0.7.0-home4"` in root `project.godot`. An older project folder/default branch does not contain this update. Back up phone saves separately.

Use the southeast **Personal Sanctuary** gate in district D of the existing city. Review its local destination card and confirm **ENTER**. Its position, internal `CollectionHallGate` node and `collection_hall` map POI remain stable. The city has not yet been rearranged to the supplied Prismheart blueprint.

The authored foyer occupies 30 × 32 m. Ivory stone, royal-blue cloth and gold inlays frame a tall vaulted atrium, twin sweeping stairways, a 3.4 m upper gallery, arched window reliefs, a floating crystal chandelier and central translucent House Sigil. Original native meshes are prototype artwork, not imported premium castle assets. Stair art uses horizontal treads over continuous collision ramps. Galleries sit on closed solid plinths; there is no traversable lower room beneath them. The construction deliberately fits the existing navigation model. Small overlaps between internal turn-collision wedges prevent coincident-edge floor-ray misses without opening a new route.

- **TROPHY HALL · YOUR COLLECTION** opens the redesigned existing Collection Hall. Its twelve saved stand/pedestal IDs and ownership remain unchanged. That visit's return arch leads back home.
- **PET CONSERVATORY** uses the existing marked east ground-floor doorway. Own one Spiritweaving pet and record its earned room milestone to enter. The separate garden returns through **RETURN TO YOUR GRAND FOYER**.
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

Unlocked themes and sigils can be mixed. Claimed milestones remain recorded permanently. Theme changes affect the foyer and Trophy Hall local materials, not shared equipment or city materials. The Conservatory keeps its fixed greenhouse palette in this stage. Reduced motion pauses ornamental motion; reduced effects lowers the Sigil intensity.

**ROOM MILESTONES** distinguishes earned progression from content availability. The Foyer and Trophy Hall are available, and the Pet Conservatory opens after its earned milestone is recorded. Sealed future doorways show requirements; recording their milestone does not open an unfinished room or create a destination.

| Room | Requirement | Current access |
| --- | --- | --- |
| Grand Foyer | Personal home | Open |
| Trophy Hall | Personal home | Redesigned existing Hall |
| Pet Conservatory | Own one Spiritweaving pet; record earned milestone | Available after recorded unlock |
| Armory | Character level 3 | Not open |
| Companion Hall | Recruit one adventurer | Not open |
| Relic Library | Complete one expedition | Not open |
| Personal Chamber | Character level 5 | Not open |
| Wardrobe | Earn Abyss Explorer through three completed expeditions | Not open |
| Rooftop Garden | Clear dungeon depth three | Not open |

## Trophy Hall and garden displays

The Trophy Hall retains its display approaches and eight equipment stands/four relic pedestals, now framed by 14.5 m walls and an 18.4 m vault. Its Rootwarden mount is an original native-mesh carving based on the shipped boss silhouette, accompanied by the existing Heart visual and real secured records. It is not a new defeated boss, imported sculpt or invented discovery date. Item displays use their existing visual scene references; placeholders remain prototype representations.

The 28 × 32 m Pet Conservatory has six habitat displays: **North Meadow**, **South Meadow**, **Crystal Grove**, **Moon Pool**, **Canopy Nest** and **Ancient Grove**. It uses the existing eight-species collection rather than generating new pets. Pet acquisition and the Spiritweaving journal remain at the city's district G Spiritweaving Conservatory; this home room is for displays. Displayed names, natural/luminous variants and origin details come from the owned record. These are bounded idle display models; they do not roam, fight or replace the active cosmetic follower.

1. Own at least one pet through existing Spiritweaving. At Home Management, choose **RECORD EARNED UNLOCKS**, review, then **CONFIRM & SAVE**. A milestone already recorded in an older profile stays recorded.
2. Enter **PET DISPLAYS** at Home Management or the garden's **GARDEN MANAGEMENT** lectern.
3. Select a habitat, tap **CHOOSE PET**, select an owned pet, then **REVIEW DISPLAY → CONFIRM & SAVE**.
4. To clear a display, choose **Keep this habitat empty**, review and confirm. Your pet remains owned and its active-follower selection is unchanged.
5. A pet may occupy one habitat at a time. Clear its previous habitat before moving it elsewhere. Cancelling, repeating an already-saved selection or touching twice must not grant a pet or duplicate an assignment.

Only the active room is presented. The six displayed models have no combat or movement-blocking role. Garden decoration caps ambient motes at twelve; idle pose updates use 10 Hz on Low and 20 Hz on other presets, with motion reduced/disabled through the existing settings. These source limits are not measured Android FPS.

## Saves and ownership

Profile v10 uses home namespace v3: `version`, `id`, `theme_id`, `sigil_id`, `unlocked_rooms`, `unlocked_styles` and six `pet_displays` references. Existing home IDs survive migration. A new profile receives an opaque ID only through its first valid, successfully saved city entry. Migration/loading neither invents an ID nor claims earned milestones. An identity can already be saved if subsequent physical arrival is obstructed; retry reuses it without a reward grant.

The first explicit migrated write retains exact original bytes in `.pre-v10.bak`, preserving earlier snapshots and the existing content-addressed backup behavior. Whole-profile validation, temporary-write verification and atomic replacement remain the save authority. Future or unavailable home data is protected read-only. Never delete a player profile to fix a scene/import error.

Read-only profiles cannot initialize or newly enter a home from the city. If storage becomes read-only while the player is already visiting a valid home, appearance saving is disabled, but existing Hall/conservatory/home/city return routes remain usable without writing or allocating an identity. This does not allow a legacy Hall visit to create a home.

The existing eight equipment stands, four relic pedestals, journals and Rootwarden display remain in the Collection Hall. Assignments reference the original owned item UIDs in `profile.displays`; travel and decoration do not transfer or duplicate possessions. Pets, companions, loadouts, enhancements, Depthmarks, talents, depth unlocks and encounter records remain in their established profile fields.

## Limits and next stages

The foyer uses static architecture batching, one environment, one directional key and bounded ambience. Low/Medium/High, reduced motion and ambient density remain available. Native headless checks cannot establish rendered art quality, Android draw calls, touch comfort or sustained 30/60 FPS. Follow the [Android checklist](personal-sanctuary-android.md) for rendered and physical-device acceptance.

The Trophy Hall and Conservatory are functionally verified in Stage 4; their rendered composition and physical-device performance still need review. Armory, other connected rooms, further decorations, a roaming/genetics pet expansion and city/sky/landscape overhaul remain later stages. This local profile home has no online visitors, guest permissions, bank, guild creation, live market or real billing. Ring Exchange remains **DEMO / NOT LIVE**. No new combat, loot or dungeon rules are introduced by the foyer.
