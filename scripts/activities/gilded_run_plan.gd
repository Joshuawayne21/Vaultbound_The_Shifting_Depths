extends RefCounted
## Six native modules, a physical rune sequence, one original Golem and two caches.
const Base = preload("res://scripts/activities/activity_run_plan.gd")
const NativeActor = preload("res://scripts/activities/echoes_run_plan.gd")
const DEFINITION = preload("res://resources/activities/gilded_vault.tres")
const ID := "gilded_vault"
const WORLD_SCRIPT := "res://scripts/activities/gilded_level.gd"
const CLUE_SCRIPT := "res://scripts/activities/gilded_clue.gd"
const PUZZLE_SCRIPT := "res://scripts/activities/gilded_puzzle.gd"
const PLATE_SCRIPT := "res://scripts/activities/gilded_plate.gd"
const SOURCE_SCRIPT := "res://scripts/activities/gilded_treasury.gd"
const REVEAL_SCRIPT := "res://scripts/activities/gilded_reveal.gd"
const TRAP_SCRIPT := "res://scripts/activities/gilded_trap.gd"
const ROOM_SIZE := 24
const MODULES := ["entrance_temple", "corridor_roots", "treasure_garden", "combat_temple", "treasure_vault", "secret_hollow"]
const SOURCE_IDS := ["clue_tablet", "rune_puzzle", "plate_sun", "plate_moon", "plate_star", "guardian",
	"main_treasury", "hidden_reveal", "optional_treasury", "optional_trap", "return_spring"]
const REQUIRED_IDS := ["rune_puzzle", "guardian", "main_treasury"]
const CLAIM_IDS := ["rune_puzzle", "guardian", "main_treasury", "hidden_reveal", "optional_trap", "optional_treasury"]
const RUNES := ["sun", "moon", "star"]
const PLAN_KEYS := ["activity_id", "definition_version", "serial", "seed", "definition", "layout", "sources", "puzzle", "guardian", "treasuries", "trap", "exit"]
const DEFINITION_KEYS := ["activity_id", "definition_version", "display_name", "required_cleared_depth",
	"main_depthmarks", "optional_depthmarks", "main_ore", "optional_fiber", "spoon_weight", "tonic_chance",
	"trap_warning_seconds", "trap_active_seconds", "trap_recovery_seconds", "trap_damage", "guardian_data"]
const GOLEM_DATA = preload("res://resources/enemies/golem.tres")

static func definition() -> Dictionary:
	var result: Dictionary = DEFINITION.snapshot()
	result.guardian_data = NativeActor.data_snapshot(GOLEM_DATA, "golem")
	return result

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _definition_valid(value: Variant) -> bool:
	if not Base.exact_keys(value, DEFINITION_KEYS) or value.activity_id != ID or value.definition_version != 1 \
			or value.display_name != "The Gilded Vault" or value.required_cleared_depth != 5 \
			or not NativeActor._data_valid(value.guardian_data, "golem"): return false
	for key: String in ["main_depthmarks", "optional_depthmarks", "main_ore", "optional_fiber"]:
		var bounds: Variant = value[key]
		var material := key in ["main_ore", "optional_fiber"]
		if not bounds is Array or bounds.size() != 2 or not Base.integer(bounds[0], 1 if material else 0, 6 if material else 100) \
				or not Base.integer(bounds[1], int(bounds[0]), 6 if material else 100): return false
	return Base.integer(value.spoon_weight, 0, 100) and Base.integer(value.tonic_chance, 0, 100) \
		and _number(value.trap_warning_seconds, 2.0, 5.0) and _number(value.trap_active_seconds, 0.1, 0.5) \
		and _number(value.trap_recovery_seconds, 0.3, 1.0) and _number(value.trap_damage, 1.0, 20.0)

static func seed_for(seed_value: int, serial: int, part: String) -> int:
	return int(("vaultbound_gilded_v1|%d|%d|%s" % [seed_value, serial, part]).sha256_text().substr(0, 8).hex_to_int()) & Base.MAX_COUNT

static func receipt(serial: int, slot_id: String) -> String:
	return "activity_gilded_%d_%s" % [serial, slot_id]

static func create(seed_value: int, serial: int) -> Dictionary:
	if not Base.integer(seed_value, 0) or not Base.integer(serial, 1, Base.MAX_COUNT - 1): return {}
	var rules := definition()
	return _build(seed_value, serial, rules) if _definition_valid(rules) else {}

static func _direction(delta: Vector2i) -> String:
	if delta == Vector2i(0, -1): return "north"
	if delta == Vector2i(1, 0): return "east"
	if delta == Vector2i(0, 1): return "south"
	if delta == Vector2i(-1, 0): return "west"
	return ""

static func _layout(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(seed_value, 0, "topology")
	var side := -1 if rng.randi_range(0, 1) == 0 else 1
	var parent := 4 if rng.randi_range(0, 1) == 0 else 3
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(side, -2), Vector2i(side, -1)]
	cells.append(Vector2i(side * 2, -1) if parent == 4 else Vector2i(side, -3))
	var edges: Array = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 1], [parent, 5]]
	var rooms: Array[Dictionary] = []
	for index in range(cells.size()):
		var neighbors: Array[int] = []
		for edge: Array in edges:
			if edge[0] == index: neighbors.append(int(edge[1]))
			elif edge[1] == index: neighbors.append(int(edge[0]))
		neighbors.sort()
		var openings: Array[String] = []
		for neighbor: int in neighbors: openings.append(_direction(cells[neighbor] - cells[index]))
		rooms.append({"id": index, "cell": [cells[index].x, cells[index].y], "module_id": MODULES[index],
			"scene": "res://scenes/rooms/%s.tscn" % MODULES[index], "neighbors": neighbors, "openings": openings})
	return {"room_size": ROOM_SIZE, "entrance_id": 0, "treasury_id": 4, "optional_id": 5, "rooms": rooms, "hidden_edge": [parent, 5]}

static func _source(serial: int, id: String, kind: String, room_id: int, point: Array, script: String, yaw: float = 0.0) -> Dictionary:
	return {"slot_id": id, "kind": kind, "room_id": room_id, "position": point.duplicate(), "yaw": yaw,
		"script": script, "receipt": receipt(serial, id)}

static func _build(seed_value: int, serial: int, rules: Dictionary) -> Dictionary:
	var layout := _layout(seed_value)
	var parent: int = layout.hidden_edge[0]
	var from_cell: Array = layout.rooms[parent].cell
	var to_cell: Array = layout.rooms[5].cell
	var direction := Vector2i(int(to_cell[0]) - int(from_cell[0]), int(to_cell[1]) - int(from_cell[1]))
	var sources: Array[Dictionary] = []
	sources.append(_source(serial, "clue_tablet", "clue", 1, [-5.0, 0.0, 3.0], CLUE_SCRIPT))
	sources.append(_source(serial, "rune_puzzle", "puzzle", 2, [0.0, 0.0, 0.0], PUZZLE_SCRIPT))
	sources.append(_source(serial, "plate_sun", "plate", 2, [-4.4, 0.0, 2.2], PLATE_SCRIPT))
	sources.append(_source(serial, "plate_moon", "plate", 2, [0.0, 0.0, -2.6], PLATE_SCRIPT))
	sources.append(_source(serial, "plate_star", "plate", 2, [4.4, 0.0, 2.2], PLATE_SCRIPT))
	sources.append(_source(serial, "guardian", "guardian", 3, [0.0, 0.15, -2.0], "res://scripts/enemies/enemy.gd"))
	sources.append(_source(serial, "main_treasury", "treasury", 4, [6.0, 0.0, 6.0], SOURCE_SCRIPT))
	sources.append(_source(serial, "hidden_reveal", "reveal", parent, [direction.x * 9.3, 0.0, direction.y * 9.3], REVEAL_SCRIPT,
		-float(direction.x) * PI / 2.0 if direction.x != 0 else 0.0))
	sources.append(_source(serial, "optional_treasury", "treasury", 5, [0.0, 0.0, -2.0], SOURCE_SCRIPT))
	sources.append(_source(serial, "optional_trap", "trap", 5, [0.0, 0.0, -2.0], TRAP_SCRIPT))
	sources.append(_source(serial, "return_spring", "exit", 0, [6.0, 0.0, 2.0], Base.EXIT_SCRIPT))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(seed_value, 0, "runes")
	var order: Array = RUNES.duplicate()
	for cursor in range(order.size() - 1, 0, -1):
		var chosen := rng.randi_range(0, cursor)
		var previous: String = order[cursor]
		order[cursor] = order[chosen]
		order[chosen] = previous
	var actor := {"member_id": "guardian", "ordinal": 1, "archetype": "golem",
		"canonical_scene": "res://scenes/enemies/golem.tscn", "canonical_script": "res://scripts/enemies/enemy.gd",
		"data_snapshot": rules.guardian_data.duplicate(true), "receipt": receipt(serial, "guardian"), "boss_seed": 0, "modifier_id": "none"}
	var treasuries: Array[Dictionary] = []
	for id: String in ["main_treasury", "optional_treasury"]:
		var main := id == "main_treasury"
		rng.seed = seed_for(seed_value, serial, id + "_reward")
		var gold_bounds: Array = rules.main_depthmarks if main else rules.optional_depthmarks
		var material_bounds: Array = rules.main_ore if main else rules.optional_fiber
		var gold := rng.randi_range(int(gold_bounds[0]), int(gold_bounds[1]))
		var items: Array[Dictionary] = []
		items.append({"id": "iron_ore" if main else "root_fiber", "quantity": rng.randi_range(int(material_bounds[0]), int(material_bounds[1]))})
		if main: items.append({"id": "gilded_supper_spoon" if rng.randi_range(1, 100) <= int(rules.spoon_weight) else "amber_trapped_pollen", "quantity": 1})
		elif rng.randi_range(1, 100) <= int(rules.tonic_chance): items.append({"id": "mooncap_tonic", "quantity": 1})
		treasuries.append({"slot_id": id, "receipt": receipt(serial, id),
			"reward": {"chest_id": receipt(serial, id) + "_reward", "category": "common", "gold": gold, "items": items},
			"cache": {"room_id": 4 if main else 5, "position": [6.0, 0.15, 6.0] if main else [0.0, 0.15, -2.0], "kind": "elite" if main else "regular"}})
	return {"activity_id": ID, "definition_version": 1, "serial": serial, "seed": seed_value, "definition": rules.duplicate(true),
		"layout": layout, "sources": sources,
		"puzzle": {"receipt": receipt(serial, "rune_puzzle"), "order": order, "plate_ids": ["plate_sun", "plate_moon", "plate_star"],
			"inside_radius": 0.8, "rearm_radius": 1.0, "height_tolerance": 0.4},
		"guardian": {"slot_id": "guardian", "room_id": 3, "position": [0.0, 0.15, -2.0], "receipt": receipt(serial, "guardian"), "actor": actor},
		"treasuries": treasuries,
		"trap": {"slot_id": "optional_trap", "treasury_slot": "optional_treasury", "receipt": receipt(serial, "optional_trap"),
			"room_id": 5, "position": [0.0, 0.0, -2.0], "radius": 2.2, "height_tolerance": 2.0,
			"warning_seconds": rules.trap_warning_seconds, "active_seconds": rules.trap_active_seconds,
			"recovery_seconds": rules.trap_recovery_seconds, "damage": rules.trap_damage},
		"exit": {"slot_id": "return_spring", "kind": "exit", "receipt": receipt(serial, "return_spring")}}

static func valid(value: Variant) -> bool:
	if not Base.exact_keys(value, PLAN_KEYS) or value.activity_id != ID or value.definition_version != 1 \
			or not Base.integer(value.serial, 1, Base.MAX_COUNT - 1) or not Base.integer(value.seed, 0) or not _definition_valid(value.definition): return false
	return value == _build(int(value.seed), int(value.serial), value.definition)

static func digest(plan: Dictionary) -> String:
	return JSON.stringify(plan, "", true, true).sha256_text() if valid(plan) else ""

static func source(plan: Dictionary, slot_id: String) -> Dictionary:
	if not valid(plan): return {}
	for row: Dictionary in plan.sources:
		if row.slot_id == slot_id: return row.duplicate(true)
	return {}

static func treasury(plan: Dictionary, slot_id: String) -> Dictionary:
	if not valid(plan): return {}
	for row: Dictionary in plan.treasuries:
		if row.slot_id == slot_id: return row.duplicate(true)
	return {}

static func required_receipts(plan: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if valid(plan):
		for id: String in REQUIRED_IDS: result.append(receipt(int(plan.serial), id))
	return result

static func valid_claims(plan: Dictionary, claims: Dictionary) -> bool:
	if not valid(plan): return false
	var allowed: Array[String] = []
	for id: String in CLAIM_IDS: allowed.append(receipt(int(plan.serial), id))
	for key: Variant in claims:
		if key not in allowed or claims[key] != true: return false
	if claims.has(receipt(int(plan.serial), "main_treasury")):
		if not claims.has(plan.puzzle.receipt) or not claims.has(plan.guardian.receipt): return false
	if claims.has(receipt(int(plan.serial), "optional_trap")) and not claims.has(receipt(int(plan.serial), "hidden_reveal")): return false
	if claims.has(receipt(int(plan.serial), "optional_treasury")):
		if not claims.has(receipt(int(plan.serial), "hidden_reveal")) or not claims.has(plan.trap.receipt): return false
	return true

static func objectives_complete(plan: Dictionary, claims: Dictionary) -> bool:
	if not valid_claims(plan, claims): return false
	for key: String in required_receipts(plan):
		if claims.get(key) != true: return false
	return true

static func prepare_actor(actor: Node3D, member: Dictionary) -> bool:
	return member.get("archetype") == "golem" and NativeActor.prepare_actor(actor, member)

static func actor_data_matches(actor: Node3D, member: Dictionary) -> bool:
	return member.get("archetype") == "golem" and NativeActor.actor_data_matches(actor, member)

static func actor_max_health(member: Dictionary) -> float:
	return NativeActor.actor_max_health(member) if member.get("archetype") == "golem" else 0.0

static func exact_keys(value: Variant, keys: Array) -> bool:
	return Base.exact_keys(value, keys)

static func integer(value: Variant, minimum: int, maximum: int = Base.MAX_COUNT) -> bool:
	return Base.integer(value, minimum, maximum)
