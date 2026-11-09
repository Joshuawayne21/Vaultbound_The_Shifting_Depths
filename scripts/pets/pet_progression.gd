class_name VaultPetProgression
extends RefCounted
## Pure cosmetic collection planning. Session admits real sources; ProfileStore saves.
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
const COUNTERS := ["eggs_found", "rescues", "rootwarden_victories"]
const TesterAccess = preload("res://scripts/progression/tester_access.gd")
const KEYS := ["ingredients", "ingredient_discoveries", "weave_seeds", "owned", "active_id", "recipe_discoveries", "achievements", "statistics"]

static func empty_fields() -> Dictionary:
	return {"ingredients": {}, "ingredient_discoveries": [], "weave_seeds": {}, "owned": {}, "active_id": "", "recipe_discoveries": [], "achievements": [], "statistics": {"eggs_found": 0, "rescues": 0, "rootwarden_victories": 0}}

static func empty_pending() -> Dictionary:
	return {"ingredients": {}, "weave_seeds": {}, "statistics": {"eggs_found": 0, "rescues": 0, "rootwarden_victories": 0}, "sources": {}}

static func valid_alias(value: Variant) -> bool:
	if not value is String or value.length() > 24 or value.to_utf8_buffer().size() > 96 or value != value.strip_edges():
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029] or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069):
			return false
	return true

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 96 and value.is_valid_identifier()

static func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= Catalog.MAX_COUNT

static func normalize(value: Variant, allow_unavailable: bool = false) -> Dictionary:
	if not value is Dictionary or value.size() != KEYS.size():
		return {}
	for key: String in KEYS:
		if not value.has(key):
			return {}
	var ingredients := Catalog.ingredients()
	var result := empty_fields()
	for key: String in ["ingredients", "weave_seeds", "owned", "statistics"]:
		if not value[key] is Dictionary:
			return {}
	if value.ingredients.size() > 32 or value.weave_seeds.size() > 8 or value.owned.size() > 8 or value.statistics.size() != COUNTERS.size():
		return {}
	for id: Variant in value.ingredients:
		if not _id(id) or (not allow_unavailable and not ingredients.has(id)) or not _integer(value.ingredients[id], 1):
			return {}
		result.ingredients[id] = int(value.ingredients[id])
	for key: String in ["ingredient_discoveries", "recipe_discoveries", "achievements"]:
		if not value[key] is Array or value[key].size() > 32:
			return {}
		for id: Variant in value[key]:
			if not _id(id) or result[key].has(id):
				return {}
			if not allow_unavailable:
				if key == "ingredient_discoveries" and not ingredients.has(id):
					return {}
				if key == "recipe_discoveries" and Catalog.recipe_for(StringName(id)) == null:
					return {}
				if key == "achievements" and not Catalog.POLICY.achievement_rules.has(id):
					return {}
			result[key].append(id)
		result[key].sort()
	for id: String in result.ingredients:
		if not result.ingredient_discoveries.has(id):
			return {}
	for id: Variant in value.weave_seeds:
		if not _id(id) or (not allow_unavailable and not Catalog.IDS.has(id)) or not _integer(value.weave_seeds[id]) or not result.ingredient_discoveries.has(String(id) + "_memory"):
			return {}
		result.weave_seeds[id] = int(value.weave_seeds[id])
	for id: Variant in value.owned:
		if not _id(id) or (not allow_unavailable and not Catalog.IDS.has(id)) or not result.weave_seeds.has(id):
			return {}
		var entry: Variant = value.owned[id]
		if not entry is Dictionary or entry.size() != 3 or not valid_alias(entry.get("alias")) or not _id(entry.get("variant")) or (not allow_unavailable and not Catalog.VARIANTS.has(entry.variant)):
			return {}
		var origin: Variant = entry.get("origin")
		if not origin is Dictionary or origin.size() != 4 or not _id(origin.get("method")) or not _id(origin.get("biome")) or origin.get("recipe_id") != "weave_" + String(id) or not _integer(origin.get("completed_expeditions")) or not result.recipe_discoveries.has(origin.recipe_id):
			return {}
		if not allow_unavailable and (origin.method != "spiritweaving" or origin.biome != "rootbound_abyss"):
			return {}
		result.owned[id] = {"alias": entry.alias, "variant": entry.variant, "origin": {"method": origin.method, "biome": origin.biome, "recipe_id": origin.recipe_id, "completed_expeditions": int(origin.completed_expeditions)}}
	if not value.active_id is String or (not value.active_id.is_empty() and not result.owned.has(value.active_id)):
		return {}
	result.active_id = value.active_id
	for key: String in COUNTERS:
		if not _integer(value.statistics.get(key)):
			return {}
		result.statistics[key] = int(value.statistics[key])
	return result

static func has_unavailable(value: Variant) -> bool:
	if normalize(value, true).is_empty():
		return false
	return normalize(value).is_empty()

static func append_findings(pending: Dictionary, findings: Dictionary, receipt: String) -> Dictionary:
	if findings.is_empty() or pending.sources.has(receipt) or receipt.is_empty():
		return {}
	var next := pending.duplicate(true)
	for id: String in findings.ingredients:
		var count := int(findings.ingredients[id])
		if count < 1 or int(next.ingredients.get(id, 0)) > Catalog.MAX_COUNT - count:
			return {}
		next.ingredients[id] = int(next.ingredients.get(id, 0)) + count
	for id: String in findings.weave_seeds:
		if not next.weave_seeds.has(id):
			next.weave_seeds[id] = findings.weave_seeds[id]
	for key: String in COUNTERS:
		if int(next.statistics[key]) > Catalog.MAX_COUNT - int(findings.statistics[key]):
			return {}
		next.statistics[key] += int(findings.statistics[key])
	next.sources[receipt] = true
	return next

static func secure(profile: Dictionary, pending: Dictionary) -> Dictionary:
	var pets: Dictionary = profile.pets.duplicate(true)
	for id: String in pending.ingredients:
		var count := int(pending.ingredients[id])
		if int(pets.ingredients.get(id, 0)) > Catalog.MAX_COUNT - count:
			return {}
		pets.ingredients[id] = int(pets.ingredients.get(id, 0)) + count
		if not pets.ingredient_discoveries.has(id):
			pets.ingredient_discoveries.append(id)
	for id: String in pending.weave_seeds:
		if not pets.weave_seeds.has(id):
			pets.weave_seeds[id] = pending.weave_seeds[id]
		var recipe_id := "weave_" + id
		if not pets.recipe_discoveries.has(recipe_id):
			pets.recipe_discoveries.append(recipe_id)
	for key: String in COUNTERS:
		if int(pets.statistics[key]) > Catalog.MAX_COUNT - int(pending.statistics[key]):
			return {}
		pets.statistics[key] += int(pending.statistics[key])
	for id: String in Catalog.POLICY.achievement_rules:
		var rule: Dictionary = Catalog.POLICY.achievement_rules[id]
		var count := int(profile.statistics.completed) if rule.stat == "completed" else int(pets.statistics.get(rule.stat, 0))
		if count >= int(rule.target) and not pets.achievements.has(id):
			pets.achievements.append(id)
	return normalize(pets)

static func active_appearance(profile: Dictionary) -> Dictionary:
	var pets: Dictionary = profile.pets
	var id := String(pets.active_id)
	if id.is_empty():
		return {"id": "", "display_name": "", "variant": "natural"}
	var entry: Dictionary = pets.owned[id]
	return {"id": id, "display_name": String(entry.alias) if not String(entry.alias).is_empty() else Catalog.definition_for(StringName(id)).label, "variant": String(entry.variant)}

static func ingredient_rows(values: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var labels := Catalog.ingredients()
	for id: String in labels:
		if int(values.get(id, 0)) > 0:
			result.append({"id": id, "label": labels[id], "quantity": int(values[id])})
	return result

static func recipe_snapshot(profile: Dictionary, id: String) -> Dictionary:
	var recipe := Catalog.recipe_for(StringName("weave_" + id))
	var result := {"id": String(recipe.id), "costs": [], "requirements": [], "can_create": true, "reason": "", "tester_access": TesterAccess.enabled(profile)}
	for ingredient: String in recipe.ingredient_costs:
		var required := int(recipe.ingredient_costs[ingredient])
		var count := int(profile.pets.ingredients.get(ingredient, 0))
		result.costs.append({"id": ingredient, "label": Catalog.ingredients()[ingredient], "required": required, "owned": count})
		if count < required:
			result.reason = "Find and extract the required ingredients."
	for achievement: StringName in recipe.achievement_requirements:
		var rule: Dictionary = Catalog.POLICY.achievement_rules[String(achievement)]
		var count := int(profile.statistics.completed) if rule.stat == "completed" else int(profile.pets.statistics.get(rule.stat, 0))
		var met: bool = profile.pets.achievements.has(String(achievement))
		result.requirements.append({"id": String(achievement), "label": rule.label, "current": count, "target": int(rule.target), "met": met, "test_access": not met and TesterAccess.enabled(profile)})
		if not met and not TesterAccess.enabled(profile):
			result.reason = String(rule.label)
	if not recipe.enabled:
		result.reason = "This combination is unavailable."
	if not profile.pets.weave_seeds.has(id):
		result.reason = "Find and extract this creature's memory."
	if profile.pets.owned.has(id):
		result.reason = "Already in your collection."
	result.can_create = String(result.reason).is_empty()
	return result

static func preview(profile: Dictionary, action: StringName, args: Dictionary) -> Dictionary:
	if (action == &"create" and not args.get("recipe_id") is String) or (action in [&"select", &"rename"] and not args.get("pet_id") is String):
		return {"ok": false, "error": "Choose a valid companion or recipe."}
	var pets: Dictionary = profile.pets
	var id := String(args.get("pet_id", ""))
	var result := {"ok": true, "title": "Spiritweaving", "message": "", "costs": [], "before": active_appearance(profile), "after": {}}
	if action == &"create":
		var recipe := Catalog.recipe_for(StringName(String(args.get("recipe_id", ""))))
		if recipe == null:
			return {"ok": false, "error": "Unknown Spiritweaving recipe."}
		id = String(recipe.pet_id)
		var details := recipe_snapshot(profile, id)
		if not details.can_create:
			return {"ok": false, "error": details.reason}
		result.costs = details.costs
		result.after = {"id": id, "display_name": Catalog.definition_for(StringName(id)).label, "variant": Catalog.variant_for(int(pets.weave_seeds[id]), String(recipe.id))}
		result.message = "Create %s · cosmetic companion only" % result.after.display_name
	elif action in [&"select", &"rename"]:
		if not pets.owned.has(id):
			return {"ok": false, "error": "That companion is not owned."}
		var entry: Dictionary = pets.owned[id]
		var alias := String(entry.alias)
		if action == &"rename":
			if not args.get("alias") is String:
				return {"ok": false, "error": "Enter a valid name."}
			alias = String(args.alias).strip_edges()
			if not valid_alias(alias):
				return {"ok": false, "error": "Names allow 24 characters / 96 UTF-8 bytes without control characters."}
		result.after = {"id": id, "display_name": alias if not alias.is_empty() else Catalog.definition_for(StringName(id)).label, "variant": String(entry.variant), "alias": alias}
		result.message = "Rename this companion to %s" % result.after.display_name if action == &"rename" else "Select %s as your cosmetic companion" % result.after.display_name
	elif action == &"rest":
		result.after = {"id": "", "display_name": "", "variant": "natural"}
		result.message = "Rest this cosmetic companion at the Conservatory"
	else:
		return {"ok": false, "error": "Unknown companion action."}
	return result

static func plan(profile: Dictionary, action: StringName, args: Dictionary, request_id: String, revision: int) -> Dictionary:
	if revision != int(profile.revision) or profile.transaction_receipts.has(request_id) or int(profile.revision) >= Catalog.MAX_COUNT:
		return {"ok": false, "error": "Progress changed. Review this companion again."}
	var shown := preview(profile, action, args)
	if not shown.ok:
		return shown
	var next := profile.duplicate(true)
	var id := String(shown.after.id)
	if action == &"create":
		var recipe := Catalog.recipe_for(StringName(String(args.recipe_id)))
		for ingredient: String in recipe.ingredient_costs:
			next.pets.ingredients[ingredient] -= int(recipe.ingredient_costs[ingredient])
			if int(next.pets.ingredients[ingredient]) == 0:
				next.pets.ingredients.erase(ingredient)
		next.pets.owned[id] = {"alias": "", "variant": shown.after.variant, "origin": {"method": "spiritweaving", "biome": "rootbound_abyss", "recipe_id": String(recipe.id), "completed_expeditions": int(profile.statistics.completed)}}
		if not next.pets.recipe_discoveries.has(String(recipe.id)):
			next.pets.recipe_discoveries.append(String(recipe.id))
		next.pets.active_id = id
	elif action == &"rename":
		next.pets.owned[id].alias = shown.after.alias
	else:
		next.pets.active_id = id
	next.revision += 1
	next.transaction_receipts.append(request_id)
	if next.transaction_receipts.size() > VaultInventory.MAX_RECEIPTS:
		next.transaction_receipts.pop_front()
	var message := "Companion name saved" if action == &"rename" else "Companion resting at the Conservatory" if action == &"rest" else "%s joined your collection · saved" % shown.after.display_name if action == &"create" else "Companion selected · saved"
	return {"ok": true, "profile": next, "message": message}
