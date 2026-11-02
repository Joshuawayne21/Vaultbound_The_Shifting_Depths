# Crimson Ember Temple

This guide describes the accepted **7D.6 Crimson Ember Temple batch**, covered by [headless validation](milestone-7d6-validation.md). Physical Android play-testing, difficulty tuning and rendered art review remain pending.

## Entering the temple

Ember uses the existing blue dungeon portal and Rootbound depth progression. Depths 1–5 remain Rootbound. Depths 6–10 retain the Rootbound/Crystal 60/40 selection. From Depth 11, the possible themes are Rootbound 45%, Crystal 30% and Crimson Ember Temple 25%. The portal shows the eligible pools before entry and the actual selected theme afterward.

Selection uses a separate seeded Ember opportunity. The existing Rootbound/Crystal draw and old encounter streams remain unchanged when Ember is not chosen. Invalid executable content denies entry with a reason; it never silently substitutes a different theme. Content version 6 freezes the selected producers and policies. Profile version 7 and the existing depth ladder remain unchanged.

Fourteen native room modules use basalt kilns, bronze temple architecture, sealed urns, broken effigies and pale forged flowers. Cooling channels and waterfalls are harmless water. Their floors, connectors, loot approaches and Return spring positions preserve the existing room contracts. These are original native-mesh prototypes; finished artwork, rendered composition and Android performance are not established by this guide.

## Encounters

Required boss selection uses Furnace Warden 34%, Cinder Liturgist 33% and Ash Sealkeeper 33%. Each has a harmless phase transition below 40% health. Ordinary packs retain the existing skeleton, archer and golem combat archetypes with Ember appearances and source-specific rewards.

- **Furnace Warden** warns before a grounded charge. A successful charge establishes the direction of its later rear-facing Backdraft; the charge and Backdraft have separate recovery and warning windows. A failed charge does not authorize an invisible follow-up. The conditional one-in-four Banked Backdraft variant adds separately warned, opposed sectors in phase two, with a harmless gap between them.
- **Cinder Liturgist** uses two angled lanes or two offset ground marks. Each stage locks its initial geometry and gives its own full warning. Later stages do not follow a fleeing player.
- **Ash Sealkeeper** combines small ground seals and a frontal sweep with a finite skeleton-and-archer channel. It admits at most two living defenders and four across the encounter. Channeling and defender sustain add no boss damage. Defenders have no independent loot or progression grants.
- **Cinder Pikewarden** is an optional, off-route encounter using a planted spear thrust. Its defeat cannot replace the required boss objective.

The existing Guardian and Mystic remain the supported AI companions. Combat, targeting and damage rules are shared by third-person and isometric cameras. No new player weapon family, recruit class, burning status or hostile projectile splash is introduced.

## Vents and mines

Flame vents show a full 2.1-second warning before a short, once-per-target damage window. Awareness vents first give the existing event warning, then the vent's own warning. Decorative closed furnace grilles are not hazards.

At most one optional arcane mine occupies an eligible off-route combat room. Its cool dormant seal is harmless. A nearby eligible party member can trigger admission of its complete 2.2-second warning, followed by one brief ground-circle damage window. It does not explode immediately on approach. Once shown, its attempt stays consumed after cancellation or leaving the room; reentry cannot create a new attempt.

Placement preserves doors, spawn space, treasure approaches, required objectives and reserved Return rooms. Unsafe placements are omitted. Dormant mines do not block otherwise safe Return springs. Actual warnings, active attacks, projectiles and nearby enemies still use the existing fresh safety checks.

## Rewards and returning

Seven configured tables reuse twenty existing item definitions, existing Depthmarks and the shared searchable-cache system. Forge and temple materials, supported equipment, valuables and a supported consumable form the pools. Existing quantities, equipment requirements, rarity and enhancement rules remain unchanged. Floor reward scaling applies once.

The stronger Furnace earns one base boss reward and a derived discovery record. Support defenders grant nothing independently. These tables do not unlock unfinished Emberglass or Ancient boss items, Rootwarden-exclusive rewards, craft-only high enhancement materials or unsupported consumables. Ember has no new pet findings; existing owned pets remain available.

Final extraction requires the actual required boss victory and saves the usual completion and next-depth unlock. A safe Return spring secures collected loot, kill XP and eligible discoveries without completing the depth. Death or abandonment loses only unsecured expedition rewards. Existing inventory, equipment, pets, companion roster and earlier discoveries are preserved.

## Testing and limits

The accepted gate retains all 196 previous runtime modes and passes 43,302 assertions across 186 suites / 221 runtime processes. It adds actual Ember generation, native geometry, encounter, hazard, companion, UI, transaction and restart checks. See the [stage report](milestone-7d6-validation.md) for exact scope, commands, corrected development failures and measurement limits.

For manual testing, use a backed-up test profile with Depth 11 legitimately unlocked. Record the displayed seed, depth, theme and boss. Check all boss warnings and hazard windows in both cameras; test the portal card at supported text scales; traverse rooms with both companions; search partial caches; try both early Return and final extraction; restart to check secured rewards. Review warning visibility and frame pacing on Low, Medium and High settings.

Physical Android controls, GPU rendering, sustained FPS, thermal behavior and visual polish remain untested until measured on devices. Dungeon simulation does not resume after process restart; secured progression does. Further themes and hazards, Ancient encounters, expanded recruits, pet genetics, Veilgarden, Bloodfall Frontier and authenticated ranked services remain later work. No live server, leaderboard, marketplace or purchasing is claimed.
