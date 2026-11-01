# Rootbound dungeon depths

Milestone 7C adds floor progression to the existing Rootbound expedition. Its validation status is recorded separately in the stage report; this guide explains the rules and preservation boundaries.

## Entering and unlocking

Approach the blue Rootbound gate in the Sanctuary Portal Promenade. Open its existing review card, select a depth and review eligibility before confirming ENTER. Selection itself does not write progress or begin an expedition. Depth 1 starts unlocked. Defeating the required boss **and successfully extracting** from Depth 1 unlocks Depth 2; each later completion unlocks the next depth. A defeated boss without completed extraction does not secure an unlock.

Unlocks, loot, pet findings, experience and completed-run statistics share the existing verified save transaction. A failed save leaves the expedition available for retry. Death or abandonment loses only the current unsecured rewards and does not reduce previously secured depths. Repeating an earlier floor preserves higher unlocks. Both cameras use the same issued floor and combat state.

This build configures depths 1–50. Clearing 50 records unlocked 51, which remains unavailable until content is configured. Valid higher unlocks in older data are retained rather than reduced to this build's content limit. There is one local human party leader with up to two recruited AI companions; this is not online party eligibility or matchmaking.

## Floor bands and bounded scaling

| Depths | Band | Rooms |
| --- | --- | --- |
| 1–5 | Beginner | 6–9 |
| 6–10 | Adventurer | 8–12 |
| 11–15 | Veteran | 10–16 |
| 16–20 | Elite | 10–16 |
| 21–30 | Master | 12–20 |
| 31–50 | Abyssal | 15–24 |

The data in `resources/expedition/depth_policy.tres` defines these bands. The floor health multiplier rises by 0.018 per depth after the first, damage by 0.012, and earned encounter DM/extraction XP by 0.035. Their respective caps are 1.9, 1.6 and 3.0. At Depth 50 the factors are 1.882, 1.588 and 2.715. These are **floor factors**: existing room-distance and elite modifiers still apply separately. Costs, cooldowns, attack range, movement, hit windows and warning times do not change with camera perspective or repeated room activation.

7C establishes progression and longer layouts. Monster/boss DM and extraction XP scale; existing treasure-chest currency, item and pet tables remain unchanged. The reward wrapper retains the original receipt/source/room-distance item roll and changes its DM amount once. Its tier-specific encounter/hazard identifiers are extension points for 7D; they do not mean new traps, biome mechanics, bosses or Ancient events already exist. No new rare item is guaranteed by reaching a depth. Early safe extraction before the required boss also belongs to the later encounter stage, rather than being mislabeled as a completed floor here.

## Reproducing a layout

Record the visible seed **and depth**, policy version and game build. Configured generation uses version 2 and preserves the original fourteen room modules, 24 m connectors, reachable boss/extraction and optional treasure. Separate deterministic random streams keep decoration from consuming encounter or topology randomness. Derived seeds are bounded so existing per-room arithmetic stays within signed 64-bit range.

The legacy `DungeonGenerator.generate(seed)` API retains its original 8–12-room behavior for existing fixtures. The new configured path is `generate_for_depth(seed, depth)`. A room's internal `depth` field still means graph distance from the entrance; it is not the selected expedition floor. Configured layouts carry a separate `expedition_depth`.

Session and the generated world each retain a detached copy of the admitted policy. World validation, later encounter activation, reward scaling and completion use that copy. Editing a shared authoring resource after admission cannot reinterpret an ongoing run; a new run resolves the current valid configuration. UI previews cannot supply authoritative reward multipliers or completion depths.

## Save compatibility

Profile v6 adds `depth_progression` with a namespace version, highest unlocked depth and highest cleared depth. Migration happens in memory on load. The first successful write preserves exact old bytes through the existing pre-migration backup mechanism. Item IDs and instance IDs, Depthmarks, rolls, enhancements, loadouts, talents, companions, pets, discoveries and Hall assignments keep their existing formats and ownership.

A pre-depth save with at least one successful Rootbound expedition proves a Depth 1 clear, so it starts at unlocked Depth 2. Many historical completions do not imply many different floors. Explicit supported legacy depth fields are validated and merged without decreasing progress; malformed or unrecognized apparent depth formats are preserved read-only for an explicit migration. Never delete a profile or replace it with empty defaults to work around an error.

Runs remain in memory and cannot be resumed after closing the game. These safeguards support offline development; editable local files are not secure account persistence. Future online admission, rewards and progression must be decided by an authenticated authoritative service.
