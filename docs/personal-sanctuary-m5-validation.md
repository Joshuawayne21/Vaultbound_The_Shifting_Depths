# Personal Sanctuary Stage 5 — six-room validation

Build **`0.7.0-home5`**, Android version code **27**, profile **v11/home namespace v3**, passed **5,313 checks across 40 runtime modes and 37 suites**, including two independent restart readers. Fresh import, **36 strict script loads** and **120 startup frames** passed. All accepted modes ran against **one final frozen source snapshot**; earlier failed and diagnostic runs are excluded. Rendered and physical Android review remain pending.

Final source SHA-256: `cf5b40bd0c3132256ca15fa8344318da47402eb9c314f89c2fbdc948a7c30f68`. Accepted run: `/workspace/scratch/vaultbound-home-stage5-validation/home-rooms/focused-79g8htlq`. The [machine report](personal-sanctuary-m5-test-results.json) records exact commands, hashes, results and limits. Independent review verified all **43 accepted logs** and **899 protected files**, plus two explicitly scoped integration exceptions.

## Implemented scope

Six separately loaded rooms reuse the existing foyer doors: Armory, Companion Hall, Relic Library, Personal Chamber, Wardrobe and Rooftop Garden. Presentation reads actual owned equipment, saved Guardian/Mystic records, secured journals and one active pet. Game retains travel/service authorization and persistence. The reviewed foyer, Trophy Hall stand IDs, Conservatory habitats, combat, cameras and dungeon systems remain preserved.

The tester extension bypasses only pet-recipe achievement gates; enabled recipes, secured ingredients, creature-memory seeds and ownership remain required, and it grants no achievement. After TEST ACCESS is turned OFF, a normally locked room's services recheck eligibility while safe exit remains available.

## Accepted checks

| Coverage | Checks |
| --- | ---: |
| Six-room native world, routes and owned presentation | 314 |
| Both cameras and transitions | 525 |
| Actual Game journey and service use | 223 |
| Room service authorization | 48 |
| Spiritweaving tester policy | 28 |
| 35 retained modes | 4,175 |
| **Total: five new + 35 retained modes** | **5,313** |

Retained coverage includes home migration/session/UI, Trophy Hall/Conservatory, foyer navigation/camera, pet progression/following/UI, party persistence, mobile UI/settings, depth/early-return guards and smoke. Independent readers cover home displays and party persistence. This is a scoped gate, not a rerun of every historical test suite or physical Android acceptance.

## Native geometry and camera findings

The new world checks include **1,438 floor/capsule probes**. The new-room camera checks cover Low/Medium/High and **4,026 samples**, including **2,016 transition frames**; the minimum measured camera distance is **0.89652 m**. The retained foyer camera mode in this gate uses Medium, including 5,376 transition frames; it is not a repeat of every historical foyer preset. The real journey keeps the same level-one player and two companion actors across six rooms, six services and three upper-gallery returns.

| Room | Mesh + MultiMesh nodes | Triangles |
| --- | ---: | ---: |
| Armory | 161 | 17,588 |
| Companion Hall | 205 | 18,690 |
| Relic Library | 97 | 12,766 |
| Personal Chamber | 108 | 7,030 |
| Wardrobe | 164 | 14,108 |
| Rooftop Garden | 135 | 16,758 |

Each room has one environment, one directional key and zero local lights. Counts remain within the tests' 300-node/30,000-triangle room budgets. Source caps bound displays to six gear models, two portraits and one resting pet where applicable, plus twelve ambient motes; idle poses use 10 Hz Low / 20 Hz other presets. Static batching estimates are not GPU draw-call measurements. Accepted runtime processes took **507.542 host seconds**, which is test duration, not Android frame rate.

## Resolved development findings

- Wardrobe bench armrests intersected authored capsule routes. Benches moved from x ±7.4 to ±8.2 m; route checks stayed intact.
- A preview-touch fixture targeted the wrong panel. It now uses the actual equipment overlay input owner, retaining rotation assertions.
- Upper-gallery arrival rays could hit one of two authored coplanar landing bodies. Only the exact canonical East/West upper-landing bodies were added to the valid-floor set; same-parent, height, normal and all three actor-capsule guards remain.
- A retained foyer test enforced a settled six-metre formation radius while a delayed command was still taking a valid ground detour around the Trophy Hall pillars. Production navigation and geometry were unchanged. The corrected test continuously checks grounding/no recovery during the bounded eight-second convergence, retains the five-metre settled condition and 32 low-velocity frames, then checks the original six-metre cap for 90 hold frames. Eight assertions were added; no distance threshold or production AI behavior was weakened.

The earlier `focused-uo_0nkb5` and `focused-bh72p3e_` runs are not counted as accepted. The final gate reran all 40 modes on the final snapshot, so no cross-snapshot acceptance bridge is needed.

## Preservation and changed files

The 899 protected files remained unchanged. Two separately reviewed exceptions are narrow: `scripts/party/party.gd` admits the canonical Companion Hall recruitment/dismissal context, and `scripts/pets/pet_progression.gd` admits TEST ACCESS achievement eligibility without changing costs/provenance. Tests used isolated source/XDG namespaces and synthetic profiles; existing player profiles were not touched. Profile v11/home v3 remains the schema, with pre-v11 backups and read-only recovery preserved.

New production files are six `scenes/world/home_*.tscn` room wrappers and `scripts/home/home_room.gd`, `home_room_service.gd`, `home_workroom_builder.gd` and `home_private_builder.gd`. Integration edits cover the home catalog, Game travel/services, foyer arrival/doors/management, session/UI and the two scoped policy files above. Relevant tests and current documentation are updated; historical reports remain unchanged. Exact source/UID manifests are in the machine report. The predecessor is accepted tester-access commit `3e9e65a23d2fd8dac759160bb6eb5e73142bdfc0`, published as `320549ea6af7ca92a1c706a05f454da739f6e1c0` with the same Git tree.

## Remaining review and limits

No screenshot or rendered GL acceptance was obtained: the optional Xorg attempt was blocked by the environment's Unix-socket restriction, and an optional retry ended without a result. No APK installation, physical Android touch test, thermals or device FPS measurement is claimed. Use [the Android checklist](personal-sanctuary-android.md) with a backed-up profile and the correct source build; keep the existing application/user-data identity and do not uninstall or clear data.

Architecture and models are original native-mesh/available-family prototypes, not new bespoke rigged art or premium licensed assets. Wardrobe uses existing equipment inspection; hairstyles and purchased skins are unavailable. Companion Hall supports the existing Guardian/Mystic. Library is read-only. Rooftop follows the owned active pet; there is no new pet inventory, genetics or acquisition. Furnishings are fixed; home themes provide current customization. The Pet Conservatory retains its greenhouse palette.

The blueprint city redesign, later home extensions, online visits, bank, guild services, live trading and billing are unfinished. This checkpoint does not claim the full requested Sanctuary overhaul is complete.
