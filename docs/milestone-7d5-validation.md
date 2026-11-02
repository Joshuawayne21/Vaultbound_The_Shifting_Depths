# Milestone 7D.5 validation — Glimmering Crystal Abyss

Accepted: **37,813 assertions across 167 suites and 196 runtime invocations**, including 21 separate-process readers. This is the first additional playable dungeon theme, not completion of all Milestone 7 features.

The accepted 7D.4 baseline is local commit `14ae57719703691b1963f0e1ad7bd3afc3072031`, published as `6695c413fc9dbbb7726d655f380789b7cc0417eb`; both have tree `25a68419d7d26cc53199e62db1ca9b54b982f67e`. Historical reports and durable evidence remain unchanged. The [machine report](milestone-7d5-test-results.json) records exact source, commands, logs, fixtures and rejected development evidence.

## Implemented behavior

Crystal shares the existing dungeon depth ladder and transition flow. Depths 1–5 remain Rootbound. At depth 6 and beyond, a dedicated seeded theme draw uses Rootbound/Crystal weights 60/40. Content-plan version 5 freezes the actual theme, presentation, source definitions, native arena and reward profiles. There is no separate Crystal unlock ladder or silent Rootbound fallback when Crystal content is invalid. Profile version 7 and depth-policy identity remain unchanged.

Fourteen Crystal native room modules preserve the existing room roles, cells, connectors, gameplay anchors and required route. Six original mineral prop designs, eighteen material roles and the Crystal environment provide the new setting. Ordinary enemies retain the functioning skeleton, archer and golem archetypes with Crystal appearances and source identities; this does not add three new AI classes. These assets and character bodies are original native-mesh prototypes pending rendered art review.

Prism Conductor uses separately warned ground-lane stages, Geode Colossus combines a frontal cone and separately warned slams, and Shard Wraith combines a visible harmless grounded relocation, finite non-splash bolts and an exposed cast. Required-boss weights are 34/33/33. The Conductor has a conditional one-in-four Refracted variant with its own later-phase cross definition; it receives one base reward. The optional Crystal Lancekeeper uses a planted narrow thrust and is not required for depth completion.

Staged attacks retain a full warning for each damaging stage, a harmless gap and one full final recovery after completion or abort. Interruption and source retirement cancel remaining stages and owned projectiles. Wraith movement is grounded and collision checked; it is not teleportation. Its flight warnings have no ground-damage authority. Exact native actor dimensions, warning shapes and private issued identities remain admission boundaries. Guardian and Mystic remain the supported companions and respond through their existing movement, danger and combat rules.

The registered resonance lane warns before up to three separated pulse attempts. Delayed frames do not cause a catch-up damage burst. Actual initial traps and awareness events share the typed implementation while retaining their different admission clocks. Private accepted/terminal identities and dispatch observations prevent reused wrappers, stale callbacks or room retirement from resolving another attempt. Rootbound roots, spores, hives and hordes remain Rootbound content; no Crystal hive or horde is added.

Seven reward tables cover ordinary tiers, three required bosses and the optional encounter using twenty existing item definitions. The catalog remains 350 noncurrency definitions plus the existing currency row. Actual source deaths use the frozen floor scaling once, existing searchable caches, partial Take and existing extraction transactions. No Rootwarden-exclusive items, Rootbound elite fragments, craft-only high enhancement components or future Ancient encounter rewards are added to these tables. Crystal grants no new pet ingredients or forms; its pet subsystem receipt only prevents repeat processing.

Secured named encounter records discover the theme and derived variant history. Ordinary kills do not invent named-boss history. Full extraction still requires actual required-boss victory and unlocks the next depth; a safe Return spring secures collected loot and kill-only XP without completing the floor. Death, abandonment, failed-save retry, old discoveries and owned pets retain their previous behavior.

The portal shows eligible theme and boss pools before entry and the actual issued selection afterward. The minimap retains the complete theme name at supported text scales. Periodic button updates repeat current local ownership, reach, LOS, focus and eligibility checks while reusing only bound reviewed availability for presentation. ENTER and deferred travel still perform fresh full content checks. A newly rejected availability result stays denied until a new review; cached display values cannot admit a run.

## Accepted validation

Godot 4.6.3.stable.official.7d41c59c4 ran serially on isolated copied source with disposable XDG directories and synthetic profiles. The project configures Compatibility rendering. Fresh import, strict loader preflight (84 changed scripts plus the Companion prerequisite, 85 unique paths) and 120-frame startup passed before runtime suites. All 171 previously accepted modes remain, with 25 new modes. Accepted runtime logs contain no ignored errors, warnings, object leaks or failed assertions. Import socket and missing Android build-tools notices are recorded separately; no APK export is claimed.

| New suite / mode | Passed assertions |
| --- | ---: |
| `crystal_content` | 1,820 |
| `crystal_presentation` | 180 |
| `crystal_rewards` | 909 |
| `crystal_journal` | 27 |
| `crystal_environment` | 382 |
| `crystal_actor_visual` | 89 |
| `crystal_boss_controller` | 160 |
| `crystal_boss_sequence` | 126 |
| `crystal_boss_projectile` | 79 |
| `crystal_miniboss` | 26 |
| `crystal_hazard_runtime` | 94 |
| `crystal_world` | 25 |
| `crystal_environment_lifecycle` | 51 |
| `typed_hazard_admission` | 20 |
| `crystal_rewards_integration` | 294 |
| `crystal_rewards_restart (write)` | 141 |
| `crystal_rewards_restart (read)` | 28 |
| `crystal_boss_ui` | 402 |
| `crystal_boss_companion (family=conductor)` | 263 |
| `crystal_boss_companion (family=colossus)` | 168 |
| `crystal_boss_companion (family=wraith)` | 162 |
| `crystal_boss_companion (family=lancekeeper)` | 93 |
| `crystal_hazard_companion` | 74 |
| `crystal_hazard_companion (active-edge)` | 78 |
| `crystal_return_ui` | 142 |

The gate exercises actual Game admission and native rooms, concrete registered bosses and optional actors, both camera modes, all four Crystal companion-family modes, actual warning and active-pulse responses, private-source cancellation and replacement, safe native returns, searchable loot, full extraction/death, migrations and separate-process persistence. Retained pre-autoload Abyss consumers remain unchanged. Eighty-three original Rootbound assets are pinned and byte-compared to the accepted baseline, including all five original Rootwarden implementation files and authored rooms, props, materials, attacks and hazards.

The actual seeded 24-room Crystal world (seed 3) measured 464 native static bodies and 769 collision shapes. Native prop and actor surface arrays, posed bounds, warning winding/lift and indexed triangle counts were inspected directly. The machine report retains the per-module and per-actor metric lines; these are CPU/native counts, not GPU draw calls or device frame times.

Retained assertion-count changes:

- `projectile_cast_token_test` 93 → 125 (+32) — Thirty-two added actual stationary-obstacle and native-attachment lifecycle assertions; all 93 prior checks retained.
- `legacy_hazard_evidence_test` 67 → 68 (+1) — One additional explicit content-v5 positive; historical v3/v4 checks retained and the future-denial fixture advances to v6. Actual Game scenarios now verify current v5.
- `content_travel_guard_test` 95 → 96 (+1) — All 95 gameplay assertions remain; one added condition observes actual Game/captured native audio resource retirement before test exit, preserving strict leak filtering.
- `event_content_test` 1,811 → 1,818 (+7) — Six explicit 100-public-Rootbound-seed guards for existing depths [1,2,6,11,30,50], plus one named-source seed guard. All 600 plans×3 original assertions retained; current content-version expectation advances 4→5.
- `content_registry_test` 261 → 264 (+3) — Three explicit 20-public-Rootbound-seed guards for existing depths [1,10,50]. Original 60 plans×4 checks and 21 postloop assertions retained.
- `rootbound_content_test` 1,813 → 1,820 (+7) — Six explicit 100-public-Rootbound-seed guards for existing depths [1,2,5,6,11,50], plus one named-source guard. Original 600 plans×3 checks and 13 postloop assertions retained.
- `smoke_test` 841 → 924 (+83) — Unchanged recursive smoke loader adds 80 actual loadable resources and 3 actual directories; all original gameplay checks retained. Tests are outside this loader scope.

## Rejected development attempts and corrections

All evidence below is excluded from accepted totals; copied sources and strict logs are retained.

- Initial strict preflight rejected two new test-only syntax/type errors: a reserved local identifier and an untyped Vector3 result. Exact local corrections preserved production, helper and export bytes; no startup or runtime proceeded after that failed setup.
- The first 45-mode diagnostic passed 37 modes and rejected eight. Three boss-controller checks left the actual player inside the boss room while forcing only the room index to the entrance. A copied trace proved synchronous cursor/token/warning cancellation succeeded; normal world processing then correctly reacquired the player's room. The fixture now moves the actual player to the native entrance before normal processing, keeping all cancellation checks.
- The reward fixture incorrectly treated an anti-replay pet receipt as a pet grant. A copied trace proved the secured profile, ingredients, seeds and statistics were unchanged, forbidden drops absent, and the whole pending DTO differed by exactly one actual receipt. The corrected fixture requires that exact full DTO and unchanged repeated-death result. The first diagnostic print itself used a nonexistent field name; that rejected probe remains recorded separately from the corrected trace.
- Five prop checks and two presenter checks used `Mesh.get_faces()`, which builds a quantized TriangleMesh representation. Independent ArrayMesh and indexed Cylinder controls proved the raw native surface arrays preserved the submitted geometry while that derived representation changed vertices. Exact surface-array/index expansion now measures the actual native meshes. Existing dimensions, physical hulls, triangle limits, tolerances, winding, lift and containment requirements are unchanged; no production mesh was altered to satisfy the test.
- The actual long Crystal minimap label measured 156 pixels against 145 available at 120% text scale. The existing overlay now wraps only when needed, using measured complete words and actual font metrics. Its legend, room graph and footer remain inside the existing frame; tests cover both ordinary and discovered Return/extraction labels.
- The retained legacy hazard fixture still identified actual current plans as version 4 and rejected version 5. It now verifies actual version 5, keeps explicit version 3/4 compatibility checks and rejects future version 6.
- Pre-gate source review found concrete shared callback and obstruction seams. The muzzle ray now includes the existing stationary encounter layer. Native projectile attachment revalidates its exact handle, parent, source and cast before pose assignment. Copied controls reverting only the muzzle mask or only the attachment guard produced four and eighteen failures respectively in the unchanged 125-check projectile suite; the candidate passed all 125. Typed hazard wrappers, dungeon reservations and cached warnings likewise preserve replacement activation ownership across callbacks; their actual-source tests are retained.

The corrective 13-mode pass cleared the eight earlier failures but rejected retained `content_travel_guard_test`: all 95 gameplay assertions passed, followed by an ObjectDB shutdown warning. Three unchanged verbose repeats produced one clean exit and two leaks of an `AudioStreamWAV`/`AudioStreamPlaybackWAV` pair. Clean retries alone were not accepted as a resolution.

A copied identity trace matched the final SceneTree-owned combat sample's signed ID to the same process's leaked WAV ID. No audio-player node remained at that capture, so this does not claim direct observation of the playback object's retirement. A separate copied control removed only the known test-owned sample cache, queued the owning Game, and observed the exact sample WeakRef and Game retiring before exit. It passed the unchanged 95 gameplay checks plus one diagnostic retirement assertion without a fixed sleep or disabled audio. The narrow retained-test correction uses that bounded observed-retirement boundary. Production audio, travel code and shared test harness remain unchanged.

The first copied audio proof was rejected at strict preflight because an instrumentation-only WeakRef inspection local inferred Variant; neither runtime probe ran. A separate copy with an explicit Object annotation performed the documented controls. All rejected attempts and the independent source/log reviews remain separate from acceptance.


## Changed files and evidence

107 semantic files were added, 67 modified and no existing system was removed. The machine report enumerates each path. Main areas are theme selection and frozen content; native Crystal rooms/presentation; three required boss families and optional Lancekeeper; typed hazards and observation; existing reward tables/journal integration; portal and minimap UI; shared projectile boundary guards; and focused/retained test fixtures. The original Rootbound assets listed in the preservation manifest remain byte-identical.

Accepted semantic source: `c20021848374c6cf89476a7b34a8c2d328f3ac523914ba2dd33d5c5357444459` (1017 files). Export configuration: `a962e04f110ca53d384ecb39105c026acc6998410bbaea51163b1c2aa14e6ebb`. Evidence: `/workspace/scratch/vaultbound-7d5-validation/final-c39qezwu`. Only genuinely new imported UID sidecars are retained; existing tracked IDs are preserved. Explicit restart fixtures, including the physical nonsymlink exchange fixture, are captured and hashed apart from normal player saves.

## Limits and manual review

No rendered screenshot/video, GPU profile, physical Android test, APK export, live multiplayer backend, authenticated authority, paid hosting or payment integration was performed. Native geometry, font metrics and Linux host timings are not device visual or FPS approval. Local source checks and profile files are not secure online accounts.

GPU fragment clipping and warning/art readability require rendered review. Test both cameras, mobile aim and companion escape paths, text scales and notches, portal availability changes, Return springs, partial inventory and long-floor frame pacing on supported Android devices. Follow [the Crystal guide](glimmering-crystal-abyss.md) and [Android testing instructions](milestone-7-android.md). Dungeon runs still do not resume across process restart; only secured profile progress persists.

Remaining themes, Ancient encounters, expanded recruitment, pet genetics, Veilgarden, Bloodfall Frontier and authenticated ranked services remain later work. No live leaderboard, marketplace or purchasing is claimed.
