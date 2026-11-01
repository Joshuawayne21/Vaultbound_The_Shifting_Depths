class_name VaultPetCatalog
extends RefCounted

const IDS := ["lantern_fox", "crystal_moth", "mossdrake", "embercap_sprite", "rift_otter", "rootling_guardian", "moonveil_butterfly", "starbound_wisp"]
const VARIANTS := ["natural", "luminous"]
const POLICY = preload("res://resources/pets/acquisition.tres")
const MAX_COUNT := 2147483647

static func definition_for(id: StringName) -> VaultPetDefinition:
	if not IDS.has(String(id)):
		return null
	return load("res://resources/pets/%s.tres" % id) as VaultPetDefinition

static func recipe_for(id: StringName) -> VaultPetRecipe:
	var pet_id := String(id).trim_prefix("weave_")
	if String(id) != "weave_" + pet_id or not IDS.has(pet_id):
		return null
	return load("res://resources/pets/weave_%s.tres" % pet_id) as VaultPetRecipe

static func ingredients() -> Dictionary:
	var result := {"rootbound_essence": "Rootbound Essence", "mysterious_egg": "Mysterious Egg", "pet_vessel": "Spirit Vessel"}
	for id: String in IDS:
		result[id + "_memory"] = definition_for(StringName(id)).label + " Memory"
	return result

static func stable_seed(seed_value: int, receipt: String, namespace_id: String) -> int:
	var text := "vaultbound_pets_v1|%d|%s|%s" % [seed_value, receipt, namespace_id]
	return int(text.sha256_text().substr(0, 8).hex_to_int()) & MAX_COUNT

static func variant_for(seed_value: int, recipe_id: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed(seed_value, recipe_id, "mutation")
	return "luminous" if rng.randf() < POLICY.luminous_chance else "natural"

static func findings_for(seed_value: int, receipt: String, kind: String) -> Dictionary:
	var result := {"ingredients": {}, "weave_seeds": {}, "statistics": {"eggs_found": 0, "rescues": 0, "rootwarden_victories": 0}}
	if kind in ["regular", "elite", "boss"]:
		result.ingredients.rootbound_essence = POLICY.boss_essence if kind == "boss" else POLICY.elite_essence if kind == "elite" else POLICY.regular_essence
		if kind == "boss":
			result.ingredients.pet_vessel = 1
			result.ingredients.rootling_guardian_memory = 1
			result.weave_seeds.rootling_guardian = stable_seed(seed_value, receipt, "rootling_guardian")
			result.statistics.rootwarden_victories = 1
	elif kind in ["egg", "rescue"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = stable_seed(seed_value, receipt, "memory")
		var total := 0
		for id: String in IDS:
			total += int(POLICY.memory_weights.get(id, 0))
		var roll := rng.randi_range(1, maxi(1, total))
		var chosen: String = IDS[0]
		for id: String in IDS:
			roll -= int(POLICY.memory_weights.get(id, 0))
			if roll <= 0:
				chosen = id
				break
		result.ingredients[chosen + "_memory"] = 1
		result.ingredients["mysterious_egg" if kind == "egg" else "pet_vessel"] = 1
		result.weave_seeds[chosen] = stable_seed(seed_value, receipt, chosen)
		result.statistics["eggs_found" if kind == "egg" else "rescues"] = 1
	else:
		return {}
	return result
