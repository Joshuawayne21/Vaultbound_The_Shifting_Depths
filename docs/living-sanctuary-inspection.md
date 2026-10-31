# Living Sanctuary — 6A inspection

Inspection date: **2026-10-31**. This document records the existing data, persistence and service boundaries before Living Sanctuary implementation. The inspection used source/configuration reads, a static catalog count and byte comparisons; it did not run Godot, modify a profile or change runtime code. Proposed additions below are not implemented features.

## Baseline and evidence

| Boundary | Inspected baseline |
| --- | --- |
| Local release HEAD | `d77e4d658a8e64bf3a742f58d7c8e40cfdeceb52` (`d77e4d6`) |
| Published release baseline | `0dc61f8`, identified by the coordinated remote inspection; this checkout has no `origin/main` tracking ref |
| Previous tested game-source commit | `4ae9c46cc2984b4a45b1a7606cdfe857bb2c809e` |
| Root project | `/workspace/vaultbound/project.godot`; keep `project.godot` at the repository root |
| Engine and renderer | Godot **4.6.3 stable**, GDScript, **GL Compatibility**, Android landscape |
| Game version | **0.5.6** |
| Current local profile schema | **v4** |

The **previous complete 5.6 gate** passed **10,519 assertions across 58 suites and 71 separate engine invocations**, with zero failed invocations. This is previous verified evidence, not a new 6A test run. Its durable [test results](milestone-5.6-test-results.json) and [validation report](milestone-5.6-validation.md) record source signature `05dc770e1535140c23172bdd4824780f1d3671743eea233a2045edb3b04435af` over 673 semantic files: `project.godot`, scripts, resources, scenes, assets and tests, excluding generated `.uid` and `.import` files.

This inspection compared every one of those **673 current files byte-for-byte against the previous tested commit** and found no differences. The release HEAD adds documentation/evidence to that same game code. The previous gate therefore describes the unchanged starting game source; it cannot validate future Living Sanctuary changes. It covers headless logic, resource, physics and input contracts, not rendered GPU performance, a physical Android review or an APK export.

## Catalog, currency and ownership to preserve

Static parsing of [the catalog registry](../resources/catalogs/items.tres) found **351 unique IDs**, all with existing definition resources: **350 noncurrency definitions plus `gold_coin`**. Of the noncurrency definitions, **300 are obtainable and 50 remain unavailable**. [Catalog contracts](../tests/catalog_contracts.gd) independently record the category totals: 50 weapons, 85 armor, 35 accessories, 80 valuables, 45 materials, 25 consumables, 30 trophies and one currency definition.

Preservation fingerprints:

- Registry file SHA-256: `f87937f671456af13b7be7658fb43f0e5d8d2913e1737eb44097efb781230c2f`.
- Sorted complete ID-list SHA-256: `2bc8f0fef317c6242cf3b49df8371f0a0e57a668ffd9a1c117b4b2704c6083d5`. Encoding: all 351 IDs sorted, joined by newline, followed by a final newline, UTF-8.
- Missing definition files: **0**. Duplicate registry IDs: **0**.

[Depthmarks](../resources/items/gold_coin.tres) already use the visible label **Depthmarks (DM)** while retaining persisted definition ID **`gold_coin`** and balance key **`gold`**. Keep those internal identifiers, all existing counts and the unsecured/secured distinction. A presentation rename must never create a replacement currency or reset an earned balance.

[VaultInventory](../scripts/progression/inventory_model.gd) stores 40 active slots plus a legacy reserve. Each owned instance has a local `item_N` UID, item definition ID, quantity, enhancement, durability, modifiers and identified/locked/favorite flags. `next_item_id` controls future instance allocation. The `items` aggregate and `equipped_item` selection are compatibility mirrors; normalization requires them to match actual instances and active equipment.

Preserve every existing UID, UID sequence, item ID, quantity, reserve quantity, roll, enhancement, durability and protection flag. Preserve equipment/loadout selection, collection display references, character and companion progression, discoveries, statistics, merchant purchases and transaction receipts. Enhancements remain guaranteed under the existing policy: Common through Legendary cap at +5, Mythic and Ancient Relic at +10. New presentation must not reroll or rebuild owned gear.

The inventory schema validates exactly eleven equipment assignments and twelve Collection Hall display assignments. The profile also validates the two existing companion roster identities. Pets must not be inserted into the equipment, display or companion dictionaries as an unversioned extension. A separate pet registry and ownership section can preserve the original 350-item catalog and existing forty-slot inventory contract.

## Local persistence and the v4 allowlist trap

[VaultProfileStore](../scripts/progression/profile_store.gd) owns `user://vaultbound/profile.json`. It validates copied candidates, writes and verifies a temporary file, preserves the previous valid `.bak`, then renames the verified primary. The session publishes changed progression only after a successful save. Failed extraction leaves its unsecured rewards available for retry.

Versions 1–3 migrate in memory without writing on load. Before a migrated write, exact source bytes are preserved in `.pre-v4.bak`; existing historical backups remain intact, and separately restored legacy sources receive content-addressed alternatives. Newer-schema profiles and structurally valid saves containing unavailable owned definitions become read-only instead of being replaced with an older backup. Unknown version-one aggregate items remain in the legacy reserve. Do not delete or reset saves to resolve an import or schema problem.

**Critical schema constraint:** the normalizer constructs a new, allowlisted profile. Unknown fields are discarded. Adding pet ownership, cosmetics or discovery dates to a v4 dictionary can appear to work in memory and then disappear on save/restart. [Inventory normalization](../scripts/progression/inventory_model.gd) also explicitly accepts source versions 2, 3 and 4 only. Changing `VERSION` alone would not implement a valid migration.

The planned **6E persistence work** should introduce an explicit v5 schema and validators before granting persistent pets or cosmetics:

1. Add bounded, separate pet ownership/selection and cosmetic ownership/selection sections, with empty defaults supplied only during explicit v1–v4 migration. Keep cosmetic selections outside combat/stat calculations. Device graphics/accessibility preferences remain in their separate [VisualSettings](../scripts/visual/visual_settings.gd) file.
2. Add discovery metadata without replacing existing discovery arrays or claiming dates that were never recorded. Keep pet identifiers and any pet instance UID sequence separate from item IDs and `next_item_id`.
3. Update all source-version gates and normalization paths. Require complete valid v5 records; missing ownership sections in a claimed v5 record must trigger recovery rather than silent defaults.
4. Migrate old data in memory without changing original fields. On the first v5 write, retain exact `.pre-v5.bak` bytes and preserve `.pre-v3`, `.pre-v4` and content-addressed snapshots.
5. Verify roundtrip and separate-process restart behavior, duplicate/missing pet identity rejection, invalid active selections, corrupt/newer/unavailable-content recovery, failed-write rollback and equality of every preserved original field. Retain the existing catalog, economy, enhancement and profile regression gates.

[Profile v4 tests](../tests/profile_v4_test.gd), [profile roundtrip tests](../tests/profile_roundtrip_test.gd), [save migration tests](../tests/save_migration_test.gd) and [loadout migration tests](../tests/loadout_migration_test.gd) provide existing preservation cases. They were inspected, not rerun for this document.

## Collection journals and discovery dates

Current persistence contains item-ID and monster-ID discovery arrays. [Extraction](../scripts/progression/expedition_session.gd) secures discoveries together with rewards, experience and statistics. [Economy rules](../scripts/progression/economy_rules.gd) add item discoveries for successful outputs and identification. The [journal UI](../scripts/ui/rpg_panel.gd) derives rows from those arrays and the catalog; completion counts obtainable noncurrency definitions only.

There are **no persisted first-discovery or acquisition dates**, and no trusted time service. Historical entries must display **“Date unknown — discovered before this update”** or equivalent honest wording. Do not assign the migration date as their discovery date. New offline discoveries may record device time in the same successful save transaction, labeled as local metadata; future authoritative online timestamps must come from the server. Death, retreat, rejected rewards and failed saves must not create secured discovery dates.

## Infrastructure actually present

The project contains an offline Godot client with local combat, party, inventory and transaction boundaries. [Project autoloads](../project.godot) are InputHub, VisualSettings and ExpeditionSession. Source/configuration inspection found no implemented authentication/accounts service, backend database or migrations, remote inventory service, HTTP/WebSocket/ENet gameplay transport, RPC replication, player marketplace, live chat service, payment SDK or payment receipt verification.

[The README](../README.md) explicitly describes no online multiplayer or player-to-player trading and no authentication, networking, replication, anti-cheat or cloud saves. [The Android export preset](../export_presets.cfg) sets `permissions/internet=false`; the game currently requests no internet permission. The managed development environment's network access is distinct from an exported game's permission or an authorized production service.

The runtime configuration inspected for this task reported **no configured secrets, runtime variables or outbound identities**. No authorized backend/database/payment credentials were available through that configuration. This is an observation about this task's supplied infrastructure, not a claim that no external service exists elsewhere. No secret values were inspected, and no hosting, database or payment resources were provisioned.

## Economy boundary and permitted local TEST demonstrations

[VaultEconomy](../scripts/progression/economy_rules.gd) evaluates copied profiles using an expected revision and request ID; duplicate receipts and stale revisions are rejected. [ExpeditionSession](../scripts/progression/expedition_session.gd) caches trusted local quotes, ignores caller-edited quote prices/quantities at confirmation, checks service access again and saves before publishing results. These are useful local contracts to preserve.

They do not establish remote trust. Profiles are editable on the device, receipts retain only the most recent 64 IDs, `item_N` UIDs are unique only within a profile, and the local file store is not a transaction across two accounts. Its stale-file protections do not provide a database compare-and-swap for simultaneous same-version writers.

The user permits a clearly labeled **local TEST exchange/chat demonstration** when no backend exists. It must use a distinct model and separate storage, such as `user://vaultbound/demo_exchange.json`, with synthetic identities, listings, items and balances. Keep TEST state out of `ExpeditionSession.profile`, earned `gold`, original item UIDs, original `next_item_id` and secured transaction receipts. A demo reset must affect only demo state. A read-only collection preview does not authorize moving real owned items into demo transactions.

Show a persistent **LOCAL TEST DEMO** label. Scripted chat replies, sample traders and simulated activity must be presented as local examples, with no invented online-player counts or live-service claims. There must be no exchange, withdrawal, conversion or promotion from TEST balances/items to earned progression or future trusted online ownership. Do not use `configure_storage()` to swap the live session into a demo: that method replaces the secured session profile.

## Prerequisites for real 6G services

Real exchange, shared chat or other online claims require an **authorized backend**, account identity, server-owned persistence and a defined deployment destination. Offline saves and TEST balances cannot be promoted into trusted balances merely by uploading or signing them on the client. Any later offline-progress import needs a separately authorized, auditable migration policy; preserve the existing offline profile independently.

A server contract must establish:

- Authenticated account identity, server-controlled balances, item ownership, eligibility and globally unique asset identity. Preserve original instance data and provenance rather than rerolling or silently rewriting offline UID references.
- Requests carrying intent, quantity, idempotency key and expected versions. The server computes price, fees and eligibility and issues a versioned quote/listing with expiry; client-supplied owner IDs, balances, prices or rolls are not authority.
- Escrow or equivalent transactional locks on exact offered assets. Purchase atomically debits the buyer, credits the seller, transfers the unchanged item record, closes the listing and writes durable receipts. Cancellation and expiry release locks exactly once.
- Revalidation of funds, inventory capacity, item protection/equipment/display status, ownership and listing version. Simultaneous purchases, replay, stale confirmations, disconnects and partial failures must have tested database-backed behavior; retries return the original committed result.
- Authenticated chat transport, bounded messages/history, rate limits and moderation/reporting controls before offering real shared chat.

No such service is currently implemented or configured. Documentation, local models and TEST demonstrations can proceed without a hosting approval request. Seek any required service/deployment approval only when there is a concrete destination, service choice, operating cost and reviewable implementation; this inspection does not require hosting approval.

## Prerequisites for 6I payments

Payment work remains gated. There is no installed payment/billing SDK, configured payment provider, authorized merchant/store account, backend entitlement service or receipt-verification secret in the inspected baseline. A local cosmetic preview or TEST currency balance must not claim a completed purchase or paid entitlement.

Before enabling purchases, establish the explicitly authorized platform/provider and product scope, store/product configuration, server-side receipt verification, replay-safe entitlement issuance, restore/refund/revocation behavior and test-mode validation. Paid entitlements must be separate from client-editable cosmetic selections. Real charging, credentials, deployment and publication require their applicable explicit authorization; no payment connection or charge is needed for 6A.
