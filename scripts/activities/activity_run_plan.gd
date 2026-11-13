extends RefCounted
## Frozen, bounded source rewards. Different visits have distinct persistent receipts.
const DEFINITION = preload("res://resources/activities/beastwilds.tres")
const MAX_COUNT := 2147483647
const ID := "beastwilds"
const WORLD_SCRIPT := "res://scripts/activities/beastwilds_level.gd"
const SOURCE_SCRIPT := "res://scripts/activities/activity_discovery.gd"
const EXIT_SCRIPT := "res://scripts/activities/activity_exit.gd"
const SOURCE_IDS := ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]
const REQUIRED_IDS := ["trail_marker", "glade_egg", "pool_rescue"]
const PLAN_KEYS := ["activity_id", "definition_version", "serial", "seed", "definition", "sources", "exit"]
const SLOT_KEYS := ["slot_id", "kind", "required", "receipt", "reward"]

static func integer(value: Variant, minimum: int, maximum: int = MAX_COUNT) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func exact_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in value:
		if key not in keys: return false
	return true

static func definition() -> Dictionary:
	return DEFINITION.snapshot().duplicate(true)

static func seed_for(seed_value: int, serial: int, slot_id: String) -> int:
	return int(("vaultbound_activity_v1|%d|%d|%s" % [seed_value, serial, slot_id]).sha256_text().substr(0, 8).hex_to_int()) & MAX_COUNT

static func create(seed_value: int, serial: int) -> Dictionary:
	if not integer(seed_value, 0) or not integer(serial, 1, MAX_COUNT - 1): return {}
	var rules := definition()
	return _build(seed_value, serial, rules) if _definition_valid(rules) else {}

static func _definition_valid(value: Variant) -> bool:
	var keys := ["activity_id", "definition_version", "display_name", "required_cleared_depth", "egg_depthmarks", "rescue_depthmarks", "forage_depthmarks", "forage_fiber"]
	if not exact_keys(value, keys) or value.activity_id != ID or value.definition_version != 1 \
			or value.display_name != "The Beastwilds" or value.required_cleared_depth != 2: return false
	for key: String in ["egg_depthmarks", "rescue_depthmarks", "forage_depthmarks", "forage_fiber"]:
		var bounds: Variant = value[key]
		if not bounds is Array or bounds.size() != 2 or not integer(bounds[0], 1 if key == "forage_fiber" else 0, 50) \
				or not integer(bounds[1], int(bounds[0]), 50): return false
	return true

static func _build(seed_value: int, serial: int, rules: Dictionary) -> Dictionary:
	var sources: Array[Dictionary] = []
	for id: String in SOURCE_IDS:
		var kind := "track" if id == "trail_marker" else "egg" if id == "glade_egg" else "rescue" if id == "pool_rescue" else "treasure"
		var receipt := "activity_beastwilds_%d_%s" % [serial, id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_for(seed_value, serial, id)
		var gold := 0
		var items: Array[Dictionary] = []
		if kind != "track":
			var bounds: Array = rules["forage_depthmarks" if kind == "treasure" else kind + "_depthmarks"]
			gold = rng.randi_range(int(bounds[0]), int(bounds[1]))
		if kind == "treasure":
			items.append({"id": "root_fiber", "quantity": rng.randi_range(int(rules.forage_fiber[0]), int(rules.forage_fiber[1]))})
		sources.append({"slot_id": id, "kind": kind, "required": id in REQUIRED_IDS, "receipt": receipt,
			"reward": {"chest_id": receipt, "category": "common", "gold": gold, "items": items}})
	return {"activity_id": ID, "definition_version": 1, "serial": serial, "seed": seed_value,
		"definition": rules.duplicate(true), "sources": sources,
		"exit": {"slot_id": "return_spring", "kind": "exit", "receipt": "activity_beastwilds_%d_return_spring" % serial}}

static func valid(value: Variant) -> bool:
	if not exact_keys(value, PLAN_KEYS) or value.activity_id != ID or value.definition_version != 1 \
			or not integer(value.serial, 1, MAX_COUNT - 1) or not integer(value.seed, 0) \
			or not _definition_valid(value.definition): return false
	# Reconstruct using the frozen settings, not a potentially edited live Resource.
	return value == _build(int(value.seed), int(value.serial), value.definition)

static func digest(plan: Dictionary) -> String:
	return JSON.stringify(plan, "", true, true).sha256_text() if valid(plan) else ""

static func source(plan: Dictionary, slot_id: String) -> Dictionary:
	if not valid(plan): return {}
	for entry: Dictionary in plan.sources:
		if entry.slot_id == slot_id: return entry.duplicate(true)
	return {}

static func objectives_complete(claimed: Dictionary) -> bool:
	for id: String in REQUIRED_IDS:
		if claimed.get(id) != true: return false
	return true
