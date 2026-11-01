class_name VaultDemoExchangeModel
extends RefCounted
## Pure local TEST transactions. Never accesses Session, files, clocks or RNG.
const Codec = preload("res://scripts/exchange/demo_exchange_codec.gd")
const State = preload("res://scripts/exchange/demo_exchange_state.gd")
const Ledger = preload("res://scripts/exchange/demo_exchange_ledger.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const ACTORS := State.ACTORS
const PUBLIC_ACTIONS := ["create_order","fill_order","cancel_order","claim","request_trade",
	"accept_trade","decline_trade","set_offer","lock_trade","cancel_trade","advance_time","reset_demo"]

static func initial_state(space: String, fixture_id: String = State.FIXTURE) -> Dictionary:
	return State.initial_state(space,fixture_id)

static func normalize(value: Variant) -> Dictionary:
	return State.normalize(value)

static func canonical_json(value: Variant) -> String:
	return Codec.canonical_json(value)

static func digest(value: Variant) -> String:
	return Codec.digest(value)

static func command_digest(command: Dictionary) -> String:
	var normalized := _command(command)
	return Codec.digest(normalized) if not normalized.is_empty() else ""

static func preview(value: Dictionary, actor_id: String, action: String, args: Dictionary) -> Dictionary:
	var state := normalize(value)
	if state.is_empty() or not ACTORS.has(actor_id) or not PUBLIC_ACTIONS.has(action):
		return {"ok":false,"error":"This TEST action is unavailable.","review":{}}
	var command := {"namespace":state.namespace,"epoch":state.epoch,"expected_revision":state.revision,
		"actor_id":actor_id,"sequence":int(state.command_heads[actor_id])+1,"action":action,"args":args.duplicate(true)}
	var proposed := plan(state,command)
	return {"ok":proposed.ok,"error":proposed.error,"review":proposed.review.duplicate(true)}

static func plan(value: Dictionary, intent: Dictionary) -> Dictionary:
	var state := normalize(value)
	var command := _command(intent)
	if state.is_empty(): return _failure("The TEST exchange state failed validation.")
	if command.is_empty() or command.namespace != state.namespace: return _failure("Invalid TEST command identity or arguments.")
	var fingerprint := Codec.digest(command)
	var previous: Dictionary = state.last_reset
	if not previous.is_empty() and command.epoch == previous.receipt.request_epoch \
			and command.actor_id == previous.actor_id and command.sequence == previous.sequence:
		return _duplicate(previous,fingerprint)
	if command.epoch != state.epoch: return _failure("This TEST command belongs to another reset epoch.")
	var head: int = state.command_heads[command.actor_id]
	if command.sequence <= head:
		for stored: Dictionary in state.recent_receipts:
			if stored.actor_id == command.actor_id and stored.sequence == command.sequence:
				return _duplicate(stored,fingerprint)
		return _failure("This TEST command was already processed; its detailed receipt is outside the retained history.","already_processed")
	if command.sequence != head+1: return _failure("TEST command sequences must be contiguous.")
	if command.expected_revision != state.revision: return _failure("The TEST exchange changed. Review the current terms again.")
	if command.action == "reset_demo": return _reset_plan(state,command,fingerprint)
	if state.revision >= State.MAX_COUNT: return _failure("The TEST revision limit has been reached; saved contents are preserved.")
	var next := state.duplicate(true)
	var outcome := _evaluate(next,command.actor_id,command.action,command.args)
	if outcome.has("error"): return _failure(outcome.error)
	next.revision += 1
	next.command_heads[command.actor_id] += 1
	var limit_error := State.limits_error(next)
	if not limit_error.is_empty(): return _failure(limit_error)
	var receipt := _receipt(state,next,command,outcome)
	_append_sales(next,command,receipt,outcome.get("sales",[]))
	next.recent_receipts.append({"actor_id":command.actor_id,"sequence":command.sequence,"payload_digest":fingerprint,"receipt":receipt.duplicate(true)})
	while next.recent_receipts.size() > State.MAX_RECEIPTS: next.recent_receipts.pop_front()
	next.history.append({"epoch":next.epoch,"revision":next.revision,"actor_id":command.actor_id,
		"action":command.action,"entity_id":outcome.entity_id,"summary":String(outcome.summary).left(240),"clock":next.clock})
	while next.history.size() > State.MAX_HISTORY: next.history.pop_front()
	if normalize(next).is_empty(): return _failure("The TEST transaction did not preserve complete ownership and accounting.")
	return {"ok":true,"status":"planned","error":"","candidate":next,"receipt":receipt,
		"review":_review(state,next,command,outcome)}

static func parent_relation(before: Dictionary, candidate: Dictionary) -> bool:
	var old := normalize(before)
	var next := normalize(candidate)
	if old.is_empty() or next.is_empty() or old.namespace != next.namespace or old.fixture_id != next.fixture_id: return false
	if int(next.epoch) == int(old.epoch)+1 and next.revision == 0:
		var stored: Dictionary = next.last_reset
		var actor: String = stored.actor_id
		var command := {"namespace":old.namespace,"epoch":old.epoch,"expected_revision":old.revision,
			"actor_id":actor,"sequence":int(old.command_heads[actor])+1,"action":"reset_demo","args":{}}
		var expected := _reset_plan(old,command,Codec.digest(command))
		return expected.ok and expected.candidate == next
	if next.epoch != old.epoch or int(next.revision) != int(old.revision)+1 or next.clock < old.clock \
			or next.last_reset != old.last_reset: return false
	for key: String in ["next_asset","next_order","next_trade","next_claim"]:
		if next[key] < old[key]: return false
	var latest: Dictionary = next.recent_receipts.back()
	if latest.receipt.action == "advance_time":
		if latest.receipt.result.from_clock != old.clock or latest.receipt.result.to_clock != next.clock: return false
	elif next.clock != old.clock: return false
	for actor: String in ACTORS:
		if int(next.command_heads[actor]) != int(old.command_heads[actor]) + (1 if actor == latest.actor_id else 0): return false
	var records: Array = old.recent_receipts.duplicate(true)
	records.append(latest)
	if records.size() > State.MAX_RECEIPTS: records.pop_front()
	var history: Array = old.history.duplicate(true)
	history.append(next.history.back())
	if history.size() > State.MAX_HISTORY: history.pop_front()
	var sales: Array = old.sales.duplicate(true)
	for sale: Dictionary in next.sales:
		if sale.revision == next.revision:
			if not _new_sale_valid(old,sale): return false
			sales.append(sale.duplicate(true))
	while sales.size() > State.MAX_SALES: sales.pop_front()
	return records == next.recent_receipts and history == next.history and sales == next.sales

static func _new_sale_valid(before: Dictionary, sale: Dictionary) -> bool:
	var reference_id: String = sale.source_order_id
	if sale.source_action == "create_order":
		if sale.source_order_id != State.make_id(before.namespace,before.epoch,"order",before.next_order): return false
		reference_id = sale.sell_order_id if sale.source_order_id == sale.buy_order_id else sale.buy_order_id
	if not before.orders.has(reference_id) or sale.clock != before.clock: return false
	var order: Dictionary = before.orders[reference_id]
	if sale.variant != order.variant or sale.unit_price != order.unit_price or sale.quantity > order.remaining_quantity: return false
	var buyer: String = sale.command_actor if order.side == "sell" else order.actor_id
	var seller: String = order.actor_id if order.side == "sell" else sale.command_actor
	return sale.buyer_actor == buyer and sale.seller_actor == seller \
		and (sale.sell_order_id if order.side == "sell" else sale.buy_order_id) == reference_id

static func _command(value: Dictionary) -> Dictionary:
	var command: Variant = Codec.integer_tree(value)
	if not Codec.keys(command,["namespace","epoch","expected_revision","actor_id","sequence","action","args"]) \
			or not Codec.hex_digest(command.namespace,32) or not Codec.integer(command.epoch,1) \
			or not Codec.integer(command.expected_revision) or not ACTORS.has(command.actor_id) \
			or not Codec.integer(command.sequence,1) or not State.ACTIONS.has(command.action) \
			or not command.args is Dictionary: return {}
	if not _args_valid(command.action,command.args): return {}
	return command

static func _args_valid(action: String, args: Dictionary) -> bool:
	match action:
		"create_order":
			if not args.get("side") is String: return false
			if args.get("side") == "sell":
				if not Codec.keys(args,["side","asset_id","quantity","unit_price","expires_in"]) or not Codec.text(args.asset_id,160): return false
			elif args.get("side") == "buy":
				if not Codec.keys(args,["side","variant","quantity","unit_price","expires_in"]) \
						or Eligibility.normalize_variant(args.variant).is_empty(): return false
			else: return false
			return Codec.integer(args.quantity,1,999) and Codec.integer(args.unit_price,1,State.MAX_PRICE) and Codec.integer(args.expires_in,1,State.MAX_TIME_STEP)
		"fill_order":
			return (Codec.keys(args,["order_id","quantity"]) or (Codec.keys(args,["order_id","quantity","asset_id"]) \
				and Codec.text(args.asset_id,160))) and Codec.text(args.order_id,160) and Codec.integer(args.quantity,1,999)
		"cancel_order": return Codec.keys(args,["order_id"]) and Codec.text(args.order_id,160)
		"claim": return Codec.keys(args,["claim_id","quantity"]) and Codec.text(args.claim_id,160) and Codec.integer(args.quantity,1,999)
		"request_trade": return Codec.keys(args,["other_actor_id","expires_in"]) and ACTORS.has(args.other_actor_id) and Codec.integer(args.expires_in,1,State.MAX_TIME_STEP)
		"accept_trade","decline_trade","lock_trade","cancel_trade": return Codec.keys(args,["trade_id"]) and Codec.text(args.trade_id,160)
		"set_offer":
			if not Codec.keys(args,["trade_id","dm","assets"]) or not Codec.text(args.trade_id,160) \
					or not Codec.integer(args.dm) or not args.assets is Array or args.assets.size() > State.MAX_OFFER_ROWS: return false
			var seen := {}
			for row: Variant in args.assets:
				if not Codec.keys(row,["asset_id","quantity"]) or not Codec.text(row.asset_id,160) \
						or not Codec.integer(row.quantity,1,999) or seen.has(row.asset_id): return false
				seen[row.asset_id] = true
			return true
		"advance_time": return Codec.keys(args,["seconds"]) and Codec.integer(args.seconds,1,State.MAX_TIME_STEP)
		"reset_demo": return args.is_empty()
		"settle_trade": return Codec.keys(args,["trade_id","offer_revision","terms_digest"]) and Codec.text(args.trade_id,160) \
			and Codec.integer(args.offer_revision) and Codec.hex_digest(args.terms_digest)
	return false

static func _evaluate(state: Dictionary, actor: String, action: String, args: Dictionary) -> Dictionary:
	match action:
		"create_order": return _create_order(state,actor,args)
		"fill_order": return _fill_order(state,actor,args)
		"cancel_order":
			if not state.orders.has(args.order_id) or state.orders[args.order_id].actor_id != actor: return {"error":"Only the owner can cancel an open TEST order."}
			var returned := Ledger.close_order(state,args.order_id)
			if returned.has("error"): return returned
			return _outcome(args.order_id,"Cancelled TEST order; remaining items are in Claims and DEMO DM is refunded.",returned)
		"claim": return _claim(state,actor,args)
		"request_trade": return _request_trade(state,actor,args)
		"accept_trade","decline_trade","set_offer","lock_trade","cancel_trade","settle_trade": return _trade_action(state,actor,action,args)
		"advance_time": return _advance_time(state,args.seconds)
	return {"error":"This TEST action is unavailable."}

static func _owned_asset(state: Dictionary, actor: String, id: String, kind: String = "inventory", ref: String = "") -> String:
	if not state.assets.has(id): return "This TEST item is unavailable."
	var asset: Dictionary = state.assets[id]
	if asset.owner_actor != actor or asset.custody.kind != kind or (not ref.is_empty() and asset.custody.ref != ref):
		return "This synthetic actor does not have that available item."
	return Eligibility.asset_error(asset)

static func _create_order(state: Dictionary, actor: String, args: Dictionary) -> Dictionary:
	if State.order_count(state,actor) >= State.MAX_ORDERS: return {"error":"This actor already has sixteen open TEST orders."}
	if int(state.clock) > State.MAX_COUNT-int(args.expires_in): return {"error":"The TEST expiry clock limit has been reached."}
	var variant: Dictionary
	if args.side == "sell":
		var error := _owned_asset(state,actor,args.asset_id)
		if not error.is_empty(): return {"error":error}
		if args.quantity > state.assets[args.asset_id].quantity: return {"error":"This selected TEST lot does not contain that quantity."}
		variant = state.assets[args.asset_id].variant.duplicate(true)
	else: variant = Eligibility.normalize_variant(args.variant)
	if variant.is_empty() or not variant.identified or args.quantity > Eligibility.stack_limit(variant): return {"error":"Choose one identified equipment item or no more than one catalog stack."}
	var reserve := int(args.quantity)*int(args.unit_price)
	if args.side == "buy" and reserve > int(state.actors[actor].wallet_dm): return {"error":"This synthetic actor cannot escrow the order's DEMO DM total."}
	var id := Ledger.allocate(state,"order")
	if id.is_empty(): return {"error":"The TEST order identity limit has been reached."}
	var claim := Ledger.reserve_claim(state,actor,"order",id,"return" if args.side == "sell" else "delivery")
	if claim.is_empty(): return {"error":"A TEST order needs a free reserved delivery/return slot."}
	var asset_id := ""
	if args.side == "sell":
		asset_id = Ledger.extract(state,args.asset_id,args.quantity)
		if asset_id.is_empty(): return {"error":"The TEST asset identity limit prevents this split."}
		Ledger.move(state,asset_id,actor,"order",id)
	else: state.actors[actor].wallet_dm -= reserve
	state.orders[id] = {"id":id,"actor_id":actor,"side":args.side,"variant":variant,
		"variant_key":Eligibility.variant_key(variant),"unit_price":args.unit_price,
		"initial_quantity":args.quantity,"remaining_quantity":args.quantity,
		"created_sequence":int(id.get_slice(":",4)),"expires_at":int(state.clock)+int(args.expires_in),
		"escrow_asset_id":asset_id,"escrow_dm":reserve if args.side == "buy" else 0,"claim_id":claim}
	# Admission must reserve transfer space before matching can hide a bad order.
	var admission_error := State.limits_error(state)
	if not admission_error.is_empty(): return {"error":admission_error}
	var candidates: Array = []
	for resting: Dictionary in state.orders.values():
		if resting.id == id or resting.actor_id == actor or resting.side == args.side \
				or resting.variant_key != state.orders[id].variant_key: continue
		if (args.side == "buy" and resting.unit_price <= args.unit_price) or (args.side == "sell" and resting.unit_price >= args.unit_price):
			candidates.append(resting.duplicate(true))
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.unit_price != b.unit_price: return a.unit_price < b.unit_price if args.side == "buy" else a.unit_price > b.unit_price
		if a.created_sequence != b.created_sequence: return a.created_sequence < b.created_sequence
		return String(a.id)<String(b.id))
	var fills: Array = []
	var paid := 0
	var received := 0
	var refund := 0
	var sales: Array = []
	for resting: Dictionary in candidates:
		if not state.orders.has(id): break
		var quantity := mini(int(state.orders[id].remaining_quantity),int(state.orders[resting.id].remaining_quantity))
		var buyer: String = actor if args.side == "buy" else resting.actor_id
		var seller: String = resting.actor_id if args.side == "buy" else actor
		sales.append(_sale_terms("create_order",id,id if args.side == "buy" else resting.id,
			resting.id if args.side == "buy" else id,buyer,seller,variant,quantity,resting.unit_price))
		var filled := Ledger.match_fill(state,resting.id if args.side == "buy" else id,id if args.side == "buy" else resting.id,quantity,resting.unit_price)
		if filled.has("error"): return filled
		fills.append({"order_id":resting.id,"quantity":quantity,"unit_price":resting.unit_price})
		if args.side == "buy":
			paid += int(filled.dm_paid)
			refund += int(filled.dm_refund)
		else: received += int(filled.dm_paid)
	var remaining: int = state.orders[id].remaining_quantity if state.orders.has(id) else 0
	var result := {"order_id":id,"remaining_quantity":remaining,"filled_quantity":int(args.quantity)-remaining,
		"fills":fills,"dm_paid":paid,"dm_received":received,"dm_refund":refund}
	return _outcome(id,"Created TEST %s order · %d filled, %d remaining." % [args.side,result.filled_quantity,remaining],result,sales)

static func _fill_order(state: Dictionary, actor: String, args: Dictionary) -> Dictionary:
	if not state.orders.has(args.order_id): return {"error":"This TEST order is closed or unavailable."}
	var order: Dictionary = state.orders[args.order_id]
	if order.actor_id == actor: return {"error":"A synthetic actor cannot match their own order."}
	if int(args.quantity) > int(order.remaining_quantity): return {"error":"The TEST order has fewer remaining units."}
	var payment := int(args.quantity)*int(order.unit_price)
	var delivery := ""
	var claim := ""
	if order.side == "sell":
		if args.has("asset_id"): return {"error":"A sell listing accepts DEMO DM, not a caller-selected replacement item."}
		if payment > int(state.actors[actor].wallet_dm): return {"error":"This synthetic actor cannot afford the TEST fill."}
		claim = Ledger.delivery_claim(state,actor,order.id,order.variant,args.quantity)
		if claim.is_empty(): return {"error":"This TEST fill needs a delivery slot in Claims."}
		delivery = Ledger.extract(state,order.escrow_asset_id,args.quantity)
		if delivery.is_empty(): return {"error":"The TEST asset identity limit prevents this partial fill."}
		var error := Ledger.put_claim(state,claim,delivery)
		if not error.is_empty(): return {"error":error}
		Ledger.release_claim(state,claim)
		state.actors[actor].wallet_dm -= payment
		state.actors[order.actor_id].wallet_dm += payment
	else:
		if not args.has("asset_id"): return {"error":"Choose the exact available item for this TEST buy order."}
		var error := _owned_asset(state,actor,args.asset_id)
		if not error.is_empty(): return {"error":error}
		var source: Dictionary = state.assets[args.asset_id]
		if source.variant != order.variant or args.quantity > source.quantity: return {"error":"This TEST buy order requires the exact variant and quantity."}
		delivery = Ledger.extract(state,args.asset_id,args.quantity)
		if delivery.is_empty(): return {"error":"The TEST asset identity limit prevents this partial fill."}
		claim = order.claim_id
		error = Ledger.put_claim(state,claim,delivery)
		if not error.is_empty(): return {"error":error}
		order.escrow_dm -= payment
		state.actors[actor].wallet_dm += payment
	order.remaining_quantity -= int(args.quantity)
	var remaining: int = order.remaining_quantity
	Ledger.finish_filled_order(state,args.order_id)
	var sales: Array = [_sale_terms("fill_order",order.id,order.id if order.side == "buy" else "",
		order.id if order.side == "sell" else "",actor if order.side == "sell" else order.actor_id,
		order.actor_id if order.side == "sell" else actor,order.variant,args.quantity,order.unit_price)]
	return _outcome(args.order_id,"Filled TEST order · %d items delivered to Claims." % int(args.quantity),
		{"order_id":args.order_id,"filled_quantity":args.quantity,"remaining_quantity":remaining,
		"unit_price":order.unit_price,"dm_amount":payment,"claim_id":claim},sales)

static func _claim(state: Dictionary, actor: String, args: Dictionary) -> Dictionary:
	if not state.claims.has(args.claim_id) or state.claims[args.claim_id].actor_id != actor: return {"error":"Only the owner can collect this TEST claim."}
	var claim: Dictionary = state.claims[args.claim_id]
	if not state.assets.has(claim.asset_id): return {"error":"This slot is reserved for a future TEST delivery or return."}
	var original: Dictionary = state.assets[claim.asset_id]
	if args.quantity > original.quantity: return {"error":"This TEST claim contains fewer units."}
	var amount := mini(int(args.quantity),Ledger.inventory_fit(state,actor,original))
	if amount <= 0: return {"error":"The TEST inventory is full. The claim remains safely reserved."}
	var delivered := Ledger.extract(state,claim.asset_id,amount)
	if delivered.is_empty(): return {"error":"The TEST asset identity limit prevents a split; collect the full lot when space permits."}
	var remaining := int(original.quantity) if delivered != claim.asset_id else 0
	if remaining == 0:
		claim.asset_id = ""
		if not claim.reserved: state.claims.erase(args.claim_id)
	var error := Ledger.put_inventory(state,actor,delivered)
	if not error.is_empty(): return {"error":error}
	return _outcome(args.claim_id,"Claimed %d TEST items · %d remain in Claims." % [amount,remaining],
		{"claim_id":args.claim_id,"requested_quantity":args.quantity,"claimed_quantity":amount,"remaining_quantity":remaining})

static func _request_trade(state: Dictionary, actor: String, args: Dictionary) -> Dictionary:
	if actor == args.other_actor_id or not state.trades.is_empty(): return {"error":"Only one TEST request/trade with the other synthetic actor can be active."}
	if int(state.clock) > State.MAX_COUNT-int(args.expires_in): return {"error":"The TEST expiry clock limit has been reached."}
	var id := Ledger.allocate(state,"trade")
	if id.is_empty(): return {"error":"The TEST trade identity limit has been reached."}
	state.trades[id] = {"id":id,"requester_actor":actor,"recipient_actor":args.other_actor_id,"status":"requested",
		"offer_revision":0,"expires_at":int(state.clock)+int(args.expires_in),
		"offers":{"demo_a":{"dm":0,"assets":[]},"demo_b":{"dm":0,"assets":[]}},"locks":{"demo_a":false,"demo_b":false}}
	return _outcome(id,"TEST trade requested. Explicitly control the other synthetic actor to accept or decline.",{"trade_id":id,"status":"requested"})

static func _trade_action(state: Dictionary, actor: String, action: String, args: Dictionary) -> Dictionary:
	if not state.trades.has(args.trade_id): return {"error":"This TEST trade is closed or unavailable."}
	var trade: Dictionary = state.trades[args.trade_id]
	if action in ["accept_trade","decline_trade"]:
		if trade.status != "requested" or trade.recipient_actor != actor: return {"error":"Only the addressed synthetic actor can accept or decline this request."}
		if action == "decline_trade":
			var result := Ledger.close_trade(state,args.trade_id)
			return _outcome(args.trade_id,"Declined the TEST trade request.",result)
		trade.status = "accepted"
		return _outcome(args.trade_id,"Accepted TEST trade. Each side must save and lock its own offer.",{"trade_id":args.trade_id,"status":"accepted"})
	if action == "cancel_trade":
		var result := Ledger.close_trade(state,args.trade_id)
		if result.has("error"): return result
		return _outcome(args.trade_id,"Cancelled TEST trade; reserved items are in Claims and DEMO DM is refunded.",result)
	if trade.status != "accepted": return {"error":"The other synthetic actor must accept this request before offers can change."}
	if action == "set_offer":
		for row: Dictionary in args.assets:
			if not state.assets.has(row.asset_id): return {"error":"An offered TEST item is unavailable."}
			var asset: Dictionary = state.assets[row.asset_id]
			if asset.owner_actor != actor or not Eligibility.asset_error(asset).is_empty() \
					or row.quantity > asset.quantity or not (asset.custody.kind == "inventory" \
					or (asset.custody.kind == "trade" and asset.custody.ref == args.trade_id)):
				return {"error":"Offer only this synthetic actor's eligible carried items or its existing trade escrow."}
		var error := Ledger.replace_offer(state,args.trade_id,actor,args.dm,args.assets)
		if not error.is_empty(): return {"error":error}
		return _outcome(args.trade_id,"Saved TEST offer; both locks and final approvals are cleared.",{"trade_id":args.trade_id,"status":"accepted","offer_revision":trade.offer_revision})
	if action == "lock_trade":
		if trade.locks[actor]: return {"error":"This TEST offer is already locked."}
		trade.locks[actor] = true
		return _outcome(args.trade_id,"Locked this synthetic actor's TEST offer. Final approval remains separate.",{"trade_id":args.trade_id,"status":"locked","offer_revision":trade.offer_revision})
	if action == "settle_trade":
		if not trade.locks.demo_a or not trade.locks.demo_b or trade.offer_revision != args.offer_revision \
				or _trade_digest(state,trade) != args.terms_digest: return {"error":"Both current TEST offers must be locked and freshly reviewed."}
		if _trade_empty(trade): return {"error":"An empty TEST trade cannot settle."}
		var result := Ledger.settle_trade(state,args.trade_id)
		if result.has("error"): return result
		return _outcome(args.trade_id,"Settled TEST trade atomically between the two synthetic inventories.",result)
	return {"error":"This TEST trade action is unavailable."}

static func _advance_time(state: Dictionary, seconds: int) -> Dictionary:
	if int(state.clock) > State.MAX_COUNT-seconds: return {"error":"The TEST clock limit has been reached."}
	var previous: int = state.clock
	state.clock += seconds
	var expired: Array[String] = []
	var order_ids: Array = state.orders.keys()
	order_ids.sort()
	for id: String in order_ids:
		if int(state.orders[id].expires_at) <= int(state.clock):
			var result := Ledger.close_order(state,id)
			if result.has("error"): return result
			expired.append(id)
	var expired_trade := ""
	for id: String in state.trades.keys():
		if int(state.trades[id].expires_at) <= int(state.clock):
			var result := Ledger.close_trade(state,id)
			if result.has("error"): return result
			expired_trade = id
	return _outcome("","Advanced the controlled TEST clock by %d seconds; expired reserves were returned." % seconds,
		{"from_clock":previous,"to_clock":state.clock,"expired_order_ids":expired,"expired_trade_id":expired_trade})

static func _reset_plan(state: Dictionary, command: Dictionary, fingerprint: String) -> Dictionary:
	if state.epoch >= State.MAX_COUNT: return _failure("The TEST epoch limit has been reached; preserve/export this state.")
	var next := State.initial_state(state.namespace,state.fixture_id,int(state.epoch)+1)
	var outcome := _outcome("","Reset only the local TEST exchange to its synthetic fixture; prior TEST contents were discarded.",
		{"old_epoch":state.epoch,"new_epoch":next.epoch})
	var receipt := _receipt(state,next,command,outcome)
	next.last_reset = {"actor_id":command.actor_id,"sequence":command.sequence,"payload_digest":fingerprint,"receipt":receipt.duplicate(true)}
	if normalize(next).is_empty(): return _failure("The reset fixture failed TEST state validation.")
	return {"ok":true,"status":"planned","error":"","candidate":next,"receipt":receipt,"review":_review(state,next,command,outcome)}

static func _receipt(before: Dictionary, next: Dictionary, command: Dictionary, outcome: Dictionary) -> Dictionary:
	return {"id":State.receipt_id(before.namespace,before.epoch,command.actor_id,command.sequence),
		"request_epoch":before.epoch,"committed_epoch":next.epoch,"revision":next.revision,
		"actor_id":command.actor_id,"sequence":command.sequence,"action":command.action,
		"status":"committed","entity_id":outcome.entity_id,"result":outcome.result.duplicate(true)}

static func _outcome(id: String, summary: String, result: Dictionary, sales: Array = []) -> Dictionary:
	return {"entity_id":id,"summary":summary,"result":result,"sales":sales}

static func _sale_terms(action: String, source_id: String, buy_id: String, sell_id: String,
		buyer: String, seller: String, variant: Dictionary, quantity: int, price: int) -> Dictionary:
	return {"source_action":action,"source_order_id":source_id,"buy_order_id":buy_id,"sell_order_id":sell_id,
		"item_id":variant.item_id,"variant":variant.duplicate(true),"variant_key":Eligibility.variant_key(variant),
		"quantity":quantity,"unit_price":price,"buyer_actor":buyer,"seller_actor":seller}

static func _append_sales(state: Dictionary, command: Dictionary, receipt: Dictionary, executions: Array) -> void:
	for index in range(executions.size()):
		var sale: Dictionary = executions[index].duplicate(true)
		sale.merge({"id":receipt.id+":fill:"+str(index),"receipt_id":receipt.id,"command_actor":command.actor_id,
			"command_sequence":command.sequence,"revision":state.revision,"fill_index":index,"clock":state.clock})
		state.sales.append(sale)
	while state.sales.size() > State.MAX_SALES: state.sales.pop_front()

static func _failure(error: String, status: String = "rejected") -> Dictionary:
	return {"ok":false,"status":status,"error":error,"candidate":{},"receipt":{},"review":{}}

static func _duplicate(stored: Dictionary, fingerprint: String) -> Dictionary:
	if stored.payload_digest != fingerprint: return _failure("That TEST command key was already used for different terms.","request_conflict")
	return {"ok":true,"status":"replayed","error":"","candidate":{},"receipt":stored.receipt.duplicate(true),"review":{}}

static func _review(before: Dictionary, next: Dictionary, command: Dictionary, outcome: Dictionary) -> Dictionary:
	var actor: String = command.actor_id
	var lines: Array[String] = [outcome.summary]
	for id: String in ACTORS:
		if before.actors[id].wallet_dm != next.actors[id].wallet_dm:
			lines.append("%s wallet: %d → %d DEMO DM" % [_actor_label(id),before.actors[id].wallet_dm,next.actors[id].wallet_dm])
	return {"action":command.action,"actor_id":actor,"title":"Review TEST " + String(command.action).replace("_"," "),
		"summary":outcome.summary,"lines":lines,"result":outcome.result.duplicate(true),
		"wallet_before":before.actors[actor].wallet_dm,"wallet_after":next.actors[actor].wallet_dm,
		"inventory_slots_before":State.inventory_count(before,actor),"inventory_slots_after":State.inventory_count(next,actor),
		"claim_slots_before":State.claim_count(before,actor),"claim_slots_after":State.claim_count(next,actor)}

static func snapshot(value: Dictionary, actor_id: String) -> Dictionary:
	var state := normalize(value)
	if state.is_empty() or not ACTORS.has(actor_id): return {}
	var inventory: Array = []
	var ids: Array = state.assets.keys()
	ids.sort()
	for id: String in ids:
		var asset: Dictionary = state.assets[id]
		if asset.owner_actor == actor_id and asset.custody.kind == "inventory": inventory.append(_asset_row(asset))
	var claims: Array = []
	ids = state.claims.keys()
	ids.sort()
	for id: String in ids:
		var claim: Dictionary = state.claims[id]
		if claim.actor_id != actor_id: continue
		var row := claim.duplicate(true)
		row.claim_id = id
		row.asset = _asset_row(state.assets[claim.asset_id]) if state.assets.has(claim.asset_id) else {}
		row.quantity = int(row.asset.get("quantity",0))
		row.label = row.asset.get("label","Reserved TEST " + claim.purpose + " slot")
		claims.append(row)
	var actors: Array = []
	for id: String in ACTORS: actors.append({"id":id,"label":_actor_label(id),"wallet_dm":state.actors[id].wallet_dm})
	var trade: Dictionary = {}
	if not state.trades.is_empty():
		trade = state.trades.values()[0].duplicate(true)
		trade.review = _trade_review(state,trade.id)
	return {"demo":true,"label":"DEMO / NOT LIVE","namespace":state.namespace,"epoch":state.epoch,
		"revision":state.revision,"clock":state.clock,"actor_id":actor_id,"actors":actors,"inventory":inventory,
		"orders":_query_orders(state,{}),"claims":claims,"trade":trade,"history":state.history.duplicate(true),
		"sales":_sales_history(state),"price_history":_price_history(state,""),
		"limits":{"inventory_slots":State.CAPACITY,"claim_slots":State.MAX_CLAIMS,"transfer_slots":State.TRANSFER_CAP,
			"open_orders":State.MAX_ORDERS,"offer_rows":State.MAX_OFFER_ROWS,"unit_price":State.MAX_PRICE,
			"quantity":999,"time_step":State.MAX_TIME_STEP,"history":State.MAX_HISTORY,"sales":State.MAX_SALES}}

static func sales_history(value: Dictionary) -> Array[Dictionary]:
	var state := normalize(value)
	return _sales_history(state) if not state.is_empty() else []

static func _sales_history(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sale: Dictionary in state.sales:
		var row := sale.duplicate(true)
		var detail := Eligibility.describe(sale.item_id)
		for key: String in ["label","category","catalog_group","rarity","icon"]: row[key] = detail[key]
		row.buyer_label = _actor_label(sale.buyer_actor)
		row.seller_label = _actor_label(sale.seller_actor)
		result.append(row)
	result.reverse()
	return result

static func price_history(value: Dictionary, variant_key: String = "") -> Array[Dictionary]:
	var state := normalize(value)
	if state.is_empty() or (not variant_key.is_empty() and not Codec.hex_digest(variant_key)): return []
	return _price_history(state,variant_key)

static func _price_history(state: Dictionary, selected: String) -> Array[Dictionary]:
	var groups := {}
	for sale: Dictionary in state.sales:
		var key: String = sale.variant_key
		if not selected.is_empty() and key != selected: continue
		if not groups.has(key):
			groups[key] = {"item_id":sale.item_id,"label":Eligibility.describe(sale.item_id).label,
				"variant":sale.variant.duplicate(true),"variant_key":key,"sale_count":0,"quantity":0,"total_dm":0,
				"min_unit_price":sale.unit_price,"max_unit_price":sale.unit_price,"last_unit_price":sale.unit_price,
				"first_clock":sale.clock,"last_clock":sale.clock}
		var group: Dictionary = groups[key]
		group.sale_count += 1
		group.quantity += int(sale.quantity)
		group.total_dm += int(sale.quantity)*int(sale.unit_price)
		group.min_unit_price = mini(group.min_unit_price,sale.unit_price)
		group.max_unit_price = maxi(group.max_unit_price,sale.unit_price)
		group.last_unit_price = sale.unit_price
		group.last_clock = sale.clock
	var result: Array[Dictionary] = []
	for group: Dictionary in groups.values(): result.append(group)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.label < b.label if a.label != b.label else a.variant_key < b.variant_key)
	return result

static func query_orders(value: Dictionary, filters: Dictionary) -> Array[Dictionary]:
	var state := normalize(value)
	return _query_orders(state,filters) if not state.is_empty() else []

static func _query_orders(state: Dictionary, filters: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: Variant in filters:
		if not key is String or key not in ["search","category","rarity","side","sort"] or not filters[key] is String: return result
	var search: String = filters.get("search","")
	var category: String = filters.get("category","")
	var rarity: String = filters.get("rarity","")
	var side: String = filters.get("side","")
	var sorting: String = filters.get("sort","oldest")
	if not Codec.text(search,64,true) or category not in ["","equipment","material","consumable","valuable"] \
			or rarity not in ["","common","uncommon","rare","epic","legendary","mythic","ancient_relic"] \
			or side not in ["","buy","sell"] or sorting not in ["price_asc","price_desc","newest","oldest"]: return result
	for order: Dictionary in state.orders.values():
		var detail := Eligibility.describe(order.variant.item_id)
		if not search.is_empty() and not (String(detail.label).to_lower().contains(search.to_lower()) or String(order.variant.item_id).contains(search.to_lower())): continue
		if not category.is_empty() and (detail.catalog_group if category == "valuable" else detail.category) != category: continue
		if not rarity.is_empty() and detail.rarity != rarity: continue
		if not side.is_empty() and side != order.side: continue
		var row := order.duplicate(true)
		row.order_id = order.id
		row.actor_label = _actor_label(order.actor_id)
		for key: String in ["label","category","catalog_group","rarity","icon"]: row[key] = detail[key]
		row.item_id = order.variant.item_id
		row.status = "open" if order.remaining_quantity == order.initial_quantity else "partial"
		result.append(row)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if sorting == "price_asc" and a.unit_price != b.unit_price: return a.unit_price < b.unit_price
		if sorting == "price_desc" and a.unit_price != b.unit_price: return a.unit_price > b.unit_price
		if a.created_sequence != b.created_sequence: return a.created_sequence > b.created_sequence if sorting == "newest" else a.created_sequence < b.created_sequence
		return String(a.order_id)<String(b.order_id))
	return result

static func trade_review(value: Dictionary, trade_id: String) -> Dictionary:
	var state := normalize(value)
	return _trade_review(state,trade_id) if not state.is_empty() else {"ok":false,"error":"Invalid TEST exchange state."}

static func _trade_review(state: Dictionary, trade_id: String) -> Dictionary:
	if not state.trades.has(trade_id): return {"ok":false,"error":"This TEST trade is unavailable."}
	var trade: Dictionary = state.trades[trade_id]
	var offers := {}
	for actor: String in ACTORS:
		var rows: Array = []
		for row: Dictionary in trade.offers[actor].assets: rows.append(_asset_row(state.assets[row.asset_id]))
		offers[actor] = {"dm":trade.offers[actor].dm,"assets":rows,"locked":trade.locks[actor]}
	var locked: bool = trade.status == "accepted" and trade.locks.demo_a and trade.locks.demo_b
	var error := ""
	if not locked: error = "Both current TEST offers must be locked."
	elif _trade_empty(trade): error = "An empty TEST trade cannot settle."
	else:
		var proposed := state.duplicate(true)
		var settled := Ledger.settle_trade(proposed,trade_id)
		error = settled.get("error","")
		if error.is_empty(): error = State.limits_error(proposed)
	return {"ok":true,"error":"","trade_id":trade_id,"offer_revision":trade.offer_revision,
		"terms_digest":_trade_digest(state,trade),"locked":locked,"offers":offers,
		"can_settle":error.is_empty(),"capacity_error":error}

static func _trade_digest(state: Dictionary, trade: Dictionary) -> String:
	var terms := {"trade_id":trade.id,"requester_actor":trade.requester_actor,"recipient_actor":trade.recipient_actor,
		"offer_revision":trade.offer_revision,"locks":trade.locks.duplicate(),"offers":{}}
	for actor: String in ACTORS:
		var assets: Array = []
		for row: Dictionary in trade.offers[actor].assets: assets.append(state.assets[row.asset_id].duplicate(true))
		terms.offers[actor] = {"dm":trade.offers[actor].dm,"assets":assets}
	return Codec.digest(terms)

static func _trade_empty(trade: Dictionary) -> bool:
	return trade.offers.demo_a.dm == 0 and trade.offers.demo_b.dm == 0 \
		and trade.offers.demo_a.assets.is_empty() and trade.offers.demo_b.assets.is_empty()

static func _asset_row(asset: Dictionary) -> Dictionary:
	var detail := Eligibility.describe(asset.variant.item_id)
	var row := {"asset_id":asset.id,"item_id":asset.variant.item_id,"quantity":asset.quantity,
		"variant":asset.variant.duplicate(true),"variant_key":Eligibility.variant_key(asset.variant),
		"protection":asset.protection.duplicate(),"custody":asset.custody.duplicate(),
		"eligible":Eligibility.asset_error(asset).is_empty(),"reason":Eligibility.asset_error(asset)}
	for key: String in ["label","category","catalog_group","rarity","icon"]: row[key] = detail[key]
	return row

static func _actor_label(actor: String) -> String:
	return "Synthetic Actor A" if actor == "demo_a" else "Synthetic Actor B"
