# Milestone 5.6 — mobile interface checkpoint

This checkpoint extends the existing HUD, inventory panel, graphics preferences,
and equipment preview. It does not add another inventory, alter economy rules,
or grant items. No Android device, GPU performance, or physical touchscreen
measurements were performed in the cloud.

## Implemented

- A shared navy and charcoal palette with bronze/gold frames, turquoise accents,
  green health, blue stamina, and distinct ability and item rarity colors.
  Rounded vector frames use a bounded shared cache of immutable style resources.
- Separate **Inventory** (`I`) and **Equipment** (`O`) HUD entries. Both use the
  existing modal owner: movement, held attacks, companions, and the dungeon pause
  while a menu is open; closing restores the same game state.
- The equipment screen instantiates the same avatar script as gameplay and applies
  the active loadout and equipped appearance. Drag inside its preview to rotate.
  This requests one preview frame per change, with no automatic spin or continuous
  hidden rendering. A second finger cannot take over the rotating finger.
- All eleven saved slots remain accessible. The existing shield and charm slots
  remain available. Larger UI sizes use four equipment cards per page rather than
  shrinking controls. Primary and secondary assignment use the existing atomic
  equipment authority.
- Inventory retains filtering, favorites, locks, quantity selection, comparison,
  protected sales and transaction confirmations. Added sorting by base item value, lowest
  rarity, category, and recent instance acquisition. Recent sorting uses the
  saved monotonic instance ID; adding to an existing stack does not change that
  stack's original ordering. Base value is the definition value; merchant sale
  quotes still account for enhancement and durability through the existing rules.
- **Graphics → Accessibility** offers 100%, 110%, and 120% UI sizes, reduced
  motion, and reduced particles/auras. Select options, then tap **Apply & Save**.
  These preferences are separate from the progression save and survive restart.
- UI scaling grows text, icons and action targets within viewport-sized canvases.
  Inventory grids reflow from five to four columns at larger sizes. Landscape
  anchors and display-cutout margins remain in the original input coordinate space.
- Reduced motion removes bar interpolation and selection pulses, reduces the
  damage-frame flash, and disables notification fading. Reduced effects lowers
  existing decorative effect budgets and loadout glow. Essential enemy attack
  warnings, collision, combat clocks and damage rules remain unchanged.

The existing family SVG icons and geometric companion portraits are reused.
This checkpoint does not claim bespoke character artwork, individual item models,
or a completed 350-item catalog.

## Cloud validation

Godot 4.6.3 headless import reported no script parse errors. The old layout,
loadout, RPG UI, party UI, expedition UI and graphics preference suites were run.
The dedicated mobile interface suite additionally checks larger UI sizes, cutout
insets, separate menu entries, preview touch ownership, sorting, and saved options.
Headless checks validate routing, geometry and state; they cannot establish final
rendered appearance, visual comfort or Android frame rate.

```sh
godot4 --headless --path . --editor --import --quit
godot4 --headless --path . --script res://tests/mobile_ui_integration_test.gd
godot4 --headless --path . --script res://tests/ui_layout_test.gd
godot4 --headless --path . --script res://tests/loadout_ui_test.gd
godot4 --headless --path . --script res://tests/rpg_ui_test.gd
godot4 --headless --path . --script res://tests/party_ui_test.gd
godot4 --headless --path . --script res://tests/expedition_ui_test.gd
godot4 --headless --path . --script res://tests/visual_settings_test.gd
godot4 --headless --path . --script res://tests/accessibility_preferences_test.gd
```

## Android review

1. Import the existing root `project.godot` in Godot 4's Android editor, allow the
   resource import to finish, and run the main scene in landscape.
2. Open Graphics and try all three UI sizes. Verify the device's actual notch,
   gesture area, text sizes, touch comfort, and contrast against bright Sanctuary
   scenery and dark dungeon rooms. Verify the viewport never moves when tapping.
3. Move with one finger and use attacks, camera swipe, loadout buttons, and camera
   toggle with another. Open Inventory while holding a charged attack; closing
   must not discharge a stale touch. Repeat with Equipment and with app suspension.
4. Open Equipment. Rotate the preview with touch and mouse if attached. Verify its
   active weapon, shield behavior, armor colors and accessories agree with gameplay
   in both cameras. Dragging outside the preview must not turn the world camera.
5. Browse every equipment page at each size. Select owned equipment and compare,
   assign primary/secondary, unequip, lock and favorite. Exercise each sort and
   scroll an inventory of forty occupied slots without accidental selection.
6. Change graphics and accessibility settings, save, restart, and verify they
   persist. Repeat with reduced motion/effects on and off during companion combat,
   a Rootwarden warning, a loot notification, and a low-health hit.
7. Play an expedition with companions, collect treasure, fight the boss, and
   extract. Verify portals, the secured inventory, and character progression remain
   intact. Measure 30/60 FPS targets on the intended devices with the preview open
   and closed; these targets have not been verified in this environment.

Known limitations: icons and portraits remain reusable family artwork; the
preview is a deliberately static pose that rotates on demand; very long names and
descriptions use truncation/wrapping; first-person or portrait layouts are outside
this landscape milestone. Final visual sign-off requires rendered Android review.
