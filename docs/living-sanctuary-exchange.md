# Ring Exchange — local TEST guide

6F implements this local workflow. See the [validation report](living-sanctuary-6f-validation.md) for the accepted source, complete headless results and device-testing limits.

The exchange uses two explicitly controlled synthetic accounts, **DEMO A** and **DEMO B**, separate TEST assets and **DEMO DM**. It has no live players, network transport, real-account balances or payments. Actual character items, Depthmarks, pets and progression stay in the existing profile. No test result can be moved into that profile or an online account.

## Entry and controls

Approach the physical Ring Exchange guide terminal in the central plaza. Its guide opens the local test market or the existing city map. Choosing CITY MAP leaves exchange authority; the top-right map remains a navigation tool and cannot remotely open trading.

The market provides Browse, My Orders/Claims, Direct Trade and History views. Select the explicitly labeled synthetic participant whose actions you want to test. Search, category/rarity filters and sorting operate on the approved existing catalog and actual demo orders. Initial order books and sale history are empty; the other participant never responds automatically.

Text and numeric fields use a single native editor at a time. Applying text changes only the draft. Review the quantity, unit price, totals and escrow outcome before confirming an order or offer. The first trade approval is pending consent, not a completed transaction.

## Exercise a partial fill

Both initial test accounts have Root Fiber and other fixed sample goods. As DEMO A, create a sell order for five Root Fiber at eight DEMO DM each. As DEMO B, fill two units of that order. The accepted fill should transfer sixteen DEMO DM from B to A and leave three units for sale. B collects the two delivered units from TEST Claims. A can cancel the remaining order and collect its returned three units.

Every step requires a successfully saved command. Repeating a stale confirmation must not repeat its payment or delivery. Equipment transfers preserve the exact demo asset ID, enhancement, condition and modifiers; a buy order for one exact variant cannot receive another variant silently.

All market deliveries go through bounded TEST Claims. If only part of a claim fits, the remainder stays held. DM proceeds and unused reserves return directly to the test wallet. Return space is reserved before accepting escrow. Inventory and claim limits also retain one transfer space, so a full inventory does not destroy canceled property. Automated capacity tests distinguish prepared conserved boundary states from combinations reachable using the small initial sample inventory.

## Exercise a direct trade

Request a trade with the other synthetic participant, then deliberately operate that participant's Accept or Decline control. For an accepted request, edit each side's offer and lock both. Every successful edit clears both locks and approvals. Review the combined immutable terms before using the separate **FINAL CONFIRM · DEMO A** and **FINAL CONFIRM · DEMO B** controls.

The first approval remains visibly pending. The second valid approval can settle the complete transfer in one saved aggregate, provided both incoming inventories fit. A failed save or capacity check leaves the prior escrow intact. There is no public action that can authorize settlement for both sides at once.

Leaving the review, closing, losing focus or traveling clears temporary final consent. Saved offers remain **PAUSED / RESERVED** until reviewed again or canceled successfully. Closing a window does not promise a refund. Reopen the physical terminal to inspect or resolve the retained trade.

## Persistence, time and reset

The runtime test file is `user://vaultbound/demo_exchange/demo_exchange.json`, separate from `profile.json` and all graphics/social preferences. It stores the complete bounded demo ledger, including orders, claims, receipts and accepted command sequence markers. Orders can remain in this file while the demo is closed and be matched by the other explicitly selected synthetic participant later.

Expiry uses an explicit nondecreasing **demo clock** advanced by the tester. It is not an online scheduler or a trusted device clock. History offers **ACTIVITY** and **SALES** views. The bounded sale tape records actual committed order executions, including exact variant, quantity, unit price and demo time. Selected-variant summaries show retained minimum, maximum, latest price and volume; different enhancements, condition or modifiers are not combined. Direct trades do not invent a per-item sale price. Initial history is empty, and reset clears it. There are no listing fees in the initial test policy.

Reset is an explicit destructive **TEST restart**: after confirmation and successful saving, it replaces only this test ledger with its fixed initial samples and a new epoch. It is not a method for restoring lost property, repairing corrupt records or resetting the actual character. Old command IDs and confirmations cannot become valid in the new epoch.

Interrupted or uncertain writes are checked against the actual committed candidate. Corrupt, foreign or newer primary data fails closed; an older backup is not automatically promoted because that could reopen processed commands. Existing files are preserved. Local byte checks and file replacement support one serialized process; they are not a transactional server database or protection against someone editing every local file.

## Scope and manual acceptance

The reviewed TEST policy allows 280 currently obtainable gameplay IDs, including valuables. Trophies, unavailable content, purchased cosmetics, pets, unidentified gear and protected assets are excluded. The fixed sample inventories exercise only a subset of the eligible catalog; an unfilled buy order does not fabricate a seller or new item supply. Actual NPC merchants and real inventory rules remain separate.

On Android, test keyboard composition, numeric errors, scrolling, every global UI scale, safe areas, held fingers during closure, Back/background/resume, both cameras and reentry after travel. Repeat the partial-fill and two-sided trade examples, then restart and check both the demo receipt and unchanged actual character progression. No physical-device testing is claimed here.

The [implementation contract](living-sanctuary-demo-contract.md), [integration plan](living-sanctuary-6f-plan.md), [server API contract](living-sanctuary-server-contract.md) and [backend proposal](living-sanctuary-backend-proposal.md) explain the boundaries and separate live-backend requirements. The local exchange is always **DEMO / NOT LIVE**.
