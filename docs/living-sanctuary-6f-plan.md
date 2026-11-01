# Ring Exchange integration plan — 6F

Implementation and complete headless regression validation are finished; this document records the integration constraints. See the [validation record](living-sanctuary-6f-validation.md) for accepted results and remaining device checks. The preserved starting point is local commit `4f104b6febeacacedddc9a625415ee71e124b5a6`, published as `cd3f251fe888be7c7c894f9554d44181a73172f9`. Its complete gate passed 13,359 assertions in 80 suites / 97 invocations. Its game/profile remains the source of actual offline progression. 6F adds a separate local transaction demonstration using actual catalog definitions and entirely synthetic accounts/assets/Depthmarks. It does not create an online player population, grant real items, import a profile, or claim production database safety.

## Ownership and integration

- `scripts/exchange/`: pure model, eligibility policy, strict separate store and source-bound controller. No ownership mutation through existing inventory grant helpers.
- `scripts/ui/`: exchange panel and one-field native editor, sharing the established modal/input owner.
- Existing Game/HUD/Overlay and Ring terminal: narrow source and modal integration, preserving the source-free city map.
- New tests: model conservation, persistence/restart, actual source/native UI and independent real-progression isolation.
- Documentation: data contracts, local limitations, Android manual review and exact validation evidence.

Use the current physical Ring terminal for a guide/TEST Exchange entry; keep the top-right source-free map and waypoints functional. No extra HUD launcher, city geometry or navigation change is needed. Physical access comes only from the exact live authored terminal/world/player, never from a synthetic actor ID. Native text input reuses the existing single-owner bridge and keyboard release gate. Search/numeric text edits drafts; only reviewed commands can mutate demo state.

## Data and eligibility

One strict version-one aggregate stores a magic marker, namespace, epoch, revision, fixture identifier, nondecreasing demo clock, ID counters, two fixed synthetic actors, asset custody, orders, trades, delivery/return claims, per-actor command high-water marks and bounded receipts/history.

Equipment gets a globally unique demo asset ID. Preserve its item ID, enhancement, durability and exact canonical modifiers across every ownership/custody transfer. Never call Inventory.add_items/consume_items to transfer gear: those APIs mint IDs or select by definition and can reroll instance attributes. Use existing catalog labels, icons, stack limits and protection semantics read-only. No demo ID is a real item_N UID or an online asset entitlement.

Eligibility is explicit and defaults to rejection. Require a current obtainable/supported definition and an approved gameplay category/ID. Reject currency-as-item, future content, cosmetic entitlements, pets, quest/account-bound rewards, unidentified gear and locked/favorite/equipped/displayed assets. Do not infer player tradability merely from NPC sellability. Catalog data remains unchanged.

Equipment quantity is one; fungible lots respect existing stack limits. An exact variant key contains definition ID, identification, enhancement, durability and sorted fixed-point modifier units. A buy order for base gear must never silently match damaged, upgraded or differently rolled gear.

Initial caps: two actors, forty inventory slots each, sixteen open orders per actor, one active pair trade, sixty-four pending claim lots per actor and 128 visible history rows. Asset/reference counts and command history are bounded too. Admission reserves delivery/return capacity; cancellation remains possible when ordinary inventory is full. Per actor, inventory slots plus claim slots/reservations cannot exceed 103, preserving space to rotate a full lot between inventory and Claims. Revision headroom includes all active orders, the active trade, every claim slot and a reset reserve; closure cannot be displaced by ordinary new commands.

## Commands and persistence

All UI commands use opaque one-use quotes containing trusted actor/action/arguments, source generation, namespace/epoch and exact expected revision. Consume a quote before callbacks; stale revisions or context changes cannot modify state. Never authorize from a caller-edited review dictionary.

Persist a per-actor contiguous accepted command sequence/high-water mark. Bounded receipt eviction must not reopen an old command. A recent exact duplicate returns its original receipt; a changed payload conflicts; a pruned old sequence returns already_processed without executing again. Reset saves epoch+1 before publication, invalidates prior IDs/tokens and requires explicit TEST reset confirmation.

The store serializes one in-process writer synchronously, compares disk fingerprint/identity/revision immediately before replacement, validates a complete candidate, flushes a temporary file, atomically replaces and verifies the committed identity. If replacement outcome is uncertain, reread that identity and recover its durable receipt; never roll back to an old executable command history. Corrupt or newer primary data fails closed. Initialization must not overwrite a failed load with empty defaults. Runtime uses a fixed dedicated demo path; test overrides are isolated disposable roots and cannot point to normal progression files.

This is local single-process persistence, not a cross-process database transaction or authoritative online account service. The backend contract requires actual database locking/transactions and authenticated identities.

## Orders and claims

Reserve sell units or buy quantity × limit price before submission. Match compatible variants across different actors by price then creation sequence, at the resting order's price. Support partial fills, exact remaining quantities and explicit refunds of unused/price-improved reserves. No self-matching or separate unchecked 'buy now' debit path.

Successful fills deliver to bounded, visibly labeled TEST Claims where needed. Claim only the amount that fits forty-slot inventory, preserving equipment IDs; retain the remainder in escrow. Cancel/expiry returns unused reserves through pre-reserved return capacity, independent of current ordinary inventory space. Never display a refund or completed fill until the aggregate save succeeds.

Use an explicit controlled demo-clock advance action for expiry tests, persisted nondecreasing. Do not imply an online scheduler or trusted device time. Orders remain in the file when the demo closes and can be matched by the other explicitly selected synthetic participant on reopening. A bounded persistent sale tape derives only from committed order executions, retaining exact variant, quantity, unit price, clock and transaction/fill identity. Activity and Sales views remain separate; variant summaries never blend differently enhanced or damaged gear. Direct trades do not infer item prices. No autonomous fictional trading activity or seeded fake sale history.

## Direct trading

Request → accept/decline → edit accepted offers → lock both offers → inspect combined immutable terms → separately final-confirm both sides. Reserve accepted offer contents atomically; any successful edit clears both locks and all final approvals. Rejected edits leave durable terms intact. The UI must distinguish unsaved drafts from accepted terms.

First final approval is visibly pending, not a durable settlement. Both synthetic sides must be operable by one tester: use explicit per-side TEST buttons or preserve the first approval across a mere viewed-actor switch while canceling unrelated quotes. The second approval invokes an internal settlement action only after both locks/digest/revision/source checks. Public UI quote actions cannot invoke that internal action directly.

Final settlement validates both incoming inventories and transfers all assets/DM in one saved candidate. An inventory-space failure leaves original escrow intact. Close/focus/travel invalidate quotes and ephemeral final approvals. Durable offers remain clearly RESERVED/PAUSED until fresh review or a successfully saved cancellation; no success/refund claim on a failed write. Reopening cannot reuse old final consent.

## Verification

Pure model: exact DM/item conservation across inventory, all escrow and claims; one custody per equipment ID; fixed payload preservation; price/time ordering; partial fills; variant incompatibility; self-trade rejection; cancellation/expiry once; capacity reservations; final-confirm invalidation; bounded histories without replay revival; epoch reset and stale/changed commands.

Persistence/controller: separate-process writers/readers, stale disk state, partial/interrupted writes, post-replace uncertain outcomes, corruption/future protection, strict path isolation, callback reentry, source range/LOS/world expiry and quote replay. Do not describe sequential stale-store tests as cross-process concurrency proof.

UI/integration: actual input and source interaction, all four tabs, search/category/rarity/sorting, numeric bounds, both synthetic sides, partial claims, full inventory feedback, decline/cancel/focus/travel, native keyboard geometries and held-key/touch quarantine. Hash actual profile and backups/preferences plus in-memory profile/revision/item counter/gear/displays/pets/companions before and after all demo actions. Catalog resources and gameplay RNG must remain unchanged.

Run every preserved suite from the exact accepted source after all focused gates. Android keyboard, touch comfort, rendering and sustained device performance remain manual.

## 6G reassessment

Current repository inspection finds no authenticated account service, multiplayer transport, database or backend deployment configuration. Android currently requests no internet permission. Existing editable offline profiles cannot be silently promoted into trusted online assets.

Before claiming an online build, resolve authoritative account and asset identity, persistent transactional wallet/inventory/escrow storage, trusted reward provenance/migration policy, party membership and spatial presence, chat moderation/retention, service configuration and deployment authorization. The reviewed contract must specify idempotency, row locking, worker recovery, disconnect outcomes and two-client tests. Local demo evidence does not satisfy those acceptance checks. No internet-accessible deployment, hosting costs or billing without the user's stated approval.

The proposed [server contract](living-sanctuary-server-contract.md) is a separate authority specification. It is not evidence of a live service.

The owner confirmed no existing backend and requested a [concrete implementation proposal](living-sanctuary-backend-proposal.md). That proposal recommends a local authenticated test realm before any separately approved hosting, preserves existing offline progression and does not authorize a public deployment or billing.
