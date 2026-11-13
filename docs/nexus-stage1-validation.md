# Nexus Stage 1 — Sanctuary reorganization validation

Build **`0.7.0-nexus1`**, Android export code **30**, passed **9,270 checks across 38 runtime modes and 36 suites**, plus fresh import, 20 strict script loads and 120 startup frames in Godot 4.6.3 Compatibility. All modes used one frozen semantic source, `55e35bf1c1305ea118ad0304984dce116c2e6acde072313109f5bf55f11c80f8`, in `focused-a1vm93s0`. Independent review verified the source, logs and **962 unchanged protected files**, with no exceptions. No rendered visual or physical Android acceptance is claimed.

[Machine evidence](nexus-stage1-test-results.json) records every mode, source/log manifests, independent review and separate budget inventory. Its SHA-256 is `3b8ea0991d6b6e4ce66d008a568ccd3c39ccf7e22fce56aa81a204e031acca41`. Earlier, interrupted and diagnostic runs are excluded from the 9,270-check gate.

The runtime baseline is local `1c05c94fa7cb733bcc2d775db9de7874cbb7bf73`, published main `8275babeb3338e1fde049d6e9ad2138cd357e0de`, tree `05a1d69b70e16579d4fe43917877b518d4c4aef5`. Stage 0 audit/plan documentation was separately committed as local `08e627386f037cabfb9c133a2dbdb25e2e4dc77e`, published main `e0249628e3b53f3bb1522250defaaf264952bd06`, tree `d64e47f4d9c432d44c1c26f2508b1702d82cbd52`; that publication left the home6b runtime unchanged. The recoverable source bundle and actual-system inventory are recorded in [the immutable Stage 0 audit](nexus-system-audit.md).

## Implemented scope and route changes

The update reorganizes the eight existing physical spokes into four functional wings, retaining the central Ring Exchange, one Living Prismheart, six shared DEMO booths, ring road and all eight arch/bridge connections.

| Wing | Physical districts | Existing services and architecture |
| --- | --- | --- |
| North — Nexus and training | A / B | Existing progressive dungeon and practice-dungeon gates; Proving Grounds gate and Practice Sentinel. This is the Nexus approach; the ten-gateway interior is later work. |
| East — merchants and crafters | C / D | Three existing NPC vendors at C; existing Blacksmith moves to D with forge/crafting presentation. All retain the original transaction authorities. |
| West — home, pets and appearance | G / H | Existing Personal Sanctuary portal and single Spiritweaving terminal at G; existing owned-equipment appearance preview on the retained H terrace. |
| South — arrival and recruitment | E / F | New public Grand Foyer on the retained E terrace, its city guide and new default arrival; existing Tavern/recruitment at F with social-court presentation. |

The public city foyer uses original native arches, columns, ivory/azure/gold inlays, banners, statues, basins, flowers and magical ornament. It is distinct from the already-owned home's Grand Foyer. The new guide and map provide actual waypoints; selection does not teleport the player or authorize distant services.

The layout has **14 POIs**: all thirteen previous identities plus `foyer_guide`. Each resolves to exactly one actual source. The home gate moves from southeast D to west G while retaining `CollectionHallGate`, `collection_hall`, the `personal_sanctuary` destination and the same saved home. The Pet Conservatory authority remains the registered `ConservatoryCityTerminal`.

Only the default city arrival intentionally changes, to **`(0, 0.95, 31)`**, facing the Exchange above the supported southern terrace. Three existing return transforms remain unchanged:

- `from_dungeon`: `(0, 0.15, -5.4)`, original orientation.
- `from_abyss`: `(3.5, 0.15, -5.5)`, yaw `-PI/2`.
- `from_hall`: `(-3.5, 0.15, -6.5)`, yaw `-PI/2`.

The former Forge/Tavern terrace geometry now supports the southern Foyer and northwestern Appearance pavilion. Their physical slopes and bridge routes remain; the services formerly occupying them move to their new wings.

## Gameplay, saves and availability

Production scope is presentation, authored city positions/labels, map grouping, one guide and the default spawn. Combat, weapons, current dungeon floors/themes/rewards, inventory, Depthmarks, equipment, companion rules, pet ownership, home rooms/displays and validated saving remain their existing systems. Profile **v11/home namespace v3** remain; this stage introduces no progression migration or new reward authority.

Playable routes remain the existing progressive expedition, practice dungeon, Proving Grounds and Personal Sanctuary/home rooms. Stage 1 does **not** deliver ten new activities, a streamed Nexus hall, Realm Mastery, Nexus Renown, Realm Seals, Ancient encounters, bank storage or guild competition. Existing cosmetics remain equipment/home presentation; no cosmetic checkout is added. Guild/social information does not claim authenticated players or rankings. The Exchange remains **DEMO / NOT LIVE** with synthetic TEST custody isolated from real progression.

After the audit found no established mask gameplay, F–S condition or Abysmal rules in this source, the user explicitly deferred that update: **“ill add that update later.”** Mask integration is deferred rather than an unanswered question. The existing `etched_patrol_mask_piece` collectible and unavailable future `forgotten_monarchs_mask` trophy remain unchanged; no invented mask probabilities, powers or drops are added.

## Accepted native coverage

- Fresh import, strict changed-script/dependency loads, startup and all 38 requested runtime modes passed on the same final source. The import reported sandbox socket and unavailable Android build-tools notices; these were isolated environment notices, not script failures or evidence of a completed APK export.
- The layout checked one actual source per POI, four wing memberships and cardinal positions, one Prismheart, four commerce authorities, one Tavern and seven shared Exchange registrations.
- Native foyer floor/arch/collision geometry, grounded default player/party arrival, exact three return contracts, service approaches and real touch interaction/waypoint guards passed.
- Actual player/Guardian/Mystic movement covered the retained ring, all eight bridge routes and both terraces. The player walked 632.97 m, Guardian 644.13 m and Mystic 652.61 m over 9,761 observed physics frames. Both companions recorded **zero recovery relocations**; maximum actor step was 0.08663 m. Both raised routes and all 24 actor/bridge witnesses were observed.
- Retained camera checks covered both modes, transitions, changed architecture and preset invariance; the capital suite sampled 11,016 transition frames. These are native collision/pose checks, not rendered visibility approval.
- Existing portal/depth/early-return/home behavior, commerce, Spiritweaving, owned-equipment preview, TEST ACCESS, mobile UI, DEMO exchange, restart readers and save isolation passed within this scoped gate. This does not claim every historical test was rerun.
- Independent review verified all accepted source/log hashes and protected-file pins. The new suite UID is included with the checked source. Historical home6b results remain separate.

## Development diagnostics — excluded

Native approach checks identified a pillar obstruction at the moved H appearance terminal and the new foyer guide intruding into the eight-metre circulation corridor. The final source moves the H terminal to district-local `Z = -1.8` and the foyer board to local `X = -4.45`; it retains line-of-sight, collision and interaction guards. A targeted two-mode repair diagnostic passed 306 checks. Those checks and the separate 12-check budget diagnostic are excluded from the accepted 9,270 total. Their relevant behavior was covered again by the final gate.

## Performance and device limits

The existing central architecture, instancing, bounded scenery and graphics settings remain. New district architecture uses existing native meshes/material families and static batching. A separate native inventory on the same frozen source passed 12 diagnostic checks across Low/Medium/High:

| Active Sanctuary after batching | Low | Medium | High |
| --- | ---: | ---: | ---: |
| Allocated instance-weighted triangles | 112,773 | 112,773 | 112,773 |
| Scene-tree-visible instance-weighted triangles | 99,216 | 104,174 | 107,359 |
| World nodes | 3,452 | 3,452 | 3,452 |
| Local realtime lights | 0 | 0 | 0 |
| Enabled world process nodes | 9 | 9 | 9 |

The world adds 120 nodes and 2,112 allocated triangles over the accepted home6b comparison; local-light and process-node budgets remain unchanged. One shared directional light is retained. Counts exclude the player/party/UI unless expressly reported in the machine file; the inventory paused party simulation. Visible geometry means scene-tree visibility before frustum/distance culling, and excludes glyph, sky and particle rendering work. The residual foyer subtree is not the whole foyer after shared batching. These counts do not measure GPU draw calls, rendered frame time, memory, thermals or sustained Android FPS.

No rendered screenshot or physical-device result has been collected for this stage. Lighting composition, wall motion/flicker, UI comfort, phone safe areas, actual keyboard behavior, follower presentation and sustained 30/60 FPS targets require the [Android review route](nexus-stage1-android.md). Preserve real phone profiles; fault injection belongs in disposable fixtures.

## Changed files and next checkpoint

Production changes: `scripts/sanctuary/sanctuary_layout.gd`, `scripts/sanctuary/sanctuary_district_art.gd`, `scripts/world/sanctuary.gd`, `scripts/ui/sanctuary_panel.gd`, `project.godot` and `export_presets.cfg`. Native coverage adds `tests/sanctuary_wings_test.gd` plus its UID and updates intentional layout assumptions in `sanctuary_world_test.gd`, `prismheart_native_checks.gd`, `visual_integration_test.gd`, `combat_test.gd` and `exchange_booths_test.gd`. Current README/home/tester guides, this report, the Android route and machine evidence accompany the stage. Stage 0 and historical reports remain unchanged.

After publication, normal **main → Code → Download ZIP** should identify `0.7.0-nexus1` / code 30. This does not install the update on a phone. The next independently tested checkpoint is the streamed north Nexus interior and common activity interaction foundation from [the ordered plan](nexus-realms-plan.md). Unavailable gameplay stays unavailable until its actual loop and reward authority exist. Mask integration is user-deferred; authenticated online infrastructure remains a separate prerequisite for live activities.
