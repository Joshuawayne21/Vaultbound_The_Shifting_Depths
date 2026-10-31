# Living Sanctuary 6D validation

The frozen 6D gate passed **12,208 assertions across 70 suites and 86 separate process invocations**, with no failed invocation, script error, warning or leak. [Durable results](living-sanctuary-6d-test-results.json) record exact commands, counts, timings, log hashes and required native-input evidence. Development/focused reruns are excluded from this total. The [6C validation](living-sanctuary-6c-validation.md), [6C test results](living-sanctuary-6c-test-results.json) and [6C resource measurements](living-sanctuary-6c-performance.md) remain unchanged historical evidence.

## Frozen source and execution

- Base commit: `fd9ab4caf73597fec01e63fea7575408c4954dcd`, plus the frozen 6D working tree.
- Semantic source: `f203f0372759719f5e598684e804ae1c27aa375963e33e89fd929a9a773f7289` over **713 files**. Opening, closing and final workspace manifests match. Scope is project.godot, scripts, resources, scenes, assets and tests; generated .uid/.import sidecars are excluded.
- Export preset: `8c3eefdb8562d05acdb423536a846b835d99fdd459f82177f09836c9a3fc9b39`, matching the workspace exactly. Project and Android version name `0.6.0-6d`, Android code **10**. No APK export was attempted.
- Godot 4.6.3.stable.official.7d41c59c4, Linux headless Compatibility. Fresh editor import and 120-frame startup preceded all suites. Every engine process ran sequentially with disposable XDG data/config/cache roots; explicit restart fixtures stayed under /tmp. Normal play storage was not used.

Import reported only the established host local-socket notices and absent Android build-tools directory. Startup and every suite log were clean. No generated script UID was missing from the workspace after validated import.

## Preserved and added coverage

All **65 prior suites and 79 modes** were preserved, contributing 11,487 assertions. Their test sources and shared harness are unchanged from 6C. The smoke suite checks six new scripts and the new social directory (717 assertions versus 710), accounting for the increase from the prior 11,480 total. The five added suites contribute 721 assertions across seven processes:

| Added suite / mode | Passed assertions |
|---|---:|
| `emote_presentation_test` | 238 |
| `native_chat_input_test` | 136 |
| `social_preferences_test` | 63 |
| `social_preferences_test --write PATH` | 13 |
| `social_preferences_test --read PATH` | 9 |
| `social_session_test` | 166 |
| `social_ui_test` | 96 |

`social_preferences_test` has three deliberate modes: its substantive no-argument suite, `--write PATH`, and `--read PATH` in a separate process. The complete gate contains **12 independent readers**. Existing visual-preference readers and every old save/restart mode remain present.

The gate reran structural validation and exact reproduction for dungeon seeds **0–99**, plus **100 cosmetic seeds × 14 modules = 1,400 cases**. Existing combat, boss, loot, inventory, economy, progression version four, accessibility, service, camera, spawn and portal checks all passed.

Actual city navigation again exercised the original player controller and both companions across all eight districts, ring sectors and both terraces, including ascent, Hold and Retreat descent. It recorded **7,046 physics frames**, player/Guardian/Mystic distances of 496.3 / 488.1 / 497.9 m, **zero recovery teleports**, and maximum actor step **0.089334 m**. Exact route-planning/probe counters remain in the JSON. These are traversal counters, not FPS measurements.

## Native input and lifecycle evidence

The new native suite boots the actual Game, HUD and LineEdit. ScreenTouch events traverse the viewport with global touch/mouse emulation disabled; the scoped chat bridge delivers native focus, buttons and scrollbar dragging. OS-style physical-key and committed Unicode events use `Input.parse_input_event` plus explicit buffer flushing. The suite proves that physical W and the underlying movement action are active before closing chat, then checks no movement/attack until release, fresh touch movement during keyboard quarantine, and successful fresh keyboard movement afterward. Direct assignment to LineEdit.text is not the evidence for native typing.

Committed Unicode, native selection/Backspace/Return, two-finger Preview deduplication, rate-limited draft retention, WORLD/PARTY draft-only behavior, focus loss, stale editor signals, modal replacement and travel all pass. All suite processes also completed cleanly. The source keeps editing after Return so the next same-batch text is retained. Callback regressions cover close/replacement during draft publication, old-token replay, attempted submission during close, preserved replacement-editor generations, and unread snapshots arriving before deferred text_changed notifications. Lifecycle invalidation and suppression precede callback-producing storage; stale continuations check their generation and submissions revalidate their editor/source.

The suite checks **72 layout combinations**: three canvas sizes × three UI scales × two safe-area insets × four synthetic keyboard heights. Composer, Back and Preview remain separate with 60-pixel target heights; an unusably tall keyboard is dismissed with the draft retained. Compact captions identify the active channel. Additional checks cover resize-only native rectangles, text width and the single conversion from physical keyboard pixels to canvas units. These are synthetic layout/input checks, not physical Android keyboard measurements.

## Presentation and storage boundaries

Social capabilities remain offline: all shared-channel sending is disabled. LOCAL creates only an explicitly labeled self DEMO preview; WORLD/PARTY keep editable drafts without fabricated delivery or remote senders. Model checks cover deep-copy snapshots, consumed submission tokens, signal-listener reentry, a global 60-row memory limit, 256 Unicode characters / 1,024 UTF-8 bytes, control-character rejection and monotonic local limits of one preview per second and five per ten seconds. No transcript file, reconnect queue or human-account authority is introduced.

Only font size, compact transcript visibility and timestamps persist in the separate version-one social settings file. Strict schema/future-file protection, write failure, independent restart and exact byte comparisons preserve the eight existing visual preferences and progression version four. Actual UI actions also preserve the secured roster, inventory and profile bytes.

All nine emotes remain finite procedural visual poses. Checks cover both weapon styles, reduced motion, pivot/attachment and planted-foot bounds, cancellation by movement/combat/damage/downing/revive/weapon change/spawn/input reset, direct controller/session paths and unchanged combat/progression state. UI checks cover all wheel selections and truthful inspection of the two actual AI companions, including queued/freed/dismissed/old-world sources. Camera/target selection remains separate from emote cancellation.

The [social behavior and retention contract](living-sanctuary-social.md) matches these current capabilities and documents the separate server requirements. No 6E pet progression, 6F exchange or online service is implemented in this checkpoint.

## Limits

No optional software capture or permission retry occurred in 6D. Headless native-control and committed Unicode checks do not establish Android IME composition, soft-keyboard display, physical Back behavior, rendered appearance, touch comfort, sustained FPS, thermal behavior or APK export. The [Android checklist](living-sanctuary-android.md) remains the device acceptance record. This stage adds no new GPU or resource-performance claim; the measured 6C report remains tied to its own frozen source.
