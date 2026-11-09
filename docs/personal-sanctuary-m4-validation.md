# Personal Sanctuary Stage 4 — Trophy Hall and Pet Conservatory validation

Build `0.7.0-home4` (Android version code 25) passed **4,928 checks across 50 unique runtime modes, 39 suites and seven independent restart readers**, plus import, 39 strict script loads and a 120-frame startup. The accepted runtime evidence spans two frozen chunks with a verified test-only bridge. This verifies functional integration; rendered visual composition, physical Android performance and APK export remain unverified.

## Baseline, source and evidence

The preserved Stage 3 baseline is local commit `95437839d392acf848ba0837ae171efd5a3a96ca`, published as `5303ee4e8eb0488b155fb1d28e1a3fe93abf7c5c`, tree `7f4c8712ab50a49577edef525a58282b842dbe21`. Its [6,081-check report](personal-sanctuary-m3-validation.md) remains historical evidence, not part of Stage 4's total.

The user reviewed that delivered foyer positively as a very good starting point. Their device, renderer, frame rate and test procedure were unspecified. This feedback does not establish physical Android verification or visual acceptance of the new Stage 4 rooms.

The recoverable Stage 3 backup is `/workspace/backups/vaultbound-before-home-stage4/accepted-home3.bundle`, SHA-256 `968d8d997fc7968c059e5a14c04a614ce969bbb97bee6fb20aeb52cdbb54bb05`. Its `receipt.json` records Git bundle verification and the verified Stage 3 ZIP. It preserves accepted project history, not phone saves; the original unfinished worktree remains separate.

Final source SHA-256: `903ccd81f0b3150db4655cbf428d37835a8cac66aaa5dadb954f198dcede897a`. Commands, source manifests, raw-log hashes, test results and native metrics are in the [machine-readable report](personal-sanctuary-m4-test-results.json). Root independently verified **56 accepted logs**, native resource references, the source bridge and all **881 protected baseline files**. Existing item/pet content, baseline UIDs and historical machine reports remain unchanged.

## What changed

- The existing Trophy Hall gains 14.5 m walls, an 18.4 m vault, floor inlays, architectural framing and an original Rootwarden carving based on the shipped boss silhouette and existing Heart visual. Its eight equipment stands and four relic pedestals keep their IDs, approaches and saved ownership references. The mount's ownership and plaque use actual secured discoveries/encounter records; no new boss or discovery date is invented.
- A separate 28 × 32 m **Pet Conservatory** uses the existing east foyer doorway at `(7, 0, 4)` and returns through **RETURN TO YOUR GRAND FOYER**. Own one Spiritweaving pet, then **RECORD EARNED UNLOCKS → CONFIRM & SAVE** at Home Management. A milestone already recorded in an older profile stays valid.
- Six habitat slots are **North Meadow**, **South Meadow**, **Crystal Grove**, **Moon Pool**, **Canopy Nest** and **Ancient Grove**. **PET DISPLAYS → habitat → CHOOSE PET → REVIEW DISPLAY → CONFIRM & SAVE** assigns an owned pet. **Keep this habitat empty** clears it. One pet can occupy one habitat; clear its old slot before moving it. Ownership and active-follower selection do not change.
- Profile v10/home namespace v3 adds six `pet_displays` references through the existing profile authority. Migration preserves the home ID, themes, sigils, earned milestones, inventory, Depthmarks, equipment, Hall displays, companions and dungeon progression. New slots begin empty; existing pet IDs, aliases, natural/luminous variants and origin records are retained. Exact pre-v10 backups and future/unavailable read-only handling remain in force.

The original eight-species pet catalog and 351 item definitions remain unchanged. This adds no genetics, breeding, free-roaming population, combat pets, second inventory or online guest service. The reviewed foyer layout and city portal position remain intact. The city's **district G Spiritweaving Conservatory** still handles acquisition/journal access; the **home Pet Conservatory** displays already-owned pets.

## Acceptance across two frozen chunks

The scoped gate covers 11 new modes and 39 relevant retained modes. It is not a repeat of the entire historical regression and not a claim that all 50 modes ran against one snapshot.

| Chunk | Source | Accepted modes | Checks |
| --- | --- | --- | --- |
| `focused-ju7mp2gq` | `7a54416e9c1e5f819db6c58445e5aef23fce7a03f0e98a9f761604f97c529b2b` | First 19 | 1,328 |
| `focused-x8ne0ta9` | `903ccd81f0b3150db4655cbf428d37835a8cac66aaa5dadb954f198dcede897a` | Remaining 31 | 3,600 |
| Combined unique coverage | Verified test-only bridge | **50** | **4,928** |

The sole difference is `tests/foyer_surfaces_test.gd`: its obsolete Stage 3 expectation that the Conservatory remain unfinished became a check of the implemented, recorded-milestone-gated door and three travel destinations. All 71 checks and geometry probes remain. Every other **1,177 semantic files**, including all production and all other tests, are byte-identical; no accepted prefix mode depends on the changed leaf. The failed old leaf result is excluded and replaced by the corrected passing result. Both chunks retain successful setup, and final-source strict loading covers 39 scripts.

The only increased retained assertion count is `smoke_test`, 1,028 → 1,034; none decreased. All accepted runtime logs are free of script/runtime errors. Import alone contains the known sandbox local-socket notices and missing Android build-tools warning, documented separately; this does not establish successful APK export.

## Results and native measurements

| Area | Accepted result |
| --- | --- |
| Profile v10 migration | 72 checks |
| Pet display authority | 47 checks |
| Independent display restart | Writer 25 / reader 25 |
| Native touch display UI | 53 checks |
| Trophy Hall world | 48 checks, 92 floor probes, 220 camera samples |
| Conservatory world | 63 checks, 102 floor/capsule route samples |
| Room journey | 78 checks; 475 physics frames; same three party actors |
| Garden cameras, Medium / Low / High | 58 checks each; 1,792 transition frames each |
| Retained foyer route / camera | 199 / 132 checks; camera 5,376 frames |
| Related retained systems | All 39 modes passed |

The native room journey observed maximum actor movement step 0.148854 m and no companion recovery relocation. Garden camera minimum distance was 3.93047 m across the three presets; the repaired Hall minimum was 0.935246 m. Retained foyer camera minimum was 1.39472 m. These checks establish tested clearance, framing/visibility and continuity; camera retraction and artistic composition still need rendered play-testing.

The Hall measured **251 mesh nodes, 25,818 triangles, one directional key and zero local lights**. The Conservatory measured **332 mesh nodes, 30 MultiMesh nodes, six display pets and six habitats**, with 45 static batches. Its batcher reports 102 saved source submissions; this is an internal batching metric, not a measured Android GPU draw-call count. Foyer geometry still measured 95 static mesh nodes and 19,872 triangles, preserving the reviewed structure.

Display models use idle poses rather than navigation/AI: 10 Hz on Low and 20 Hz on Medium/High, with reduced-motion support. Ambient motes are capped at twelve. The existing active follower is separate from the six display slots. Only the active room remains loaded after travel completes. Accepted runtime processes took 543.116 host seconds; test duration and scene counts are not Android FPS, frame pacing, thermals or battery measurements.

Save tests use isolated synthetic profiles. They exercise migration/backups, owned-only assignment, duplicate-slot rejection, clear/reassign, stale/repeated confirmation, source validity, failed writes, read-only escape and independent restart. No player's phone save was opened or claimed as tested.

## Development failures and repairs

Failed and diagnostic runs are retained outside accepted totals:

- `focused-fggezzzr`: test-only typing/bootstrap problems and an ArrayMesh-specific metric API used on another mesh type. Explicit fixture typing and common mesh face counting fixed these without removing assertions or budgets.
- `focused-3smsnqwa`: a standalone fixture's strong camera type loaded its InputHub dependency before autoload bootstrap. The fixture now resolves the same real camera scene after startup.
- `focused-9zvpxzjd` and bounded diagnostic `focused-6qk21g5u`: the low Rootwarden mount retracted the camera to approximately 0.464 m at a valid walk-under point, and two rear planters encroached on the garden crossing path. Raising the whole mount from 3.65 m to 4.3 m, moving rear trees to z = −14.2 m and reducing planter radius from 1.1 m to 0.95 m corrected the geometry. Camera rules and distance tolerances were not weakened. The original garden probes remain, with 24 additional crossing-width probes.
- `focused-ju7mp2gq`'s later retained leaf failure: the obsolete sealed-Conservatory expectation described above. Its passing prefix is retained through the verified bridge; the failed leaf is not counted.

## Limits, import and manual review

Home themes recolor the foyer and Trophy Hall. The Conservatory intentionally keeps its authored greenhouse palette. The Rootwarden carving, item family visuals, garden pets and architecture are original/existing native prototype art, not finished imported premium models. No paid asset or external service was added.

Use the published **`vaultbound-personal-sanctuary-m4.zip`** or GitHub branch **`feature/personal-sanctuary`** once this checkpoint is published. Import the newly extracted folder's root `project.godot`, verify `config/version="0.7.0-home4"` (Project Settings → Application → Config → Version), then **Run Project**. An old folder/default branch can show earlier rooms; Run Current Scene on the Hall alone bypasses the home route. Publication remains a separate final step from this validation record.

Back up the phone profile and backup files separately. Follow the [Android checklist](personal-sanctuary-android.md) through **city district D → foyer → Hall / Conservatory → foyer → city**, display save/restart, both cameras and all presets. Inspect actual lighting, models, pet scale, clipping, touch comfort, cutouts and frame pacing. No rendered capture, physical Android test or signed export was performed for this stage.

Armory, Companion Hall, Relic Library, private rooms and the city/landscape/sky overhaul remain unfinished. Online visiting, banking, guild creation, live trading and purchases are not introduced. The user-reviewed foyer and these functionally verified rooms are incremental checkpoints, not completion of the full Sanctuary overhaul.
