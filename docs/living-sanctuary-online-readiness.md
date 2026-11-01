# Online authority readiness — 6G boundary

The repository currently contains an offline Godot game. The verified 6F exchange uses an isolated local test adapter. It is not a live market, account service or database backend. This record distinguishes available integration work from the prerequisites for online acceptance.

## Present in the project

- The preserved expedition, combat, inventory and progression systems use local GDScript authority and a versioned JSON profile.
- The social interface has LOCAL/WORLD/PARTY tabs, but `offline_social_adapter.gd` reports `can_send = false` for every channel. LOCAL previews are explicitly not sent.
- The Android export preset retains `permissions/internet=false`.
- The exchange integration plan and [server contract](living-sanctuary-server-contract.md) describe authenticated commands, exact asset identity, escrow, transactional settlement, recovery and required tests.

Inspection found no gameplay multiplayer transport, authenticated account implementation, online inventory/wallet database, backend application, deployment configuration or billing verification. The owner subsequently confirmed there is no existing backend and requested a proposal. The [concrete backend proposal](living-sanctuary-backend-proposal.md) recommends a local Nakama/PostgreSQL prototype, preserves offline progression and defines separate hosting approval and validation gates. No service was installed or deployed for that proposal.

## Decisions and setup required for an online build

1. Identify the authoritative backend/account service to integrate, or review a new backend design and its development/deployment scope. Provide configuration through the appropriate secret-management mechanism, not committed client files.
2. Choose the persistent transactional database and deployment environment. An internet-accessible deployment, external service configuration or hosting cost requires the owner's explicit approval.
3. Decide how existing offline progression relates to online progression. Preserve existing local files. Editable client JSON and TEST assets cannot silently become trusted online balances; a legitimate migration or separate online progression policy must be explicit.
4. Establish trusted reward provenance, authoritative party/world/spatial membership, rate limits, moderation/report access and retention policy. Client-only ownership, positions and sender identity are insufficient.
5. Run the actual chosen backend with at least two authenticated test clients and persistent database storage. Verify competing orders, partial fills, disconnects, offline matching, idempotent retries, restart recovery and private-channel isolation before an online claim.

A locally tested server, if built later, must still be described as a local development service until a deployment is authorized and verified. The local 6F adapter cannot substitute for those tests. Its file replacement and stale-writer checks are not cross-process database transactions.

## Separate later gates

The cosmetic pavilion's catalog/preview stage follows the online-authority decision in the requested order. Real purchases additionally need store/account configuration, a permitted billing integration, secure token verification, revocation/refund/restore handling and official test purchases. No card data, live payment or purchased cosmetic entitlement is implemented by the exchange prototype.

Physical Android keyboard composition, touch comfort, rendering and sustained performance remain device acceptance work. Existing headless results do not establish those outcomes.
