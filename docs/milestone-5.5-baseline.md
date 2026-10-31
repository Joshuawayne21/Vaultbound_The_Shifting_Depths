# Milestone 5.5 — initial visual and structural baseline

Recorded on **2026-10-31**, before visual changes, from Milestone 5 commit **`e4138d014c1e3d646aaa9ddea8d9a7e6f5ddfd6c`**. An isolated `git archive` of that commit was imported and inspected with **Godot 4.6.3 stable, Linux headless**. Existing Milestone 5 validation records 2,659 passing assertions across 27 invocations; those results are the regression starting point, not evidence that later visual changes pass.

This is a source/resource and scene-tree baseline. **No rendered screenshot, GPU timing, Android frame rate, heat or battery measurement is claimed.** The runner has no configured display or `/dev/dri`; `DISPLAY` is unset and Xvfb/glxinfo are unavailable. A bounded attempt to start the installed Xorg dummy driver failed to bind its display sockets (`Cannot establish any listening sockets`). No elevated permissions or external assets were requested. A headless frame rate would omit the rendering workload and cannot establish either the 30 FPS goal or the optional 60 FPS goal.

## Renderer and resource inventory

- Desktop and Android both select **GL Compatibility**, with 1280 × 720 logical landscape UI and expanding canvas stretch. Physics runs at 60 Hz. VSync is enabled, but there is no selectable graphics tier or explicit frame target.
- MSAA and screen-space AA are disabled. Directional and positional shadow settings are 1024. Texture import enables ETC2/ASTC; anisotropic filtering is disabled.
- There are **54 native scenes**, including **14 Abyss room variants plus their base**, **12 reusable Abyss props**, eight item display models, the original Sanctuary/practice dungeon/arena, Collection Hall, player/companions/enemies, portals and HUD.
- The complete baseline has **70 `.tres` resources**, including **17 shared Abyss materials**, and **12 SVG images**: the project icon and eleven item-family icons. There are no imported raster surface textures, external 3D models or custom shaders. Geometry, animation and placeholder sound are authored in the project.
- Static resource-path inspection and the clean baseline import found no missing scene, material or script references. The restricted runner reports its editor TCP listener errors; no project parse/load errors occurred in the baseline import or scene audit.

## Lighting and atmosphere

Each world uses one directional light with orthogonal shadows, a 44 m shadow distance and simple color ambient lighting. No OmniLight3D, SpotLight3D, baked lightmap, volumetric lighting, SSAO, SSR or realtime GI is authored. Decorative flames, crystals, mushrooms and runes are emissive or unshaded geometry; they do not light their surroundings. Environment glow is disabled.

| World | Ambient energy | Directional energy | Fog |
| --- | ---: | ---: | --- |
| Sanctuary | 0.65 | 1.10 | Disabled |
| Original dungeon / arena | 0.70 | 0.80 | Disabled |
| Rootbound Abyss | 0.50 | 0.80 | Enabled, density 0.014 |
| Collection Hall | 0.62 | 0.82 | Enabled, density 0.007 |

The Sanctuary starts with pale slate/green stone and a warm directional sun. The Abyss uses low-saturation teal stone, dark soil, brown roots and a small mint/lilac emissive palette. Most Abyss materials have roughness 0.94; water uses roughness 0.32 and metallic 0.15. This offers consistent inexpensive rendering but little surface variation. Dark soil, shaded walls and similarly colored foliage are **readability risks to inspect in a real render**, not measured underexposure findings. Warm lantern illumination and a contrasting crystal focal point are not yet present as local lighting compositions.

## Scene-tree geometry baseline

The following counts come from actual instantiated worlds after three physics frames. They count the active world's descendants, including its authored NPCs/encounters, but exclude the persistent human player, party manager and HUD. The Hall has no owned displays selected. The Abyss uses seed **7**, with **11 rooms**, at its entrance before combat. “Visible” means inherited `Node3D` visibility, **not camera-frustum visibility**. Triangle counts expand MultiMesh instances and exclude text. Mesh counts are scene nodes, **not measured GPU draw calls**.

| World | Nodes | Mesh nodes | MultiMeshes / instances | Unique mesh resources | Unique used material resources | Total triangles | Inherited-visible triangles | Static bodies |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Sanctuary | 881 | 622 | 2 / 182 | 624 | 101 | 25,220 | 23,028 | 81 |
| Collection Hall | 503 | 310 | 2 / 224 | 312 | 15 | 17,810 | 17,684 | 58 |
| Original dungeon | 279 | 178 | 2 / 120 | 180 | 22 | 10,912 | 10,912 | 36 |
| Combat arena | 480 | 289 | 2 / 462 | 291 | 35 | 17,106 | 16,338 | 56 |
| Rootbound Abyss, seed 7 | 1,822 | 1,039 | 22 / 1,584 | 158 | 44 | 55,718 | 12,878 | 246 |

Sanctuary has 611 mesh nodes configured to cast shadows; the Hall has 296 and the full seed-7 Abyss has 732. These counts include nodes outside the current view and hidden nodes, so they indicate authored workload rather than rendered shadow draws. Sanctuary has 564 inherited-visible mesh nodes, and the seed-7 Abyss entrance has 213. No particle system nodes are present in these baseline worlds.

The 14 room modules are instantiated individually with their default closed door fillers. Every module contains two paving MultiMeshes totaling 144 tiles. All use the same 24 m square floor and six-meter centered cardinal openings.

| Module | Mesh nodes | Expanded triangles | Static bodies |
| --- | ---: | ---: | ---: |
| Entrance grove | 96 | 5,738 | 28 |
| Entrance temple | 85 | 3,849 | 25 |
| Corridor roots | 68 | 4,790 | 26 |
| Corridor stream | 79 | 4,060 | 18 |
| Combat grove | 70 | 4,244 | 26 |
| Combat temple | 80 | 3,519 | 22 |
| Combat crystal | 73 | 3,499 | 20 |
| Combat falls | 66 | 3,955 | 19 |
| Treasure garden | 91 | 4,783 | 18 |
| Treasure vault | 81 | 3,711 | 22 |
| Trap thorns | 71 | 3,907 | 18 |
| Secret hollow | 82 | 5,267 | 23 |
| Boss heart | 79 | 4,030 | 33 |
| Extraction spring | 92 | 4,767 | 19 |

## Visual gaps and reusable foundations

**Sanctuary.** The playable plaza has paving, borders, columns, banners, planters, three portal arches, a training court, the Tavern and four service counters. The central “heart” is currently a flat disk/rune treatment; it has no vertical crystal landmark or water feature. Trees are stacked low-resolution spheres, shrubs are cone clusters and benches are simple slabs. The Tavern is an awning and recruitment counter with stools and mugs, without a developed interior space. Merchant layouts are functional and distinct in stock props but share simple rectangular stalls. The Hall already has open vault ribs, twelve stands, lantern meshes, crystals, journals and a trophy wall, making it a useful architectural foundation rather than a scene to replace.

**Abyss.** Existing roots, arches, columns, rubble, flowers, crystals, mushroom clusters, thorn beds, streams, falls and a dais can be reused. Rooms select five or six large prop placements around the common room footprint. Root/temple/water/crystal variants have useful themes, but identical rectangular boundary walls, paving and repeated props produce a strong test-room pattern. Roots are a few straight tapered cylinders; foliage is static primitive clusters. There are no authored rock cliff backdrops, ruined bridge silhouettes, broken guardian statues or ambient wildlife systems.

**Water.** Streams are flat rectangular slabs with straight bank strips. Three foam strips move down each stream; a waterfall rotates/scales the same scene against a collision-backed rock slab and adds a pool and foam torus. The water has no ripple shader, depth-based shoreline transition or fluid simulation. Existing transforms and floor heights should be retained while improving the visible water/bank treatment.

**Combat.** Damage is owned by the existing combat rules, independently of presentation. Impact feedback is a transient expanding alpha torus and a synthesized sound. Enemy and player bodies use procedural hit flashes, poses and death movement. Rootwarden reuses four warning meshes with existing radii and timing. These are valuable boundaries: improve contrast, trails and shape detail without changing hit detection, damage windows or warning duration. Environmental greens must not compete with enemy warning colors.

## Performance and camera risks to address

1. **Submission and resource duplication:** Sanctuary's 624 mesh resources and 101 used material resources are high relative to 25k triangles. `Architecture.new()` allocates a new palette for each caller, and primitives are independently created. Sharing immutable materials/meshes and batching repeated noninteractive ornament should be evaluated before simply adding more mesh nodes. This is a structural risk, not a measured GPU bottleneck.
2. **Shadows:** hundreds of small decorative meshes retain the default shadow-casting state. Small emissive details, ground trim, motes and dense foliage should have intentional shadow policies. A new graphics tier must not hide gameplay obstacles, closed door fillers, loot or attack warnings.
3. **Room lifecycle:** all 8–12 room geometries remain allocated. Rendering and processing are enabled only in the current cardinal neighborhood (at most five rooms); hidden secret rooms stay hidden. The refresh interval is 0.2 s. Preserve this lifecycle and keep decorative animations under their room parent. Collision remains active in distant rooms for safe party movement.
4. **Bounded combat:** normal encounters cap at six active enemies; boss encounters suspend them. There are at most two active companions, two pooled environmental hazards and four boss warning meshes. Preserve these limits. Baseline transient impact rings are not globally pooled, so any richer impact effect needs its own bounded lifecycle.
5. **Camera obstruction:** the same camera uses a 0.24 m sphere sweep against World (layer 1) and camera occluders (layer 8), repeated after smoothing. Third-person distance is 6.6 m; tactical distance is 16 m. Portal veils and the Tavern canopy already supply camera-only collision, while merchant awnings have no equivalent camera collider. New large visual-only roofs, cliffs or hanging roots can otherwise clip the view. Keep open tactical sightlines, use appropriate obstruction handling and avoid removing walls to create visibility exploits.
6. **Critical clearances:** preserve Sanctuary NPC/service positions, portal approach lanes and spawn transforms; retain the Hall's central aisle and exhibit approaches. Preserve all room origins, cardinal opening widths, closed-door collision, spawn points, chest anchors and secret blockers. Small visible stairs should not introduce a new navigation elevation requirement to the flat companion navigation model.

## Comparison and device review method

Repeat the same scene-tree audit against the completed visual pass, with the same empty profile and seed 7, and report Low/Medium/High separately. Record any extra nodes, unique materials, approximate triangles, shadow-casting geometry and bounded effect counts. These metrics explain structural tradeoffs; they cannot substitute for draw-call capture, GPU timings or memory measurement on the target device.

On physical Android hardware, record device/OS/Godot version, renderer, resolution, graphics tier, frame target, seed, party size and encounter. Review Sanctuary arrivals/merchants/Tavern/Hall, each room theme, water edges, telegraphs and camera obstruction in both views. Measure sustained frame pacing and thermal behavior after repeated expeditions; verify the 30 FPS goal first, then optional 60 FPS on capable devices. Keep unverified visual quality and performance claims separate from automated resource, navigation and gameplay checks.
