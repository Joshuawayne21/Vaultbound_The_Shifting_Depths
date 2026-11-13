# Personal Sanctuary — Grand Foyer and connected rooms

Build `0.7.0-home5` adds the six-room expansion: Armory, Companion Hall, Relic Library, Personal Chamber, Wardrobe and Rooftop Garden. It retains the reviewed Grand Foyer and accepted Trophy Hall/Pet Conservatory. **Stage 5 passed 5,313 checks across 40 runtime modes and 37 suites** on one frozen snapshot, with two independent restart readers, 36 strict script loads and 120 startup frames; see [the report](personal-sanctuary-m5-validation.md). Previous [Stage 4 results](personal-sanctuary-m4-validation.md) and [tester-access results](tester-access-validation.md) are historical checkpoints, not proof of these new rooms. Rendered and physical Android review remain pending. The user liked the delivered foyer, but their device/renderer were unspecified. The blueprint-based city redesign remains unfinished.

## Route and architecture

The current capital build is `0.7.0-home6b` / code 29. Stage 6.1b lowers the city walls, repairs conflicting wall relief and adds the enclosed Exchange/bridge and landscape presentation while retaining the southeast home gate and accepted Stage 5 ownership/services. Its scoped native gate passed 8,435 checks across 33 modes; rendered and physical Android review remain pending. See [the current report](personal-sanctuary-m6-1b-validation.md). The preceding home6a capital passed its separate [8,250-check historical gate](personal-sanctuary-m6-1-validation.md).

Download the current project from the [GitHub repository](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths) using **main → Code → Download ZIP**, or use the [main source ZIP](https://github.com/Joshuawayne21/Vaultbound_The_Shifting_Depths/archive/refs/heads/main.zip). Import the fresh extraction's root `project.godot` and verify `config/version="0.7.0-home6b"` (Android export code **29**). An older extracted project folder can still contain earlier rooms. Back up phone saves separately and preserve the same application/user-data identity; a source ZIP is not an APK and does not migrate profiles between applications.

Use the southeast **Personal Sanctuary** gate in district D of the existing city. Review its local destination card and confirm **ENTER**. Its position, internal `CollectionHallGate` node and `collection_hall` map POI remain stable. The city has not yet been rearranged to the supplied Prismheart blueprint.

The authored foyer occupies 30 × 32 m. Ivory stone, royal-blue cloth and gold inlays frame a tall vaulted atrium, twin sweeping stairways, a 3.4 m upper gallery, arched window reliefs, a floating crystal chandelier and central translucent House Sigil. Original native meshes are prototype artwork, not imported premium castle assets. Stair art uses horizontal treads over continuous collision ramps. Galleries sit on closed solid plinths; there is no traversable lower room beneath them. The construction deliberately fits the existing navigation model. Small overlaps between internal turn-collision wedges prevent coincident-edge floor-ray misses without opening a new route.

- **TROPHY HALL · YOUR COLLECTION** opens the redesigned existing Collection Hall. Its twelve saved stand/pedestal IDs and ownership remain unchanged. That visit's return arch leads back home.
- **PET CONSERVATORY** uses the existing marked east ground-floor doorway. Own one Spiritweaving pet and record its earned room milestone to enter. The separate garden returns through **RETURN TO YOUR GRAND FOYER**.
- **RETURN TO SANCTUARY** returns to the existing city return spawn.
- The **Home Management** lectern near the central aisle opens the appearance and room-milestone menu. Its available room and city routes use the existing travel system.

A legacy direct Collection Hall visit still returns to the city. Loaded Hall instances keep their own return context. The persistent player, both cameras, Guardian/Mystic and selected cosmetic pet continue using their existing controllers. Destination admission checks floor support and clearance before retiring the previous world; obstruction should retain the previous location and restore controls. The foyer integration resolves companion formation on the leader's walkable level and advances cosmetic pets through sampled stair crests with the existing capsule-clearance/query limits. Native tests exercised the complete route with both companions and ground/flying pets without recovery relocation.

## Home Management

Approach the lectern and use the normal interaction control. **APPEARANCE** shows theme and sigil choices with their actual secured-progress requirements. **RECORD EARNED UNLOCKS** reviews already-earned styles and room milestones; **CONFIRM & SAVE** records them. Then select an unlocked theme/sigil, choose **REVIEW APPEARANCE**, and confirm the save. Previewing or cancelling does not recolor the world or alter saved progress. Applying the already-selected appearance performs no new save. Choices are free cosmetic changes; they grant no items, currency or combat benefits.

| Theme | Paired sigil | Requirement |
| --- | --- | --- |
| Royal Azure | Vault Diamond | Enter your Personal Sanctuary |
| Enchanted Forest | Root Crown | Own one Spiritweaving pet |
| Runic Obsidian | Runic Seal | Complete one expedition |
| Celestial Violet | Crystal Star | Clear dungeon depth three |

Unlocked themes and sigils can be mixed. Claimed milestones remain recorded permanently. Theme changes affect local materials in the foyer, Trophy Hall and six new rooms, not shared equipment or city materials. The Conservatory keeps its fixed greenhouse palette in this stage. Reduced motion pauses ornamental motion; reduced effects lowers the Sigil intensity.

**ROOM MILESTONES** distinguishes earned progression from content availability. In normal play, record an already-earned room milestone before entry. The six new destinations reuse the existing door locations; future unimplemented rooms remain unavailable. The saved offline TEST ACCESS switch can bypass implemented room gates without marking them earned. It does not grant inventory or ownership; see [enable/disable instructions](tester-access.md).

| Room | Requirement | Current access |
| --- | --- | --- |
| Grand Foyer | Personal home | Open |
| Trophy Hall | Personal home | Redesigned existing Hall |
| Pet Conservatory | Own one Spiritweaving pet; record earned milestone | Available after recorded unlock |
| Armory | Character level 3 | Ground floor, east beyond Conservatory |
| Companion Hall | Recruit one adventurer | Ground floor, west |
| Relic Library | Complete one expedition | Ground floor, west beyond Companion Hall |
| Personal Chamber | Character level 5 | Upper gallery, left door |
| Wardrobe | Earn Abyss Explorer through three completed expeditions | Upper gallery, center door |
| Rooftop Garden | Clear dungeon depth three | Upper gallery, right door |

## Trophy Hall and garden displays

In Stage 5, TEST ACCESS also bypasses a Spiritweaving recipe's achievement gate, but creation still needs its enabled recipe, required secured ingredients and fixed creature-memory seed. Existing ownership and one-species rules remain; the achievement itself is not granted. The home Conservatory and Rooftop still only display pets actually owned. If access is turned OFF inside a normally locked room, room-service actions recheck eligibility and become unavailable while the safe return to the foyer/city remains usable.

The Trophy Hall retains its display approaches and eight equipment stands/four relic pedestals, now framed by 14.5 m walls and an 18.4 m vault. Its Rootwarden mount is an original native-mesh carving based on the shipped boss silhouette, accompanied by the existing Heart visual and real secured records. It is not a new defeated boss, imported sculpt or invented discovery date. Item displays use their existing visual scene references; placeholders remain prototype representations.

The 28 × 32 m Pet Conservatory has six habitat displays: **North Meadow**, **South Meadow**, **Crystal Grove**, **Moon Pool**, **Canopy Nest** and **Ancient Grove**. It uses the existing eight-species collection rather than generating new pets. Pet acquisition and the Spiritweaving journal remain at the city's district G Spiritweaving Conservatory; this home room is for displays. Displayed names, natural/luminous variants and origin details come from the owned record. These are bounded idle display models; they do not roam, fight or replace the active cosmetic follower.

1. Own at least one pet through existing Spiritweaving. At Home Management, choose **RECORD EARNED UNLOCKS**, review, then **CONFIRM & SAVE**. A milestone already recorded in an older profile stays recorded.
2. Enter **PET DISPLAYS** at Home Management or the garden's **GARDEN MANAGEMENT** lectern.
3. Select a habitat, tap **CHOOSE PET**, select an owned pet, then **REVIEW DISPLAY → CONFIRM & SAVE**.
4. To clear a display, choose **Keep this habitat empty**, review and confirm. Your pet remains owned and its active-follower selection is unchanged.
5. A pet may occupy one habitat at a time. Clear its previous habitat before moving it elsewhere. Cancelling, repeating an already-saved selection or touching twice must not grant a pet or duplicate an assignment.

Only the active room is presented. The six displayed models have no combat or movement-blocking role. Garden decoration caps ambient motes at twelve; idle pose updates use 10 Hz on Low and 20 Hz on other presets, with motion reduced/disabled through the existing settings. These source limits are not measured Android FPS.

## Six rooms behind the existing foyer doors

Each room loads separately and has **RETURN TO YOUR GRAND FOYER** plus Home Management. No new freeform building system or inventory is introduced. Upper-room returns use the upper gallery; ground rooms return near their original doors. Normal requirements are listed above. If testing before earning them, turn on **SETTINGS → TEST ACCESS → ON → REVIEW CHANGE → CONFIRM & SAVE** once on the device and check the saved badge. That does not remotely enable an online account.

| Room | Implemented integration |
| --- | --- |
| Armory | Six bounded showcases, selected from equipped and then favorited owned equipment, plus one mannequin using the actual equipped appearance. The existing Equipment inspector provides rotation/comparison. Nothing is deposited or removed. |
| Companion Hall | Guardian/Mystic saved names, roles, levels and recruited status; existing recruitment/party management. Only recruited companions receive the two noncombat portrait models. These do not add combatants or new classes. |
| Relic Library | Existing read-only item/monster journals and secured expedition/encounter summaries. Decorative shelves do not fabricate records, dates or achievements. Hall display assignment remains in the Trophy Hall. |
| Personal Chamber | An authored royal chamber with existing Home Management and equipment inspection. Furniture is fixed architecture; home themes supply the current customization. |
| Wardrobe | Separate primary and secondary owned-loadout plinths, actual equipped-outfit mannequin and existing rotatable equipment preview. Empty loadout positions stay empty. Purchased skins, hairstyles and new appearance systems are unavailable. |
| Rooftop Garden | Pools, seating, trees, protected parapets and lightweight distant scenery; one resting display reads the owned active pet's alias and saved variant. Active selection remains in existing Spiritweaving. |

The three workrooms are 24 × 28 m with 14.4 m walls and an 18.2 m open vault. Chamber/Wardrobe occupy 24 × 26 m; Rooftop occupies 28 × 32 m. Original native meshes and existing item-family visuals are prototype art, not imported premium furniture/character models. A stylized mirror does not perform real-time reflections. Existing item visuals may be shared family placeholders; unavailable models are labeled, not claimed complete.

Display refresh follows profile revisions instead of scanning inventory every frame. Source budgets cap each room at six gear models, two portrait models and one resting pet where applicable; the actual Armory/Wardrobe each use one outfit mannequin. One directional key, no local lights, at most twelve ambient motes and 10 Hz Low / 20 Hz other idle poses limit work. Only the current room is loaded. These are implementation limits, not measured device FPS.

## Saves and ownership

Profile v11 retains home namespace v3: `version`, `id`, `theme_id`, `sigil_id`, `unlocked_rooms`, `unlocked_styles` and six `pet_displays` references. Existing home IDs survive migration. A new profile receives an opaque ID only through its first valid, successfully saved city entry. Migration/loading neither invents an ID nor claims earned milestones. An identity can already be saved if subsequent physical arrival is obstructed; retry reuses it without a reward grant.

The first explicit migrated write retains exact original bytes in `.pre-v11.bak`, preserving earlier snapshots and the existing content-addressed backup behavior. Whole-profile validation, temporary-write verification and atomic replacement remain the save authority. Future or unavailable home data is protected read-only. Never delete a player profile to fix a scene/import error.

Read-only profiles cannot initialize or newly enter a home from the city. If storage becomes read-only while the player is already visiting a valid home, appearance saving is disabled, but existing room/home/city return routes remain usable without writing or allocating an identity. This does not allow a legacy Hall visit to create a home.

The existing eight equipment stands, four relic pedestals, journals and Rootwarden display remain in the Collection Hall. Assignments reference the original owned item UIDs in `profile.displays`; travel and decoration do not transfer or duplicate possessions. Pets, companions, loadouts, enhancements, Depthmarks, talents, depth unlocks and encounter records remain in their established profile fields.

## Limits and next stages

The foyer uses static architecture batching, one environment, one directional key and bounded ambience. Low/Medium/High, reduced motion and ambient density remain available. Native headless checks cannot establish rendered art quality, Android draw calls, touch comfort or sustained 30/60 FPS. Follow the [Android checklist](personal-sanctuary-android.md) for rendered and physical-device acceptance.

The Trophy Hall and Conservatory passed Stage 4; the six-room Stage 5 gate passed its scoped native checks. Rendered composition and physical-device performance still need review. Future home extensions, unrestricted decoration placement, roaming/genetics pets and the full cardinal-district/sky overhaul remain later stages. This local profile home has no online visitors, guest permissions, bank, guild creation, live market or real billing. Ring Exchange remains **DEMO / NOT LIVE**. No new combat, loot or dungeon rules are introduced by the foyer.
