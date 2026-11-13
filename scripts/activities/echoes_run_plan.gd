extends RefCounted
## Five frozen native rosters, one reward per wave and two bounded break choices.
const Base = preload("res://scripts/activities/activity_run_plan.gd")
const DEFINITION = preload("res://resources/activities/echoes_of_eternity.tres")
const ID := "echoes_of_eternity"
const WORLD_SCRIPT := "res://scripts/activities/echoes_level.gd"
const DIRECTOR_SCRIPT := "res://scripts/activities/echoes_director.gd"
const BREAK_SCRIPT := "res://scripts/activities/echoes_break.gd"
const TOTAL_WAVES := 5
const CHOICE_IDS := ["echo_force", "restoring_rhythm"]
const ROSTERS := [["skeleton", "skeleton"], ["skeleton", "archer"], ["skeleton", "skeleton", "archer"],
	["golem", "skeleton", "archer"], ["rootwarden"]]
const POINTS := [100, 150, 200, 300, 500]
const GOLD := [[8, 12], [12, 18], [18, 24], [24, 34], [60, 90]]
const CACHE_ANCHORS := [[-6.0, 0.15, 17.0], [-3.0, 0.15, 17.0], [0.0, 0.15, 17.0], [3.0, 0.15, 17.0], [6.0, 0.15, 17.0]]
const PLAN_KEYS := ["activity_id", "definition_version", "serial", "seed", "definition", "waves", "director", "break_source", "breaks", "exit"]
const ENEMY_FIELDS := ["archetype", "display_name", "max_health", "damage", "armor", "move_speed", "detection_range", "attack_range", "preferred_range",
	"leash_radius", "patrol_radius", "windup_time", "recovery_time", "attack_active_time", "attack_cone_dot", "ranged", "radial_attack",
	"projectile_speed", "projectile_lifetime", "hit_recovery", "stagger_resistance", "collision_radius", "collision_height", "label_height", "accent_color"]
const BOSS_FIELDS := ["max_health", "armor", "move_speed", "detection_range", "leash_radius", "movement_radius", "windup_slam", "windup_thorns",
	"windup_grasp", "windup_fury", "recovery", "phase_transition_time", "slam_damage", "thorn_damage", "grasp_damage", "fury_damage",
	"slam_range", "thorn_radius", "grasp_radius", "fury_radius", "thorn_interval", "active_window"]
const ACTOR_DATA := {
	"skeleton": preload("res://resources/enemies/skeleton.tres"),
	"archer": preload("res://resources/enemies/archer.tres"),
	"golem": preload("res://resources/enemies/golem.tres"),
	"rootwarden": preload("res://resources/enemies/rootwarden.tres")}

static func seed_for(seed_value: int, serial: int, part: String) -> int:
	return int(("vaultbound_echoes_v1|%d|%d|%s" % [seed_value, serial, part]).sha256_text().substr(0, 8).hex_to_int()) & Base.MAX_COUNT

static func definition() -> Dictionary:
	var result: Dictionary = DEFINITION.snapshot()
	if result.is_empty(): return {}
	result.actors = {}
	for id: String in ACTOR_DATA: result.actors[id] = data_snapshot(ACTOR_DATA[id], id)
	return result

static func data_snapshot(resource: Resource, archetype: String) -> Dictionary:
	if resource == null or not ACTOR_DATA.has(archetype): return {}
	var result := {}
	for key: String in (BOSS_FIELDS if archetype == "rootwarden" else ENEMY_FIELDS):
		var value: Variant = resource.get(key)
		if value is Color: result[key] = [value.r, value.g, value.b, value.a]
		elif value is StringName: result[key] = String(value)
		else: result[key] = value
	return result

static func _data_valid(value: Variant, archetype: String) -> bool:
	if not Base.exact_keys(value, BOSS_FIELDS if archetype == "rootwarden" else ENEMY_FIELDS): return false
	for key: String in value:
		var number: Variant = value[key]
		if key == "archetype":
			if number != archetype: return false
		elif key == "display_name":
			if not number is String or number.is_empty() or number.length() > 64: return false
		elif key in ["ranged", "radial_attack"]:
			if not number is bool: return false
		elif key == "accent_color":
			if not number is Array or number.size() != 4: return false
			for channel: Variant in number:
				if not (channel is float or channel is int) or not is_finite(float(channel)) or channel < 0.0 or channel > 1.0: return false
		elif not (number is float or number is int) or not is_finite(float(number)) or number < 0.0 or number > 1000.0: return false
	if value.max_health < 1.0 or value.armor > 0.75 or value.move_speed > 8.0: return false
	if archetype == "rootwarden":
		for key: String in ["windup_slam", "windup_thorns", "windup_grasp", "windup_fury"]:
			if value[key] < 0.7: return false
	else:
		if value.windup_time < 0.5 or value.collision_radius < 0.2 or value.collision_radius > 1.0 \
				or value.collision_height < 1.0 or value.collision_height > 3.0: return false
		if value.ranged != (archetype == "archer") or value.radial_attack != (archetype == "golem"): return false
	return true

static func _definition_valid(value: Variant) -> bool:
	if not Base.exact_keys(value, ["activity_id", "definition_version", "display_name", "required_cleared_depth", "spawn_warning_seconds", "damage_step", "regeneration_step", "actors"]) \
			or value.activity_id != ID or value.definition_version != 1 or value.display_name != "Echoes of Eternity" or value.required_cleared_depth != 3 \
			or not Base.exact_keys(value.actors, ACTOR_DATA.keys()): return false
	for key: String in ["spawn_warning_seconds", "damage_step", "regeneration_step"]:
		if not (value[key] is float or value[key] is int) or not is_finite(float(value[key])): return false
	if value.spawn_warning_seconds < 2.0 or value.spawn_warning_seconds > 5.0 or value.damage_step <= 0.0 or value.damage_step > 0.06 \
			or value.regeneration_step <= 0.0 or value.regeneration_step > 0.12: return false
	for id: String in ACTOR_DATA:
		if not _data_valid(value.actors[id], id): return false
	return true

static func create(seed_value: int, serial: int) -> Dictionary:
	if not Base.integer(seed_value, 0) or not Base.integer(serial, 1, Base.MAX_COUNT - 1): return {}
	var rules := definition()
	return _build(seed_value, serial, rules) if _definition_valid(rules) else {}

static func _build(seed_value: int, serial: int, rules: Dictionary) -> Dictionary:
	var waves: Array[Dictionary] = []
	for index in range(TOTAL_WAVES):
		var wave_number := index + 1
		var receipt := "activity_echoes_%d_wave_%d" % [serial, wave_number]
		var members: Array[Dictionary] = []
		for ordinal in range(ROSTERS[index].size()):
			var id: String = ROSTERS[index][ordinal]
			var member_id := "wave_%d_member_%d" % [wave_number, ordinal + 1]
			var boss_seed := seed_for(seed_value, serial, member_id) if id == "rootwarden" else 0
			var modifier := "none"
			if id == "rootwarden":
				var boss_rng := RandomNumberGenerator.new()
				boss_rng.seed = boss_seed
				modifier = ["none", "thick_bark", "blooming_thorns"][boss_rng.randi_range(0, 2)]
			members.append({"member_id": member_id, "ordinal": ordinal + 1, "archetype": id,
				"canonical_scene": "res://scenes/enemies/%s.tscn" % id,
				"canonical_script": "res://scripts/enemies/rootwarden.gd" if id == "rootwarden" else "res://scripts/enemies/enemy.gd",
				"data_snapshot": rules.actors[id].duplicate(true), "receipt": receipt + "_member_%d" % (ordinal + 1),
				"boss_seed": boss_seed, "modifier_id": modifier})
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_for(seed_value, serial, "wave_%d_sockets" % wave_number)
		var order: Array = [0] if wave_number == 5 else [0, 1, 2, 3, 4, 5, 6, 7]
		for cursor in range(order.size() - 1, 0, -1):
			var chosen := rng.randi_range(0, cursor)
			var previous: int = order[cursor]
			order[cursor] = order[chosen]
			order[chosen] = previous
		rng.seed = seed_for(seed_value, serial, "wave_%d_reward" % wave_number)
		var items: Array[Dictionary] = []
		if wave_number in [2, 4]:
			items.append({"id": "mooncap_tonic", "quantity": 1})
		else:
			items.append({"id": "root_fiber", "quantity": 1 if wave_number == 1 else 2 if wave_number == 3 else 3})
		waves.append({"wave": wave_number, "receipt": receipt, "members": members, "spawn_order": order,
			"reward": {"chest_id": receipt, "category": "common", "gold": rng.randi_range(GOLD[index][0], GOLD[index][1]), "items": items},
			"score": POINTS[index], "cache": {"slot_id": "wave_cache_%d" % wave_number, "room_id": 0,
				"position": CACHE_ANCHORS[index].duplicate(), "kind": "elite"}})
	return {"activity_id": ID, "definition_version": 1, "serial": serial, "seed": seed_value, "definition": rules.duplicate(true), "waves": waves,
		"director": {"slot_id": "trial_director", "kind": "director", "receipt": "activity_echoes_%d_director" % serial},
		"break_source": {"slot_id": "break_shrine", "kind": "break", "receipt": "activity_echoes_%d_break" % serial},
		"breaks": [{"wave": 2, "choice_ids": CHOICE_IDS.duplicate()}, {"wave": 4, "choice_ids": CHOICE_IDS.duplicate()}],
		"exit": {"slot_id": "return_spring", "kind": "exit", "receipt": "activity_echoes_%d_return_spring" % serial}}

static func valid(value: Variant) -> bool:
	if not Base.exact_keys(value, PLAN_KEYS) or value.activity_id != ID or value.definition_version != 1 \
			or not Base.integer(value.serial, 1, Base.MAX_COUNT - 1) or not Base.integer(value.seed, 0) or not _definition_valid(value.definition): return false
	return value == _build(int(value.seed), int(value.serial), value.definition)

static func digest(plan: Dictionary) -> String:
	return JSON.stringify(plan, "", true, true).sha256_text() if valid(plan) else ""

static func wave(plan: Dictionary, wave_number: int) -> Dictionary:
	return plan.waves[wave_number - 1].duplicate(true) if valid(plan) and wave_number >= 1 and wave_number <= TOTAL_WAVES else {}

static func prefix(plan: Dictionary, claims: Dictionary) -> int:
	if not valid(plan): return -1
	var count := 0
	for row: Dictionary in plan.waves:
		if claims.get(row.receipt) == true and count == int(row.wave) - 1: count += 1
	if claims.size() != count: return -1
	return count

static func score(plan: Dictionary, claims: Dictionary) -> int:
	var count := prefix(plan, claims)
	var result := 0
	for index in range(maxi(0, count)): result += int(plan.waves[index].score)
	return result

static func choices(plan: Dictionary) -> Array[Dictionary]:
	if not valid(plan): return []
	return [{"id": "echo_force", "label": "Echo Force", "description": "+%d%% outgoing damage for this trial" % roundi(float(plan.definition.damage_step) * 100.0)},
		{"id": "restoring_rhythm", "label": "Restoring Rhythm", "description": "+%d%% stamina regeneration for this trial" % roundi(float(plan.definition.regeneration_step) * 100.0)}]

static func prepare_actor(actor: Node3D, member: Dictionary) -> bool:
	if not is_instance_valid(actor) or actor.is_inside_tree() or actor.is_node_ready() or not ACTOR_DATA.has(member.get("archetype")) \
			or actor.scene_file_path != member.get("canonical_scene") or actor.get_script() == null \
			or actor.get_script().resource_path != member.get("canonical_script") or not _data_valid(member.get("data_snapshot"), member.archetype): return false
	var resource: Resource = ACTOR_DATA[member.archetype].duplicate(true)
	for key: String in member.data_snapshot:
		var value: Variant = member.data_snapshot[key]
		if key == "accent_color": value = Color(value[0], value[1], value[2], value[3])
		elif key == "archetype": value = StringName(value)
		resource.set(key, value)
	actor.set("data", resource)
	actor.set("combat_active", false)
	if member.archetype == "rootwarden": actor.configure(int(member.boss_seed))
	return true

static func actor_data_matches(actor: Node3D, member: Dictionary) -> bool:
	if not is_instance_valid(actor) or actor.get_script() == null or actor.get_script().resource_path != member.get("canonical_script") \
			or actor.scene_file_path != member.get("canonical_scene") or not actor.get("data") is Resource \
			or data_snapshot(actor.get("data"), member.get("archetype", "")) != member.get("data_snapshot"): return false
	if member.archetype == "rootwarden":
		return int(actor.get("seed_value")) == int(member.boss_seed) and String(actor.get("modifier_id")) == member.modifier_id
	return true

static func actor_max_health(member: Dictionary) -> float:
	return float(member.data_snapshot.max_health) * (1.15 if member.modifier_id == "thick_bark" else 1.0)

static func exact_keys(value: Variant, keys: Array) -> bool:
	return Base.exact_keys(value, keys)

static func integer(value: Variant, minimum: int, maximum: int = Base.MAX_COUNT) -> bool:
	return Base.integer(value, minimum, maximum)
