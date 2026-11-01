# Milestone 7D.1 validation

The frozen full gate passed **21,102 assertions across 109 suites and 130 separate test processes**, plus a fresh import, strict 48-script loader preflight and 120-frame startup. Every accepted runtime log exited cleanly without script errors, warnings or leaks. [Machine-readable results](milestone-7d1-test-results.json) preserve every source hash, command, result, log hash and separate development diagnostic. Earlier failed/focused attempts are excluded from these totals.

## Scope and frozen baseline

This is the first 7D integration batch. **Only the existing Rootbound Abyss, three existing ordinary enemies and actual Rootwarden are enabled.** Registered definitions, detached plans, source-specific rewards, scheduler reservations, explicit danger footprints and projectile lifetime interfaces prepare later content without advertising new bosses, biomes, hives or hordes.

- Local base commit `9718040dfa6a663917a695557558383e594329dd`; published GitHub counterpart `46e9a547b4c5a4cab5f34ee647a7ac7bf91059b3` has the same Git tree `d48396e6bebbaa877463ad757bb631f263187b33`. Historical 7C reports remain unchanged.
- **822 semantic files**, SHA256 `ce56f6dac67516f7082b426c88985e10629f96744e8034e6a9dcd79658882e15`. Opening, closing and workspace manifests match. Scope covers `project.godot`, scripts, resources, scenes, assets and tests; generated sidecars and documentation are excluded.
- Export SHA256 `0904bcda843e4b49beed6a2a6f3a822d1624d8051b86520079b0e0eb05841993`; project **0.7.0-7d1**, Android code **15**, profile schema **7**.
- Godot **4.6.3.stable.official.7d41c59c4**, Linux headless, Compatibility configuration. Source contains **256 GDScript files, 59 scenes, 476 resources, 7 shaders and 18 game SVG assets**. No semantic file was removed.
- Every engine ran serially from a copied source with disposable XDG and `/tmp` fixtures. **17 independent reader processes** verify persisted results. Normal play saves were not used.

Import recorded only the established sandbox local-socket and unavailable Android build-tools notices. The runtime warning/error/leak filter remains unchanged. The full gate includes all **97 preserved suites / 117 invocations**, plus **12 new suites / 13 invocations**.

## Changed systems

- New `biome_definition.gd`, `dungeon_presentation.gd` and Rootbound resources resolve fourteen existing modules, eighteen material roles, native textures and environment values into a detached plan. Room/decor hooks share reconstructed materials once per world and preserve authored geometry, collision and seeded decoration.
- New boss/attack definitions and registry adapt all 22 existing Rootwarden tuning exports without replacing its scene/controller. Content IDs, deterministic streams and `dungeon_content.gd` bind enabled definitions and frozen combat/presentation values to the existing depth policy. Legacy/configured generator outputs remain covered.
- Abyss, EncounterManager and the new scheduler privately register real actors, admit required-boss deaths once, and account for six active ordinary enemies, one boss lease, two hazards and one warned event. Pending warnings reserve capacity before display; safe-area/boss/exit cancellation releases it. Future summons remain rejected.
- Session, encounter progression, profile storage, rewards and pet-source mapping secure actual encounter records with existing extraction rewards. Unsupported encounter/depth metadata stays read-only; exact v1–v6 migration bytes, items, Depthmarks, equipment, companions, pets and depths remain protected.
- Game compares complete issued plans through the final fade, while the existing HUD displays issued theme/boss labels. Late failure restores the safe retained world, or returns to Sanctuary if that world is unavailable or an expired expedition, while restoring player/party/pet and preserving a newer Session or completed extraction.
- Explicit circle/capsule/sector/annular footprints support analytic segment checks and delayed Guardian/Mystic escape decisions. New projectile tokens opt into source and target eligibility plus reentrant lifetime checks; ordinary empty-token combat retains its existing rules.
- Twelve new suites, narrowly adapted retained fixtures, release metadata and the [content architecture](dungeon-content.md)/[Android instructions](milestone-7-android.md) document this stage. The machine report lists every added/modified semantic file.

## New accepted checks

| Suite / mode | Assertions |
| --- | ---: |
| `boss_definition_test` | 167 |
| `biome_presentation_test` | 177 |
| `content_registry_test` | 260 |
| `danger_geometry_test` | 602 |
| `encounter_progression_test` | 36 |
| `profile_v7_test` | 97 |
| `projectile_cast_token_test` | 93 |
| `content_session_test` | 46 |
| `content_restart_test --write` | 13 |
| `content_restart_test --read` | 12 |
| `content_world_test` | 41 |
| `content_travel_guard_test` | 87 |
| `companion_danger_shapes_test` | 113 |

These tests use actual Player, CameraRig, Guardian/Mystic, Rootwarden, room meshes, colliders, source containers, travel and save paths. They cover native-versus-content module equality, immutable plans, unavailable-definition rejection, source spoofing/duplicate receipts, warning reservations, full-delay commits/cancellation, boss admission, actual loot search/extraction and separate restart. Both cameras preserve actor/generation/reward identity. Projectile cases include thin-wall/muzzle checks, splash target eligibility, duplicate fan receipts, dodge receipts, source revocation and target/world removal.

Shape tests include independent seeded footprint membership, exact boundary/height cases, narrow safe holes, long segments and invalid queries. Actual companions keep reaction delays, committed attacks/heals and bounded decisions while leaving typed hazards. The retained 240-layout depth suite and 100-seed legacy suite also pass. These are native geometry/physics checks, not rendered approval.

## Preservation and fixture deltas

| Preserved mode | Accepted 7C | Current |
| --- | ---: | ---: |
| `rpg_integration_test` | 118 | 122 |
| `smoke_test` | 774 | 791 |

The RPG fixture now uses actual registered Skeleton and Rootwarden deaths instead of synthetic production completion setters, preserving its original 118 assertions and adding four source checks. Smoke adds exactly eleven production scripts, three resources and three scanned directories. There are no per-room count changes from accepted 7C; no previous assertion is dropped to satisfy a new source restriction. Retained 25-mode focused coverage passed 5,429 assertions before the full gate; that total is not added to acceptance.

## Development findings and corrections

The first aggregate loader exposed test-only strict-typing/alias errors together. All were corrected before runtime. A separate load-only exit symptom retained four existing catalog resources when CompanionBrain loaded first; accepted 7C reproduced it. Loading the unchanged VaultCompanion dependency first yielded clean 24-script baseline and 48-script current controls. The adopted preflight checks **all 47 changed/new scripts plus one explicit prerequisite**, exactly once, without changing production or suppressing diagnostics. Native `--check-only` lacked InputHub autoload context and was rejected, not reported as successful.

Runtime checks found a real legacy-record migration defect: Dictionary dot assignment created a StringName ID while strict normalization required a String. The fix creates the canonical String key and keeps external validation strict. Failed writes preserved original data. Direct migration/normalize/secure regressions and all six old-version exact-byte backups now pass. Omitted water shader color defaults were also resolved through native Color channels before snapshot encoding; exact appearance comparison remains, without numeric tolerance.

Other failures identified incomplete fixtures rather than gameplay regressions: standalone tests imported autoload-dependent actor types too early; an executing object cannot legally `free()` itself through a callback; a patrol fixture had no unoccupied socket beyond the safety radius; a trusted fade callback enabled the actor but not InputHub; an oracle used normalized-t padding against a metre tolerance. Each correction retains the original behavioral assertion and adds concrete eligibility/identity coverage where appropriate.

Two new suites ended immediately after a real combat sound. Verbose logs identified only an AudioStreamWAV/playback pair still retiring. Narrow synchronous WeakRef helpers remove isolated cached ownership, free the owning test world/arena and await actual bounded native retirement; production audio, strict filters and functional checks stay intact. Repeating a mutated restart reader alone was recorded as a non-equivalent failed probe; the fresh writer/reader pair establishes the audio evidence.

The final companion failure was a safe +Z dodge while the fixture assumed -Z. A decision trace recorded the selected destination, legal full-roll sweep and actual wall bodies; no unsafe roll or stale wall was established. The corrected fixture excludes the alternative with a second explicit warning, checks the actual selected heading and retains real escape/zero-dodge assertions. AI behavior was not changed to force a test direction.

All development logs and diagnostic file hashes remain separate in the machine report. Pre-gate reviews also closed warning-reservation, inactive-before-registration, final-fade recovery and typed-geometry edge cases before acceptance.

## Remaining verification

- Linux headless native tests are not rendered visual review, screenshots/video, physical Android touch/IME, APK export, sustained FPS, thermal or battery measurements.
- No display/GPU capture path was available; no Xvfb or GPU device was installed or assumed. Compatibility is the configured renderer.
- Only existing Rootbound rooms, enemies and Rootwarden are enabled. Additional biome controllers, bosses, summons, hives, hordes and Ancient encounters remain later content work.
- Curved warning meshes are triangle approximations. An enabled annular attack must also clip the inner safe hole in its local warning material; this batch enables no such new attack.
- Local runtime admission is not authenticated server security. No online deployment, matchmaking, accounts, database authority, leaderboard or payment was implemented/tested.
- Ordinary active expeditions still do not resume after process exit. Secured progress persists; local files remain editable development saves.
- Frozen run plans/presentation do not claim arbitrary live item-catalog or economy hot reload. Final balance and Android performance require manual testing.

Use the [Android checklist](milestone-7-android.md) for physical touch/keyboard, camera readability, audio, transitions, graphics presets and sustained performance testing. Existing Sanctuary, Ring Exchange demo isolation, portals, inventory/equipment, Spiritweaving, loot/extraction and both cameras remain in the accepted regression set. No service was deployed and no payment or physical Android test was claimed.
