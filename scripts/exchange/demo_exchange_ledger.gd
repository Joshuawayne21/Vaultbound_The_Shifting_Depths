class_name VaultDemoExchangeLedger
extends RefCounted
## Private candidate-only custody operations. Errors discard the whole candidate.
const State = preload("res://scripts/exchange/demo_exchange_state.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")

static func allocate(state: Dictionary, kind: String) -> String:
	var field := "next_" + kind
	if int(state[field]) >= State.MAX_COUNT: return ""
	var id := State.make_id(state.namespace,state.epoch,kind,int(state[field]))
	state[field] += 1
	return id

static func reserve_claim(state: Dictionary, actor: String, kind: String, source: String, purpose: String) -> String:
	if State.claim_count(state,actor) >= State.MAX_CLAIMS: return ""
	var id := allocate(state,"claim")
	if id.is_empty(): return ""
	state.claims[id] = {"id":id,"actor_id":actor,"source_kind":kind,"source_id":source,
		"purpose":purpose,"asset_id":"","reserved":true}
	return id

static func release_claim(state: Dictionary, id: String) -> void:
	if not state.claims.has(id): return
	state.claims[id].reserved = false
	if String(state.claims[id].asset_id).is_empty(): state.claims.erase(id)

static func move(state: Dictionary, id: String, actor: String, kind: String, ref: String) -> void:
	state.assets[id].owner_actor = actor
	state.assets[id].custody = {"kind":kind,"ref":ref}

static func extract(state: Dictionary, id: String, quantity: int) -> String:
	if not state.assets.has(id) or quantity <= 0 or quantity > int(state.assets[id].quantity): return ""
	var asset: Dictionary = state.assets[id]
	if quantity == int(asset.quantity): return id
	if Eligibility.equipment(asset.variant): return ""
	var split := allocate(state,"asset")
	if split.is_empty(): return ""
	var part := asset.duplicate(true)
	part.id = split
	part.quantity = quantity
	asset.quantity -= quantity
	state.assets[split] = part
	return split

static func put_claim(state: Dictionary, claim_id: String, asset_id: String) -> String:
	if not state.claims.has(claim_id) or not state.assets.has(asset_id): return "The reserved TEST delivery slot is unavailable."
	var claim: Dictionary = state.claims[claim_id]
	var incoming: Dictionary = state.assets[asset_id]
	if String(claim.asset_id).is_empty():
		claim.asset_id = asset_id
		move(state,asset_id,claim.actor_id,"claim",claim_id)
		return ""
	if not state.assets.has(claim.asset_id) or claim.asset_id == asset_id: return "This delivery already occupies its claim."
	var held: Dictionary = state.assets[claim.asset_id]
	if held.variant != incoming.variant or held.protection != incoming.protection \
			or int(held.quantity) + int(incoming.quantity) > Eligibility.stack_limit(held.variant):
		return "The reserved TEST delivery lot cannot contain this variant or quantity."
	held.quantity += int(incoming.quantity)
	state.assets.erase(asset_id)
	return ""

static func inventory_fit(state: Dictionary, actor: String, asset: Dictionary) -> int:
	var limit := Eligibility.stack_limit(asset.variant)
	var result := (State.CAPACITY - State.inventory_count(state,actor)) * limit
	if limit > 1:
		for held: Dictionary in state.assets.values():
			if held.owner_actor == actor and held.custody.kind == "inventory" \
					and held.variant == asset.variant and held.protection == asset.protection:
				result += limit - int(held.quantity)
	return maxi(0,result)

static func put_inventory(state: Dictionary, actor: String, asset_id: String) -> String:
	if not state.assets.has(asset_id): return "The TEST asset is unavailable."
	var incoming: Dictionary = state.assets[asset_id]
	if inventory_fit(state,actor,incoming) < int(incoming.quantity): return "The recipient's forty TEST inventory slots cannot hold the full delivery."
	var limit := Eligibility.stack_limit(incoming.variant)
	if limit > 1:
		var ids: Array = state.assets.keys()
		ids.sort()
		for id: String in ids:
			if id == asset_id: continue
			var held: Dictionary = state.assets[id]
			if held.owner_actor != actor or held.custody.kind != "inventory" \
					or held.variant != incoming.variant or held.protection != incoming.protection: continue
			var amount := mini(int(incoming.quantity),limit-int(held.quantity))
			held.quantity += amount
			incoming.quantity -= amount
			if incoming.quantity == 0:
				state.assets.erase(asset_id)
				return ""
	if State.inventory_count(state,actor) >= State.CAPACITY: return "The recipient's forty TEST inventory slots are full."
	move(state,asset_id,actor,"inventory",actor)
	return ""

static func close_order(state: Dictionary, id: String) -> Dictionary:
	if not state.orders.has(id): return {"error":"This TEST order is closed or unavailable."}
	var order: Dictionary = state.orders[id]
	var result := {"order_id":id,"returned_asset_id":"","returned_quantity":0,"dm_refund":0,"claim_id":""}
	if order.side == "sell" and state.assets.has(order.escrow_asset_id):
		result.returned_asset_id = order.escrow_asset_id
		result.returned_quantity = int(state.assets[order.escrow_asset_id].quantity)
		result.claim_id = order.claim_id
		var error := put_claim(state,order.claim_id,order.escrow_asset_id)
		if not error.is_empty(): return {"error":error}
	elif order.side == "buy":
		result.dm_refund = int(order.escrow_dm)
		state.actors[order.actor_id].wallet_dm += int(order.escrow_dm)
	release_claim(state,order.claim_id)
	state.orders.erase(id)
	return result

static func finish_filled_order(state: Dictionary, id: String) -> void:
	if not state.orders.has(id) or int(state.orders[id].remaining_quantity) != 0: return
	var order: Dictionary = state.orders[id]
	# Filled sell lots have already left escrow; filled buy reserves are zero.
	release_claim(state,order.claim_id)
	state.orders.erase(id)

static func close_trade(state: Dictionary, id: String) -> Dictionary:
	if not state.trades.has(id): return {"error":"This TEST trade is closed or unavailable."}
	var trade: Dictionary = state.trades[id]
	var ids: Array[String] = []
	var result := {"trade_id":id,"returned_asset_ids":ids,"dm_a_refund":0,"dm_b_refund":0}
	for actor: String in State.ACTORS:
		var offer: Dictionary = trade.offers[actor]
		for row: Dictionary in offer.assets:
			var error := put_claim(state,row.return_claim_id,row.asset_id)
			if not error.is_empty(): return {"error":error}
			ids.append(row.asset_id)
			release_claim(state,row.return_claim_id)
		state.actors[actor].wallet_dm += int(offer.dm)
		result["dm_a_refund" if actor == "demo_a" else "dm_b_refund"] = int(offer.dm)
	state.trades.erase(id)
	return result

static func match_fill(state: Dictionary, sell_id: String, buy_id: String, quantity: int, price: int) -> Dictionary:
	var sell: Dictionary = state.orders[sell_id]
	var buy: Dictionary = state.orders[buy_id]
	if sell.actor_id == buy.actor_id or sell.variant_key != buy.variant_key or quantity <= 0 \
			or quantity > mini(sell.remaining_quantity,buy.remaining_quantity) \
			or price < int(sell.unit_price) or price > int(buy.unit_price): return {"error":"Incompatible TEST order fill."}
	var delivery := extract(state,sell.escrow_asset_id,quantity)
	if delivery.is_empty(): return {"error":"The TEST lot identity limit prevents this split; the existing escrow is preserved."}
	var error := put_claim(state,buy.claim_id,delivery)
	if not error.is_empty(): return {"error":error}
	var reserved := quantity * int(buy.unit_price)
	var payment := quantity * price
	buy.escrow_dm -= reserved
	state.actors[buy.actor_id].wallet_dm += reserved-payment
	state.actors[sell.actor_id].wallet_dm += payment
	buy.remaining_quantity -= quantity
	sell.remaining_quantity -= quantity
	finish_filled_order(state,sell_id)
	finish_filled_order(state,buy_id)
	return {"quantity":quantity,"unit_price":price,"dm_paid":payment,"dm_refund":reserved-payment}

static func delivery_claim(state: Dictionary, actor: String, order_id: String, variant: Dictionary, quantity: int) -> String:
	# A direct buyer may reuse a visible unreserved same-order delivery lot.
	var ids: Array = state.claims.keys()
	ids.sort()
	for id: String in ids:
		var claim: Dictionary = state.claims[id]
		if claim.actor_id != actor or claim.source_kind != "order" or claim.source_id != order_id \
				or claim.purpose != "delivery" or claim.reserved or not state.assets.has(claim.asset_id): continue
		var held: Dictionary = state.assets[claim.asset_id]
		if held.variant == variant and int(held.quantity)+quantity <= Eligibility.stack_limit(variant): return id
	return reserve_claim(state,actor,"order",order_id,"delivery")

static func replace_offer(state: Dictionary, trade_id: String, actor: String, dm: int, requested: Array) -> String:
	var trade: Dictionary = state.trades[trade_id]
	var offer: Dictionary = trade.offers[actor]
	if dm > int(state.actors[actor].wallet_dm) + int(offer.dm): return "This synthetic actor cannot reserve that many DEMO DM."
	var wanted := {}
	for row: Dictionary in requested: wanted[row.asset_id] = int(row.quantity)
	var retained: Array = []
	for row: Dictionary in offer.assets:
		var asset: Dictionary = state.assets[row.asset_id]
		var keep: int = wanted.get(row.asset_id,0)
		if keep == 0:
			var error := put_claim(state,row.return_claim_id,row.asset_id)
			if not error.is_empty(): return error
			release_claim(state,row.return_claim_id)
		else:
			if keep < int(asset.quantity):
				var claim := reserve_claim(state,actor,"trade",trade_id,"return")
				if claim.is_empty(): return "This offer edit needs another return slot; cancel the unchanged offer to use its existing reservations."
				var returned := extract(state,row.asset_id,int(asset.quantity)-keep)
				if returned.is_empty(): return "The TEST asset identity limit prevents this offer split."
				var error := put_claim(state,claim,returned)
				if not error.is_empty(): return error
				release_claim(state,claim)
			retained.append(row.duplicate())
			wanted.erase(row.asset_id)
	for source_id: String in wanted:
		var claim := reserve_claim(state,actor,"trade",trade_id,"return")
		if claim.is_empty(): return "This offer needs a free reserved return slot."
		var asset_id := extract(state,source_id,wanted[source_id])
		if asset_id.is_empty(): return "The TEST asset identity limit prevents this offer split."
		move(state,asset_id,actor,"trade",trade_id)
		retained.append({"asset_id":asset_id,"return_claim_id":claim})
	retained.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.asset_id)<String(b.asset_id))
	state.actors[actor].wallet_dm += int(offer.dm)-dm
	offer.dm = dm
	offer.assets = retained
	trade.offer_revision += 1
	trade.locks = {"demo_a":false,"demo_b":false}
	return ""

static func settle_trade(state: Dictionary, id: String) -> Dictionary:
	var trade: Dictionary = state.trades[id]
	var transferred: Array[String] = []
	# All outgoing reserves already left inventories. Release only this trade's
	# return reservations before testing the complete candidate's transfer space.
	for actor: String in State.ACTORS:
		for row: Dictionary in trade.offers[actor].assets: release_claim(state,row.return_claim_id)
	for actor: String in State.ACTORS:
		var recipient := "demo_b" if actor == "demo_a" else "demo_a"
		for row: Dictionary in trade.offers[actor].assets:
			var error := put_inventory(state,recipient,row.asset_id)
			if not error.is_empty(): return {"error":error}
			transferred.append(row.asset_id)
		state.actors[recipient].wallet_dm += int(trade.offers[actor].dm)
	var result := {"trade_id":id,"transferred_asset_ids":transferred,
		"dm_a_to_b":int(trade.offers.demo_a.dm),"dm_b_to_a":int(trade.offers.demo_b.dm)}
	state.trades.erase(id)
	return result
