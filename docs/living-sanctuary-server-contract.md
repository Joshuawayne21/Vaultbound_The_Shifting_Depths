# Ring Exchange server contract — proposed integration, no live service

This document specifies the authority needed after the isolated 6F demonstration. It is not a deployed API, a database implementation, an account service or proof of online trading. The current game remains an offline Godot client. Endpoints, hosting, account provisioning and the production database have not been configured.

The [backend proposal](living-sanctuary-backend-proposal.md) recommends a concrete stack and staged local tests. The routes below are logical API operations; that proposal maps them to authenticated versioned Nakama RPCs before considering a separate HTTP gateway.

## Trust boundary

The server derives account identity from an authenticated session. It ignores client-supplied account IDs, sender names, balances, ownership, eligibility, prices calculated from game rewards, party membership and claimed position. Public player IDs identify interaction targets; they are not authorization tokens. All reads of private offers, inventory, claims and receipts require ownership or explicit participation.

Existing editable offline profiles and demo assets cannot be uploaded as trusted online possessions. Preserve those files and their offline play. Before online progression is enabled, choose an explicit migration policy and a trusted reward source; do not silently wipe old progression or convert client JSON into authoritative currency. Every earned grant requires a unique server-validated encounter/objective receipt.

Use encrypted transport for authenticated deployment, short-lived access sessions, revocation and secure credential storage appropriate to the chosen account service/platform. Never place production credentials or payment details in the Godot project. This market transfers earned gameplay items and Depthmarks only, not real money or purchased cosmetics.

## Core records

- Account: stable private account ID, public player identity, enabled/restricted status and authoritative party/world membership references.
- Wallet: nonnegative integer available/reserved Depthmarks and revision. The internal legacy offline gold field is not this wallet.
- Item definition policy: catalog version, tradability/binding class, supported mechanics, quantity limits and approved exact variant representation.
- Asset/lot: globally unique ID, definition ID, exact equipment enhancement/condition/modifiers or fungible quantity, owner and exactly one custody location. Equipment transfer never recreates its rolled instance.
- Order: unique ID, owner, side, exact variant, limit price, initial/remaining quantity, price-time sequence, server UTC expiry, escrow references and status.
- Trade: unique ID, two participants, request/status, offer revision, exact accepted terms, locks and per-participant final approval bound to the same digest.
- Claim: owner, source transaction, assets/DM held for delivery or return, remaining quantity and status. Capacity admission reserves safe return space.
- Financial transaction: unique ID and balanced item/DM ledger entries, source command, participants and committed timestamp.
- Idempotency record: unique actor/operation/key, canonical request digest, durable outcome/transaction reference. Archived response detail must not make the key executable again.
- Outbox event: committed transaction reference and recipient; notifications are delivered after commit and can be retried independently.

Enforce nonnegative quantities, legal integer ranges, unique asset custody, valid foreign keys and unique transaction/source IDs in the database as well as application validation. Bound requests and matching work. Display currency as integers; never use floating-point money.

## API shape

The exact host and authentication provider are configuration, not hardcoded public endpoints. Proposed version-one routes:

| Route | Purpose / server-derived checks |
| --- | --- |
| GET /market/catalog | Current eligible definitions, restrictions, fee policy and catalog version |
| GET /market/orders | Bounded search/category/rarity/exact-variant/side filters, deterministic sorting and cursor pagination |
| GET /market/history | Committed recent sales and aggregate price history; no fabricated activity |
| GET /me/exchange | Authenticated available/reserved balances, own orders, trades and claims |
| POST /market/orders | Reserve actual owned sell units or maximum buy cost; match compatible other-account orders |
| POST /market/orders/{id}/cancel | Owner-only cancellation of the remaining reserve |
| POST /me/claims/{id}/collect | Atomically collect only quantities that fit, leaving any remainder held safely |
| POST /trades | Request another public player; validate restrictions, rate limits and allowed proximity/world policy |
| POST /trades/{id}/accept or /decline | Invitee-only response to the current request |
| PUT /trades/{id}/offer | Participant edits against exact offer revision; atomically replace escrow and invalidate both locks/approvals |
| POST /trades/{id}/lock | Participant locks the server's exact current offer digest |
| POST /trades/{id}/confirm | Participant confirms both locked terms; second valid approval settles atomically |
| POST /trades/{id}/cancel | Participant cancellation/return according to current committed status |
| GET /me/transactions/{id} | Authorized receipt and recovery lookup after a lost response |

Mutations require an idempotency key and relevant expected revision/digest. They accept user intent, never precomputed balances or success flags. Repeated identical committed commands return the same outcome. A reused key with changed content conflicts. Stale terms return a refreshed review requirement, not silent consent to changed prices. Distinguish invalid input, forbidden ownership, stale revision, capacity, rate limit, unavailable service and already-completed outcomes.

## Transaction rules

Order submission locks the affected wallet/assets/order-book rows in a deterministic order, validates current catalog and ownership, reserves everything, and matches by best price then creation sequence at the resting order price. Partial fills update both orders, all custody/payment records, price-improvement refunds and receipts together. An order cannot match its own account. Filled equipment retains its exact ID and variant.

Cancel/expiry races with fills under the same transactional lock. Only the still-unused reserve is returned, once. Server UTC and server workers decide expiry; device clock edits have no authority. Offline order owners require no connected client for matching. Worker restarts and repeated expiry jobs use unique idempotent work records.

Direct trade requests require explicit acceptance. Offer edits atomically release/reacquire the accepted reserve and reset both locks/approvals. Final confirmation must include the current server digest/revision, remain authorized for that participant, and respect consent expiry. The second valid confirmation checks both incoming inventory capacities, transfers all assets/Depthmarks and writes the receipt in one database transaction. A failure leaves the prior reserved state intact. The public API cannot invoke an internal settlement shortcut on behalf of both participants.

Disconnect invalidates pending consent according to the configured pause/cancel policy. Already committed settlements stay committed even if the response is lost. Reconnection queries the transaction/trade ID; it never retries by creating a new transfer. Unsettled escrow must remain visible and recoverable, with a server-controlled expiry/return path. Never claim a refund merely because a client window closed.

Financial ledger writes, account revisions and an outbox notification record commit together. Notifications may repeat; recipients deduplicate event IDs. A failed notification cannot roll back a committed transfer. Do not broadcast private balances, offers or receipts to unrelated players.

## Abuse and operational boundaries

Configure account/action rate limits, open-order caps, quantity/price bounds and matching work limits server-side. Disable self-trades, reject ineligible bound/cosmetic/quest items and flag suspicious repeated counterparty activity for review. These checks reduce specific abuse; they are not a claim of complete bot prevention or market manipulation resistance. Fees default to zero until a configured policy is shown before confirmation.

Define access-controlled retention for financial receipts, moderation reports and operational logs before release. Avoid storing message bodies or authentication tokens in general transaction logs. The existing social contract retains offline previews only in session memory; never upload those drafts/history during online enablement. Live LOCAL routing requires authoritative world and radius, WORLD requires server/world membership, and PARTY requires the current server roster. Sender identity, text limits, filtering, mute/block/report decisions and channel authorization are checked at the server.

## Required two-client and restart gate

Use real authenticated test sessions and the actual chosen database, not the local demo adapter. Verify account/read isolation, spoofed identities and stale membership; same-key retries and altered payloads; simultaneous competing orders/cancellations; exact equipment transfers; partial fills and price improvement; full inventory/return capacity; request rejection; edits after locking; one-sided approval; disconnect before/after commit; offline order fill; worker restart; interrupted database transaction; duplicate outbox delivery; save/receipt recovery; LOCAL distance and PARTY isolation; moderation/rate limits; and nontradable cosmetics.

Assert DM/item conservation and unique custody directly from committed database state after adversarial runs. Verify a server process restart retains orders, escrow, grants and idempotency. Test at least two Godot clients with the intended network transport before claiming in-game multiplayer. Public deployment, hosting costs and real billing remain separate approval and release gates. Local server tests, if later implemented, must be reported as local tests rather than a live internet service.
