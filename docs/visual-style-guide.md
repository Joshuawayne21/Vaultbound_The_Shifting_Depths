# Enchanted Dark Fantasy visual system

Milestone 5.5 preserves the existing Compatibility renderer and gameplay geometry. The style uses readable silhouettes, layered stone and bronze trim, warm inhabited spaces, and cool magical accents. All new material, shader and geometry work is original to this project; no purchased or externally licensed asset pack is required.

## Palette and reuse

`VaultVisualStyle.palette()` returns a fresh dictionary of shared material resources. The original Architecture keys remain valid, so existing hubs, shops, portals and displays reuse the same palette. Remapping a kit's dictionary does not modify another kit. Do not change a loaded material's properties for a single object; duplicate it first if individual variation is needed. MultiMesh instance colors provide inexpensive variation where the shader supports them.

| Family | Treatment | Principal resources |
| --- | --- | --- |
| Sanctuary architecture | Slate walls, muted green-gray paving, pale carved edges | `sanctuary_slate`, `sanctuary_stone`, `sanctuary_light_stone`, `sanctuary_paving_a/b` |
| Ornament | Aged bronze supports and restrained polished gold highlights | `sanctuary_bronze`, `sanctuary_gold` |
| Inhabited spaces | Deep wood, teal cloth, warm lantern cores | `sanctuary_wood`, `sanctuary_cloth`, `sanctuary_flame` |
| Magic | Turquoise crystal faces and brighter emerald runes | `sanctuary_crystal`, `abyss_crystal`, `abyss_glow` |
| Abyss | Mossy stone, layered bark, emerald foliage, blue-green luminous caps, lavender flowers | Existing `abyss_*` material paths |

The two reusable 128×128 native noise textures add subdued stone grain and stretched bark detail. They have fixed seeds and generate locally; there are no downloaded textures. They use one albedo sample per textured material, without triplanar sampling or normal maps. The limited texture size is an explicit mobile budget rather than a claim of measured device memory use.

## Lighting and atmosphere

`environment_preset(&"sanctuary" / &"abyss" / &"hall")` provides independently editable native Environment resources. `Architecture.environment()` installs the shared preset and one directional light. The three environments deliberately retain enough ambient fill to read characters and combat against dark stone. Sanctuary and Hall favor amber key light against turquoise accents; the Abyss favors a soft canopy-colored key against cool luminous plants.

Depth fog begins beyond nearby gameplay and increases toward the room horizon. It is conventional renderer depth fog; volumetric fog, height-fog dependence, glow, SSAO and SSR are disabled. Emission colors make magic readable but do not illuminate adjacent surfaces or imply post-process bloom. Warm lantern appearance combines luminous cores, warm nearby materials and the level's key light; it does not add many realtime point lights. Small architectural decoration stops casting individual shadows, while collidable architecture retains them. Graphics settings control the remaining directional shadow budget.

## Water and living scenery

The opaque water shader uses UV color transitions, flowing ripples and restrained highlights. It never samples the rendered scene or depth buffer. Existing stream banks, pool levels, waterfall backing and all collision dimensions remain unchanged. Falling water has its own faster material; three soft foam ribbons animate at 10/15/20 updates per second on Low/Medium/High, with the third ribbon hidden on Low. Surface shading continues through shader time without allocating per-frame materials.

Foliage uses an opaque vertex shader with a small anchored sway and instance-color variation. There is no transparent leaf texture stack. Ambient motes use one MultiMesh draw with 24 allocated quads and an 8/16/24 visible quality budget; Abyss rooms additionally cap themselves at twelve. Each small additive sprite remains depth-tested, has no collision or light, and animates on the GPU. Parent room visibility culls the entire batch. These are decoration counts, not measured draw calls or performance results on Android.

## Authoring constraints

Keep connectors, walls, collision and navigation anchors unchanged when decorating a dungeon module. Reserve central routes and existing enemy/chest anchors. Place optional foliage and ornaments at room perimeters and use MultiMesh batches for repeated shapes. Never hide an essential wall, boss warning or interactable to satisfy a graphics preset. Do not use an alpha surface to suggest a solid obstacle unless matching collision already exists.

The automated style suite checks resource sharing, independent presets, fog/effect configuration, shadow policy, bounded ambience, water movement and unchanged waterfall collision. It does not prove shader compilation on every GPU or final lighting, alpha sorting, foliage visibility, frame pacing or touch comfort. Those require the Android review checklist in `test-plan.md`.
