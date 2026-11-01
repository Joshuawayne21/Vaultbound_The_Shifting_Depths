class_name VaultDemoExchangeState
extends RefCounted
## Closed schema and complete custody/supply validation for the synthetic realm.
const Codec = preload("res://scripts/exchange/demo_exchange_codec.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const ACTORS := ["demo_a", "demo_b"]
const MAGIC := "vaultbound_demo_exchange"
const VERSION := 1
const FIXTURE := "ring_exchange_v1"
const MAX_COUNT := 2147483647
const CAPACITY := 40
const MAX_CLAIMS := 64
const TRANSFER_CAP := 103
const MAX_ASSETS := 208
const MAX_ORDERS := 16
const MAX_OFFER_ROWS := 8
const MAX_RECEIPTS := 64
const MAX_HISTORY := 128
const MAX_SALES := 128
const MAX_PRICE := 1000000
const MAX_TIME_STEP := 86400
const INITIAL_DM := 20000
const ACTIONS := ["create_order","fill_order","cancel_order","claim","request_trade",
	"accept_trade","decline_trade","set_offer","lock_trade","cancel_trade","advance_time","reset_demo","settle_trade"]
const STATE_KEYS := ["magic","version","namespace","epoch","revision","fixture_id","clock",
	"next_asset","next_order","next_trade","next_claim","actors","assets","orders","trades","claims",
	"command_heads","recent_receipts","history","last_reset","sales"]
const CLAIM_KEYS := ["id","actor_id","source_kind","source_id","purpose","asset_id","reserved"]

static func initial_state(space: String, fixture_id: String = FIXTURE, epoch: int = 1) -> Dictionary:
	if not Codec.hex_digest(space, 32) or fixture_id != FIXTURE or not Codec.integer(epoch, 1): return {}
	return {"magic":MAGIC,"version":VERSION,"namespace":space,"epoch":epoch,"revision":0,
		"fixture_id":FIXTURE,"clock":0,"next_asset":25,"next_order":1,"next_trade":1,"next_claim":1,
		"actors":{"demo_a":{"wallet_dm":10000},"demo_b":{"wallet_dm":10000}},
		"assets":fixture_assets(space,epoch),"orders":{},"trades":{},"claims":{},
		"command_heads":{"demo_a":0,"demo_b":0},"recent_receipts":[],"history":[],"last_reset":{},"sales":[]}

static func fixture_assets(space: String, epoch: int) -> Dictionary:
	var result := {}
	var rows := [["traveler_sword",1],["apprentice_staff",1],["iron_helm",1],["round_shield",1],
		["runic_staff",1],["iron_ore",30],["root_fiber",20],["common_enhancement_stone",12],
		["mooncap_tonic",5],["stamina_draught",5],["mossworn_obol",10],["smoky_quartz_shard",5]]
	var sequence := 1
	for actor: String in ACTORS:
		for row: Array in rows:
			var variant := Eligibility.base_variant(row[0])
			if variant.is_empty(): return {}
			if row[0] == "traveler_sword" and actor == "demo_b":
				variant.enhancement = 1
				variant.durability = 75
				variant.modifier_units = {"damage_bonus":10000}
			if row[0] == "iron_helm" and actor == "demo_b": variant.durability = 80
			if row[0] == "runic_staff":
				variant.enhancement = 1 if actor == "demo_a" else 0
				variant.modifier_units = {"damage_bonus":10000 if actor == "demo_a" else 20000}
			var id := make_id(space,epoch,"asset",sequence)
			result[id] = {"id":id,"quantity":int(row[1]),"variant":variant,
				"protection":{"locked":false,"favorite":false,"equipped":false,"displayed":false},
				"owner_actor":actor,"custody":{"kind":"inventory","ref":actor}}
			sequence += 1
	return result

static func make_id(space: String, epoch: int, kind: String, sequence: int) -> String:
	return "demo:%s:%d:%s:%d" % [space,epoch,kind,sequence]

static func id_valid(state: Dictionary, id: Variant, kind: String) -> bool:
	if not id is String: return false
	var parts: PackedStringArray = id.split(":")
	if parts.size() != 5 or parts[0] != "demo" or parts[1] != state.namespace \
			or parts[2] != str(state.epoch) or parts[3] != kind or not parts[4].is_valid_int(): return false
	var sequence := int(parts[4])
	return sequence > 0 and sequence < int(state["next_" + kind]) and parts[4] == str(sequence)

static func inventory_count(state: Dictionary, actor: String) -> int:
	var count := 0
	for asset: Dictionary in state.assets.values():
		if asset.owner_actor == actor and asset.custody.kind == "inventory": count += 1
	return count

static func claim_count(state: Dictionary, actor: String) -> int:
	var count := 0
	for claim: Dictionary in state.claims.values():
		if claim.actor_id == actor: count += 1
	return count

static func order_count(state: Dictionary, actor: String) -> int:
	var count := 0
	for order: Dictionary in state.orders.values():
		if order.actor_id == actor: count += 1
	return count

static func limits_error(state: Dictionary) -> String:
	if state.assets.size() > MAX_ASSETS or state.trades.size() > 1: return "The TEST asset/trade limit was reached."
	for actor: String in ACTORS:
		var carried := inventory_count(state,actor)
		var claims := claim_count(state,actor)
		if carried > CAPACITY: return "The recipient's forty TEST inventory slots are full."
		if claims > MAX_CLAIMS: return "The sixty-four TEST claim slots are occupied or reserved."
		if carried + claims > TRANSFER_CAP:
			return "Keep one transfer space: claim a full lot or offer a whole carried lot before splitting more items."
		if order_count(state,actor) > MAX_ORDERS: return "This actor already has sixteen open TEST orders."
	var debt: int = state.orders.size() + state.trades.size() + state.claims.size() + 1
	if MAX_COUNT - int(state.revision) < debt: return "The TEST revision limit preserves remaining cancellation and claim operations."
	return ""

static func normalize(value: Variant) -> Dictionary:
	var state: Variant = Codec.integer_tree(value)
	if not Codec.keys(state, STATE_KEYS) or not Codec.strings(state,["magic","fixture_id"]) \
			or not Codec.integer(state.version,VERSION,VERSION) or state.magic != MAGIC \
			or state.fixture_id != FIXTURE or not Codec.hex_digest(state.namespace,32): return {}
	for key: String in ["epoch","next_asset","next_order","next_trade","next_claim"]:
		if not Codec.integer(state[key],1): return {}
	for key: String in ["revision","clock"]:
		if not Codec.integer(state[key]): return {}
	if not Codec.keys(state.actors,ACTORS) or not Codec.keys(state.command_heads,ACTORS): return {}
	var money := 0
	var heads := 0
	for actor: String in ACTORS:
		if not Codec.keys(state.actors[actor],["wallet_dm"]) \
				or not Codec.integer(state.actors[actor].wallet_dm) or not Codec.integer(state.command_heads[actor]): return {}
		money += int(state.actors[actor].wallet_dm)
		heads += int(state.command_heads[actor])
	if heads != state.revision: return {}
	for key: String in ["assets","orders","trades","claims","last_reset"]:
		if not state[key] is Dictionary: return {}
	if state.assets.size() > MAX_ASSETS or state.orders.size() > MAX_ORDERS * 2 \
			or state.trades.size() > 1 or state.claims.size() > MAX_CLAIMS * 2: return {}
	var fixture := fixture_assets(state.namespace,state.epoch)
	if fixture.size() != 24: return {}
	var expected_supply := _supply(fixture)
	var actual_supply := {}
	var referenced := {}
	var reserved := {}
	for id: Variant in state.assets:
		var asset: Variant = state.assets[id]
		if not id_valid(state,id,"asset") or not Codec.keys(asset,["id","quantity","variant","protection","owner_actor","custody"]) \
				or not Codec.text(asset.id,160) or asset.id != id or not ACTORS.has(asset.owner_actor): return {}
		var variant := Eligibility.normalize_variant(asset.variant)
		if variant.is_empty() or variant != asset.variant or not Codec.integer(asset.quantity,1,Eligibility.stack_limit(variant)): return {}
		if not Codec.keys(asset.protection,["locked","favorite","equipped","displayed"]): return {}
		for flag: String in asset.protection:
			if not asset.protection[flag] is bool: return {}
		if not Codec.keys(asset.custody,["kind","ref"]) or not asset.custody.kind is String \
				or not asset.custody.ref is String or asset.custody.kind not in ["inventory","order","trade","claim"]: return {}
		if asset.custody.kind == "inventory" and asset.custody.ref != asset.owner_actor: return {}
		if asset.custody.kind != "inventory" and not Eligibility.asset_error(asset).is_empty(): return {}
		if Eligibility.equipment(variant) and (not fixture.has(id) or fixture[id].variant != variant): return {}
		var key := Eligibility.variant_key(variant)
		actual_supply[key] = int(actual_supply.get(key,0)) + int(asset.quantity)
	if actual_supply != expected_supply: return {}
	for id: Variant in state.orders:
		var order: Variant = state.orders[id]
		if not id_valid(state,id,"order") or not Codec.keys(order,["id","actor_id","side","variant","variant_key",
				"unit_price","initial_quantity","remaining_quantity","created_sequence","expires_at","escrow_asset_id","escrow_dm","claim_id"]): return {}
		if not Codec.strings(order,["id","actor_id","side","variant_key","escrow_asset_id","claim_id"]) \
				or order.id != id or not ACTORS.has(order.actor_id) or order.side not in ["buy","sell"]: return {}
		var variant := Eligibility.normalize_variant(order.variant)
		if variant.is_empty() or not variant.identified or Eligibility.variant_key(variant) != order.variant_key \
				or not Codec.integer(order.unit_price,1,MAX_PRICE) or not Codec.integer(order.initial_quantity,1,Eligibility.stack_limit(variant)) \
				or not Codec.integer(order.remaining_quantity,1,order.initial_quantity) \
				or not Codec.integer(order.created_sequence,1) or order.created_sequence != int(String(id).get_slice(":",4)) \
				or not Codec.integer(order.expires_at,int(state.clock)+1) or not Codec.integer(order.escrow_dm) \
				or not order.escrow_asset_id is String or not state.claims.has(order.claim_id): return {}
		var claim: Variant = state.claims[order.claim_id]
		if not _claim_shape(state,order.claim_id,claim) or claim.actor_id != order.actor_id or claim.source_kind != "order" \
				or claim.source_id != id or not claim.reserved: return {}
		reserved[order.claim_id] = int(reserved.get(order.claim_id,0)) + 1
		if order.side == "sell":
			if order.escrow_dm != 0 or claim.get("purpose") != "return" or claim.get("asset_id") != "" \
					or not _reference(state,referenced,order.escrow_asset_id,order.actor_id,"order",id): return {}
			var asset: Dictionary = state.assets[order.escrow_asset_id]
			if asset.variant != order.variant or asset.quantity != order.remaining_quantity: return {}
		else:
			if not order.escrow_asset_id.is_empty() or claim.get("purpose") != "delivery" \
					or int(order.escrow_dm) != int(order.remaining_quantity) * int(order.unit_price): return {}
			money += int(order.escrow_dm)
	for id: Variant in state.trades:
		var trade: Variant = state.trades[id]
		if not id_valid(state,id,"trade") or not Codec.keys(trade,["id","requester_actor","recipient_actor","status",
				"offer_revision","expires_at","offers","locks"]): return {}
		if not Codec.strings(trade,["id","requester_actor","recipient_actor","status"]) \
				or trade.id != id or not ACTORS.has(trade.requester_actor) or not ACTORS.has(trade.recipient_actor) \
				or trade.requester_actor == trade.recipient_actor or trade.status not in ["requested","accepted"] \
				or not Codec.integer(trade.offer_revision) or not Codec.integer(trade.expires_at,int(state.clock)+1) \
				or not Codec.keys(trade.offers,ACTORS) or not Codec.keys(trade.locks,ACTORS): return {}
		for actor: String in ACTORS:
			var offer: Variant = trade.offers[actor]
			if not Codec.keys(offer,["dm","assets"]) or not Codec.integer(offer.dm) or not offer.assets is Array \
					or offer.assets.size() > MAX_OFFER_ROWS or not trade.locks[actor] is bool: return {}
			money += int(offer.dm)
			if trade.status == "requested" and (offer.dm != 0 or not offer.assets.is_empty() or trade.locks[actor]): return {}
			for row: Variant in offer.assets:
				if not Codec.keys(row,["asset_id","return_claim_id"]) \
						or not _reference(state,referenced,row.asset_id,actor,"trade",id) or not state.claims.has(row.return_claim_id): return {}
				var claim: Variant = state.claims[row.return_claim_id]
				if not _claim_shape(state,row.return_claim_id,claim) or claim.actor_id != actor or claim.source_kind != "trade" \
						or claim.source_id != id or claim.purpose != "return" or not claim.reserved or claim.asset_id != "": return {}
				reserved[row.return_claim_id] = int(reserved.get(row.return_claim_id,0)) + 1
	if money != INITIAL_DM: return {}
	for id: Variant in state.claims:
		var claim: Variant = state.claims[id]
		if not _claim_shape(state,id,claim): return {}
		if claim.reserved != (int(reserved.get(id,0)) == 1) or int(reserved.get(id,0)) > 1: return {}
		if claim.asset_id.is_empty():
			if not claim.reserved: return {}
		elif not _reference(state,referenced,claim.asset_id,claim.actor_id,"claim",id): return {}
	for id: String in state.assets:
		var expected := 0 if state.assets[id].custody.kind == "inventory" else 1
		if int(referenced.get(id,0)) != expected: return {}
	if not limits_error(state).is_empty() or not _history_valid(state) or not _sales_valid(state,expected_supply): return {}
	return state.duplicate(true)

static func _claim_shape(state: Dictionary, id: Variant, claim: Variant) -> bool:
	return id_valid(state,id,"claim") and Codec.keys(claim,CLAIM_KEYS) \
		and Codec.strings(claim,["id","actor_id","source_kind","source_id","purpose","asset_id"]) \
		and claim.id == id and ACTORS.has(claim.actor_id) and claim.source_kind in ["order","trade"] \
		and id_valid(state,claim.source_id,claim.source_kind) and claim.purpose in ["delivery","return"] and claim.reserved is bool

static func _reference(state: Dictionary, references: Dictionary, id: Variant, actor: String, kind: String, ref: String) -> bool:
	if not id is String or not state.assets.has(id): return false
	var asset: Dictionary = state.assets[id]
	if asset.owner_actor != actor or asset.custody != {"kind":kind,"ref":ref}: return false
	references[id] = int(references.get(id,0)) + 1
	return references[id] == 1

static func _supply(assets: Dictionary) -> Dictionary:
	var result := {}
	for asset: Dictionary in assets.values():
		var key := Eligibility.variant_key(asset.variant)
		result[key] = int(result.get(key,0)) + int(asset.quantity)
	return result

static func _history_valid(state: Dictionary) -> bool:
	if not state.recent_receipts is Array or state.recent_receipts.size() != mini(state.revision,MAX_RECEIPTS) \
			or not state.history is Array or state.history.size() != mini(state.revision,MAX_HISTORY): return false
	var revision: int = state.revision - state.recent_receipts.size() + 1
	var seen := {}
	var observed_heads := {}
	for stored: Variant in state.recent_receipts:
		if not receipt_valid(state,stored,false) or stored.receipt.revision != revision \
				or stored.sequence > state.command_heads[stored.actor_id]: return false
		var key := str(stored.actor_id) + ":" + str(stored.sequence)
		if seen.has(key): return false
		if observed_heads.has(stored.actor_id) and int(stored.sequence) != int(observed_heads[stored.actor_id])+1: return false
		seen[key] = true
		observed_heads[stored.actor_id] = int(stored.sequence)
		revision += 1
	for actor: String in observed_heads:
		if observed_heads[actor] != state.command_heads[actor]: return false
	revision = state.revision - state.history.size() + 1
	for row: Variant in state.history:
		if not Codec.keys(row,["epoch","revision","actor_id","action","entity_id","summary","clock"]) \
				or not Codec.integer(row.epoch,1) or not Codec.integer(row.revision,1) \
				or not Codec.strings(row,["actor_id","action","entity_id","summary"]) \
				or row.epoch != state.epoch or row.revision != revision or not ACTORS.has(row.actor_id) \
				or not ACTIONS.has(row.action) or not Codec.text(row.entity_id,160,true) \
				or not Codec.text(row.summary,240) or not Codec.integer(row.clock,0,state.clock): return false
		revision += 1
	if state.epoch == 1: return state.last_reset.is_empty()
	return receipt_valid(state,state.last_reset,true)

static func receipt_valid(state: Dictionary, stored: Variant, reset: bool) -> bool:
	if not Codec.keys(stored,["actor_id","sequence","payload_digest","receipt"]) \
			or not ACTORS.has(stored.actor_id) or not Codec.integer(stored.sequence,1) \
			or not Codec.hex_digest(stored.payload_digest): return false
	var receipt: Variant = stored.receipt
	if not Codec.keys(receipt,["id","request_epoch","committed_epoch","revision","actor_id","sequence","action","status","entity_id","result"]): return false
	if not Codec.strings(receipt,["id","actor_id","action","status","entity_id"]) \
			or not Codec.integer(receipt.request_epoch,1) or not Codec.integer(receipt.committed_epoch,1) \
			or not Codec.integer(receipt.sequence,1): return false
	var request_epoch: int = state.epoch - 1 if reset else state.epoch
	if receipt.id != receipt_id(state.namespace,request_epoch,stored.actor_id,stored.sequence) \
			or receipt.actor_id != stored.actor_id or receipt.sequence != stored.sequence \
			or receipt.request_epoch != request_epoch or receipt.committed_epoch != state.epoch \
			or not Codec.integer(receipt.revision,0,state.revision) or receipt.status != "committed" \
			or not ACTIONS.has(receipt.action) or not Codec.text(receipt.entity_id,160,true) \
			or not receipt.result is Dictionary: return false
	if reset and (receipt.action != "reset_demo" or receipt.revision != 0): return false
	if not reset and (receipt.action == "reset_demo" or receipt.revision == 0): return false
	return _result_valid(state,receipt.action,receipt.result,receipt.entity_id)

static func _result_valid(state: Dictionary, action: String, result: Dictionary, entity_id: String) -> bool:
	var expected: Array = []
	var numbers: Array = []
	var entity_field := ""
	var entity_kind := ""
	match action:
		"create_order":
			expected = ["order_id","remaining_quantity","filled_quantity","fills","dm_paid","dm_received","dm_refund"]
			numbers = ["remaining_quantity","filled_quantity","dm_paid","dm_received","dm_refund"]
			entity_field = "order_id"
			entity_kind = "order"
		"fill_order":
			expected = ["order_id","filled_quantity","remaining_quantity","unit_price","dm_amount","claim_id"]
			numbers = ["filled_quantity","remaining_quantity","unit_price","dm_amount"]
			entity_field = "order_id"
			entity_kind = "order"
		"cancel_order":
			expected = ["order_id","returned_asset_id","returned_quantity","dm_refund","claim_id"]
			numbers = ["returned_quantity","dm_refund"]
			entity_field = "order_id"
			entity_kind = "order"
		"claim":
			expected = ["claim_id","requested_quantity","claimed_quantity","remaining_quantity"]
			numbers = ["requested_quantity","claimed_quantity","remaining_quantity"]
			entity_field = "claim_id"
			entity_kind = "claim"
		"request_trade","accept_trade":
			expected = ["trade_id","status"]
			entity_field = "trade_id"
			entity_kind = "trade"
		"set_offer","lock_trade":
			expected = ["trade_id","status","offer_revision"]
			numbers = ["offer_revision"]
			entity_field = "trade_id"
			entity_kind = "trade"
		"decline_trade","cancel_trade":
			expected = ["trade_id","returned_asset_ids","dm_a_refund","dm_b_refund"]
			numbers = ["dm_a_refund","dm_b_refund"]
			entity_field = "trade_id"
			entity_kind = "trade"
		"settle_trade":
			expected = ["trade_id","transferred_asset_ids","dm_a_to_b","dm_b_to_a"]
			numbers = ["dm_a_to_b","dm_b_to_a"]
			entity_field = "trade_id"
			entity_kind = "trade"
		"advance_time":
			expected = ["from_clock","to_clock","expired_order_ids","expired_trade_id"]
			numbers = ["from_clock","to_clock"]
		"reset_demo":
			expected = ["old_epoch","new_epoch"]
			numbers = ["old_epoch","new_epoch"]
		_: return false
	if not Codec.keys(result,expected): return false
	for key: String in numbers:
		if not Codec.integer(result[key]): return false
	if entity_field.is_empty():
		if not entity_id.is_empty(): return false
	elif not id_valid(state,result[entity_field],entity_kind) or result[entity_field] != entity_id: return false
	for key: String in ["remaining_quantity","filled_quantity","returned_quantity","requested_quantity","claimed_quantity"]:
		if result.has(key) and not Codec.integer(result[key],0,999): return false
	if result.has("unit_price") and not Codec.integer(result.unit_price,1,MAX_PRICE): return false
	if action == "fill_order" and (result.filled_quantity < 1 or not id_valid(state,result.claim_id,"claim")): return false
	if action == "claim" and (result.claimed_quantity < 1 or result.requested_quantity < result.claimed_quantity): return false
	if action == "create_order":
		if not result.fills is Array or result.fills.size() > MAX_ORDERS: return false
		var seen := {}
		var quantity := 0
		for fill: Variant in result.fills:
			if not Codec.keys(fill,["order_id","quantity","unit_price"]) or not id_valid(state,fill.order_id,"order") \
					or seen.has(fill.order_id) or not Codec.integer(fill.quantity,1,999) or not Codec.integer(fill.unit_price,1,MAX_PRICE): return false
			seen[fill.order_id] = true
			quantity += int(fill.quantity)
		if quantity != result.filled_quantity or result.filled_quantity + result.remaining_quantity < 1 \
				or result.filled_quantity + result.remaining_quantity > 999: return false
	if action == "cancel_order":
		if not result.returned_asset_id is String or not result.claim_id is String: return false
		if result.returned_quantity == 0:
			if not result.returned_asset_id.is_empty() or not result.claim_id.is_empty(): return false
		elif not id_valid(state,result.returned_asset_id,"asset") or not id_valid(state,result.claim_id,"claim"): return false
	if action in ["request_trade","accept_trade","set_offer","lock_trade"]:
		var required := "requested" if action == "request_trade" else "locked" if action == "lock_trade" else "accepted"
		if not result.status is String or result.status != required: return false
	for key: String in ["returned_asset_ids","transferred_asset_ids","expired_order_ids"]:
		if result.has(key):
			var kind := "order" if key == "expired_order_ids" else "asset"
			var cap := MAX_ORDERS*2 if kind == "order" else MAX_OFFER_ROWS*2
			if not result[key] is Array or result[key].size() > cap: return false
			var seen := {}
			for id: Variant in result[key]:
				if not id_valid(state,id,kind) or seen.has(id): return false
				seen[id] = true
	if action == "advance_time":
		if result.to_clock <= result.from_clock or int(result.to_clock)-int(result.from_clock) > MAX_TIME_STEP \
				or result.to_clock > state.clock or not result.expired_trade_id is String: return false
		if not result.expired_trade_id.is_empty() and not id_valid(state,result.expired_trade_id,"trade"): return false
	if action == "reset_demo" and (result.new_epoch != state.epoch or result.old_epoch != state.epoch-1): return false
	return true

static func receipt_id(space: String, epoch: int, actor: String, sequence: int) -> String:
	return "demo:%s:%d:command:%s:%d" % [space,epoch,actor,sequence]

static func _sales_valid(state: Dictionary, supply: Dictionary) -> bool:
	if not state.sales is Array or state.sales.size() > MAX_SALES: return false
	var expected := ["id","receipt_id","command_actor","command_sequence","source_action","source_order_id",
		"buy_order_id","sell_order_id","revision","fill_index","clock","item_id","variant","variant_key",
		"quantity","unit_price","buyer_actor","seller_actor"]
	var strings := ["id","receipt_id","command_actor","source_action","source_order_id","buy_order_id","sell_order_id",
		"item_id","variant_key","buyer_actor","seller_actor"]
	var receipts := {}
	for stored: Dictionary in state.recent_receipts: receipts[stored.receipt.revision] = stored.receipt
	var seen := {}
	var by_revision := {}
	var previous: Dictionary = {}
	for sale: Variant in state.sales:
		if not Codec.keys(sale,expected) or not Codec.strings(sale,strings) \
				or not ACTORS.has(sale.command_actor) or not ACTORS.has(sale.buyer_actor) or not ACTORS.has(sale.seller_actor) \
				or sale.buyer_actor == sale.seller_actor or sale.source_action not in ["create_order","fill_order"] \
				or not Codec.integer(sale.command_sequence,1,state.command_heads[sale.command_actor]) \
				or not Codec.integer(sale.revision,1,state.revision) or not Codec.integer(sale.fill_index,0,MAX_ORDERS-1) \
				or not Codec.integer(sale.clock,0,state.clock) or not Codec.integer(sale.unit_price,1,MAX_PRICE): return false
		var variant := Eligibility.normalize_variant(sale.variant)
		if variant.is_empty() or not variant.identified or sale.item_id != variant.item_id \
				or sale.variant_key != Eligibility.variant_key(variant) or not supply.has(sale.variant_key) \
				or not Codec.integer(sale.quantity,1,Eligibility.stack_limit(variant)) \
				or int(sale.quantity)*int(sale.unit_price) > INITIAL_DM: return false
		if sale.receipt_id != receipt_id(state.namespace,state.epoch,sale.command_actor,sale.command_sequence) \
				or sale.id != sale.receipt_id+":fill:"+str(sale.fill_index) or seen.has(sale.id) \
				or not id_valid(state,sale.source_order_id,"order"): return false
		seen[sale.id] = true
		for key: String in ["buy_order_id","sell_order_id"]:
			if not sale[key].is_empty() and not id_valid(state,sale[key],"order"): return false
			if state.orders.has(sale[key]):
				var order: Dictionary = state.orders[sale[key]]
				var buy: bool = key == "buy_order_id"
				if order.side != ("buy" if buy else "sell") or order.actor_id != (sale.buyer_actor if buy else sale.seller_actor) \
						or order.variant != sale.variant or (buy and order.unit_price < sale.unit_price) \
						or (not buy and order.unit_price > sale.unit_price): return false
		if sale.source_action == "create_order":
			if sale.buy_order_id.is_empty() or sale.sell_order_id.is_empty() or sale.buy_order_id == sale.sell_order_id \
					or sale.source_order_id not in [sale.buy_order_id,sale.sell_order_id]: return false
			var incoming_buy: bool = sale.source_order_id == sale.buy_order_id
			if sale.command_actor != (sale.buyer_actor if incoming_buy else sale.seller_actor): return false
			var resting: String = sale.sell_order_id if incoming_buy else sale.buy_order_id
			if int(sale.source_order_id.get_slice(":",4)) <= int(resting.get_slice(":",4)): return false
		else:
			if sale.fill_index != 0 or sale.buy_order_id.is_empty() == sale.sell_order_id.is_empty(): return false
			var taking_sell: bool = not sale.sell_order_id.is_empty()
			if sale.source_order_id != (sale.sell_order_id if taking_sell else sale.buy_order_id) \
					or sale.command_actor != (sale.buyer_actor if taking_sell else sale.seller_actor): return false
		if not previous.is_empty():
			if sale.revision < previous.revision or sale.clock < previous.clock: return false
			if sale.revision == previous.revision:
				if sale.receipt_id != previous.receipt_id or sale.fill_index != int(previous.fill_index)+1 \
						or sale.source_order_id != previous.source_order_id or sale.variant_key != previous.variant_key: return false
			elif sale.fill_index != 0: return false
		elif sale.fill_index != 0 and state.sales.size() < MAX_SALES: return false
		previous = sale
		by_revision[sale.revision] = int(by_revision.get(sale.revision,0))+1
		if receipts.has(sale.revision):
			var receipt: Dictionary = receipts[sale.revision]
			if receipt.id != sale.receipt_id or receipt.actor_id != sale.command_actor or receipt.sequence != sale.command_sequence \
					or receipt.action != sale.source_action or receipt.entity_id != sale.source_order_id: return false
			if sale.source_action == "create_order":
				var fills: Array = receipt.result.fills
				if sale.fill_index >= fills.size(): return false
				var fill: Dictionary = fills[sale.fill_index]
				var opposite: String = sale.sell_order_id if sale.source_order_id == sale.buy_order_id else sale.buy_order_id
				if fill.order_id != opposite or fill.quantity != sale.quantity or fill.unit_price != sale.unit_price: return false
			elif receipt.result.filled_quantity != sale.quantity or receipt.result.unit_price != sale.unit_price: return false
	# Every execution still provable by retained command receipts must appear in
	# the tape, except the exact prefix removed by its128-row retention bound.
	for receipt: Dictionary in receipts.values():
		var count := 0
		if receipt.action == "create_order": count = receipt.result.fills.size()
		elif receipt.action == "fill_order": count = 1
		if count == 0:
			if by_revision.has(receipt.revision): return false
			continue
		if state.sales.is_empty(): return false
		var first: Dictionary = state.sales[0]
		if receipt.revision < first.revision:
			if state.sales.size() < MAX_SALES: return false
			continue
		var pruned: int = first.fill_index if receipt.revision == first.revision else 0
		if int(by_revision.get(receipt.revision,0)) != count-pruned: return false
	return true
