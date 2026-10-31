class_name CharacterProgression
extends RefCounted
## Pure progression/stat resolution. Profile persistence and transaction authority
## remain with ExpeditionSession; no scene, camera or network state is consulted.

const DATA = preload("res://resources/progression/character_progression.tres")
const LEVEL_CAP := 30
const EXPERIENCE_CAP := 46400
const TALENT_IDS := ["offense", "defense", "utility"]
const SLOT_IDS := ["main_weapon", "off_hand", "helmet", "chest_armor", "boots", "accessory"]
const STAT_LIMITS := {"max_health": 80.0, "max_stamina": 60.0, "damage_bonus": 0.35, "armor": 0.20, "stamina_regen": 8.0}

static func empty_character() -> Dictionary:
	return {"level": 1, "experience": 0, "talents": {"offense": 0, "defense": 0, "utility": 0}}

static func normalize_character(value: Variant) -> Dictionary:
	if not value is Dictionary or not _integer(value.get("level"), 1, LEVEL_CAP) or not _integer(value.get("experience"), 0, EXPERIENCE_CAP):
		return {}
	if int(value.level) != level_for_xp(int(value.experience)) or not value.get("talents") is Dictionary:
		return {}
	var result := empty_character()
	result.level = int(value.level)
	result.experience = int(value.experience)
	var spent := 0
	for id: Variant in value.talents:
		if not id is String or not TALENT_IDS.has(id):
			return {}
	for id: String in TALENT_IDS:
		var rank: Variant = value.talents.get(id, 0)
		if not _integer(rank, 0, int(DATA.talent_branches[id].max_rank)):
			return {}
		result.talents[id] = int(rank)
		spent += int(rank)
	if spent > result.level - 1:
		return {}
	return result

static func level_for_xp(experience: int) -> int:
	var level := 1
	for index in range(1, mini(LEVEL_CAP, DATA.experience_thresholds.size())):
		if experience < int(DATA.experience_thresholds[index]):
			break
		level = index + 1
	return level

static func award_xp(character: Dictionary, amount: int) -> Dictionary:
	var result := normalize_character(character)
	if result.is_empty() or amount < 0:
		return {}
	# Clamp before adding, avoiding overflow from a malformed future caller.
	result.experience += mini(amount, EXPERIENCE_CAP - int(result.experience))
	result.level = level_for_xp(result.experience)
	return result

static func allocate(character: Dictionary, branch: String) -> Dictionary:
	var result := normalize_character(character)
	if result.is_empty() or not TALENT_IDS.has(branch):
		return {}
	if unspent_points(result) < 1 or int(result.talents[branch]) >= int(DATA.talent_branches[branch].max_rank):
		return {}
	result.talents[branch] += 1
	return result

static func unspent_points(character: Dictionary) -> int:
	var spent := 0
	for id: String in TALENT_IDS:
		spent += int(character.get("talents", {}).get(id, 0))
	return maxi(0, int(character.get("level", 1)) - 1 - spent)

static func branches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in TALENT_IDS:
		var branch: Dictionary = DATA.talent_branches[id].duplicate(true)
		branch.id = id
		result.append(branch)
	return result

static func snapshot(character: Dictionary) -> Dictionary:
	var result := normalize_character(character)
	if result.is_empty():
		result = empty_character()
	var level: int = result.level
	result.talent_points = unspent_points(result)
	result.next_level_experience = int(DATA.experience_thresholds[level]) if level < LEVEL_CAP else EXPERIENCE_CAP
	result.level_start_experience = int(DATA.experience_thresholds[level - 1])
	result.level_cap = LEVEL_CAP
	result.branches = branches()
	return result

static func item_stats(entry: Dictionary) -> Dictionary:
	var result := {"max_health": 0.0, "max_stamina": 0.0, "damage_bonus": 0.0, "armor": 0.0, "stamina_regen": 0.0}
	var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
	if definition == null or definition.category != "equipment" or not bool(entry.get("identified", true)) or int(entry.get("durability", 100)) <= 0:
		return result
	var raw_stats: Variant = definition.get("base_stats")
	var base: Dictionary = raw_stats if raw_stats is Dictionary else {}
	var modifiers: Variant = entry.get("modifiers", {})
	var enhancement := clampi(int(entry.get("enhancement", 0)), 0, 5)
	for key: String in STAT_LIMITS:
		var value := _safe_stat(base.get(key, 0.0), float(STAT_LIMITS[key])) * (1.0 + 0.08 * enhancement)
		if modifiers is Dictionary:
			value += _safe_stat(modifiers.get(key, 0.0), float(STAT_LIMITS[key]) * 0.25)
		result[key] = value
	return result

static func resolve_stats(profile: Dictionary, weapon_style: StringName = &"sword", normalized: bool = false) -> Dictionary:
	# A future PvP mode can opt into this explicit equal-stat policy. It grants
	# no networking or remote authority and never mutates earned progression.
	var character := empty_character() if normalized else normalize_character(profile.get("character", empty_character()))
	if character.is_empty():
		character = empty_character()
	var level: int = character.level
	var result := {"max_health": float(DATA.health_by_level[level - 1]),
		"max_stamina": float(DATA.stamina_by_level[level - 1]), "damage_multiplier": 1.0,
		"armor": 0.0, "stamina_regen": 23.0, "appearance": {}, "level": level,
		"talent_points": unspent_points(character), "normalized": normalized}
	if normalized:
		return result
	var bonus := {"max_health": 0.0, "max_stamina": 0.0, "damage_bonus": 0.0, "armor": 0.0, "stamina_regen": 0.0}
	for branch: String in TALENT_IDS:
		var data: Dictionary = DATA.talent_branches[branch]
		for key: String in data.bonuses:
			bonus[key] += float(data.bonuses[key]) * int(character.talents[branch])
	var equipped: Variant = profile.get("equipment", {})
	var inventory: Variant = profile.get("inventory", [])
	if equipped is Dictionary and inventory is Array:
		var seen: Array[String] = []
		for slot: String in SLOT_IDS:
			var uid := String(equipped.get(slot, ""))
			if uid.is_empty() or seen.has(uid):
				continue
			var entry := _find(inventory, uid)
			if entry.is_empty() or not bool(entry.get("identified", true)):
				continue
			var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
			if definition == null or definition.category != "equipment" or String(definition.get("slot")) != slot:
				continue
			if level < int(definition.get("required_level")):
				continue
			seen.append(uid)
			result.appearance[slot] = {"item_id": String(definition.id), "label": definition.label,
				"rarity": definition.rarity, "enhancement": int(entry.get("enhancement", 0)), "weapon_style": String(definition.weapon_style)}
			# Swapping to the other original family does not borrow a weapon or
			# shield bonus that belongs to the equipped family's authored mechanics.
			if slot in ["main_weapon", "off_hand"] and definition.weapon_style != &"" and definition.weapon_style != weapon_style:
				continue
			var additions := item_stats(entry)
			for key: String in bonus:
				bonus[key] += float(additions.get(key, 0.0))
	result.max_health = clampf(result.max_health + bonus.max_health, 100.0, 500.0)
	result.max_stamina = clampf(result.max_stamina + bonus.max_stamina, 100.0, 350.0)
	result.damage_multiplier = clampf(1.0 + bonus.damage_bonus, 1.0, 2.0)
	result.armor = clampf(bonus.armor, 0.0, 0.55)
	result.stamina_regen = clampf(result.stamina_regen + bonus.stamina_regen, 23.0, 45.0)
	return result

static func compare_item(profile: Dictionary, uid: String, weapon_style: StringName = &"sword") -> Dictionary:
	var current := resolve_stats(profile, weapon_style)
	var entry := _find(profile.get("inventory", []), uid)
	var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
	if definition == null or definition.category != "equipment":
		return {"current": current, "candidate": current.duplicate(true), "difference": {}}
	var candidate := profile.duplicate(true)
	var slot := String(definition.get("slot"))
	if not SLOT_IDS.has(slot):
		return {"current": current, "candidate": current.duplicate(true), "difference": {}}
	if not candidate.get("equipment") is Dictionary:
		candidate.equipment = {}
	candidate.equipment[slot] = uid
	var family: StringName = definition.weapon_style if slot == "main_weapon" else weapon_style
	var after := resolve_stats(candidate, family)
	var difference := {}
	for key: String in ["max_health", "max_stamina", "damage_multiplier", "armor", "stamina_regen"]:
		difference[key] = float(after[key]) - float(current[key])
	return {"current": current, "candidate": after, "difference": difference}

static func _find(inventory: Array, uid: String) -> Dictionary:
	for entry: Variant in inventory:
		if entry is Dictionary and entry.get("uid", "") == uid:
			return entry
	return {}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _safe_stat(value: Variant, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0.0
	return clampf(float(value), 0.0, maximum)
