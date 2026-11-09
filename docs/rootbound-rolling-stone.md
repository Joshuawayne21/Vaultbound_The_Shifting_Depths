# Rootbound rolling stone

This guide describes the accepted **7D.7 Rootbound rolling-stone batch**, covered by [headless validation](milestone-7d7-validation.md). Rendered warning readability, apparent ground contact, physical Android controls and performance remain pending.

## Encounter

From Depth 6, a Rootbound floor with an eligible, unreserved thorn-trap room has one configured 25% opportunity to select a rolling stone. At most one room is selected. The selection uses a separate deterministic stream after the existing room-content choices. Crystal and Ember floors do not receive this trap.

The initial stone has a 0.65-metre radius and travels six metres at three metres per second. A complete two-second ground warning precedes contact. During travel, the warning covers the remaining route; ground behind the stone's radius becomes safe. Only the stone's current swept segment can deal damage. One attack identity covers the whole pass, including attempted hits avoided by a dodge.

The stone is a damaging volume with a moving visual, without a navigation or body collider. It cannot push actors, block a doorway or change room connectivity. Native walls and loss of supporting floor stop it harmlessly. A stalled active frame longer than 0.25 seconds cancels the pass without a catch-up hit. Its initial damage is 14, with the existing frozen depth multiplier applied once.

Only the selected room's initial legacy-root opportunity is replaced. Existing monsters, chests, doors and other content choices remain. Native admission can omit an unsafe placement or refuse an unavailable shared hazard slot. It has one first-entry attempt: leaving, cancellation or reentry cannot rearm the selected opportunity. It does not grant loot, currency, XP, discoveries or depth completion.

## Existing systems

The trap reuses the two environmental hazard wrappers, source identities, damage receipts, camera-independent combat rules, Guardian/Mystic danger responses and Return safety checks. Its fixed source node remains separate from its moving appearance. Directional blocking receives the validated approach position, preserving the existing shield and staff rules.

The selected floor plan advances to content version 7. Profile version 7, inventory, equipment, Depthmarks, pets, companions, prior encounters and the depth ladder keep their existing save format. Secured rewards still persist through the established transaction flow. Active dungeon simulations remain run-local and do not resume after process restart.

## Validation and manual review

The accepted gate retains all 221 prior runtime modes and passes 45,807 assertions across 194 suites / 229 runtime processes. Eight new suites cover actual native admission and obstruction, full warning and swept-contact timing, shield-facing behavior, attempted-hit deduplication, source cancellation/replacement, both companions and cameras, unchanged room rewards and honest Return behavior. The [stage report](milestone-7d7-validation.md) records exact commands, measurements, corrected development failures and evidence limits.

On Android, use a backed-up test profile with an eligible depth legitimately unlocked. Record the seed, depth and build. Inspect the entire warning in both camera views; escape sideways and behind the moving stone; compare shield-facing blocks and dodges; leave and reenter the room; verify adjacent chest and door access. Check Guardian/Mystic responses, Low/Medium/High settings, reduced motion/effects, touchscreen comfort and frame pacing. Test early Return and full extraction on separate runs, then reload secured progression.

The rock and its warning use original native prototype geometry. Headless bounds cannot establish visual polish, shader clipping, apparent ground contact or Android FPS. This batch does not implement collapsing floors, moving walls, laser barriers, mimic chests, cursed shrines, expanded hives or Ancient bosses. Those and the remaining Milestone 7 stages remain unfinished. No multiplayer, ranked server or authenticated persistence is claimed.
