class_name VaultInventory
extends RefCounted
## Pure instance/stack rules. Callers mutate a copied candidate and save it before
## publishing changes. Definitions are shared resources; instances are plain data.

const Catalog = preload("res://scripts/progression/loot_table.gd")
const EnhancementPolicy = preload("res://scripts/progression/enhancement_policy.gd")
const Effects = preload("res://resources/progression/equipment_effects.tres")
const CAPACITY := 40
const MAX_COUNT := 2147483647
const MAX_RECEIPTS := 64
const LEGACY_SLOTS := ["main_weapon", "off_hand", "helmet", "chest_armor", "boots", "accessory"]
# The shield and legacy accessory remain independent assignments. New slots do
# not rename or discard the equipment a version-two player already owns.
const SLOTS := ["main_weapon", "off_hand", "helmet", "chest_armor", "boots", "accessory",
	"secondary_weapon", "gloves", "leg_armor", "necklace", "ring"]
const LOADOUT_SLOTS := ["main_weapon", "secondary_weapon"]
const LEGACY_MODIFIER_LIMITS := {"max_health": 12.0, "max_stamina": 10.0, "damage_bonus": 0.05,
	"armor": 0.04, "stamina_regen": 1.5}
const MODIFIER_LIMITS := {"max_health": 12.0, "max_stamina": 10.0, "damage_bonus": 0.05,
	"armor": 0.04, "stamina_regen": 1.5, "crit_chance": 0.05, "lifesteal": 0.015,
	"block_strength": 0.05, "ability_cooldown_reduction": 0.05}

static func empty_fields() -> Dictionary:
	var equipment := {}
	var displays := {}
	for slot: String in SLOTS:
		equipment[slot] = ""
	for index in range(8):
		displays["equipment_%d" % index] = ""
	for index in range(4):
		displays["relic_%d" % index] = ""
	return {"inventory": [], "equipment": equipment, "active_loadout": "main_weapon", "next_item_id": 1,
		"legacy_reserve": {}, "displays": displays, "transaction_receipts": [],
		"merchant_purchases": {}}

static func migrate_legacy(items: Dictionary, equipped_item: String = "") -> Dictionary:
	var result := empty_fields()
	var ids: Array = items.keys()
	ids.sort()
	# Preserve the previously selected weapon before filling optional old stacks.
	if ids.has(equipped_item):
		ids.erase(equipped_item)
		ids.push_front(equipped_item)
	for raw_id: Variant in ids:
		if not raw_id is String or not _integer(items[raw_id], 1, MAX_COUNT):
			return {}
		var id := String(raw_id)
		if not _text(id, 96):
			return {}
		var remaining := int(items[id])
		var definition := Catalog.item_for(id)
		if definition_available(definition) and definition.category != "gold":
			while remaining > 0 and result.inventory.size() < CAPACITY:
				var amount := mini(remaining, stack_limit(definition))
				var entry := _new_entry(result, id, amount, 0, false)
				# Legacy ownership did not contain random modifiers or hidden properties.
				entry.modifiers = {}
				entry.identified = true
				result.inventory.append(entry)
				remaining -= amount
				if id == equipped_item and definition.category == "equipment" and result.equipment.get(String(definition.slot), "") == "":
					result.equipment[String(definition.slot)] = entry.uid
		if remaining > 0:
			result.legacy_reserve[id] = remaining
	return result

static func normalize_fields(value: Dictionary, source_version: int = 5) -> Dictionary:
	return _normalize_fields(value, source_version, {})

static func _normalize_fields(value: Dictionary, source_version: int, unavailable_items: Dictionary) -> Dictionary:
	# Unavailable IDs are used only by ProfileStore's read-only classification.
	# The normal inventory API never accepts them or creates substitute items.
	if source_version not in [2, 3, 4, 5]:
		return {}
	if not value.get("inventory") is Array or value.inventory.size() > CAPACITY:
		return {}
	if not _integer(value.get("next_item_id"), 1, MAX_COUNT):
		return {}
	for key: String in ["equipment", "legacy_reserve", "displays", "merchant_purchases"]:
		if not value.get(key) is Dictionary:
			return {}
	# Versioned records must retain every assignment field. Missing keys are a
	# damaged record, not permission to silently replace equipment/displays with
	# empty selections; only the explicit legacy migration supplies defaults.
	var expected_slots: Array = LEGACY_SLOTS if source_version == 2 else SLOTS
	if value.equipment.size() != expected_slots.size() or value.displays.size() != 12:
		return {}
	for slot: String in expected_slots:
		if not value.equipment.has(slot):
			return {}
	if source_version >= 3 and (not value.get("active_loadout") is String or value.active_loadout not in LOADOUT_SLOTS):
		return {}
	for index in range(8):
		if not value.displays.has("equipment_%d" % index):
			return {}
	for index in range(4):
		if not value.displays.has("relic_%d" % index):
			return {}
	if not value.get("transaction_receipts") is Array or value.transaction_receipts.size() > MAX_RECEIPTS:
		return {}
	var result := empty_fields()
	if source_version >= 3:
		result.active_loadout = String(value.active_loadout)
	var modifier_limits: Dictionary = LEGACY_MODIFIER_LIMITS if source_version < 4 else MODIFIER_LIMITS
	result.next_item_id = int(value.next_item_id)
	var used := {}
	for raw: Variant in value.inventory:
		if not raw is Dictionary:
			return {}
		var uid: Variant = raw.get("uid")
		var item_id: Variant = raw.get("item_id")
		if not uid is String or not _uid_valid(uid) or used.has(uid) or not item_id is String or not _text(item_id, 96):
			return {}
		if int(String(uid).trim_prefix("item_")) >= result.next_item_id:
			return {}
		var definition := Catalog.item_for(item_id)
		var unavailable := unavailable_items.has(item_id)
		if not unavailable and not definition_available(definition):
			return {}
		if (not unavailable and definition.category == "gold") or not _integer(raw.get("quantity"), 1, MAX_COUNT if unavailable else stack_limit(definition)):
			return {}
		var enhancement_cap: int = 5 if source_version < 4 else 10 if unavailable else EnhancementPolicy.cap_for(definition)
		if not _integer(raw.get("enhancement"), 0, enhancement_cap) or not _integer(raw.get("durability"), 0, 100):
			return {}
		for key: String in ["identified", "locked", "favorite"]:
			if not raw.get(key) is bool:
				return {}
		if not raw.get("modifiers") is Dictionary or raw.modifiers.size() > 2:
			return {}
		var modifiers := {}
		for stat: Variant in raw.modifiers:
			if not stat is String or not modifier_limits.has(stat):
				return {}
			var amount: Variant = raw.modifiers[stat]
			if not _number(amount, 0.0, modifier_limits[stat]) or float(amount) <= 0.0:
				return {}
			modifiers[stat] = float(amount)
		if not unavailable and definition.category != "equipment" and (int(raw.enhancement) != 0 or int(raw.durability) != 100 or not modifiers.is_empty() or not raw.identified):
			return {}
		var entry := {"uid": String(uid), "item_id": String(item_id), "quantity": int(raw.quantity),
			"enhancement": int(raw.enhancement), "durability": int(raw.durability), "modifiers": modifiers,
			"identified": bool(raw.identified), "locked": bool(raw.locked), "favorite": bool(raw.favorite)}
		result.inventory.append(entry)
		used[uid] = entry
	var assigned := {}
	for slot: Variant in value.equipment:
		if not slot is String or not expected_slots.has(slot) or not value.equipment[slot] is String:
			return {}
		var uid: String = value.equipment[slot]
		if not uid.is_empty():
			if not used.has(uid) or assigned.has(uid):
				return {}
			var definition := Catalog.item_for(used[uid].item_id)
			if (not unavailable_items.has(used[uid].item_id) and not slot_accepts(definition, slot)) or not used[uid].identified:
				return {}
			assigned[uid] = true
		result.equipment[slot] = uid
	# Practice combat exists only when neither slot owns a weapon. Otherwise the
	# active assignment must name a real owned instance, including after unequip.
	if result.equipment[result.active_loadout].is_empty():
		if result.active_loadout != "main_weapon" or not result.equipment.main_weapon.is_empty() or not result.equipment.secondary_weapon.is_empty():
			return {}
	for id: Variant in value.legacy_reserve:
		if not id is String or not _text(id, 96) or not _integer(value.legacy_reserve[id], 1, MAX_COUNT):
			return {}
		result.legacy_reserve[id] = int(value.legacy_reserve[id])
	var displayed := {}
	for stand: Variant in value.displays:
		if not stand is String or not result.displays.has(stand) or not value.displays[stand] is String:
			return {}
		var uid: String = value.displays[stand]
		if not uid.is_empty():
			if not used.has(uid) or displayed.has(uid):
				return {}
			if (not unavailable_items.has(used[uid].item_id) and not display_eligible(used[uid], stand)) or not used[uid].identified:
				return {}
			displayed[uid] = true
		result.displays[stand] = uid
	for receipt: Variant in value.transaction_receipts:
		if not receipt is String or not _text(receipt, 120) or result.transaction_receipts.has(receipt):
			return {}
		result.transaction_receipts.append(receipt)
	if value.merchant_purchases.size() > 128:
		return {}
	for key: Variant in value.merchant_purchases:
		if not key is String or not _text(key, 160) or not _integer(value.merchant_purchases[key], 1, 9999):
			return {}
		result.merchant_purchases[key] = int(value.merchant_purchases[key])
	var aggregate := totals(result)
	for amount: int in aggregate.values():
		if amount > MAX_COUNT:
			return {}
	return result

static func totals(profile: Dictionary) -> Dictionary:
	var result: Dictionary = profile.get("legacy_reserve", {}).duplicate(true)
	for entry: Dictionary in profile.get("inventory", []):
		result[entry.item_id] = int(result.get(entry.item_id, 0)) + int(entry.quantity)
	return result

static func sync_mirrors(profile: Dictionary) -> void:
	profile.items = totals(profile)
	var active := active_weapon_entry(profile)
	profile.equipped_item = String(active.item_id) if not active.is_empty() else ""

static func active_weapon_slot(profile: Dictionary) -> String:
	var selected := String(profile.get("active_loadout", "main_weapon"))
	return selected if selected in LOADOUT_SLOTS else "main_weapon"

static func active_weapon_entry(profile: Dictionary) -> Dictionary:
	return find(profile, String(profile.get("equipment", {}).get(active_weapon_slot(profile), "")))

static func slot_accepts(definition: VaultItemDefinition, slot: String) -> bool:
	if definition == null or not definition.can_equip() or slot not in SLOTS:
		return false
	if slot in LOADOUT_SLOTS:
		return definition.slot == &"main_weapon" and definition.weapon_style in [&"sword", &"staff"]
	return String(definition.slot) == slot

static func find(profile: Dictionary, uid: String) -> Dictionary:
	for entry: Dictionary in profile.get("inventory", []):
		if String(entry.uid) == uid:
			return entry
	return {}

static func used_slots(profile: Dictionary) -> int:
	return profile.get("inventory", []).size()

static func stack_limit(definition: VaultItemDefinition) -> int:
	return 1 if definition.category == "equipment" else clampi(int(definition.stack_limit), 1, 999)

static func definition_available(definition: VaultItemDefinition) -> bool:
	# A catalog entry can describe future content without enabling its owned
	# instances in this build. Currency has separate inventory exclusion rules.
	return definition != null and definition.obtainable \
		and (definition.category != "equipment" or definition.can_equip())

static func add_items(profile: Dictionary, items: Dictionary, seed: int = 0) -> bool:
	var next := profile.duplicate(true)
	var ids: Array = items.keys()
	ids.sort()
	for raw_id: Variant in ids:
		if not raw_id is String or not _integer(items[raw_id], 1, MAX_COUNT):
			return false
		var id := String(raw_id)
		var definition := Catalog.item_for(id)
		if not definition_available(definition) or definition.category == "gold":
			return false
		if int(totals(next).get(id, 0)) > MAX_COUNT - int(items[id]):
			return false
		var remaining := int(items[id])
		var limit := stack_limit(definition)
		if limit > 1:
			for entry: Dictionary in next.inventory:
				if entry.item_id != id or entry.quantity >= limit:
					continue
				var added := mini(remaining, limit - int(entry.quantity))
				entry.quantity += added
				remaining -= added
				if remaining == 0:
					break
		while remaining > 0:
			if next.inventory.size() >= CAPACITY or int(next.next_item_id) >= MAX_COUNT:
				return false
			var amount := mini(remaining, limit)
			next.inventory.append(_new_entry(next, id, amount, seed))
			remaining -= amount
	profile.inventory = next.inventory
	profile.next_item_id = next.next_item_id
	sync_mirrors(profile)
	return true

static func consume_items(profile: Dictionary, items: Dictionary) -> bool:
	var next := profile.duplicate(true)
	for id: Variant in items:
		if not id is String or not _integer(items[id], 1, MAX_COUNT):
			return false
		var remaining := int(items[id])
		for entry: Dictionary in next.inventory:
			if entry.item_id != id or is_protected(next, entry):
				continue
			var taken := mini(remaining, int(entry.quantity))
			entry.quantity -= taken
			remaining -= taken
			if remaining == 0:
				break
		if remaining > 0:
			return false
		next.inventory = next.inventory.filter(func(entry: Dictionary) -> bool: return int(entry.quantity) > 0)
	profile.inventory = next.inventory
	sync_mirrors(profile)
	return true

static func available(profile: Dictionary, item_id: String) -> int:
	var count := 0
	for entry: Dictionary in profile.get("inventory", []):
		if entry.item_id == item_id and not is_protected(profile, entry):
			count += int(entry.quantity)
	return count

static func is_protected(profile: Dictionary, entry: Dictionary) -> bool:
	return bool(entry.get("locked", false)) or bool(entry.get("favorite", false)) \
		or profile.get("equipment", {}).values().has(entry.get("uid", "")) \
		or profile.get("displays", {}).values().has(entry.get("uid", ""))

static func display_eligible(entry: Dictionary, stand: String) -> bool:
	var definition := Catalog.item_for(String(entry.get("item_id", "")))
	if definition == null or not bool(entry.get("identified", false)):
		return false
	return (stand.begins_with("equipment_") and definition.category == "equipment") \
		or (stand.begins_with("relic_") and definition.category == "collectible")

static func describe_entries(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in profile.get("inventory", []):
		var definition := Catalog.item_for(entry.item_id)
		if definition == null:
			continue
		var detail := definition.describe(int(entry.quantity))
		detail.merge(entry.duplicate(true), true)
		detail.equipped = profile.get("equipment", {}).values().has(entry.uid)
		detail.displayed = profile.get("displays", {}).values().has(entry.uid)
		detail.protected = is_protected(profile, entry)
		if not entry.identified:
			detail.modifiers = {}
			detail.base_stats = {}
			detail.special_effects = []
			detail.description = "Hidden properties await the Relic Appraiser in Sanctuary."
		result.append(detail)
	return result

static func _new_entry(profile: Dictionary, item_id: String, quantity: int, seed: int, roll_modifiers: bool = true) -> Dictionary:
	var uid := "item_%010d" % int(profile.next_item_id)
	profile.next_item_id = int(profile.next_item_id) + 1
	var definition := Catalog.item_for(item_id)
	var entry := {"uid": uid, "item_id": item_id, "quantity": quantity, "enhancement": 0,
		"durability": 100, "modifiers": {}, "identified": bool(definition.identified_by_default),
		"locked": false, "favorite": false}
	if definition.category == "equipment":
		if roll_modifiers:
			entry.modifiers = Effects.roll_modifiers(definition.rarity, seed ^ int(uid.hash()) ^ int(item_id.hash()), definition.base_stats)
	else:
		entry.identified = true
	return entry

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _uid_valid(value: String) -> bool:
	if not value.begins_with("item_") or value.length() != 15:
		return false
	var digits := value.trim_prefix("item_")
	return digits.is_valid_int() and digits == "%010d" % int(digits) and int(digits) > 0

static func _text(value: String, maximum: int) -> bool:
	if value.is_empty() or value.length() > maximum:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true
