extends "res://tests/test_harness.gd"
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const SPACE := "00112233445566778899aabbccddeeff"
var state: Dictionary
var last_command: Dictionary
var last_result: Dictionary
var commands := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE SALES"
	_run.call_deferred()

func _run() -> void:
	_exact_sales_and_types()
	_retention_and_reset()
	print("DEMO SALES METRICS: " + JSON.stringify({"executed_command_plans":commands,"sale_cap":128,
		"retention_fixture_sales":129,"prices_from_order_execution_only":true,"fixed_point_variants":true}))
	finish()

func _fresh() -> void:
	state = Model.initial_state(SPACE)
	check(state.sales.is_empty() and Model.sales_history(state).is_empty() and Model.price_history(state).is_empty(),
		"Initial TEST fixture contains no manufactured sales or prices")

func _command(actor: String, action: String, args: Dictionary) -> Dictionary:
	return {"namespace":state.namespace,"epoch":state.epoch,"expected_revision":state.revision,
		"actor_id":actor,"sequence":int(state.command_heads[actor])+1,"action":action,"args":args.duplicate(true)}

func _apply(actor: String, action: String, args: Dictionary) -> bool:
	var before := state.duplicate(true)
	last_command = _command(actor,action,args)
	last_result = Model.plan(state,last_command)
	if not check(last_result.ok and last_result.status == "planned", action + " creates a valid internally derived sale-aware plan: " + String(last_result.error)): return false
	if not check(state == before and Model.parent_relation(before,last_result.candidate), action + " preserves source state and corroborates appended sales against its parent orders"): return false
	state = last_result.candidate
	commands += 1
	return true

func _asset(actor: String, item_id: String) -> String:
	for id: String in state.assets:
		var asset: Dictionary = state.assets[id]
		if asset.owner_actor == actor and asset.custody.kind == "inventory" and asset.variant.item_id == item_id: return id
	return ""

func _exact_sales_and_types() -> void:
	_fresh()
	if not _apply("demo_a","create_order",{"side":"sell","asset_id":_asset("demo_a","iron_ore"),"quantity":3,"unit_price":9,"expires_in":100}): return
	var order: String = last_result.receipt.result.order_id
	check(state.sales.is_empty(), "Unfilled listings do not fabricate price history")
	if not _apply("demo_b","fill_order",{"order_id":order,"quantity":1}): return
	var first: Dictionary = state.sales[0]
	check(first.item_id == "iron_ore" and first.variant == Eligibility.base_variant("iron_ore") \
		and first.quantity == 1 and first.unit_price == 9 and first.buyer_actor == "demo_b" and first.seller_actor == "demo_a" \
		and first.source_order_id == order and first.sell_order_id == order and first.buy_order_id.is_empty(),
		"Direct sell-order fill records exact variant/price/quantity/distinct actors and source order")
	check(first.id == last_result.receipt.id+":fill:0" and first.receipt_id == last_result.receipt.id \
		and first.revision == state.revision and first.clock == state.clock, "Sale identity/time derives from the committed transaction and controlled demo clock")
	var before := state.duplicate(true)
	var second_command := _command("demo_b","fill_order",{"order_id":order,"quantity":2})
	var second := Model.plan(state,second_command)
	if not check(second.ok, "Second sale closes the order"): return
	var forged: Dictionary = second.candidate.duplicate(true)
	forged.sales.back().variant = Eligibility.base_variant("root_fiber")
	forged.sales.back().variant_key = Eligibility.variant_key(forged.sales.back().variant)
	forged.sales.back().item_id = "root_fiber"
	check(not Model.parent_relation(before,forged), "New persisted sale cannot substitute another known fixture variant for the actual parent order")
	forged = second.candidate.duplicate(true)
	forged.sales.back().buyer_actor = "demo_a"
	forged.sales.back().seller_actor = "demo_b"
	check(not Model.parent_relation(before,forged), "New sale cannot reverse actual parent-order buyer/seller authority")
	if not _apply("demo_b","fill_order",{"order_id":order,"quantity":2}): return
	check(not state.orders.has(order) and state.sales.size() == 2, "Structured sales remain after the original order closes")
	var tape: Array = state.sales.duplicate(true)
	var replay := Model.plan(state,last_command)
	check(replay.status == "replayed" and replay.candidate.is_empty() and state.sales == tape, "Duplicate execution returns no candidate and appends no extra sale")
	forged = state.duplicate(true)
	forged.sales.pop_front()
	check(Model.normalize(forged).is_empty(), "A short tape cannot falsely claim its first provable sale was pruned")
	var summary := Model.price_history(state,Eligibility.variant_key(Eligibility.base_variant("iron_ore")))
	check(summary.size() == 1 and summary[0].quantity == 3 and summary[0].sale_count == 2 \
		and summary[0].min_unit_price == 9 and summary[0].max_unit_price == 9 and summary[0].total_dm == 27,
		"Read-only exact-variant price view reports retained executed quantity/value and price range")
	if not _apply("demo_a","request_trade",{"other_actor_id":"demo_b","expires_in":100}): return
	var trade: String = last_result.receipt.result.trade_id
	if not _apply("demo_b","accept_trade",{"trade_id":trade}): return
	if not _apply("demo_a","set_offer",{"trade_id":trade,"dm":1,"assets":[]}): return
	if not _apply("demo_a","lock_trade",{"trade_id":trade}): return
	if not _apply("demo_b","lock_trade",{"trade_id":trade}): return
	var review := Model.trade_review(state,trade)
	if not _apply("demo_b","settle_trade",{"trade_id":trade,"offer_revision":review.offer_revision,"terms_digest":review.terms_digest}): return
	check(state.sales == tape, "Even a committed direct DM trade creates no inferred sale price")
	# Keep each compared identity family present for malformed scalar probes.
	if not _apply("demo_a","create_order",{"side":"sell","asset_id":_asset("demo_a","root_fiber"),"quantity":1,"unit_price":3,"expires_in":100}): return
	order = last_result.receipt.result.order_id
	if not _apply("demo_a","request_trade",{"other_actor_id":"demo_b","expires_in":100}): return
	trade = last_result.receipt.result.trade_id
	var asset: String = state.assets.keys()[0]
	var claim: String = state.orders[order].claim_id
	var paths: Array = [["magic"],["fixture_id"],["version"],["namespace"],["revision"],
		["assets",asset,"id"],["assets",asset,"owner_actor"],["assets",asset,"custody","kind"],
		["orders",order,"id"],["orders",order,"variant_key"],["orders",order,"claim_id"],
		["trades",trade,"id"],["trades",trade,"status"],
		["claims",claim,"id"],["claims",claim,"source_id"],["claims",claim,"reserved"],
		["history",0,"epoch"],["history",0,"revision"],["history",0,"actor_id"],["history",0,"action"],
		["recent_receipts",0,"receipt","id"],["recent_receipts",0,"receipt","actor_id"],
		["recent_receipts",0,"receipt","sequence"],["recent_receipts",0,"receipt","request_epoch"],
		["recent_receipts",0,"receipt","committed_epoch"],["recent_receipts",0,"receipt","status"],
		["recent_receipts",0,"receipt","action"],["recent_receipts",0,"receipt","entity_id"],
		["sales",0,"id"],["sales",0,"receipt_id"],["sales",0,"revision"],["sales",0,"fill_index"],
		["sales",0,"clock"],["sales",0,"quantity"],["sales",0,"unit_price"],["sales",0,"command_sequence"],
		["sales",0,"buyer_actor"],["sales",0,"source_action"],["sales",0,"variant","item_id"]]
	for path: Array in paths:
		for bad: Variant in [null,[],{}]:
			forged = state.duplicate(true)
			var target: Variant = forged
			for index in range(path.size()-1): target = target[path[index]]
			target[path.back()] = bad
			check(Model.normalize(forged).is_empty(), "Malformed identity/scalar family rejects safely: " + str(path))
		forged = state.duplicate(true)
		var target: Variant = forged
		for index in range(path.size()-1): target = target[path[index]]
		target[path.back()] = 1 if target[path.back()] is bool else true
		check(Model.normalize(forged).is_empty(), "Boolean/integer substitution rejects before comparison: " + str(path))
	check(not Model.preview(state,"demo_a","create_order",{"side":true,"asset_id":asset,"quantity":1,"unit_price":1,"expires_in":1}).ok,
		"Wrong-type user action enum rejects without invalid-operand diagnostics")
	forged = state.duplicate(true)
	forged.sales[0].extra = "unsupported"
	check(Model.normalize(forged).is_empty(), "Sale DTO rejects extra persisted fields")
	var base := _asset("demo_a","traveler_sword")
	var improved := _asset("demo_b","traveler_sword")
	var base_key := Eligibility.variant_key(state.assets[base].variant)
	var improved_key := Eligibility.variant_key(state.assets[improved].variant)
	if not _apply("demo_a","create_order",{"side":"sell","asset_id":base,"quantity":1,"unit_price":11,"expires_in":100}): return
	order = last_result.receipt.result.order_id
	if not _apply("demo_b","fill_order",{"order_id":order,"quantity":1}): return
	if not _apply("demo_b","create_order",{"side":"sell","asset_id":improved,"quantity":1,"unit_price":17,"expires_in":100}): return
	order = last_result.receipt.result.order_id
	if not _apply("demo_a","fill_order",{"order_id":order,"quantity":1}): return
	var base_prices := Model.price_history(state,base_key)
	var improved_prices := Model.price_history(state,improved_key)
	check(base_key != improved_key and base_prices.size() == 1 and improved_prices.size() == 1 \
		and base_prices[0].last_unit_price == 11 and improved_prices[0].last_unit_price == 17 \
		and base_prices[0].quantity == 1 and improved_prices[0].quantity == 1,
		"Same-item swords with different enhancement/durability/rolls retain separate exact-variant price histories")

func _retention_and_reset() -> void:
	_fresh()
	for price: int in [1,2,3]:
		if not _apply("demo_a","create_order",{"side":"sell","asset_id":_asset("demo_a","iron_ore"),"quantity":1,"unit_price":price,"expires_in":100}): return
	if not _apply("demo_b","create_order",{"side":"buy","variant":Eligibility.base_variant("iron_ore"),"quantity":3,"unit_price":3,"expires_in":100}): return
	check(state.sales.size() == 3 and state.sales[0].unit_price == 1 and state.sales[1].unit_price == 2 \
		and state.sales[2].unit_price == 3 and state.sales[2].fill_index == 2,
		"One incoming match creates separate actual maker-price rows with exact fill indices")
	var forged := state.duplicate(true)
	forged.sales.pop_front()
	check(Model.normalize(forged).is_empty(), "A small multi-fill tape cannot omit its first fill as if128-row pruning occurred")
	var claim: String = state.claims.keys().filter(func(id: String) -> bool: return not String(state.claims[id].asset_id).is_empty())[0]
	if not _apply("demo_b","claim",{"claim_id":claim,"quantity":3}): return
	var last_fill: Dictionary = {}
	for index in range(126):
		var seller := "demo_a" if index % 2 == 0 else "demo_b"
		var buyer := "demo_b" if seller == "demo_a" else "demo_a"
		if not _apply(seller,"create_order",{"side":"sell","asset_id":_asset(seller,"iron_ore"),"quantity":1,"unit_price":2+index%3,"expires_in":100}): return
		var order: String = last_result.receipt.result.order_id
		if not _apply(buyer,"fill_order",{"order_id":order,"quantity":1}): return
		last_fill = last_command.duplicate(true)
		claim = last_result.receipt.result.claim_id
		if not _apply(buyer,"claim",{"claim_id":claim,"quantity":1}): return
	check(state.sales.size() == 128 and state.sales[0].fill_index == 1 and not Model.normalize(state).is_empty(),
		"129 actual executions retain128 rows, including a legitimately pruned prefix inside an old multi-fill transaction")
	var summary := Model.price_history(state)
	check(summary.size() == 1 and summary[0].sale_count == 128 and summary[0].quantity == 128 \
		and summary[0].min_unit_price == 2 and summary[0].max_unit_price == 4 and summary[0].last_unit_price == 4,
		"Bounded price summary uses only retained executed rows, not removed activity or catalog valuations")
	var tape: Array = state.sales.duplicate(true)
	var replay := Model.plan(state,last_fill)
	check(replay.status == "replayed" and replay.candidate.is_empty() and state.sales == tape, "Repeated latest fill cannot extend the full sale tape")
	var loaded := Model.normalize(JSON.parse_string(Model.canonical_json(state)))
	check(loaded == state and Model.price_history(loaded) == summary, "Strict canonical reload retains the full sale tape and exact price summaries")
	var shown := Model.sales_history(state)
	check(shown[0].id == state.sales.back().id and shown.back().id == state.sales[0].id, "Read-only sale view is newest-first while persistence remains chronological")
	shown[0].variant.modifier_units["damage_bonus"] = 999
	summary[0].quantity = 999
	check(state.sales == tape and Model.price_history(state)[0].quantity == 128, "Caller-edited sale/price snapshots cannot change durable history")
	if not _apply("demo_a","reset_demo",{}): return
	check(state.sales.is_empty() and Model.sales_history(state).is_empty() and Model.price_history(state).is_empty(),
		"Explicit TEST reset clears sales/price history rather than seeding fictional replacement activity")
