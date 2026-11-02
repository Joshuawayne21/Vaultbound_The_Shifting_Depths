# Rootbound encounter expansion

This guide describes the first playable 7D.2 content batch, covered by the
[accepted headless validation](milestone-7d2-validation.md). Physical Android
play-testing and rendered art review remain pending. This batch does not
complete Milestone 7D or add Ancient Bosses, additional biomes, hives, hordes or
early extraction. The later [7D.3 event batch](rootbound-events.md) adds hives/hordes and hazards, and [7D.4 Return springs](dungeon-return-springs.md) add collected-loot early exits.

The later [7D.5 Crystal theme](glimmering-crystal-abyss.md) shares the same depth ladder. The pool below applies when Rootbound is selected.

## Selection and progression

Depth 1 keeps the original Rootwarden. From Depth 2, the seeded required-boss
pool uses weights of 50 for Rootwarden, 25 for Thornmarshal and 25 for Mycelial
Cantor. These weights describe each eligible selection, not a guarantee that
players will see all three within a particular number of expeditions.

From Depth 6, a selected Thornmarshal has a one-in-four chance of using its
Ascendant pattern. An optional Root Bark Champion may occupy one safe side-route
combat room in place of that room's ordinary enemy pack. A layout without a
suitable room has no Champion. Killing the Champion does not complete the floor.

The blue portal describes the possible pool before entry. The dungeon HUD shows
the actual active encounter and distinguishes an optional Champion from the
required objective. Defeating the required boss and successfully extracting
unlocks the next depth. Searching its cache is optional; extraction secures the
loot actually collected. Existing retreat and death rules still discard
unsecured finds.

## Encounter behavior

| Encounter | Readable attacks and response |
| --- | --- |
| Rootwarden | Existing Root Slam, Thorn Eruption and Vine Grasp, with Guardian's Fury and the existing seeded modifiers. Its original controller and assets remain in place. |
| Thornmarshal | A marked frontal cleave, a straight charge with its path locked before impact, and a circular stomp. Move out of the marked area; terrain can shorten the charge. Below 40% health, a harmless transition precedes its second sequence. |
| Ascendant Thornmarshal | Increased health and an additional separately warned stomp in its second sequence. It does not gain faster attacks or extra damage from the variant. |
| Mycelial Cantor | Two separated ground patches, a close pulse, and a long channel that can summon up to two skeleton defenders. The Cantor pauses damaging casts while its defenders remain alive. It is exposed during its channel and ensuing recovery. |
| Root Bark Champion | A grounded skeleton elite with one larger, clearly warned sector attack. It is an optional encounter, with no boss phase or summons. |

The Cantor consumes at most one summon attempt in each of its two phases. A
blocked or canceled attempt is still consumed. Defenders require supported
ground, body clearance, a connected route and more than six metres of separation
from every available party member when admitted. Unsafe positions produce fewer
defenders or none; they do not fall back to a position beside the player.

New boss and Champion profiles apply the admitted floor health and damage factors
once. Ordinary enemy room-distance and elite multipliers are not applied again.
Camera switching does not select a new encounter or restart an attack. Damage
uses the existing shared combat rules and per-attack receipts.

## Loot and records

All new rewards use the existing item database, loot-table sampler, searchable
cache, unsecured bag and extraction transaction. No separate inventory or
currency is introduced.

- Thornmarshal and Cantor have distinct equipment and material tables, with
  base currency ranges of 120–250 DM before the existing floor reward factor.
- Champion uses its own smaller table and a base range of 25–50 DM. Its elite
  material is tied to an actual admitted defeat.
- Summoned defenders grant no separate loot, currency, kill experience, pet
  finding, discovery record or floor completion.
- Rootwarden-exclusive rewards remain restricted to the existing Rootwarden.
  These new encounters do not award its heart, essence or exclusive weapons.
  Existing crafting recipes for those weapons remain available.
- A secured Ascendant defeat adds a subset observation alongside its Thornmarshal
  record. It is not a second boss kill, cache or reward.

Encounter records retain profile-v7 structure. Existing items, equipment
instances, Depthmarks, recruits, pets, displays and depth unlocks are preserved.
New boss and variant records are stored in the local profile; their dedicated
Hall/journal presentation remains work for 7G.
Older builds that do not recognize the new records must leave that profile
unchanged rather than silently deleting its discoveries. Back up saves before
changing versions; use a matching or newer supported build to continue play.

## Presentation and performance limits

The new silhouettes and pose animations are original native-mesh prototypes,
not imported production rigs. The warning outlines share the analytic attack
geometry; only their visible meshes are lifted above floor trim. Walls still
occlude them. Existing room floors, doors, connectors and navigation space remain
the basis of the encounters.

The shared budget limits active nonboss enemies, including support actors, to
six; only one required or optional boss is active at a time. A Cantor owns at most
two live defenders. Warning capacity is reserved before presentation. Unloading
an encounter, changing its source generation or defeating its owner cancels its
pending attacks and support actors.

Native geometry, physics and automated input checks cannot establish Android
readability, touch comfort, thermal behavior or sustained frame rate. Test both
cameras, each graphics preset and reduced effects on a physical device using the
[Milestone 7 Android checklist](milestone-7-android.md). No online authority or
physical Android result is claimed by this guide.
