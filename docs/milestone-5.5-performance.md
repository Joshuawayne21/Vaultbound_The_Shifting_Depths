# Milestone 5.5 visual and performance report

Recorded on **2026-10-31**, using **Godot 4.6.3 stable, Linux headless**. The renderer remains **GL Compatibility** on desktop and Android. **30 FPS on supported midrange Android hardware and optional 60 FPS remain goals, not measured results.** No physical device, rendered GPU review, Android shader compilation, APK export, thermal test or battery measurement was available.

## Method and baseline

The [initial baseline](milestone-5.5-baseline.md) was captured from an isolated archive of Milestone 5 commit `e4138d014c1e3d646aaa9ddea8d9a7e6f5ddfd6c`. That completed milestone has also been published on GitHub as `92006f72`; its game data was preserved for this visual pass. The completed visual scenes were instantiated with the same empty profile and seed **7**, after three physics frames, at Low, Medium and High.

Counts cover descendants of the world scene, including its own NPCs/encounters but excluding the persistent human player, party manager and HUD. The Hall has no selected equipment/relic exhibits. Seed 7 contains eleven rooms and starts in the entrance. Mesh nodes with no mesh after static batching are excluded. Triangles expand MultiMesh instances and omit text. “Visible” uses inherited scene visibility and quality instance counts; it does **not** account for the camera frustum, distance culling or actual draw submission. It is an upper structural workload indicator, not a GPU measurement.

The sandbox has no configured display or GPU device. A bounded attempt to use the installed Xorg dummy driver failed to bind its display sockets. Headless rendering statistics or frame rates would not represent the Android workload, so none are presented as performance evidence.

## Before and after structure

The following after counts use **Medium**. The scene content is richer than the baseline, so this is a cost/change comparison rather than a claim of a universal speedup.

| Metric | Sanctuary before → after | Collection Hall before → after | Abyss seed 7 before → after |
| --- | --- | --- | --- |
| Scene nodes | 881 → 1,047 | 503 → 552 | 1,822 → 1,957 |
| Renderable mesh nodes | 622 → 501 | 310 → 191 | 1,039 → 1,027 |
| MultiMesh batches | 2 → 49 | 2 → 16 | 22 → 158 |
| Allocated MultiMesh instances | 182 → 815 | 224 → 460 | 1,584 → 6,314 |
| Unique mesh resources | 624 → 521 | 312 → 201 | 158 → 166 |
| Unique used material resources | 101 → 81 | 15 → 16 | 44 → 43 |
| Mesh nodes configured to cast shadows | 611 → 303 | 296 → 51 | 732 → 699 |
| Total expanded triangles | 25,220 → 32,632 | 17,810 → 19,428 | 55,718 → 199,714 |
| Inherited-visible triangles | 23,028 → 29,106 | 17,684 → 19,138 | 12,878 → 37,750 |
| Static bodies | 81 → 86 | 58 → 58 | 246 → 246 |

The five additional Sanctuary bodies are **camera-only** blockers for the suspended crystal and four merchant canopies. They do not add player/companion navigation collision. All existing room connectors, floor and door collision, chest/spawn anchors and service transforms remain preserved.

Shared materials and conservative static batching reduce Sanctuary/Hall renderable mesh nodes and shadow casters despite added art. The batcher accepts only marked, static, opaque native architecture and preserves the original collision nodes and transforms. It excludes animated/avatar/display geometry, shader surfaces and nonuniform/reflected transforms that cannot preserve the original normals safely. Its recorded reductions within the decorated scenes are 656 → 501 renderable Sanctuary mesh nodes and 298 → 191 Hall mesh nodes; these figures isolate the batching step from the added-art cost.

Abyss detail increases total and visible triangle counts substantially. Material/mesh reuse, material-grouped MultiMeshes, the existing neighborhood culling and limited effects bound its structure; **these do not prove the increase meets a device's frame budget**. The GPU cost of extra visible geometry, shaders and small alpha surfaces remains a priority for device review.

## Quality tiers and bounded work

| Control | Low | Medium | High |
| --- | --- | --- | --- |
| Optional plant density | 50% | 75% | 100% |
| Optional detail distance | 24 m | 34 m | 44 m |
| Directional shadows | Disabled | 1024 map / 34 m | 2048 map / 44 m |
| MSAA | Disabled | Disabled | 2× |
| Ambient mote budget per batch | 8 | 16 | 24 |
| Impact burst cap | 8 | 14 | 20 |
| Spark instances per impact | 0 | 6 | 10 |
| Foam CPU updates / second | 10 | 15 | 20 |
| Visible foam ribbons per stream | 2 | 3 | 3 |

The default is **Medium / 30 FPS**. Both 30 and 60 targets are available independently of quality. Physics stays at 60 Hz; no attack rule, cooldown, companion decision rule or damage radius changes with a graphics option. Preferences are verified and saved separately from progression in `user://vaultbound/visual_settings.cfg`.

The same headless scene audit produced these inherited-visible triangle totals:

| Location | Low | Medium | High |
| --- | ---: | ---: | ---: |
| Sanctuary | 28,858 | 29,106 | 29,354 |
| Collection Hall | 19,070 | 19,138 | 19,206 |
| Abyss seed 7 entrance | 35,406 | 37,750 | 40,054 |

Tier changes do not unload the allocated room geometry. Their primary current savings are shadow/AA settings, optional foliage instance counts and distance, ambient effects and transient burst budgets. The viewport LOD threshold is configured for compatible future assets; current native primitives have **no authored LOD chain**, so it is not counted as an established geometry reduction.

Additional bounds and choices:

- Each world has one directional light; there are no new Omni/Spot lights, realtime GI, SSAO, SSR, volumetric fog or post-process glow. Conventional depth fog, ambient fill and luminous materials provide atmosphere.
- Two original 128×128 noise textures provide stone/bark variation. A theoretical uncompressed RGBA8 mip chain for both is about **171 KiB**; actual renderer texture/resource memory has not been measured.
- Opaque water uses simple ripples and UV shoreline coloring without screen/depth reads. Foam and motes use small depth-tested alpha surfaces; no fluid or wildlife simulation is added.
- A mote batch allocates at most 24 quads; Abyss rooms cap the visible count at twelve even on High. Each room adds at most eight material/primitive decoration batches plus its mote batch, while selected reusable props have an additional detail batch.
- At most the current room and four cardinal neighbors render/simulate. Secret rooms remain hidden until revealed. Collision stays registered for safe party navigation.
- The existing maximum of six regular active enemies, two companions, two hazard instances and four boss warning meshes remains intact. Impact effects have an explicit tier-dependent lifetime/budget and do not create shadow lights.
- Essential architectural landmarks, collision walls, interactables and attack warnings never disappear to satisfy Low. Only optional small plants receive density/distance cuts.

## Known limits and required device work

This is an original stylized prototype art pass. It retains low-poly primitive actors, procedural animations and placeholder sound. The Tavern is an enriched open bar/interior alcove; the flat companion-navigation model is retained. Ruined bridge/stair details and guardian reliefs do not add a new multilevel cave or physically traversable raised bridge system. A simulated wildlife system and detailed replacement character assets are outside the pass.

Rendered lighting exposure, material texture orientation, shader compilation, fog appearance, water seams, foliage clipping, alpha sorting, draw-call counts and actual graphics memory remain unverified. The visual result cannot be described as device-approved premium art without that review. Headless camera/collision tests cover selected routes and transitions, not every possible orbit or pose.

Follow the [Android visual checklist](test-plan.md#milestone-55-physical-android-visual-review): compare the same views and seeds on each tier, warm up first, then measure sustained 15-minute sessions with two companions and full encounters. Record frame-time spikes, draw calls, memory, heat and battery behavior. Establish the 30 FPS goal before considering optional 60 FPS. Multiplayer development remains outside Milestone 5.5.
