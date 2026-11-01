extends "res://tests/test_harness.gd"
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const State = preload("res://scripts/exchange/demo_exchange_state.gd")
const Ledger = preload("res://scripts/exchange/demo_exchange_ledger.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const SPACE := "00112233445566778899aabbccddeeff"
var state: Dictionary
var fixture: Dictionary
var last_command: Dictionary
var last_result: Dictionary
var commands := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE MODEL"
	_run.call_deferred()

func _run() -> void:
	_orders()
	_matching()
	_trades()
	_replay_and_codec()
	_capacity()
	print("DEMO MODEL METRICS: " + JSON.stringify({"real_planned_commands":commands,"fixture_units":184,
		"initial_lots":24,"immutable_equipment":10,"initial_demo_dm":20000,
		"prepared_capacity_state":true,"reachable_max_lots_by_supply":184,"configured_asset_cap":208}))
	finish()

func _fresh() -> void:
	state = Model.initial_state(SPACE)
	fixture = state.duplicate(true)
	check(not Model.normalize(state).is_empty(), "Initial synthetic fixture is fully valid")
	check(state.orders.is_empty() and state.trades.is_empty() and state.claims.is_empty() \
		and state.history.is_empty(), "No listing, counterpart response, delivery or sale history is invented")

func _command(actor: String, action: String, args: Dictionary) -> Dictionary:
	return {"namespace":state.namespace,"epoch":state.epoch,"expected_revision":state.revision,
		"actor_id":actor,"sequence":int(state.command_heads[actor])+1,"action":action,"args":args.duplicate(true)}

func _apply(actor: String, action: String, args: Dictionary) -> bool:
	var before := state.duplicate(true)
	last_command = _command(actor,action,args)
	last_result = Model.plan(state,last_command)
	if not check(last_result.ok and last_result.status == "planned", action + " plans successfully: " + String(last_result.error)): return false
	check(state == before and Model.parent_relation(before,last_result.candidate), action + " is pure with an exact valid parent transition")
	state = last_result.candidate
	commands += 1
	check(_conserved(), action + " independently conserves all DM, item units and immutable equipment IDs")
	return true

func _reject(actor: String, action: String, args: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	var result := Model.plan(state,_command(actor,action,args))
	check(not result.ok and result.candidate.is_empty() and state == before, label)

func _asset(actor: String, item_id: String) -> String:
	for id: String in state.assets:
		var asset: Dictionary = state.assets[id]
		if asset.owner_actor == actor and asset.custody.kind == "inventory" and asset.variant.item_id == item_id: return id
	return ""

func _filled_claim(actor: String, item_id: String = "") -> String:
	for id: String in state.claims:
		var claim: Dictionary = state.claims[id]
		if claim.actor_id == actor and state.assets.has(claim.asset_id) \
				and (item_id.is_empty() or state.assets[claim.asset_id].variant.item_id == item_id): return id
	return ""

func _orders() -> void:
	_fresh()
	var original := state.duplicate(true)
	var sell_args := {"side":"sell","asset_id":_asset("demo_a","iron_ore"),"quantity":10,"unit_price":7,"expires_in":100}
	check(Model.preview(state,"demo_a","create_order",sell_args) == Model.preview(state,"demo_a","create_order",sell_args) \
		and state == original, "Repeated reviews are deterministic and do not reserve items or DM")
	if not _apply("demo_a","create_order",sell_args): return
	var sale: String = last_result.receipt.result.order_id
	var first_command := last_command.duplicate(true)
	_reject("demo_a","fill_order",{"order_id":sale,"quantity":1},"Self-fill cannot fabricate trade volume or move funds")
	if not _apply("demo_b","create_order",{"side":"buy","variant":Eligibility.base_variant("iron_ore"),"quantity":6,"unit_price":10,"expires_in":100}): return
	check(state.actors.demo_a.wallet_dm == 10042 and state.actors.demo_b.wallet_dm == 9958 \
		and state.orders[sale].remaining_quantity == 4, "Partial match uses resting price7 and immediately returns buy price improvement")
	var receipt: Dictionary = last_result.receipt.duplicate(true)
	var claim := _filled_claim("demo_b","iron_ore")
	if not _apply("demo_b","claim",{"claim_id":claim,"quantity":3}): return
	check(state.assets[state.claims[claim].asset_id].quantity == 3, "Partial claim leaves the remainder in its visible bounded lot")
	if not _apply("demo_a","cancel_order",{"order_id":sale}): return
	check(state.orders.is_empty() and state.assets[state.claims[_filled_claim("demo_a","iron_ore")].asset_id].quantity == 4, "Cancellation returns only unfilled units through the preallocated slot")
	_reject("demo_a","cancel_order",{"order_id":sale},"A new cancel request cannot return closed escrow again")
	var old := Model.plan(state,first_command)
	check(old.ok and old.status == "replayed" and old.candidate.is_empty(), "Recent duplicate returns its original receipt without executing again")
	var altered := first_command.duplicate(true)
	altered.args.unit_price = 8
	check(Model.plan(state,altered).status == "request_conflict", "Same command key with changed price conflicts")
	check(receipt.result.filled_quantity == 6 and receipt.result.dm_refund == 18, "Detached receipt retains exact executed fill and refund")
	if not _apply("demo_b","claim",{"claim_id":claim,"quantity":3}): return
	if not _apply("demo_a","claim",{"claim_id":_filled_claim("demo_a","iron_ore"),"quantity":4}): return
	if not _apply("demo_a","create_order",{"side":"sell","asset_id":_asset("demo_a","root_fiber"),"quantity":5,"unit_price":2,"expires_in":5}): return
	if not _apply("demo_b","create_order",{"side":"buy","variant":Eligibility.base_variant("root_fiber"),"quantity":3,"unit_price":1,"expires_in":5}): return
	check(state.orders.size() == 2, "Noncrossing limits remain explicitly open, with no fictional autonomous trades")
	if not _apply("demo_b","advance_time",{"seconds":5}): return
	check(state.orders.is_empty() and last_result.receipt.result.expired_order_ids.size() == 2, "Only explicit persisted demo-time advance expires both sides once")
	var a_sword := _asset("demo_a","traveler_sword")
	if not _apply("demo_a","create_order",{"side":"buy","variant":state.assets[a_sword].variant,"quantity":1,"unit_price":25,"expires_in":20}): return
	var buy: String = last_result.receipt.result.order_id
	_reject("demo_b","fill_order",{"order_id":buy,"quantity":1,"asset_id":_asset("demo_b","traveler_sword")},"Damaged/enhanced/rolled gear cannot fill a base-variant order")
	var detached := Model.snapshot(state,"demo_a")
	detached.inventory[0].variant.modifier_units["damage_bonus"] = 999999
	check(state.assets[a_sword].variant.enhancement == 0 and _conserved(), "Caller-edited read snapshots never change real model asset terms")

func _trades() -> void:
	_fresh()
	if not _apply("demo_a","request_trade",{"other_actor_id":"demo_b","expires_in":100}): return
	var trade: String = last_result.receipt.result.trade_id
	_reject("demo_a","accept_trade",{"trade_id":trade},"Requester cannot pretend the counterpart accepted")
	if not _apply("demo_b","accept_trade",{"trade_id":trade}): return
	var sword := _asset("demo_a","traveler_sword")
	var helm := _asset("demo_b","iron_helm")
	var sword_payload: Dictionary = state.assets[sword].variant.duplicate(true)
	if not _apply("demo_a","set_offer",{"trade_id":trade,"dm":11,"assets":[{"asset_id":sword,"quantity":1}]}): return
	if not _apply("demo_b","set_offer",{"trade_id":trade,"dm":3,"assets":[{"asset_id":helm,"quantity":1}]}): return
	if not _apply("demo_a","lock_trade",{"trade_id":trade}): return
	if not _apply("demo_b","lock_trade",{"trade_id":trade}): return
	var review := Model.trade_review(state,trade)
	check(review.can_settle and review.locked, "Both saved locked offers produce combined immutable review terms")
	check(not Model.preview(state,"demo_a","settle_trade",{"trade_id":trade,"offer_revision":review.offer_revision,"terms_digest":review.terms_digest}).ok \
		and not Model.preview(state,"demo_a","confirm_trade",{"trade_id":trade}).ok, "Public model preview exposes neither private settlement nor fake persisted first consent")
	_reject("demo_a","set_offer",{"trade_id":trade,"dm":20001,"assets":[]},"Rejected offer edit leaves both accepted locks and escrow intact")
	check(state.trades[trade].locks.demo_a and state.trades[trade].locks.demo_b, "Failed draft cannot invalidate accepted durable terms")
	if not _apply("demo_a","set_offer",{"trade_id":trade,"dm":12,"assets":[{"asset_id":sword,"quantity":1}]}): return
	check(not state.trades[trade].locks.demo_a and not state.trades[trade].locks.demo_b, "Successful edit clears BOTH locks")
	_reject("demo_b","settle_trade",{"trade_id":trade,"offer_revision":review.offer_revision,"terms_digest":review.terms_digest},"Old terms digest cannot settle edited escrow")
	if not _apply("demo_a","lock_trade",{"trade_id":trade}): return
	if not _apply("demo_b","lock_trade",{"trade_id":trade}): return
	review = Model.trade_review(state,trade)
	if not _apply("demo_b","settle_trade",{"trade_id":trade,"offer_revision":review.offer_revision,"terms_digest":review.terms_digest}): return
	check(state.trades.is_empty() and state.assets[sword].owner_actor == "demo_b" and state.assets[sword].variant == sword_payload \
		and state.assets[helm].owner_actor == "demo_a", "Private settlement transfers exact equipment IDs/payloads to both inventories in one candidate")
	check(state.actors.demo_a.wallet_dm == 9991 and state.actors.demo_b.wallet_dm == 10009, "Two-way direct DM transfers conserve the exact accepted totals")
	if not _apply("demo_b","request_trade",{"other_actor_id":"demo_a","expires_in":20}): return
	trade = last_result.receipt.result.trade_id
	if not _apply("demo_a","decline_trade",{"trade_id":trade}): return
	check(state.trades.is_empty(), "Explicit decline releases the sole request slot without fabricated acceptance")
	if not _apply("demo_b","request_trade",{"other_actor_id":"demo_a","expires_in":20}): return
	trade = last_result.receipt.result.trade_id
	if not _apply("demo_a","accept_trade",{"trade_id":trade}): return
	if not _apply("demo_b","set_offer",{"trade_id":trade,"dm":100,"assets":[{"asset_id":_asset("demo_b","iron_ore"),"quantity":10}]}): return
	if not _apply("demo_b","lock_trade",{"trade_id":trade}): return
	if not _apply("demo_a","advance_time",{"seconds":20}): return
	check(state.trades.is_empty() and state.actors.demo_b.wallet_dm == 10009 \
		and state.assets[state.claims[_filled_claim("demo_b","iron_ore")].asset_id].quantity == 10,
		"Explicit trade expiry returns exactly the locked DM and items through original reservations")

func _matching() -> void:
	_fresh()
	var ids: Array[String] = []
	for price: int in [7,6,7]:
		if not _apply("demo_a","create_order",{"side":"sell","asset_id":_asset("demo_a","iron_ore"),"quantity":2,"unit_price":price,"expires_in":100}): return
		ids.append(last_result.receipt.result.order_id)
	var rows := Model.query_orders(state,{"search":"ore","category":"material","rarity":"common","side":"sell","sort":"price_asc"})
	check(rows.size() == 3 and rows[0].order_id == ids[1] and rows[1].order_id == ids[0] \
		and rows[2].order_id == ids[2], "Browse filters/order are deterministic by price then creation sequence")
	var stale := _command("demo_b","create_order",{"side":"buy","variant":Eligibility.base_variant("iron_ore"),"quantity":1,"unit_price":10,"expires_in":100})
	if not _apply("demo_b","create_order",{"side":"buy","variant":Eligibility.base_variant("iron_ore"),"quantity":5,"unit_price":10,"expires_in":100}): return
	var fills: Array = last_result.receipt.result.fills
	check(fills.size() == 3 and fills[0].order_id == ids[1] and fills[1].order_id == ids[0] \
		and fills[2].order_id == ids[2] and state.actors.demo_b.wallet_dm == 9967,
		"Automatic matching uses best resting price, then time; final crossing is a partial fill")
	check(last_result.receipt.result.dm_refund == 17 and state.orders[ids[2]].remaining_quantity == 1,
		"Every matched unit has explicit price-improvement refund and exact residual escrow")
	stale.sequence = int(state.command_heads.demo_b)+1
	check(not Model.plan(state,stale).ok, "Fresh sequence cannot authorize a stale review revision")

func _replay_and_codec() -> void:
	_fresh()
	if not _apply("demo_b","advance_time",{"seconds":1}): return
	var old_b := last_command.duplicate(true)
	for index in range(135):
		if not _apply("demo_a","advance_time",{"seconds":1}): return
	check(state.recent_receipts.size() == 64 and state.history.size() == 128, "Exact receipts and visible history stay independently bounded")
	check(Model.plan(state,old_b).status == "already_processed", "Pruned old actor command never becomes executable after history eviction")
	var parsed: Variant = JSON.parse_string(Model.canonical_json(state))
	check(Model.normalize(parsed) == state and Model.plan(parsed,old_b).status == "already_processed", "Canonical JSON reload preserves durable high-water replay safety")
	var damaged := state.duplicate(true)
	damaged.command_heads.demo_b -= 1
	damaged.command_heads.demo_a += 1
	check(Model.normalize(damaged).is_empty(), "Corrupt head redistribution cannot reopen an absent actor's pruned commands")
	damaged = state.duplicate(true)
	damaged.recent_receipts[1].sequence += 2
	check(Model.normalize(damaged).is_empty(), "Retained per-actor receipt sequences must be contiguous")
	for replacement: Variant in [null,0.5,NAN,{"extra":1}]:
		damaged = state.duplicate(true)
		damaged.recent_receipts.back().receipt.result.to_clock = replacement
		check(Model.normalize(damaged).is_empty(), "Malformed nullable/fractional receipt results reject the whole load")
	damaged = state.duplicate(true)
	damaged.recent_receipts.back().receipt.result.extra = 1
	check(Model.normalize(damaged).is_empty(), "Receipt result dictionaries reject unknown fields")
	damaged = state.duplicate(true)
	damaged.assets.values()[0].variant.durability = 20
	check(Model.normalize(damaged).is_empty(), "Equipment payload corruption cannot pass complete fixture-supply validation")
	var gap := _command("demo_a","advance_time",{"seconds":1})
	gap.sequence += 1
	check(not Model.plan(state,gap).ok, "Skipped durable command sequence rejects without consuming high-water")
	var before_reset := state.duplicate(true)
	if not _apply("demo_a","reset_demo",{}): return
	check(state.epoch == 2 and state.revision == 0 and state.clock == 0 and state.history.is_empty() \
		and state.command_heads == {"demo_a":0,"demo_b":0}, "Explicit reset starts a fresh fixture epoch without retaining invented sale history")
	var reset_replay := Model.plan(state,last_command)
	check(reset_replay.ok and reset_replay.status == "replayed" and reset_replay.receipt == last_result.receipt, "One persisted reset receipt reconciles a repeated reset acknowledgement")
	check(not Model.plan(state,old_b).ok and Model.parent_relation(before_reset,state), "Reset invalidates all other old-epoch commands with an exact allowed parent relation")
	fixture = Model.initial_state(SPACE)
	# Reset changes only the synthetic namespace epoch; its new equipment IDs are
	# compared against the same fixed payload fixtures at that epoch.
	fixture.assets = State.fixture_assets(SPACE,state.epoch)
	check(_conserved(), "Reset re-creates only the explicit synthetic fixture supply")

func _prepared_capacity() -> Dictionary:
	var prepared := Model.initial_state(SPACE)
	var initial_ids: Array = prepared.assets.keys()
	for id: String in initial_ids:
		if Eligibility.equipment(prepared.assets[id].variant): Ledger.move(prepared,id,"demo_a","inventory","demo_a")
	var source := Ledger.allocate(prepared,"order") # closed source reference in this prepared valid state
	var carried := 10
	var claimed := 0
	for id: String in initial_ids:
		if Eligibility.equipment(prepared.assets[id].variant): continue
		var remaining: int = prepared.assets[id].quantity
		while remaining > 0 and (carried < 40 or claimed < 63):
			var amount := 2 if carried == 10 and remaining >= 2 else 1
			var part := Ledger.extract(prepared,id,amount)
			remaining -= amount
			if carried < 40:
				Ledger.move(prepared,part,"demo_a","inventory","demo_a")
				carried += 1
			else:
				var claim := Ledger.reserve_claim(prepared,"demo_a","order",source,"return")
				Ledger.put_claim(prepared,claim,part)
				Ledger.release_claim(prepared,claim)
				claimed += 1
		if remaining > 0: Ledger.move(prepared,id,"demo_b","inventory","demo_b")
	return prepared

func _capacity() -> void:
	_fresh()
	state = _prepared_capacity()
	check(not Model.normalize(state).is_empty() and _conserved(), "Prepared normalized boundary (not constructed by a command sequence) preserves exact supply and equipment")
	check(State.inventory_count(state,"demo_a") == 40 and State.claim_count(state,"demo_a") == 63, "Prepared boundary has forty carried lots plus sixty-three claims")
	var two_unit := ""
	for id: String in state.assets:
		if state.assets[id].owner_actor == "demo_a" and state.assets[id].custody.kind == "inventory" and state.assets[id].quantity == 2: two_unit = id
	_reject("demo_a","create_order",{"side":"sell","asset_id":two_unit,"quantity":1,"unit_price":1,"expires_in":100},"Partial outgoing lot cannot consume the last transfer space")
	if not _apply("demo_a","create_order",{"side":"sell","asset_id":two_unit,"quantity":2,"unit_price":1,"expires_in":100}): return
	var order: String = last_result.receipt.result.order_id
	check(State.inventory_count(state,"demo_a") == 39 and State.claim_count(state,"demo_a") == 64, "Whole-lot listing preserves a free carried slot while reserving the64th return Claim")
	if not _apply("demo_b","request_trade",{"other_actor_id":"demo_a","expires_in":100}): return
	var trade: String = last_result.receipt.result.trade_id
	if not _apply("demo_a","accept_trade",{"trade_id":trade}): return
	if not _apply("demo_b","set_offer",{"trade_id":trade,"dm":0,"assets":[{"asset_id":_asset("demo_b","stamina_draught"),"quantity":1}]}): return
	if not _apply("demo_a","lock_trade",{"trade_id":trade}): return
	if not _apply("demo_b","lock_trade",{"trade_id":trade}): return
	var blocked := Model.trade_review(state,trade)
	check(not blocked.can_settle and blocked.capacity_error.contains("transfer space"), "Direct incoming gift cannot consume the last capacity needed to claim or return property")
	_reject("demo_b","settle_trade",{"trade_id":trade,"offer_revision":blocked.offer_revision,"terms_digest":blocked.terms_digest},"Blocked two-sided settlement preserves both offers and all reservations")
	if not _apply("demo_b","cancel_trade",{"trade_id":trade}): return
	var held_variants := {}
	for asset: Dictionary in state.assets.values():
		if asset.owner_actor == "demo_a" and asset.custody.kind == "inventory": held_variants[Eligibility.variant_key(asset.variant)] = true
	var claim_id := ""
	for id: String in state.claims:
		var claim: Dictionary = state.claims[id]
		if claim.actor_id == "demo_a" and not claim.reserved and not held_variants.has(Eligibility.variant_key(state.assets[claim.asset_id].variant)):
			claim_id = id
			break
	if not check(not claim_id.is_empty(), "Prepared saturation includes an unreserved different-variant lot to shuttle"): return
	if not _apply("demo_a","claim",{"claim_id":claim_id,"quantity":1}): return
	check(State.inventory_count(state,"demo_a") == 40 and State.claim_count(state,"demo_a") == 63, "Full-lot claim reuses transfer space without splitting or minting IDs")
	var asset_counter: int = state.next_asset
	if not _apply("demo_a","cancel_order",{"order_id":order}): return
	check(State.inventory_count(state,"demo_a") == 40 and State.claim_count(state,"demo_a") == 63 \
		and state.next_asset == asset_counter, "Cancellation with forty full slots still returns property using existing IDs and reserved Claim")
	var forged := state.duplicate(true)
	var template: Dictionary = forged.assets[two_unit]
	while forged.assets.size() <= State.MAX_ASSETS:
		var id := Ledger.allocate(forged,"asset")
		var extra := template.duplicate(true)
		extra.id = id
		forged.assets[id] = extra
	check(Model.normalize(forged).is_empty(), "More than208 assets is explicitly a forged-invalid case; fixture has only184 conserved units")
	var debt: int = state.orders.size()+state.trades.size()+state.claims.size()+1
	var boundary := state.duplicate(true)
	boundary.revision = State.MAX_COUNT-debt
	check(State.limits_error(boundary).is_empty(), "Numeric closure headroom includes every retained claim slot")
	boundary.revision += 1
	check(not State.limits_error(boundary).is_empty(), "Non-closure mutation cannot consume numeric cleanup headroom")

func _conserved() -> bool:
	var money := 0
	for actor: Dictionary in state.actors.values(): money += int(actor.wallet_dm)
	for order: Dictionary in state.orders.values(): money += int(order.escrow_dm)
	for trade: Dictionary in state.trades.values():
		for offer: Dictionary in trade.offers.values(): money += int(offer.dm)
	if money != 20000: return false
	var expected := {}
	var actual := {}
	var equipment := {}
	var initial := State.fixture_assets(state.namespace,state.epoch)
	for asset: Dictionary in initial.values():
		var key := Model.canonical_json(asset.variant)
		expected[key] = int(expected.get(key,0))+int(asset.quantity)
		if Eligibility.equipment(asset.variant): equipment[asset.id] = asset.variant
	for id: String in state.assets:
		var asset: Dictionary = state.assets[id]
		var key := Model.canonical_json(asset.variant)
		actual[key] = int(actual.get(key,0))+int(asset.quantity)
		if Eligibility.equipment(asset.variant):
			if not equipment.has(id) or equipment[id] != asset.variant or asset.quantity != 1: return false
			equipment.erase(id)
	return actual == expected and equipment.is_empty()
