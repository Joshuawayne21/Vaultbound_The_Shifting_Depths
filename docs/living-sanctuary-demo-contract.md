# TEST exchange — implementation contract

This is the offline 6F adapter. It never authorizes real players or writes the progression profile. The [live server contract](living-sanctuary-server-contract.md) and [backend proposal](living-sanctuary-backend-proposal.md) describe separate future authority. Local validation is not protection against an owner editing every file or running simultaneous writers.

## Component boundaries

| Component | Responsibility |
| --- | --- |
| `exchange_eligibility.gd` | Explicit 280-ID TEST allowlist; read-only catalog metadata; supported/obtainable/category checks; exact equipment variant and protection policy |
| `demo_exchange_codec.gd` | Closed schema helpers, integer conversion, sorted canonical JSON and digests |
| `demo_exchange_state.gd` | Fixed synthetic fixture, schema normalization, custody, supply, receipt and sale-history invariants |
| `demo_exchange_ledger.gd` | Candidate escrow, matching, settlement, claims and execution recording |
| `demo_exchange_model.gd` | Pure planning, replay handling, parent-state checks and detached presentation snapshots |
| `demo_exchange_store.gd` | Dedicated file, synchronous single-writer guard, byte/revision checks, verified replacement and uncertain-write recovery |
| `demo_exchange_controller.gd` | Actual nearby Ring terminal authorization, one-use reviewed intents, temporary final consent and save-before-publication |
| `demo_exchange_panel.gd` / `exchange_text_panel.gd` | TEST labels, two synthetic participants, four views, item inspection and single-field native editing through the existing modal owner |

Production exchange code reads existing catalog definitions but does not call gameplay inventory transfer/grant helpers, import a real profile, mutate item resources or consume gameplay RNG. Runtime source authorization references the actual Game/world/player and authored terminal; it does not derive financial identity from those nodes. DEMO A and B remain explicitly synthetic.

## Version-one aggregate

The dedicated file is `user://vaultbound/demo_exchange/demo_exchange.json`. Its closed keys are:

```text
magic, version, namespace, epoch, revision, fixture_id, clock,
next_asset, next_order, next_trade, next_claim,
actors, assets, orders, trades, claims,
command_heads, recent_receipts, history, last_reset, sales
```

`magic` is `vaultbound_demo_exchange`, `version` is `1` and `fixture_id` is `ring_exchange_v1`. The separate real progression profile remains v5. A per-store 32-character hexadecimal namespace comes from independent entropy. Object IDs are `demo:<namespace>:<epoch>:<kind>:<sequence>`, where kind is asset/order/trade/claim. Counters never reuse an identity within an epoch. Reset commits a new epoch and the fixed fixture; it cannot reactivate an old command or confirmation.

There are exactly two actors, each initially holding 10,000 TEST DM and twelve sample lots. Total supply is 20,000 TEST DM, 184 item units and ten immutable equipment identities. The sample includes base, enhanced, damaged and differently modified equipment. No initial order, sale, trade or automatic counterparty activity is fabricated.

Each asset has one owner, quantity, protection flags and exactly one custody location: inventory, order, trade or claim. Inventory membership derives from custody rather than a second editable list. Equipment identity and variant are preserved. The exact variant is:

```text
{item_id, identified, enhancement, durability, modifier_units}
```

Modifier values use fixed integer units with scale 1,000,000 and existing bounded modifier semantics. At most two known modifiers are allowed. Non-equipment has no enhancement or modifiers. A sorted canonical hash identifies a variant; differently enhanced, damaged or rolled gear cannot silently match. Presentation conversion does not convert a TEST asset into a gameplay item.

Normalization rejects unknown/missing keys, wrong types, illegal references, invalid quantities and inconsistent totals instead of dropping records or substituting defaults. JSON's numeric representation is accepted only when finite, exactly integral and within the field's bounds. Canonical command encoding itself permits no floats and sorts string keys. Whole saves are limited to 2 MiB.

## Bounded state

| Limit | Value |
| --- | ---: |
| Inventory slots | 40 per actor |
| Open orders | 16 per actor |
| Active direct request/trade | 1 total |
| Offered asset rows | 8 per actor |
| Claim slots, including reservations | 64 per actor |
| Inventory plus claim slots | 103 per actor |
| Live assets | 208 aggregate ceiling; the fixed 184-unit supply imposes a smaller reachable count |
| Retained exact receipts | 64 |
| Activity rows / actual sale rows | 128 each |
| Unit price | 1–1,000,000 TEST DM |
| Order quantity | One equipment item, or one permitted fungible stack |
| Explicit demo-clock step / expiry offset | 1–86,400 seconds |
| Integer money/counter ceiling | 2,147,483,647 |

Claim admission reserves return/delivery space before escrow is accepted. The combined slot bound leaves a transfer space for whole-lot movement. Revision headroom retains budget for existing orders, trades and claims to close. Numeric exhaustion rejects new work while preserving inspectable records; a destructive TEST reset is not recovery of owned contents. Prepared boundary fixtures in tests are distinguished from sequences executed from the small starting inventory.

## Reviewed commands and recovery

`Controller.quote(actor, action, arguments)` returns an opaque token and detached review. For durable commands, `commit(token)` consumes the token before callbacks, checks the exact source generation/namespace/epoch/revision, creates a candidate, saves it and only then publishes success. Caller edits to the displayed review do not change the intent. Invalid or failed commands cannot publish money, assets or sale rows.

Public actions cover order creation/fill/cancellation, claims, trade request/accept/decline/offer/lock/cancel, explicit time advance, reset and final-confirm presentation. The internal `settle_trade` planner action is not a public quote action. Two separate final approvals are required for the current combined terms. First approval is temporary, not a receipt or settlement. Closing, focus loss, source loss, travel or leaving review clears that consent. Persisted offers remain reserved until fresh approval or a successfully saved cancellation.

Every accepted financial command advances that actor's contiguous sequence and aggregate revision. A retained identical replay returns its receipt; changed content conflicts. Pruned old sequences remain already processed through high-water marks. Retained receipt sequences must be continuous for each actor and end at that actor's head. History pruning cannot reopen commands.

The store validates identity and bytes immediately before a verified temporary-file replacement, retaining a backup. After an uncertain replacement result it rereads the candidate's durable identity. It does not roll back to an executable old history. Corrupt, unsupported newer-format or foreign primary files and missing primaries beside existing sidecars fail closed without writing defaults. A compatible higher epoch/revision can be accepted by explicit reload after stale-state detection. Backups are not automatically promoted. Explicit test roots are restricted to disposable `/tmp/vaultbound-6f-*` paths and reject symlink escapes; the production UI cannot choose a path.

## Sales and presentation

Only actual matched order executions append sale rows. Each row links to its command receipt/fill index, exact variant, quantity, executed unit price, buyer/seller, relevant order IDs, revision and controlled demo clock. Parent-state validation corroborates newly appended executions; a short retained tape cannot silently lose its prefix. A full bounded tape may trim only the old prefix required by newly appended sales.

Snapshots return detached newest-first sales. Price summaries group only retained executions of the exact same variant and expose minimum, maximum, latest price and unit volume. No direct-trade valuation, inferred average, seeded market history or device-clock schedule is used.

The panel refreshes on state, source and user changes rather than rebuilding inventory/history every frame. One deferred refresh clears a command's temporary busy presentation after notification callbacks return. A bounded physical-source probe remains independent of full snapshots. Native text entry monitors keyboard/layout changes without rebuilding unchanged exchange data. These structural choices require physical Android measurement before any responsiveness claim.

Use the [exchange guide](living-sanctuary-exchange.md) for the user flow and the [Android checklist](living-sanctuary-android.md) for keyboard, touch and performance acceptance.
