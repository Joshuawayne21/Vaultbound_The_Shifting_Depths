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

## Performance and visual limits

The source defines explicit geometry, actor and effect ceilings. Retained butterfly slots are distinct from visible/active butterflies; room motes and existing item effects have their own budgets. Counts and measurements belong in the stage's validation/performance report, not an inferred FPS claim.

No new production humanoid rig, fitted item-specific armor, sculpted trophy set or large wildlife simulation is included. The existing [5.6 asset register](milestone-5.6-assets.md) still describes item-family artwork and missing character assets. Public-player gathering, live storefronts and billing remain separate, unimplemented service phases at this checkpoint.

The optional software-rendered capture attempt was canceled before producing an image. No rendered screenshot, physical Android GPU result or device audio review is claimed. See the [Android checklist](living-sanctuary-android.md) for remaining visual, input, audio and sustained-performance checks.
