class_name VaultEconomy
extends RefCounted
## Pure, reviewable transactions. No UI, actor, clock, file or networking writes.
## A quote is committed against one revision and receipt; the caller saves first.

const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")
const Enhancement = preload("res://scripts/progression/enhancement_policy.gd")
const ACTIONS := [&"buy", &"sell", &"equip", &"unequip", &"lock", &"favorite", &"craft",
	&"upgrade", &"repair", &"salvage", &"identify", &"display", &"claim_reserve", &"talent", &"use", &"activate_loadout"]

static func preview(profile: Dictionary, action: StringName, arguments: Dictionary) -> Dictionary:
	var result := _evaluate(profile, action, arguments)
	result.erase("profile")
	# Appraisal must charge before hidden properties become visible. A quote may
	# advertise the reveal, but cannot provide a free peek at the pending roll.
	for key: String in ["before", "after"]:
		var entry: Dictionary = result.get(key, {})
		if not entry.is_empty() and (not bool(entry.get("identified", true)) or action == &"identify"):
			entry.modifiers = {}
			entry.identified = false
	if action == &"identify" and result.ok:
		result.message = "Hidden properties will be revealed after payment."
	return result

static func plan(profile: Dictionary, action: StringName, arguments: Dictionary,
		request_id: String, expected_revision: int) -> Dictionary:
	if not Inventory._text(request_id, 120):
		return _failure("The transaction request is invalid.")
	if expected_revision != int(profile.get("revision", -1)):
		return _failure("Your inventory changed. Review a fresh preview before confirming.")
	if profile.get("transaction_receipts", []).has(request_id):
		return _failure("This transaction was already applied.")
	if expected_revision >= Inventory.MAX_COUNT:
		return _failure("The saved transaction limit has been reached.")
	var result := _evaluate(profile, action, arguments)
	if not result.ok:
		return result
	var next: Dictionary = result.profile
	next.revision = expected_revision + 1
	next.transaction_receipts.append(request_id)
	while next.transaction_receipts.size() > Inventory.MAX_RECEIPTS:
		next.transaction_receipts.pop_front()
	return result

static func _evaluate(profile: Dictionary, action: StringName, arguments: Dictionary) -> Dictionary:
	if action not in ACTIONS:
		return _failure("That action is not available.")
	if Inventory.normalize_fields(profile).is_empty() or not Inventory._integer(profile.get("gold"), 0, Inventory.MAX_COUNT):
		return _failure("Inventory data needs recovery before making changes.")
	if profile.get("items", {}) != Inventory.totals(profile):
		return _failure("Inventory totals do not match their owned instances.")
	var next := profile.duplicate(true)
	var result := {"ok": true, "error": "", "message": "", "cost_gold": 0, "gold_gain": 0,
		"materials": {}, "outputs": {}, "before": {}, "after": {}, "profile": next}
	var uid := String(arguments.get("uid", ""))
	var entry := Inventory.find(next, uid)
	var definition: VaultItemDefinition = Catalog.item_for(String(entry.get("item_id", "")))
	var quantity: Variant = arguments.get("quantity", 1)
	if not Inventory._integer(quantity, 1, 999):
		return _failure("Choose a whole quantity between 1 and 999.")
	var count := int(quantity)
	if count != 1 and action not in [&"buy", &"sell", &"claim_reserve"]:
		return _failure("Confirm one item action at a time.")
	match action:
		&"buy":
			var vendor := String(arguments.get("vendor", ""))
			if vendor not in ["general", "equipment", "appraiser"]:
				return _failure("This merchant is not available.")
			var stock := _stock(vendor, int(profile.get("statistics", {}).get("completed", 0)))
			var selected := {}
			for offer: Dictionary in stock:
				if String(offer.stock_id) == String(arguments.get("stock_id", "")):
					selected = offer
					break
			if selected.is_empty() or count > 99:
				return _failure("Select an available merchant offer and a quantity up to 99.")
			var key := "%s:%d:%s" % [vendor, int(profile.statistics.completed), String(selected.stock_id)]
			var purchased := int(next.merchant_purchases.get(key, 0))
			if purchased + count > int(selected.quantity):
				return _failure("The merchant does not have that much stock this rotation.")
			result.cost_gold = int(selected.price) * count
			result.outputs = {String(selected.item_id): count}
			if not _spend(next, result.cost_gold):
				return _failure("You need %d DM for this purchase." % result.cost_gold, result)
			if not Inventory.add_items(next, result.outputs, int(profile.revision)):
				return _failure("Your 40-slot inventory has no room for this purchase.", result)
			next.merchant_purchases[key] = purchased + count
			# Rotation keys use successful expedition counts, never device time.
			for old: String in next.merchant_purchases.keys():
				var parts := old.split(":")
				if parts.size() >= 3 and int(parts[1]) < int(profile.statistics.completed) - 2:
					next.merchant_purchases.erase(old)
			result.message = "Purchased %s ×%d" % [Catalog.item_for(selected.item_id).label, count]
		&"craft":
			var recipe := _recipe(String(arguments.get("recipe_id", "")))
			if recipe.is_empty():
				return _failure("Choose a known crafting recipe.")
			if int(profile.get("character", {}).get("level", 1)) < int(recipe.required_level):
				return _failure("This recipe requires level %d." % int(recipe.required_level))
			result.materials = recipe.ingredients.duplicate(true)
			result.cost_gold = int(recipe.gold)
			result.outputs = {String(recipe.output_id): int(recipe.output_quantity)}
			if not _spend(next, result.cost_gold):
				return _failure("You need %d DM to craft this recipe." % result.cost_gold, result)
			if not Inventory.consume_items(next, result.materials):
				return _failure("Required materials are missing, locked or displayed. Claim legacy reserves first.", result)
			if not Inventory.add_items(next, result.outputs, int(profile.revision)):
				return _failure("Make room in your 40-slot inventory before crafting.", result)
			result.message = "Crafted " + String(recipe.label)
		&"unequip":
			var slot := String(arguments.get("slot", ""))
			if not Inventory.SLOTS.has(slot) or String(next.equipment[slot]).is_empty():
				return _failure("That equipment slot is already empty.")
			result.before = Inventory.find(next, next.equipment[slot]).duplicate(true)
			next.equipment[slot] = ""
			_resolve_active_loadout(next)
			result.message = "Unequipped " + slot.replace("_", " ")
		&"activate_loadout":
			var slot := String(arguments.get("slot", ""))
			if slot not in Inventory.LOADOUT_SLOTS or String(next.equipment.get(slot, "")).is_empty():
				return _failure("Equip an owned weapon in that loadout first.")
			if Inventory.active_weapon_slot(next) == slot:
				return _failure("That weapon loadout is already active.")
			next.active_loadout = slot
			result.message = "Active loadout · " + Catalog.item_for(Inventory.active_weapon_entry(next).item_id).label
		&"display":
			var stand := String(arguments.get("stand_id", ""))
			if not next.displays.has(stand):
				return _failure("Choose an existing Collection Hall display.")
			if not uid.is_empty():
				if entry.is_empty() or not Inventory.display_eligible(entry, stand):
					return _failure("Choose an owned, identified item suitable for this stand.")
				for other: String in next.displays:
					if other != stand and next.displays[other] == uid:
						return _failure("That instance is already displayed on another stand.")
			if next.displays[stand] == uid:
				return _failure("That display selection is already saved.")
			next.displays[stand] = uid
			result.message = "Display cleared" if uid.is_empty() else "Displayed " + definition.label
		&"claim_reserve":
			var item_id := String(arguments.get("item_id", ""))
			if int(next.legacy_reserve.get(item_id, 0)) < count:
				return _failure("The preserved reserve does not contain that quantity.")
			next.legacy_reserve[item_id] -= count
			if next.legacy_reserve[item_id] == 0:
				next.legacy_reserve.erase(item_id)
			if not Inventory.add_items(next, {item_id: count}):
				return _failure("Make room before claiming preserved items; unknown legacy items remain safe in reserve.")
			result.outputs = {item_id: count}
			result.message = "Claimed preserved items from reserve"
		&"talent":
			var progression := load("res://scripts/progression/character_progression.gd") as Script
			var branch := String(arguments.get("branch", ""))
			var allocated: Dictionary = progression.allocate(next.character, branch) if progression != null else {}
			if allocated.is_empty():
				return _failure("Choose an available talent branch with an unspent point.")
			next.character = allocated
			result.message = "Allocated a point to " + branch.capitalize()
		_:
			if entry.is_empty() or definition == null:
				return _failure("That owned item instance is no longer available.")
			result.before = entry.duplicate(true)
			match action:
				&"lock", &"favorite":
					if not arguments.get("value") is bool:
						return _failure("The selected protection setting is invalid.")
					var flag := "locked" if action == &"lock" else "favorite"
					if entry[flag] == arguments.value:
						return _failure("That protection setting is already saved.")
					entry[flag] = bool(arguments.value)
					result.message = "%s · %s" % [definition.label, "Locked" if entry.locked else "Favorite" if entry.favorite else "Protection updated"]
				&"equip":
					var slot := String(arguments.get("slot", String(definition.slot)))
					if not Inventory.slot_accepts(definition, slot):
						return _failure("This item cannot be equipped.")
					if not entry.identified:
						return _failure("Identify the hidden properties before equipping this item.")
					if int(profile.get("character", {}).get("level", 1)) < definition.required_level:
						return _failure("This equipment requires level %d." % definition.required_level)
					if next.equipment[slot] == uid:
						return _failure("This instance is already equipped.")
					# Move an existing assignment atomically; one owned instance cannot
					# contribute through both loadouts or two armor slots.
					for previous: String in next.equipment:
						if next.equipment[previous] == uid:
							next.equipment[previous] = ""
					next.equipment[slot] = uid
					_resolve_active_loadout(next)
					result.message = "Equipped " + definition.label
				&"sell":
					if Inventory.is_protected(next, entry):
						return _failure("Unlock, unfavorite, unequip and remove this item from displays before selling.")
					if count > int(entry.quantity):
						return _failure("You do not own that quantity in the selected stack.")
					result.gold_gain = sell_price(entry) * count
					if int(next.gold) > Inventory.MAX_COUNT - int(result.gold_gain):
						return _failure("This sale would exceed the DM limit.", result)
					_remove_selected(next, entry, count)
					next.gold += result.gold_gain
					result.message = "Sold %s ×%d for %d DM" % [definition.label, count, result.gold_gain]
				&"upgrade":
					if not entry.identified:
						return _failure("Identify the equipment's hidden properties before upgrading.")
					var costs := upgrade_cost(entry)
					result["enhancement_quote"] = costs.duplicate(true)
					if not bool(costs.get("ok", false)):
						return _failure(String(costs.get("error", "This item cannot be enhanced.")), result)
					if int(entry.durability) <= 0:
						return _failure("Repair broken equipment before upgrading.")
					result.cost_gold = costs.gold
					result.materials = costs.materials.duplicate(true)
					# Affordability failures still show the exact proposed item/stats;
					# neither the original instance nor its rolled modifiers changes.
					result.after = entry.duplicate(true)
					result.after.enhancement = int(costs.next_level)
					if not _spend(next, result.cost_gold) or not Inventory.consume_items(next, result.materials):
						return _failure("The upgrade needs %d DM and the listed unlocked materials." % int(result.cost_gold), result)
					# consume_items replaces its inventory copy; reacquire by identity.
					entry = Inventory.find(next, uid)
					entry.enhancement = int(costs.next_level)
					result.message = "%s upgraded to +%d · guaranteed" % [definition.label, entry.enhancement]
				&"repair":
					if definition.category != "equipment" or int(entry.durability) >= 100:
						return _failure("This equipment does not need repair.")
					result.cost_gold = repair_cost(entry)
					if not _spend(next, result.cost_gold):
						return _failure("You need %d DM to restore this equipment." % int(result.cost_gold), result)
					entry.durability = 100
					result.message = definition.label + " repaired to full condition"
				&"salvage":
					if definition.category != "equipment" or Inventory.is_protected(next, entry) or definition.salvage.is_empty():
						return _failure("Choose unprotected, unequipped equipment that is not on display.")
					result.outputs = definition.salvage.duplicate(true)
					_remove_selected(next, entry, 1)
					if not Inventory.add_items(next, result.outputs, int(profile.revision)):
						return _failure("Make room for the salvage materials before confirming.", result)
					result.message = "Salvaged " + definition.label
				&"identify":
					if entry.identified or definition.category != "equipment":
						return _failure("This item has no hidden properties to identify.")
					result.cost_gold = maxi(20, ceili(float(definition.value) * 0.3))
					if not _spend(next, result.cost_gold):
						return _failure("You need %d DM for appraisal." % int(result.cost_gold), result)
					entry.identified = true
					result.message = "Identified " + definition.label
				&"use":
					if definition.category != "consumable" or Inventory.is_protected(next, entry):
						return _failure("Choose an unlocked, unfavorited consumable from your inventory.")
					_remove_selected(next, entry, 1)
					result.message = "Used " + definition.label
			result.after = Inventory.find(next, uid).duplicate(true)
	for item_id: String in result.outputs:
		if Catalog.item_for(item_id) != null and not next.discoveries.has(item_id):
			next.discoveries.append(item_id)
	if action == &"identify" and not next.discoveries.has(entry.item_id):
		next.discoveries.append(entry.item_id)
	next.discoveries.sort()
	Inventory.sync_mirrors(next)
	if Inventory.normalize_fields(next).is_empty():
		return _failure("The resulting inventory did not pass validation. Nothing changed.")
	return result

static func upgrade_cost(entry: Dictionary) -> Dictionary:
	var definition := Catalog.item_for(String(entry.get("item_id", "")))
	var rank: Variant = entry.get("enhancement", 0)
	return Enhancement.quote(definition, int(rank) if rank is int else -1)

static func _resolve_active_loadout(profile: Dictionary) -> void:
	var active_slot := Inventory.active_weapon_slot(profile)
	if not String(profile.equipment.get(active_slot, "")).is_empty():
		return
	for slot: String in Inventory.LOADOUT_SLOTS:
		if not String(profile.equipment.get(slot, "")).is_empty():
			profile.active_loadout = slot
			return
	profile.active_loadout = "main_weapon"

static func repair_cost(entry: Dictionary) -> int:
	var definition := Catalog.item_for(String(entry.get("item_id", "")))
	if definition == null:
		return 0
	return maxi(3, ceili(float(100 - int(entry.get("durability", 100))) * float(definition.value) / 400.0))

static func sell_price(entry: Dictionary) -> int:
	var definition := Catalog.item_for(String(entry.get("item_id", "")))
	if definition == null:
		return 0
	var condition := 0.25 + float(entry.get("durability", 100)) * 0.0075
	var known := 1.0 if bool(entry.get("identified", true)) else 0.25
	return maxi(1, floori(float(definition.value) * 0.4 * condition * known * (1.0 + float(entry.get("enhancement", 0)) * 0.05)))

static func _stock(vendor: String, completed: int) -> Array:
	var script := load("res://scripts/progression/merchant_catalog.gd") as Script
	return script.stock(vendor, completed) if script != null else []

static func _recipe(id: String) -> Dictionary:
	var script := load("res://scripts/progression/recipe_catalog.gd") as Script
	return script.recipe_for(id) if script != null else {}

static func _spend(profile: Dictionary, amount: int) -> bool:
	if amount < 0 or int(profile.gold) < amount:
		return false
	profile.gold -= amount
	return true

static func _remove_selected(profile: Dictionary, entry: Dictionary, quantity: int) -> void:
	entry.quantity -= quantity
	if entry.quantity <= 0:
		profile.inventory = profile.inventory.filter(func(candidate: Dictionary) -> bool: return candidate.uid != entry.uid)

static func _failure(message: String, preview_data: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "error": message, "message": message, "cost_gold": 0,
		"gold_gain": 0, "materials": {}, "outputs": {}, "before": {}, "after": {}}
	for key: String in ["cost_gold", "gold_gain", "materials", "outputs", "before", "after", "enhancement_quote"]:
		if preview_data.has(key):
			result[key] = preview_data[key]
	return result.duplicate(true)
