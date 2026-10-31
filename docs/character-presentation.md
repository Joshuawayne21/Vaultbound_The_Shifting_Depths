# Character presentation — Milestone 5.6, checkpoint 3

The existing character now has rounded torso, head, shoulders, limbs, gloves and
boots, with short exponential pose transitions and a restrained idle breath.
The same `player_avatar.gd` still serves the player, Guardian, Mystic, Sanctuary
NPCs and equipment preview. No gameplay controller, attack window, collider,
weapon bind anchor or save schema is changed by this checkpoint.

## Art provenance and limits

These are original Godot primitive meshes and procedural rigid-pivot poses,
created within the project. No downloaded model, paid asset, external plugin,
skeleton, motion capture or authored animation clip is included. This is improved
prototype art, not a production character rig. Elbows and knees do not have
independently skinned joints; fingers, facial animation, cloth simulation and
individual item meshes remain absent. Armor and jewelry use shared visual
families with rarity tints rather than item-specific artwork.

A production replacement still needs a properly licensed humanoid rig, compatible
skin weights, hand sockets, fitted armor, sword/shield and staff grips, and idle,
walk, run, dodge, three sword attacks, block, cast, stagger and death clips. Verify
those assets against the current capsule and attachment transforms before import.

## Compatibility and presentation behavior

- Both shoulder and hip anchors retain their original transforms. Sword, staff
  and shield remain children of the same arm pivots. Equipment model visibility
  changes immediately after an accepted weapon switch.
- Idle, movement, defensive, charging, attack, stagger and death targets blend
  with frame-rate independent damping. Slash visibility and gameplay damage
  timing remain immediate. The dodge body keeps its complete waist-centered
  rotation; quaternion blending cannot shorten it into a partial turn.
- Gloves, leg armor, necklace and ring now have separate appearance surfaces,
  alongside the existing helmet, boots, weapon, shield and legacy accessory.
  Their item definitions and availability are owned by later inventory stages.
  Repeated equipment refreshes use captured base colors so chest tints cannot
  progressively contaminate another slot's tint.
- Reduced motion removes idle breathing, cape oscillation and decorative staff
  rotation, and reduces the switch gesture. Reduced effects removes dodge
  ribbons and limits crystal expansion. Attack poses and charge cues remain.

## Geometry and verification

The complete instantiated avatar contains 53 mesh instances and 5,216 primitive
triangles, including both weapon models and rings. Only the active weapon family
is shown. Twenty-five rounded surfaces share one 12-segment, six-ring SphereMesh
resource per avatar. The existing sword/dodge ImmediateMesh cues add 38 triangles.
No extra particle system, light, texture or per-frame mesh construction is added.
These are structural counts, not measured GPU draw calls or Android frame times.

`tests/character_presentation_test.gd` passed 21 checks in Godot 4.6.3 headless:
bounded geometry, grounded rest bounds, stable anchors and grip, independent and
idempotent equipment tints, finite non-reflected poses, immediate cues, full-turn
dodge, recovery, accessibility preferences and 30/60/120 FPS pose convergence.
Existing focused regressions also passed: combat presentation (33), character
progression (69), companion behavior (38), and owned loadouts (78).

Run the focused suite from the repository root:

```sh
godot4 --headless --path . --script tests/character_presentation_test.gd
```

## Android visual review still required

1. Open the Sanctuary with Guardian and Mystic recruited. Inspect body silhouettes
   from front, side and rear in both cameras and the rotatable equipment preview.
2. Walk, run, block, charge, perform each sword combo, cast, dodge, take a hit and
   enter downed/death states. Check grip alignment, floor contact, shield coverage,
   cape/armor clipping and readability throughout transitions.
3. Switch between equipped sword and staff while moving and recovering. Confirm
   only the selected model appears and the combat cue still matches the attack.
4. Equip and remove each available armor/jewelry item. Compare the actual player
   with the preview and verify another party member's colors remain unchanged.
5. Compare Low/Medium/High, 30/60 FPS targets, reduced motion and reduced effects.
   Measure device frame time and inspect silhouettes at the smallest UI scale.

The cloud environment provided no rendered character review or physical Android
test. Headless transform checks cannot certify the absence of visible clipping,
the quality of the silhouette, GPU performance, or animation feel on a device.
