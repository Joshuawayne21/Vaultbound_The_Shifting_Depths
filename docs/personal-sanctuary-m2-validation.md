# Personal Sanctuary Stage 2 validation

Build `0.7.0-home2` provides a saved offline home identity, a temporary ground-floor entrance and the preserved Trophy Hall route. The full Grand Foyer, other home rooms and public-city architectural redesign remain unfinished. The supplied Prismheart blueprint has been inspected and is recorded in the [integration plan](personal-sanctuary-plan.md).

## Accepted result

The final Godot 4.6.3 run passed **46,230 assertions across 198 suites and 234 separate runtime processes**, including **23 independent restart readers**. Isolated editor import, **34 strict script loads** and **120 startup frames** also passed. No runtime script error, warning, failed assertion or timeout was accepted.

[Per-process report](personal-sanctuary-m2-test-results.json) SHA-256: `fa8b255f8e28aa5d8bfc80bdd2a9dd4c6a84290ae9dda70ac0173bf10a8e34e9`.

The accepted semantic snapshot contains 1,147 files and has SHA-256 `1bc8ea1c182dcb861afede41bcc39b97edf9566700f4cad8d884f089b822b38c`. Its opening copy, closing copy and working project matched exactly. Export metadata was pinned separately. Root independently rehashed and rescanned all 237 accepted raw engine logs before approving the report; a separate verifier also checked the excluded development evidence.

All **229** runtime modes from the accepted 7D.7 baseline remain, with five new Home modes adding **390** checks. Six retained suites add **33** route/resource checks; none loses assertions. The total is `45,807 + 390 + 33 = 46,230`. All 351 item definitions, 26 loot tables, 415 pre-existing script UID files and 30 historical reports retain their exact pinned bytes. Eight new script UID sidecars were copied from the accepted imported project.

## What was exercised

- Profile versions 1–7 migrate to v8 through the existing save service, preserving exact original migration backups, secured ownership and unknown/future-data protection. Failed writes do not publish an empty replacement profile.
- Actual touch input opens the city portal card, confirms entry and traverses Home → existing Trophy Hall → Home → Sanctuary. Repeated touches retain one active world and the same player/party actors. A subsequent legacy Hall visit returns to the city independently.
- First entry creates one opaque home identity and one revision; repeated visits reuse both. An obstructed first arrival may have prepared that identity already, but grants no visit reward and never rerolls it on retry.
- Native floor and capsule queries check the actual player and both companion formation slots. Missing floor, unknown entry IDs and individual blocked slots reject arrival; failed travel retains the previous scene and restores controls.
- The actual movement joystick drives the player across the home while Guardian and Mystic follow. Continuous observation covers **314 physics frames**, with maximum actor displacement **0.085546 m per observed frame** and no companion recovery relocation.
- Both camera transitions remain clear of native solids through **1,344 observed transition frames**, across Low/Medium/High settings and multiple poses. This verifies collision behavior, not rendered composition.
- Existing Hall displays resolve the same owned equipment/relic UIDs and earned Rootwarden display. Home travel and presentation changes preserve exact saved profile bytes after identity creation.
- A real expedition after home entry admits the required boss arena, verifies ordinary extraction, and verifies later expedition death preserves secured ownership under the existing durability/death rules. The Home fixture defeats the registered boss through controlled test damage; retained combat/boss suites separately exercise their mechanics.
- Independent writer/reader processes preserve home identity, inventory, loadouts, displays, pets, companions and progression. The reader's death changes only the existing death counter, revision and equipped-item durability.
- Retained combat, weapons, enemies, bosses, dungeon generation, safe returns, merchants, crafting, enhancements, pets, party, social/demo-exchange and mobile UI suites pass. The demo exchange remains isolated from earned Depthmarks.

## Corrected development failures

The first focused run attacked a sleeping boss from the entrance room. Its fixture now moves into the actual arena through the existing discovery/activation flow before damage; production combat restrictions were unchanged.

The second run incorrectly measured 20 settling frames as a single actor step. The test now observes every physics frame through movement, settling and regrouping, retaining the original maximum-step and no-recovery checks. The corrected focused run passed 6,239 checks in 64 modes before the separate full run. None of these development runs contributes to the accepted total above.

## Scope, performance and manual work

The home uses the existing static architecture batcher, one environment, one directional light and bounded ambience. The host spent 2,371.025 seconds running the full headless engine checks; this is test duration, **not game FPS or Android performance**. No new light-heavy renderer features, external art purchases, gameplay currency, inventory domain or multiplayer service were introduced.

Import emitted the already-known sandbox socket notices and a missing Android build-tools notice. These are listed separately in the report; they do not establish APK export readiness. Runtime validation accepted no errors or warnings.

No physical Android device, rendered screenshot, APK export, GPU frame-rate measurement or pixel-quality assessment was performed. Current art is original native-mesh prototyping. Actual touch comfort, screen cutouts, lighting/framing, thermals and sustained 30/60 FPS targets require the [Android acceptance route](personal-sanctuary-android.md). Migration tests use rich synthetic historical profiles; actual player files were not opened.

The [home guide](personal-sanctuary-home.md) documents the playable route and save boundary. The original unfinished 7D.8 work remains preserved in the separate worktree and verified pre-change backup. Full foyer architecture, management/customization, later rooms and the blueprint city expansion are subsequent stages. Live accounts, visiting permissions, guild creation, banking, real trading and billing remain unavailable.
