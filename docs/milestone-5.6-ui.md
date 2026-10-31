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
  quotes account for enhancement and durability through the existing rules. In a
  merchant's Sell tab, the value sort and per-item labels use the actual sale price.
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

## Enhancement and effect presentation

The Blacksmith's **Preview Upgrade** opens a dedicated review showing the current
and next rank, the item's rarity cap, exact quoted Depthmarks and materials, and
current → upgraded statistics. Common through Legendary equipment stops at +5;
Mythic and Ancient Relic equipment stops at +10. Existing eligible accessories
remain supported. Upgrades are guaranteed. Unaffordable previews retain the next
stats and exact requirements, with confirmation disabled and the failure reason.

The UI never calculates or submits its own transaction result. A released
confirmation consumes the existing Session quote; a second held finger, canceled
gesture, or repeated confirmation cannot repeat the purchase. The one-second
success cue starts only after a saved, accepted upgrade and displays its actual
rank. Reduced motion removes spatial animation; reduced effects removes sparks.
Hidden and idle panels perform no success-animation work.

Equipment tooltips expose every effective stat through an independently clipped
**Item Stats · Swipe** area. These gestures do not scroll the inventory, select
items, rotate the preview, or trigger an action. Main-weapon comparisons use the
active loadout. Critical chance, lifesteal, block strength and ability recovery
appear as named percentages; the equipment summary shows their active aggregate
values. The canonical effect policy supplies the cap caption: 20% critical
chance, 4% lifesteal with at most 4 health per attack, +20% block strength and 15%
ability cooldown reduction. Rolled bonuses and special effects stay fixed when
enhancement increases base stats. Resistance types are not claimed as implemented.

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
godot4 --headless --path . --script res://tests/enhancement_ui_test.gd
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
8. At the Blacksmith, inspect both ordinary and high-rarity gear at all three UI
   scales. Swipe the stat comparison, preview the upgrade, check exact costs and
   current/next values, cancel, then confirm. Try two fingers and touch cancellation;
   only one purchase should occur. Verify insufficient materials disable approval,
   caps are shown correctly, and restarting retains successful upgrades. Compare
   success feedback with reduced motion/effects enabled and disabled. Confirm all
   labels, materials and numerical changes remain readable on the physical device.

Known limitations: icons and portraits remain reusable family artwork; the
preview is a deliberately static pose that rotates on demand; very long names and
descriptions use truncation/wrapping; first-person or portrait layouts are outside
this landscape milestone. Final visual sign-off requires rendered Android review.

## Item and Collection Hall inspection

Tap the labeled **Inspect** icon on a selected owned item, or interact with a
Collection Hall stand and inspect its preselected display. The read-only viewer
shows the saved instance ID, enhancement, durability, lore, accessible rarity
label and the existing model's honest artwork status. Drag the model to rotate;
swipe the independently clipped text to read the full lore. **Back** returns to
the same inventory or Hall selection while the existing gameplay modal stays
paused. Neither inspecting nor displaying creates another item.

The item viewer has a separate, isolated 384×384 viewport. It renders only on
opening, dragging, resizing or preference changes, and stops rendering when
closed. It does not change the character preview or introduce a new avatar rig.
Missing artwork remains labeled unavailable; shared family models remain
identified as prototypes. The shared presentation component supplies a static
rarity rim and runes; no particles or scheduler run inside inspection. Both mesh
and MultiMesh bounds are included when framing small items. No bespoke trophy
artwork is claimed.

Journals show collection completion from obtainable noncurrency definitions.
The Catalog filter permits read-only browsing of future definitions, explicitly
marked unavailable; these never count toward completion or grant ownership.
Journal rows and counts rebuild on saved snapshot refresh, not every frame.
Only visible rows draw within the existing native clipping and touch scrolling.

Automated inspection coverage is available with:

```sh
godot4 --headless --path . --script res://tests/hall_inspection_ui_test.gd
```

On Android, check the Inspect target, model framing, lore scroll and Back gesture
at every UI scale and graphics preset. Try two fingers, cancel a gesture, suspend
and resume the app, inspect from both Inventory and a Hall stand, and restart to
verify the displayed owned instance remains unchanged. Confirm labels, shared
model shapes and contrast on a rendered device; the cloud tests establish input,
geometry, ownership and rendering request behavior, not final visual appearance.

Inspection distinguishes owned instances, unsecured expedition stacks, secured
legacy overflow, merchant stock and catalog references; UID-less stacks retain
their real quantity and never receive fabricated instance IDs. Same-UID saved
updates refresh enhancement, durability, lore and static aura while preserving the
inspection angle. Authored item scripts and every descendant process mode are
disabled before insertion into the preview tree.

Inventory additionally offers Weapons, Armor, Accessories, Valuables and Trophies
group filters. Existing generic Equipment, favorites, locked and reserve filters
retain their IDs and behavior. Category sorting uses catalog group, equipment
slot and deterministic item-name ordering.

## Rare find feedback

Accepted Rare through Ancient Relic expedition rewards queue a compact,
noninteractive card with the existing shared family icon, readable rarity, exact
accepted quantity and **UNSECURED · Extract to keep**. Search inspection,
rejected transfers and repeated confirmations never create a discovery card.
Ownership and persistence remain with the existing reward and extraction rules.

One card is visible for 3.2 seconds, with at most four waiting cards. Waiting
copies of the same item combine their quantities; a larger burst discards the
oldest pending announcement without changing collected loot. Cards wait for
Search, Inventory, other menus and existing notices. Open menus, scene fades,
downed state or insufficient safe HUD space pause the visible lifetime. Leaving
or restarting a run clears its remaining announcements, including repeated seeds.
Reduced motion or effects removes the short border reveal. There are no added
particles, timers, preview viewports or input targets.

`tests/rare_discovery_test.gd` covers real accepted Search transfers, replay
rejection, exact quantities, queue limits, preserved save bytes, modal timing,
run resets and safe-area layout at all three UI scales. On a rendered Android
device, check readability over combat and Rootwarden telegraphs, touch-through
behavior, suspension/resume and late notices after death or extraction. Geometry
checks establish separation from HUD controls; they cannot establish whether a
world enemy or attack is briefly obscured behind the card.
