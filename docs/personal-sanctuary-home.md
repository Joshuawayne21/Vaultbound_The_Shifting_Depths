# Personal Sanctuary — home-entry foundation

Build `0.7.0-home2` introduces the entrance and persistence boundary for an offline personal home. This is Stage 2 of the [Sanctuary and home plan](personal-sanctuary-plan.md), not the complete Grand Foyer or city redesign. The final regression passed 46,230 checks across 234 runtime processes; development runs are excluded from that total. The [Stage 2 validation report](personal-sanctuary-m2-validation.md) and [per-process results](personal-sanctuary-m2-test-results.json) record the accepted evidence and its limits.

## Playable route

Use the southeast **Personal Sanctuary** gate in district D of the existing city. Its mobile entry card explains the local destination and requires an explicit **ENTER** confirmation. The portal occupies the former Collection Hall gate's position; its internal `CollectionHallGate` node and `collection_hall` map POI remain stable for compatibility.

The home currently contains a 30 × 28 m ground-floor arrival room, ivory and royal-blue prototype stonework, gold floor inlays, decorative window reliefs and two functioning doors:

- **TROPHY HALL · YOUR COLLECTION** opens the existing Collection Hall. That visit's return arch leads back to the home.
- **RETURN TO SANCTUARY** returns to the city using the existing Hall return spawn.

A legacy direct Collection Hall visit still returns to the city. Return context belongs to that loaded Hall instance and cannot leak into a later visit. The original Sanctuary, practice dungeon, Proving Grounds, Rootbound expedition and Collection Hall destinations remain registered; the home is an additional scene.

The persistent player, cameras, recruited Guardian/Mystic and selected cosmetic pet use their existing systems. Native home admission checks actual floor support and clearance for the player plus both companion formation slots before retiring the prior world. An obstructed arrival retains the prior location and restores controls with an explanation.

## Saved identity and ownership

Profile v8 adds only `home = {version: 1, id: ""}`. Loading an older profile does not write a file or create a random home. The first valid city-to-home entry creates an opaque ID through the existing verified save service. Later visits reuse it without changing the home identity, inventory or progression revision.

The identity is prepared before physical arrival. If the destination is then obstructed, that identity can already be saved; a retry uses it again. It is not a visit record, unlock reward, separate currency account or second inventory. Read-only save states cannot initialize or enter the home.

The existing eight equipment stands, four relic pedestals, discovery journals and Rootwarden display remain in the Collection Hall. Saved assignments continue to reference the same owned item UIDs in `profile.displays`; travel neither moves nor duplicates those items. Pet and companion ownership, equipment, loadouts, enhancements, Depthmarks, talents, depth unlocks and encounter records remain in their existing profile fields.

Versions 1–7 migrate in memory. The first explicit migrated write retains exact original bytes in `.pre-v8.bak`, preserving earlier migration snapshots; restoring a different older record uses the existing content-addressed backup behavior. Writes still validate the full candidate, verify a temporary file and atomically replace the primary. Unsupported future profile/home versions or home fields are preserved read-only before fallback to an older backup. A malformed current record can recover an existing valid backup. Do not delete a player save to resolve a scene or import problem.

## Scope and performance limits

The initial home uses the existing static architecture batcher, one WorldEnvironment, one directional key and bounded ambience. Low/Medium/High, reduced motion and ambient density remain available. Headless collision and scene tests do not establish rendered art quality, draw-call performance on a phone or sustained 30/60 FPS.

The two-story Grand Foyer, staircases, balcony, floating chandelier/House Sigil, Home Management, additional home rooms, room unlocks and decoration choices are not implemented in this stage. The supplied Prismheart blueprint now permits the subsequent architectural work, but the current public city has not been rearranged to that plan.

Homes are local to the saved offline profile. Online visiting, guest permissions, guild creation, banking, live trading, real cosmetic purchases and ranked PvP are not introduced here. The existing Ring Exchange remains **DEMO / NOT LIVE**. No new items, loot tables, combat mechanics or dungeon rules are added by the home entrance.

Use the [Android checklist](personal-sanctuary-android.md) for the complete round trip, saved ownership comparison and manual visual review.
