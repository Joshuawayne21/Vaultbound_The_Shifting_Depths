# Collection Hall and item presentation

This pass adds original native-mesh presentation accents around the existing family display models. It does not claim bespoke trophy models, a new character rig, authored animation clips, or additional item artwork.

## Ownership and integration

- The existing eight equipment stands, four relic pedestals, collision geometry, interaction positions, UID assignments and Rootwarden trophy unlock remain unchanged.
- Occupied stands read a defensive item snapshot. They never grant, move, consume or save an item. Changing a display still uses the existing validated Collection Hall transaction.
- `VaultItemPresentation.configure(definition, entry, motion_target, context)` supplies rarity rims/rune counts and bounded model motion. The optional motion target is used only by `display` context. `clear()` restores the exact original transform.
- `display` and `weapon` contexts use one shared world scheduler. `inspection` and `weapon_preview` are static: no `_process`, spark mesh allocation, scheduler registration, or model/pivot mutation. The inspector owns its drag yaw and demand rendering.
- PlayerAvatar's `static_item_presentation` flag should be set **before adding a preview avatar to the scene tree**. A SubViewport check also enforces static child cues for existing Equipment preview callers. Disabling only a parent process is insufficient for arbitrary child scripts.
- Weapon enhancement cues attach below the existing Sword/MagicStaff nodes and follow their visibility. They do not alter attack state, animation pivots, hitboxes, cooldowns, equipment ownership, or combat statistics.
- Existing dynamic-subtree exclusions keep owned display art outside static architecture baking.

## Accessibility and structural budgets

The shared scheduler checks nearby visible world components four times per second and rejects other World3D instances. It limits distance to 20 units and respects the active camera frustum when present. Only active displays with animation or allocated sparks process each frame. Empty/hidden/distant components stop processing.

Item sparks share **4 / 8 / 12** instances for Low / Medium / High, derived from half the existing ambient preset budget; each component has at most three. Spark meshes use one bounded MultiMesh per component. This is an additional item-specific budget, not a replacement for the existing environmental ambience budget. Static previews allocate zero sparks. There are no added lights, physics shapes, external assets, animated shader materials or full-screen effects. All accents retain depth testing and cannot reveal an item through an occluding wall.

Reduced motion freezes display transforms in place and stops spark motion; disabling it resumes from the same phase. Reduced effects removes sparks and dims static accents, retaining rarity labels and one-to-seven rune patterns so color is not the sole indicator. Rotation is capped at 0.5 radians/second and bob at 0.08 units. Each frame derives the transform from its captured base, avoiding cumulative drift.

The Hall completion label counts secured discovery IDs against obtainable, noncurrency catalog definitions. Future unavailable entries do not lower completion. It updates only on profile revision and does not scan inventory every frame.

## Validation and remaining manual checks

Headless automated coverage includes bounded budgets at all presets, long-running transform stability, exact clear/reset, hidden/distant deactivation, static artifact inspection, hidden Equipment preview child processing, real weapon anchor/visibility preservation, depth-tested materials, actual Hall UID bindings, dynamic-bake exclusion, and read-only completion counts. Existing collection approaches, character poses, loadout UI, graphics settings and static batching remain covered.

On physical Android, inspect occupied stands and both camera modes; confirm small labels and rune accents remain readable, weapons do not clip hands, and wall occlusion remains correct. Open/close and drag both preview screens repeatedly, change graphics/accessibility settings, assign/remove displays, exit/re-enter the Hall and restart. Check thermal behavior, frame time and memory with a full Hall and active combat. **No physical Android measurements or 30/60 FPS claims were made.** Actual visual inspection still requires a renderer/device; cloud headless checks establish structure and invariants, not final art quality.
