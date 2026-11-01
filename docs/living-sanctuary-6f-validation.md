# Living Sanctuary 6F validation

The frozen 6F gate passed **17,741 assertions across 89 suites and 108 separate engine processes**. Startup and every accepted suite exited cleanly with no script error, warning or leak. [Durable results](living-sanctuary-6f-test-results.json) contain exact commands, timings, source identity, per-log hashes and required input/isolation evidence. Focused development reruns are excluded. The JSON separately preserves 1 earlier stopped full-gate attempt, excluded from accepted totals. The [6E validation](living-sanctuary-6e-validation.md) and all earlier stage evidence remain unchanged.

## Frozen source and isolation

- Base commit `4f104b6febeacacedddc9a625415ee71e124b5a6`, plus the frozen 6F working tree.
- Semantic source `5687d40205e9b32f875d2e492f0933b11c17221fddf1b35f5a727c2de32ec478` over **775 files**. Opening, closing and final workspace manifests match. Scope: project.godot, scripts, resources, scenes, assets and tests; generated .uid/.import sidecars are excluded.
- Export preset `e7f792890b13be521636814d85393437d8f123f48074505cd51b9297704fb83f` matches the workspace. Project and Android version name `0.6.0-6f`, Android code **12**. No APK export was attempted.
- Godot 4.6.3.stable.official.7d41c59c4, Linux headless Compatibility. A fresh import and 120-frame startup preceded the suites. All processes ran sequentially from a copied snapshot with isolated XDG data, config and cache directories. Explicit save fixtures remain under /tmp; normal play storage was not used.

Editor import permits only the established local-socket/Android-tools environment notices. Startup and runtime logs use the strict error, warning and leak filter.

## Changed file groups

- `scripts/exchange/`: pure synthetic model, strict state/receipt/sale validation, eligibility, file store and source-bound controller.
- `scripts/ui/demo_exchange_panel.gd` and `exchange_text_panel.gd`: local TEST market/history and native draft editing, with narrow Game, HUD, Overlay, inspection and Sanctuary terminal hooks.
- Nine new runnable suites and their helpers: model, eligibility, sales, store, controller, restart, main UI, native input and independent real-progression isolation. The retained pet-world suite has the fixture-only encoding correction below.
- Project/export release metadata, README and stage documents: local authority and persistence contracts, manual Android checks, validation evidence and a backend proposal. The backend proposal adds no deployed service.

## Review and development corrections

The first full gate stopped at the retained pet-world extraction/reload assertion after 75 earlier invocations passed. A disposable deterministic reproduction isolated one adjacent IEEE-754 value: `statistics.best_seconds` encoded as `0.9583029999999999` and decoded as `0.958303` (variant payload bytes `f813950d6baaee3f` → `f913950d6baaee3f`). Every discrete field and all three pet provenance counters matched; the primary bytes and normalized decoded intent were exact. ProfileStore already verifies that serialization contract. The fixture now exercises this known case and compares exact encoded primary bytes, normalized decoded intent and unchanged discrete values/counters. No production code, tolerance or statistic rounding changed. The original frozen source and 76-invocation stopped run remain preserved and excluded from the accepted count.

A malformed-data probe reproduced runtime errors when boolean values reached comparisons intended for integer headers, receipt identities and history revisions. Explicit scalar guards and the sale suite's wrong-type matrix now reject these inputs without engine diagnostics. Review also closed two sale-history gaps: a short tape cannot claim that missing early rows were pruned by the 128-row limit, and newly appended records must match the preceding actual order's variant, execution price and buyer/seller. The terminal binding now retains the authored instance across same-world and candidate-world rollback, preventing a renamed replacement node from acquiring authority.

Focused runs also exposed GDScript type annotations, a Back fixture requiring a real process-frame boundary, an existing accessory slot used incorrectly by the protected fixture, and JSON-decoded numeric types in restart evidence. Those fixture/import corrections retain the original behavioral checks. The reader compares canonical fingerprints while recording every protected filename, length and SHA256, so representation differences do not weaken file preservation. A runner initially misclassified the passing text “Orphan backup” as an engine orphan diagnostic; the stage-specific filter now requires an actual orphan line prefix while still rejecting errors, warnings and leaks. These development runs are not counted as accepted full-gate evidence.

## Preserved and added checks

All **80 earlier suites /97 invocations** remain, contributing **13,371 assertions**. Nine new suites add **4,370 assertions across eleven processes**:

| New suite / mode | Passed assertions |
|---|---:|
| `demo_exchange_controller_test` | 83 |
| `demo_exchange_eligibility_test` | 29 |
| `demo_exchange_model_test` | 597 |
| `demo_exchange_restart_test --write ROOT` | 11 |
| `demo_exchange_restart_test --read ROOT` | 11 |
| `demo_exchange_sales_test` | 979 |
| `demo_exchange_store_test` | 42 |
| `demo_exchange_ui_test` | 408 |
| `exchange_isolation_test` | 2,041 |
| `exchange_isolation_test --read` | 38 |
| `native_exchange_input_test` | 131 |

The complete gate includes **15 separate-process readers**. The new store restart suite runs only `--write ROOT` then `--read ROOT`; the isolation suite runs its normal writer then `--read`. Both readers share only their writer's isolated fixture and XDG namespace. No default restart mode is invented.

Preserved counts changed only as recorded below. Dynamic smoke coverage adds nine script loads and one check opening the new exchange directory. The pet-world fixture adds exact encoding/discrete-data checks for the proven elapsed-time boundary while preserving its prior source and lifecycle checks; the correction is explained above.

| Preserved mode | 6E assertions | 6F assertions |
|---|---:|---:|
| `pet_world_sources_test` | 316 | 318 |
| `smoke_test` | 750 | 760 |

Dungeon seeds **0–99** again pass structural validation and exact reproduction; **100 cosmetic seeds ×14 modules** retain authored-transform/native-mesh bounds coverage; pet-discovery seeds **1–100** retain deterministic placement and RNG checks. The real player and both AI companions traverse all eight city districts and both terraces with zero companion recoveries across **7,067 physics frames** and maximum actor step **0.089334 m**. The existing pet traversal, geometry, 30/60/120 simulated update-rate fixtures, native chat and pet naming suites also pass. These records are not measured device FPS or GPU performance.

## Local transaction and persistence evidence

The TEST realm starts with two synthetic actors, **20,000 DEMO DM, 24 lots, 184 item units and ten fixed equipment identities**. It contains no fabricated sale history. Eligibility uses the reviewed existing catalog; ownership never comes from actual player progression. Tests conserve money, finite units, full equipment variants and exclusive custody through orders, partial fills, resting-price matching, price-improvement refunds, claims, edits, direct trades, cancellation and explicit saved clock expiry.

Each actual-game command rechecks protected profile/UID counters, gear, talents, displays, companions, pets, visual/social settings, every protected file, retained catalog fields and gameplay RNG state. The writer executes **191 reviewed commands**, observes **85 live lots** and reaches **64 claims for one actor through persisted commands**. Current profile, rotating backup, pre-v5 migration backup and preference hashes are identical in the separate-process reader. Both processes report the same committed aggregate hash: `ecc3d0de7041d3d6377fffff3c847d8fa46f2bc0ea4b4ba023f957f5d7f98c55`. Restart retains orders, deliveries and locked escrow; final approvals do not return from disk.

A separate pure-model sequence completes **129 actual executions** and verifies exact retention, including pruning within an earlier multi-fill command. The bounded tape retains up to **128 actual committed order executions**, including exact item variant, price, quantity, buyer/seller, command receipt and controlled time. Automatic fills use the resting order price. Closed/canceled orders retain their completed sale rows; retries and rejected or failed saves cannot duplicate them. The UI separates ACTIVITY from SALES and groups min/max/last/unit-volume summaries by exact variant. Direct trades receive no inferred per-item price. Reset clears this synthetic tape. The independent writer and reader retain **1 sale row** with matching canonical tape hash `16ccc83b2ba4d0c1dc26ff2ff606ad67e614fe02229a737b22eea68611ab8dc8`.

Capacity coverage distinguishes its setup: the pure suite prepares a normalized 40-inventory+63-claim boundary, then executes listing, full-claim and cancellation operations. That boundary was not built by a fixture-to-boundary command sequence. The actual-game writer independently reaches 64 claims through committed commands. More than 208 assets is a forged-invalid normalization case; the conserved fixture contains only 184 units. Revision cleanup headroom and preallocated return claims preserve cancellation/claim routes without depending on spare ordinary inventory capacity.

Canonical payloads, namespace/epoch/revision and per-actor command counters govern duplicate handling. Retained receipts have strict action-specific result shapes and contiguous observed actor sequences ending at their saved heads. Pruned commands remain processed; changed-payload repeats cannot execute; explicit reset changes epoch and retains its reconciliation receipt. Stale disk adapters, changed bytes at the same identity, missing-primary history, future/corrupt files, write/backup/replace faults, lost acknowledgements and uncertain outcomes are covered. Exact readback decides publication; corrupt data cannot silently reset to a fresh executable history.

One-use opaque UI confirmations are consumed before callbacks. The mutation guard spans persistence, state installation and notifications. Reentrant callbacks can close presentation, but cannot quote/commit/reload another mutation. First direct-trade approval is ephemeral: no disk write, receipt, command counter or transfer. A separate second approval saves the complete settlement once; failures clear temporary approvals and preserve committed escrow. Closing, travel and focus loss invalidate consent without announcing a fictitious refund.

## Physical authority and native input

The real authored Ring terminal establishes authority before the guide pauses gameplay. Guide, market and native field retain that same binding. The source-free top-right map cannot acquire exchange authority; choosing CITY MAP clears the binding. Fresh actions require the exact current world/player/source, life state, range and line of sight. Queued/freed or copied terminals, travel, focus loss and callback replacement reject stale intent. Focus loss retains the weak physical binding while disabling availability and clearing pending consent; resume revalidates it.

The native exchange editor uses actual viewport ScreenTouch dispatch and committed Unicode/physical-key events through `Input.parse_input_event` plus explicit flushing. Tests prove physical W and the global movement action are held before close, then require release quarantine. Direct editor-text assignment is not the typing proof. Numeric bounds, same-batch Return, Unicode Backspace, two-finger Apply, canceled/dragged controls, Back during a held press, old editor callbacks, source loss and travel all pass. Search and numeric Apply edit drafts only; transactions require a separate review.

Idle main-panel and native editing checks cross multiple source-watch intervals without rebuilding the full inventory/history snapshot. Source/focus events refresh availability, and one deferred completion refresh handles externally initiated guarded operations without restoring recurring polling.

The editor covers **72 synthetic canvas/scale/inset/keyboard combinations** and preserves existing preference files. Retained chat and pet-name native suites repeat their own 72-case geometry and callback checks. Demo item inspection remains explicitly labeled and resets its context before real inventory inspection.

## Limits

This is a local offline demonstration. It does not prove authenticated accounts, simultaneous-process database safety, server ownership, trusted rewards, production idempotency storage, online matching or deployed networking. The [server contract](living-sanctuary-server-contract.md) records those later requirements. No optional capture, permission retry, APK export or physical Android test occurred. Headless checks do not establish Android IME composition, rendered art quality, touch comfort, sustained FPS or thermal behavior; the [Android checklist](living-sanctuary-android.md) remains the manual acceptance record.
