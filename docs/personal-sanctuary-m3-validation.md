# Personal Sanctuary Stage 3 — Grand Foyer validation

The functional foyer checkpoint `0.7.0-home3` passed **6,081 checks across 46 suites and 60 separate runtime modes**, including nine independent restart readers. Godot import, 35 strict script loads and a 120-frame startup also passed. This verifies the authored foyer's gameplay integration; rendered visual composition and physical Android acceptance remain pending. The other home rooms and blueprint-based city overhaul are not complete.

## Accepted source and scope

- Engine: **Godot 4.6.3.stable.official.7d41c59c4**, GDScript, Compatibility renderer.
- Source SHA-256: `69dafcf0d7b488ea71e31a3383f16e7737cbdbcd66d8bb8bfccc13d916337a7e`.
- Final run: `/workspace/scratch/vaultbound-home-stage3-validation/focused-oxrl2_rg`.
- Raw results, commands and hashes: [machine-readable report](personal-sanctuary-m3-test-results.json).
- Root independently rehashed and rescanned all 63 accepted logs. Final source, export metadata, protected files and runner artifacts remained unchanged.

The scoped gate runs 11 new modes and 49 relevant retained modes. It covers migration, home transactions/restart, native touch UI/travel, physical stairs/rails, player/Guardian/Mystic/ground-or-flying-pet circuits, both cameras under three presets, and related existing travel, display, economy, persistence and combat checks. Every modified retained test remains represented. Retained assertion counts increased only in `home_world_test` (+12) and `smoke_test` (+9); none decreased.

This is not a rerun of all 234 historical Stage 2 modes. Stage 2's [46,230-check report](personal-sanctuary-m2-validation.md) remains unchanged historical evidence. Development, diagnostic and failed runs are excluded from the 6,081-check total.

## Implemented behavior

- A two-story foyer with ivory/blue/gold architecture, horizontal stair treads over continuous collision ramps, guarded upper gallery, tall vault ribs, window reliefs, central floating House Sigil and crystal chandelier.
- Home-local themes/sigils, a touchscreen management lectern, reviewed/confirmed saves, permanent earned milestone records and the existing Trophy Hall/city travel routes.
- Profile v9/home namespace v2 migration retaining the original home ID, earlier backup files and established inventory, pet, companion, trophy and progression ownership.
- Sealed future doorways with actual requirements. Only Foyer and the existing Trophy Hall are open; earning a future room's milestone does not create its service or destination.

Original native meshes remain prototype art. No new inventory, economy, combat rules, online visits, guild service, banking, live market or billing was introduced.

## Final results

| Check | Result |
| --- | --- |
| Import, strict loads, startup | Passed; 35 scripts, 120 startup frames |
| Profile v9 migration | 81 checks passed |
| Home Management authority | 126 checks passed |
| Home Management independent restart | Writer 31 and reader 23 passed |
| Native management touch UI | 126 checks passed |
| Foyer surfaces and visible stairs | 71 checks passed; 439 floor samples |
| Ground-pet stair circuit | 199 checks passed |
| Flying-pet stair circuit | 199 checks passed |
| Foyer cameras, Medium / Low / High | 132 checks each; 5,376 transition frames each |
| Related retained modes | All 49 passed |
| Protected content | 351 items, 26 loot definitions, 423 existing UIDs and 32 historical reports unchanged |
| Rendered visual / physical Android review | Not performed |
| APK export/signing | Not verified |

Each stair circuit recorded 5,011 physics frames and approximately 277.6 m of player walking, with Guardian and Mystic following. Maximum observed actor step was 0.085511 m. Ground/flying pets recorded no recovery or replacement placements during the observed circuits and retained the six-query cap; their maximum observed movement steps were 0.200001 m and 0.240709 m respectively. Tests included both directions, upper Hold/Follow, lower-floor regrouping and Retreat, and camera changes during movement.

Camera tests cover native clearance, target visibility/framing and smooth transitions at 12 positions on both floors. All three presets retained essential collision. Retraction is expected near solid architecture; the tests do not establish attractive rendered composition or physical-device comfort. Existing home round-trip coverage separately sampled 1,344 camera-transition frames and 316 walking frames.

Save tests use isolated synthetic progressed profiles, not the player's phone save. They exercise migration backups, ownership preservation, read-only handling, failed writes, stale/repeated confirmations and independent restart. Existing Hall display IDs and inventory ownership remain in their established fields. Read-only return routes do not allocate identities or write progression.

## Development failures and repairs

Failed runs were retained and excluded from final totals. The accepted run includes the following repairs:

- Coincident internal stair-turn wedge boundaries could make floor rays miss. Internal collision wedges now overlap by 0.001 radian while keeping the intended route and outer boundaries. Final geometry checks covered 439 supported samples.
- Home batching cells increased from 8 m to 12 m, reducing static mesh nodes from 124 to 95 without deleting architecture.
- UI fixtures were corrected to use actual touch input, evaluate the intended read-only state and respect queued scene destruction. Production behavior was not weakened to satisfy these fixture errors.
- Raw formation offsets behind a gallery retaining face could target upstairs while the leader stayed below. The existing decision-time navigator now resolves offsets on the leader's continuously walkable surface with floor, body and hazard checks. Both Follow and the separate direct Retreat caller use that resolved destination. The earlier combined candidate passed only 198/199 ground-route checks because Retreat had been missed; the final ground and flying routes each passed 199/199.
- Pet movement across a flat-to-slope crest could cut the floor along a straight chord despite supported endpoints and trigger recovery. The trail now advances to its already-sampled midpoint where needed, retaining the same full capsule sweep and six-query budget. It does not raise collision clearance or hide failure through relocation.

Earlier successful diagnostic camera/UI/surface suites are superseded by the same checks on the final source. A successful individual suite never made its surrounding failed diagnostic run an accepted build.

## Changed files and performance findings

Production changes are concentrated in `scripts/home/`, the home catalog resource/class, `scripts/ui/home_panel.gd`, the existing profile/inventory/session authority, and a narrow Game travel bridge. The route fixes also touch `scripts/party/companion_navigation.gd`, its `companion_brain.gd` callers and `scripts/pets/pet_trail.gd`; retained city/party/pet checks passed. Focused tests cover these changes. The city layout, combat mechanics, loot definitions and dungeon content are not redesigned by this stage.

The final native architecture sample measured **95 static mesh nodes, 19,872 triangles, 12 materials, one environment, one directional light and zero local lights**. Its 100 stair treads include 200 gold-nosing triangles; maximum visible-to-collision offset was 0.035546 m. Geometry is built once and uses the existing static batcher. Accessibility settings control ornamental motion and Sigil intensity.

These are scene counts, not Android GPU draw calls or FPS. Runtime processes took 995.672 host seconds in total, excluding setup; this is test duration, not gameplay performance. Import reported the known sandbox socket notices and missing Android build-tools, documented separately from runtime errors. No Android GPU shader, sustained frame-time, thermal, battery or APK acceptance is implied.

## Remaining work and manual testing

Run the [Android checklist](personal-sanctuary-android.md) for both floor circuits, companions/pets, all camera presets, touch comfort, management saves, Hall ownership and dungeon return routes. Review actual lighting, geometry seams, stair silhouettes, Sigil/chandelier composition, camera retraction and UI readability on rendered hardware.

Closed plinths fit the existing single-height-field navigation model; this does not add arbitrary stacked-floor navigation. The expanded Trophy Hall, pet display habitat, Armory and remaining connected rooms still need their own stages. The six-booth Prismheart city redesign, monumental walls, landscaping and sky overhaul remain pending. This checkpoint is functionally verified prototype architecture, not a claim of finished premium artwork.
