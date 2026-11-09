# Personal Sanctuary milestone 1: audit and backup

Completed 2026-11-09. No new home gameplay is represented as implemented by this milestone.

The existing Godot 4.6.3 Compatibility project was inspected for world travel, Sanctuary architecture, cameras, inventory/equipment, collection ownership, pets, companions, local persistence, scenery, quality settings and online readiness. [The integration plan](personal-sanctuary-plan.md) records the existing systems, ten-stage order and constraints. The Prismheart blueprint image was not present; the written architectural directions are recorded without claiming an image match.

[Backup evidence](personal-sanctuary-backup.json) identifies the verified Git bundle and 1,667-file archive, including all unfinished shrine changes. The new worktree starts from the published D7 tree. No existing files were reset. The recovered shrine diagnostic finished 24 modes, with 16 passing and eight failing; it remains unaccepted and is outside this feature branch.

## Fresh accepted-build baseline

| Suite | Passed checks |
| --- | ---: |
| Sanctuary world | 225 |
| Collection world | 36 |
| Profile v7 | 97 |
| Smoke/resource loading | 1,010 |
| **Total** | **1,368** |

All four modes exited successfully in an isolated copy of the accepted 1,133-file semantic source. Godot version was verified and 12 relevant scripts passed deferred strict loading. Source manifests before and after match. All seven raw log hashes and their recorded check totals were independently rechecked. See [machine-readable results](personal-sanctuary-baseline-results.json) for exact commands, hashes and evidence paths.

Import emitted the known sandbox editor-socket notices and missing Android build-tools notice. Runtime modes and strict loading had no errors or warnings. This run did not repeat the historical 229-mode D7 gate or add a separate 120-frame startup pass. It used disposable user data and did not touch a normal player save.

## Findings and next gate

Preserve the existing Collection Hall scene and twelve saved display IDs behind the new foyer. Append a home destination to the shared travel shell, keep the legacy Hall route, and configure the Hall's return per visit. Add home persistence explicitly through profile validation and exact pre-migration backups. Reuse existing touch controls and camera collision.

The full Grand Foyer requires tested navigation across stacked floors; the existing companion navigator assumes one floor per horizontal position. The isometric camera also needs approximately 14 m of overhead clearance. Those are milestone 3 requirements, not solved by a decorative staircase.

No current backend supports online home visits, guilds, real trading or billing. No bank storage service or purchased-cosmetic entitlement system exists. These gaps remain explicit in the plan.

No rendered visual approval, physical Android measurements or APK export occurred. The first home stage must verify actual portal interaction, arrival floors, both cameras, trophy preservation, repeated entry, independent-process save/reload and failed-write behavior before its commit.

Changed files in this milestone: `personal-sanctuary-plan.md`, `personal-sanctuary-backup.json`, `personal-sanctuary-baseline-results.json`, and this report. Gameplay source and player data are unchanged.
