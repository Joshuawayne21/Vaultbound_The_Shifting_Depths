class_name VaultLootLedger
extends RefCounted
## Per-expedition remaining rewards, not an inventory. The Session owns access,
## capacity checks and transfer into its existing unsecured bag. No Node, clock,
## device identity or client networking state belongs in this ledger.

const MAX_COUNT := 2147483647
const MAX_ROWS := 32
const MAX_MERGED_SOURCES := 32
const MERGE_DISTANCE := 3.0
const CURRENCY_ROW := "__depthmarks"
const KINDS := ["regular", "elite", "boss"]
const LABELS := {"regular": "Fallen Foe Cache", "elite": "Reinforced Loot Cache", "boss": "Rootwarden Reliquary"}
const SOURCE_PRESENTATIONS := {
	"thornmarshal": {"kind": "boss", "label": "Thornmarshal Reliquary"},
	"mycelial_cantor": {"kind": "boss", "label": "Mycelial Cantor Reliquary"},
	"root_bark_champion": {"kind": "elite", "label": "Root Bark Champion Cache"},
}

var _records: Dictionary = {}
var _sources: Dictionary = {}
var _activated: Dictionary = {}
var _generation := 0
var _sequence := 0

func reset() -> void:
	_records.clear()
	_sources.clear()
	_activated.clear()
	_generation += 1
	_sequence = 0

func has_source(receipt: String) -> bool:
	return _sources.has(receipt)

func source_cache(receipt: String) -> String:
	return String(_sources.get(receipt, ""))

func records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _records.values():
		result.append(record.duplicate(true))
	return result

func snapshot(id: String) -> Dictionary:
	return _records.get(id, {}).duplicate(true)

func merge_candidate(room_id: int, at: Vector3, reward: Dictionary) -> String:
	if not _valid_reward(reward) or not _low_tier(reward):
		return ""
	var best := ""
	var distance := MERGE_DISTANCE * MERGE_DISTANCE
	for id: String in _records:
		var record: Dictionary = _records[id]
		var candidate_distance: float = at.distance_squared_to(record.position)
		if candidate_distance <= distance and _can_merge(record, reward, room_id, at, "regular"):
			best = id
			distance = candidate_distance
	return best

func register(reward: Dictionary, room_id: int, at: Vector3, kind: String,
		merge_id: String = "", presentation_id: String = "") -> Dictionary:
	if not _valid_reward(reward) or room_id < 0 or not at.is_finite() or not KINDS.has(kind):
		return {"ok": false, "id": "", "created": false}
	if not presentation_id.is_empty() and (not SOURCE_PRESENTATIONS.has(presentation_id) or SOURCE_PRESENTATIONS[presentation_id].kind != kind):
		return {"ok": false, "id": "", "created": false}
	var receipt: String = reward.chest_id
	if has_source(receipt):
		return {"ok": false, "id": source_cache(receipt), "created": false, "duplicate": true}
	if _records.has(merge_id) and _can_merge(_records[merge_id], reward, room_id, at, kind):
		var record: Dictionary = _records[merge_id]
		record.gold += int(reward.gold)
		for item: Dictionary in reward.items:
			record.items[item.id] = int(record.items.get(item.id, 0)) + int(item.quantity)
		record.source_ids.append(receipt)
		record.source_values[receipt] = int(reward.get("value", reward.gold))
		record.source_rewards[receipt] = reward.duplicate(true)
		record.revision += 1
		_sources[receipt] = merge_id
		return {"ok": true, "id": merge_id, "created": false}
	var totals := {}
	for item: Dictionary in reward.items:
		totals[item.id] = int(totals.get(item.id, 0)) + int(item.quantity)
	_sequence += 1
	_records[receipt] = {"id": receipt, "kind": kind, "label": LABELS[kind] if presentation_id.is_empty() else SOURCE_PRESENTATIONS[presentation_id].label,
		"owner_id": "local_player", "room_id": room_id, "position": at,
		"revision": 0, "gold": int(reward.gold), "items": totals,
		"source_ids": [receipt], "source_values": {receipt: int(reward.get("value", reward.gold))},
		"source_rewards": {receipt: reward.duplicate(true)},
		"empty": false, "opened": false, "mergeable": kind == "regular" and _low_tier(reward),
		"sequence": _sequence, "category": String(reward.get("category", "common"))}
	_sources[receipt] = receipt
	return {"ok": true, "id": receipt, "created": true}

func plan_take(id: String, item_id: String = "", quantity: int = 0,
		expected_revision: int = -1) -> Dictionary:
	if quantity < 0 or not _records.has(id):
		return {}
	var record: Dictionary = _records[id]
	if record.empty or (expected_revision >= 0 and expected_revision != int(record.revision)):
		return {}
	var next: Dictionary = record.duplicate(true)
	var taken_gold := 0
	var taken_items: Array[Dictionary] = []
	if item_id.is_empty():
		if quantity != 0:
			return {}
		taken_gold = int(next.gold)
		next.gold = 0
		var keys: Array = next.items.keys()
		keys.sort()
		for key: String in keys:
			taken_items.append({"id": key, "quantity": int(next.items[key])})
		next.items.clear()
	elif item_id == CURRENCY_ROW:
		taken_gold = int(next.gold) if quantity == 0 else quantity
		if taken_gold <= 0 or taken_gold > int(next.gold):
			return {}
		next.gold -= taken_gold
	else:
		var available := int(next.items.get(item_id, 0))
		var amount := available if quantity == 0 else quantity
		if amount <= 0 or amount > available:
			return {}
		taken_items.append({"id": item_id, "quantity": amount})
		if amount == available:
			next.items.erase(item_id)
		else:
			next.items[item_id] = available - amount
	var newly_activated: Array[Dictionary] = []
	for source: String in record.source_ids:
		if not _activated.has(source):
			newly_activated.append(record.source_rewards[source].duplicate(true))
	next.revision += 1
	next.opened = true
	next.empty = int(next.gold) == 0 and next.items.is_empty()
	return {"id": id, "generation": _generation, "revision": int(record.revision),
		"item_id": item_id, "quantity": quantity, "next_record": next,
		"activated_sources": newly_activated,
		"reward": {"chest_id": "loot_take_%d_%d_%d" % [_generation, int(record.sequence), int(record.revision)],
			"category": record.category, "gold": taken_gold, "items": taken_items, "cursed": false}}

func commit_take(plan: Dictionary) -> bool:
	# Recompute from the current record: callers cannot alter amounts or replay a
	# plan after a Take, merge, reset, or a new expedition with the same seed.
	if plan.get("generation", -1) != _generation or not plan.get("id") is String \
			or not plan.get("item_id") is String or not plan.get("quantity") is int \
			or not plan.get("revision") is int:
		return false
	var verified := plan_take(plan.id, plan.item_id, plan.quantity, plan.revision)
	if verified.is_empty() or verified != plan:
		return false
	_records[plan.id] = verified.next_record.duplicate(true)
	for source: Dictionary in verified.activated_sources:
		_activated[source.chest_id] = true
	return true

func _can_merge(record: Dictionary, reward: Dictionary, room_id: int, at: Vector3, kind: String) -> bool:
	if kind != "regular" or not record.mergeable or record.opened or record.empty \
			or int(record.room_id) != room_id or not _low_tier(reward) \
			or record.position.distance_squared_to(at) > MERGE_DISTANCE * MERGE_DISTANCE \
			or record.source_ids.size() >= MAX_MERGED_SOURCES \
			or int(record.gold) > MAX_COUNT - int(reward.gold):
		return false
	var totals: Dictionary = record.items.duplicate()
	for item: Dictionary in reward.items:
		if int(totals.get(item.id, 0)) > MAX_COUNT - int(item.quantity):
			return false
		totals[item.id] = int(totals.get(item.id, 0)) + int(item.quantity)
	return totals.size() <= MAX_ROWS

func _low_tier(reward: Dictionary) -> bool:
	if String(reward.get("category", "common")) != "common":
		return false
	for item: Dictionary in reward.items:
		var definition := VaultLootTable.item_for(item.id)
		if definition == null or definition.rarity not in ["common", "uncommon"]:
			return false
	return true

func _valid_reward(reward: Dictionary) -> bool:
	if not reward.get("chest_id") is String or reward.chest_id.is_empty() or reward.chest_id.length() > 160 \
			or not reward.get("gold") is int or reward.gold < 0 or reward.gold > MAX_COUNT \
			or not reward.get("items") is Array or reward.items.size() > MAX_ROWS:
		return false
	if not reward.get("value", 0) is int or int(reward.get("value", 0)) < 0:
		return false
	if not VaultLootTable.CATEGORIES.has(String(reward.get("category", "common"))):
		return false
	var totals := {}
	for item: Variant in reward.items:
		if not item is Dictionary or not item.get("id") is String or item.id.is_empty() \
				or item.id == CURRENCY_ROW or not item.get("quantity") is int \
				or item.quantity <= 0 or item.quantity > MAX_COUNT:
			return false
		if int(totals.get(item.id, 0)) > MAX_COUNT - int(item.quantity):
			return false
		totals[item.id] = int(totals.get(item.id, 0)) + int(item.quantity)
	return reward.gold > 0 or not totals.is_empty()
