# Living Sanctuary — presentation provenance

The expansion extends the existing Godot project with original native meshes, shaders, procedural poses and generated prototype sound. No paid assets, external model packs, recorded sound libraries or purchased artwork have been introduced. This document describes the source assets; engine validation and device review are recorded separately.

## Connected city — 6B

The Ring Exchange and eight district silhouettes use the existing slate, bronze, gold, foliage, crystal and water palette. Native arches, counters, ramps, columns, roofs, planters and labels are built through the existing Architecture and Dressing helpers. Static opaque architecture is spatially batched. The original gameplay avatar, equipment families, merchants, Tavern recruitment and Collection Hall displays remain in use.

The [city map](living-sanctuary-map.svg) is an original schematic. It is not a rendered screenshot of gameplay.

## Landscape and ambience — 6C

- `sanctuary_landscape.gd` adds small interdistrict gardens and eight distant scenery sectors. Trees, cliffs, ruins and water silhouettes are native mesh art. They have no collision or navigation objects. Distant mesh bounds remain outside the city and its camera envelope.
- `sanctuary_ambience.gd` creates four reusable native residents and four small hares. Quality and distance determine which are shown. Rounded primitive body parts and simple poses are prototype presentation, with no imported rig, authored animation clips, conversational AI, network-player identity or pet ownership implied.
- `ambient_fauna.gd`, its world allocator and the wings shader provide regional butterfly buffers with a shared active limit. Wing flutter, bounded drift, hover pauses and restrained luminous markings are shader presentation. They do not simulate full insect behavior or interact with combat.
- The Sanctuary sky is a static native gradient. A separate local presentation cycle adjusts existing lighting and background intensity. It is not a server clock, a weather simulation or an announcement of real community activity.
- Optional ambient sound is one original three-second, 11,025 Hz mono generated wind loop. It starts disabled. It is a placeholder for future licensed environmental recordings and needs audible review on speakers/headphones; automated stream checks do not establish sound quality.
- Rootbound's fourteen existing room motifs gain native wall carvings and reliefs using the existing mesh/material families. The art remains seed-reproducible and does not add a new gameplay biome.

The five additional resources in `resources/biome_art/` describe future **Crystal Caverns, Ember Crypt, Flooded Ruins, Hollow Sky Vault and Forgotten Catacombs** art directions. They are explicitly unavailable. They supply no playable destinations, encounters, finished models, reward sources or synchronized multiplayer content. Rootbound's entry refers to the existing playable dungeon.

## Social presentation — 6D

The nine emotes use finite original procedural poses on the existing avatar's torso, limb and cape pivots. Weapons keep their existing attachments. These are rigid-pivot animation placeholders, not newly acquired rigs or authored motion-capture clips; planted feet, silhouettes and transitions still need visual review in both cameras.

The emote wheel and companion card reuse the existing fantasy UI theme. The chat composer uses native Godot Controls and the engine's fallback font, with no downloaded font or icon pack. Text labels identify LOCAL DEMO rows and AI companions; no artwork is presented as evidence of real online players or live message delivery.

## Cosmetic pets — 6E

Eight original native-mesh silhouettes represent the Lantern Fox, Crystal Moth, Mossdrake, Embercap Sprite, Rift Otter, Rootling Guardian, Moonveil Butterfly and Starbound Wisp. Rounded primitives, facets and finite pivot poses provide following, idle, sit/perch, playful and emote reactions. These are procedural placeholders, with no imported animal skeleton, authored animation clips or external texture pack. Natural and luminous variants share geometry and differ only in appearance.

The Conservatory renders the same pet definition and appearance in an isolated, demand-rendered preview. It uses no simulated gameplay actor. The world follower has no collider, target, light or particle emitter. Egg and rescued-spirit discovery props use the existing original material and geometry helpers. No paid acquisition, unfinished-biome rewards or tradable pet entitlement is implied.

Focused native mesh measurements found 7–14 meshes, 312–828 triangles and 1–6 animated pivots per species. These structural counts are not GPU measurements. The full stage report records accepted source and follower checks; Android silhouettes, apparent foot contact, wing motion and luminous intensity still need rendered review.

## Performance and visual limits

The source defines explicit geometry, actor and effect ceilings. Retained butterfly slots are distinct from visible/active butterflies; room motes and existing item effects have their own budgets. Counts and measurements belong in the stage's validation/performance report, not an inferred FPS claim.

No new production humanoid rig, fitted item-specific armor, sculpted trophy set or large wildlife simulation is included. The existing [5.6 asset register](milestone-5.6-assets.md) still describes item-family artwork and missing character assets. Public-player gathering, live storefronts and billing remain separate, unimplemented service phases at this checkpoint.

The optional software-rendered capture attempt was canceled before producing an image. No rendered screenshot, physical Android GPU result or device audio review is claimed. See the [Android checklist](living-sanctuary-android.md) for remaining visual, input, audio and sustained-performance checks.
