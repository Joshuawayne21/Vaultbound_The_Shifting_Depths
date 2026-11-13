# Next local activities — proposed implementation slices

**Proposal only; neither activity described here is implemented or accepted.** Use the accepted [Beastwilds Stage 5a baseline](nexus-stage5a-validation.md); its native evidence does not validate these proposed activities. The current Echoes and Gilded portals remain unavailable. This plan does not add multiplayer, rankings, Realm Mastery or masks; the user explicitly deferred Masks of the Abyss.

## 5b — Echoes of Eternity: one complete five-wave trial

Start with an original spectral courtyard, open combat floor, readable spawn gates, upgrade shrine and safe return alcove. Reuse the existing combat controllers, enemy scenes, companion AI, two cameras and touchscreen controls. Normal entry would require a cleared/extracted Depth 3; existing offline TEST ACCESS could bypass eligibility once this activity actually works.

| Wave | Proposed existing enemies | Purpose |
| --- | --- | --- |
| 1 | Two Skeleton Warriors | Melee spacing and spawn warning |
| 2 | Skeleton Warrior and Goblin Archer | Mixed melee/ranged pressure |
| 3 | Two Skeleton Warriors and Goblin Archer | Target prioritization and flanking |
| 4 | Corrupted Golem, Skeleton Warrior and Goblin Archer | Heavy telegraph within a mixed group |
| 5 | Existing standalone Rootwarden, without adds | Actual boss attack/phase challenge |

This is a local five-wave trial with the recruited AI party, not endless survival, online cooperation or a new unique boss. Maximum active load is three ordinary enemies or one boss. Use bounded seeded pack/socket permutations and conservative data tuning. Each spawn needs actual floor/capsule clearance, at least six metres from party occupants and at least two seconds of warning. If sockets are blocked, request repositioning; never silently remove a required enemy or force an unavoidable spawn.

Wave completion must come from the original registered actors reaching verified death states. Missing/freed/replaced actors and repeated death signals cannot advance a wave or pay again. A frozen plan owns roster, receipts, rewards and break choices. Clean up only the retired wave's attacks/projectiles; do not replace the existing Proving Grounds or forge Rootbound depth admission to make newer dungeon bosses run.

After waves 2 and 4, propose one of exactly two clearly temporary player-only bonuses: +6% outgoing damage or +12% stamina regeneration. These are initial balance proposals. Bind the choice to the original shrine, generation and break, allow only one confirmed choice per break, and require explicit NEXT WAVE. Do not refill health/stamina, reset cooldowns/revives, mutate equipment or persist the bonus. Apply identity/default effects outside the owning run and preserve the same limits through weapon/camera changes.

Use the existing searchable loot interface, Session-owned unsecured bag and capacity checks, with at most one cache per cleared wave. Capacity failure leaves rewards searchable. Five verified waves enable explicit SECURE & RETURN; earlier departure is disclosed abandonment. The initial slice grants no character or companion XP. The trial must never grant Rootbound clears, Rootwarden trophies, Ancient discoveries or dungeon-specific secret achievements.

## Authority and save compatibility first

The Beastwilds v1 plan and its existing receipts/digests remain stable. Add a small explicit activity dispatcher and a separate Echoes plan rather than relaxing the Beast-only schema into arbitrary scene-provided authority. Keep canonical IDs/scripts, original source identity, native admission, reviewed/deferred input checks, completed-return proofs and the existing single Session/inventory/save owner.

Select the next profile/activity schema versions from the accepted baseline; do not reserve numbers while another migration is landing. Preserve normalized Beast records and any interrupted open ticket exactly. A shared monotonic serial must reconcile the sum of per-activity entries, with only one open ticket; retire an interrupted Beast visit against Beast's row. Unknown future IDs, fields and versions remain protected, with exact pre-migration backup and verified writes. Inspecting a locked portal must not write progression.

Extend loot access through an explicit admitted activity context while preserving the unchanged depth context, view identity, source receipt, generation, reach, line of sight and quote checks. Do not reopen generic arbitrary-reward helpers or create another inventory. Proposed local records include highest verified wave, objective-based score and fastest complete trial; they are not an online leaderboard.

## Independently testable Echoes checkpoints

1. **Compatibility:** add the closed dispatcher, migration and frozen plan while leaving entry unavailable. Preserve Beast golden plans/receipts, older saves, interrupted-ticket ownership and all current admission/settlement fixtures.
2. **Actual combat:** build the native courtyard and five-wave director with real existing enemy/boss actors. Verify a full combat run, spawning, all death-source/failure cases, companion reactions and both cameras. Keep entry unavailable until settlement works.
3. **Breaks and rewards:** add the two scoped choices, original-source caches, records and once-only save/return. Test touch cancellation/replay, full inventory, wipe/fall, failed save and failed destination retry.
4. **Release:** only after acceptance, enable the exact Depth 3 route and Nexus return, update cards/HUD/current guides and verify all retained worlds. Four major routes would then be playable and six remain unavailable; this is a proposed future count.

## 5c — The Gilded Vault: separate treasure expedition

After accepted Echoes, propose a seeded five- or six-room route: entrance reliquary, clue gallery, plate chamber, sealed treasury guarded by the existing Corrupted Golem, return route and optional hidden alcove. Reuse compatible authored 24 m modules with ivory/gold/amber dressing, preserving door openings, source space and both-camera visibility. Required and optional connectors must be reciprocal and reachable; movement must always allow returning to abandon.

Implement one genuine three-plate sequence puzzle. An inspectable clue gives the seeded order; the living player physically enters original bound plates. Wrong order resets safely; companion/pet overlap does not solve or reset it. Success latches once and opens a physical seal into a clear recess. Main treasure requires both the verified puzzle and actual guardian death. Use two or three seeded searchable caches with existing eligible valuables/materials/equipment; no unsupported boss drops or mask rules.

One optional trapped cache may use a clear warning, escape path and single owned damage window. Current depth-bound hazards/chests cannot be admitted with pretend depth metadata: add a narrow activity source adapter using existing visuals/damage/loot components and frozen receipts. Cancel retired attacks safely. Moving walls and mimics are **later work**, not descriptions of a stationary seal or ordinary Golem guard.

Proposed normal entry requires cleared/extracted Depth 5. Secure completion requires the puzzle, guardian and treasury objective; optional discoveries never block it. Keep separate records and the same failure/retry/save contract. Only enable Gilded after its actual loop and settlement pass; a fifth released route would leave five unavailable activities.

## Verification and remaining requirements

Each release needs fresh import/strict loads/startup, a frozen source and independent log review, existing regression gates and separate restart processes. Exercise real player/Guardian/Mystic movement, both cameras, original actor/source rejection, repeated/fake completion, callback replacement generations, full inventory, modal/focus behavior, death/healthy fall, failed save and saved-return retry. Gilded also needs at least twenty structurally valid deterministic seeds, native connector/puzzle/escape checks and physical walks of representative layouts.

Record actual native geometry/process/light budgets separately from rendered GPU costs and Android measurements. Physical touchscreen, background/resume, scene composition, frame pacing, memory and thermals still require device review. These local slices need no paid hosting, purchase credentials, paid assets or external services. Real cooperative play and public rankings remain separate authenticated-backend work.
