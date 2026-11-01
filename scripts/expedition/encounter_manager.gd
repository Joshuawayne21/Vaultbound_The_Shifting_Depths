class_name EncounterManager
extends Node
## Reuses the existing three archetypes. Dormant actors retain health and death state.
signal enemy_defeated(enemy: Node3D)
signal encounter_started(room_id: int)
const ENEMIES := {
	&"skeleton": preload("res://scenes/enemies/skeleton.tscn"),
	&"archer": preload("res://scenes/enemies/archer.tscn"),
	&"golem": preload("res://scenes/enemies/golem.tscn"),
}
const MAX_ACTIVE_ENEMIES := 6
const DEPTH_POLICY = preload("res://resources/expedition/depth_policy.tres")
var layout: Dictionary
var rooms: Dictionary
var seed_value := 0
var current_room_id := -1
var suspended_for_boss := false
var spawned: Dictionary = {}
var actors_by_room: Dictionary = {}
var cleared: Dictionary = {}
var _level: Node3D
var _tick := 0.0
var _spawn_ordinals: Dictionary = {}
var _registered_actors: Dictionary = {}
var _defeated_receipts: Dictionary = {}
var _depth_policy: Dictionary = {}

func configure(value: Dictionary, instances: Dictionary, level: Node3D, expedition_seed: int, expedition_depth: int = 1) -> void:
	if is_inside_tree() or not _depth_policy.is_empty():
		return
	# The world froze this plan before admission. Room activation may happen much
	# later, so never resolve live Resource values when spawning an encounter.
	var policy: Dictionary = level.issued_depth_policy() if is_instance_valid(level) and level.has_method("issued_depth_policy") else DEPTH_POLICY.describe_depth(expedition_depth)
	if not VaultDepthPolicy.valid_snapshot(policy, expedition_depth):
		return
	_depth_policy = policy.duplicate(true)
	layout = value.duplicate(true)
	rooms = instances
	_level = level
	seed_value = expedition_seed

func activate_room(id: int) -> void:
	current_room_id = id
	if not spawned.has(id):
		spawned[id] = true
		var room: Dictionary = layout.rooms[id]
		if room.kind in [&"combat", &"trap"]:
			_spawn_initial(id)
	_refresh_activity()

func set_boss_active(enabled: bool) -> void:
	if suspended_for_boss != enabled:
		suspended_for_boss = enabled
		_refresh_activity()

func _spawn_initial(id: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + id * 104729
	var room: Dictionary = layout.rooms[id]
	var count := rng.randi_range(1, 2) if room.kind == &"trap" else rng.randi_range(2, 3)
	var points: Array[Vector3] = rooms[id].get_spawn_points()
	var has_golem := false
	for index in range(mini(count, points.size())):
		var roll := rng.randf()
		var archetype: StringName = &"skeleton" if roll < 0.55 else (&"archer" if roll < 0.88 else &"golem")
		if archetype == &"golem":
			if room.depth < 3 or has_golem:
				archetype = &"skeleton"
			else:
				has_golem = true
		var elite: bool = room.depth >= 3 and rng.randf() < 0.12
		_spawn(id, archetype, points[index], elite, 1.0 + minf(0.2, room.depth * 0.025))
	encounter_started.emit(id)

func _spawn(room_id: int, archetype: StringName, local_point: Vector3, elite: bool, strength: float = 1.0) -> Node3D:
	if _depth_policy.is_empty() or not rooms.has(room_id) or not ENEMIES.has(archetype):
		return null
	var enemy := ENEMIES[archetype].instantiate() as Node3D
	var data: Resource = enemy.data.duplicate(true)
	data.max_health *= float(_depth_policy.health_multiplier) * strength * (1.3 if elite else 1.0)
	data.damage *= float(_depth_policy.damage_multiplier) * strength * (1.15 if elite else 1.0)
	data.leash_radius = 8.5
	data.patrol_radius = 1.0
	data.detection_range = 8.0
	# Elites hit harder but telegraph longer; there is no speed/stacking modifier.
	if elite:
		data.display_name = "Elder " + data.display_name
		data.windup_time *= 1.15
		data.accent_color = Color("c6b46a")
	enemy.data = data
	enemy.set_meta("abyss_room", room_id)
	enemy.set_meta("elite", elite)
	var ordinal := int(_spawn_ordinals.get(room_id, 0))
	_spawn_ordinals[room_id] = ordinal + 1
	var receipt := "enemy_room_%d_spawn_%d" % [room_id, ordinal]
	enemy.set_meta("loot_receipt", receipt)
	# Metadata is a presentation/debug hint. Identity and reward source come from
	# this spawn registry, so a foreign actor or repeated died signal grants nothing.
	_registered_actors[enemy.get_instance_id()] = {"actor": weakref(enemy), "receipt": receipt,
		"room_id": room_id, "archetype": String(archetype), "elite": elite}
	enemy.position = local_point + Vector3.UP * 0.15
	rooms[room_id].add_child(enemy)
	if not actors_by_room.has(room_id):
		actors_by_room[room_id] = []
	actors_by_room[room_id].append(enemy)
	enemy.died.connect(_on_enemy_died)
	return enemy

func spawn_patrol(room_id: int, elite: bool = false) -> bool:
	if active_enemy_count() >= MAX_ACTIVE_ENEMIES or not rooms.has(room_id):
		return false
	var record: Dictionary = layout.rooms[room_id]
	if record.kind in [&"entrance", &"extraction", &"boss", &"secret"]:
		return false
	# Bound all awareness reinforcements to two per room and one per event.
	var actors: Array = actors_by_room.get(room_id, [])
	if actors.size() >= 5:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var choices: Array[Vector3] = rooms[room_id].get_spawn_points()
	var chosen := Vector3.ZERO
	var best_distance := 6.0
	var found := false
	for point: Vector3 in choices:
		var world_point: Vector3 = rooms[room_id].to_global(point)
		var distance := world_point.distance_to(player.global_position)
		for teammate: Node3D in CombatRules.party_targets(self):
			distance = minf(distance, world_point.distance_to(teammate.global_position))
		if distance <= best_distance:
			continue
		var occupied := false
		for actor: Node3D in actors:
			if is_instance_valid(actor) and actor.health > 0.0 and actor.global_position.distance_to(world_point) < 2.5:
				occupied = true
		if not occupied:
			chosen = point
			best_distance = distance
			found = true
	if not found:
		return false
	_spawn(room_id, &"golem" if elite else &"skeleton", chosen, elite)
	cleared.erase(room_id)
	_refresh_activity()
	return true

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.2:
		_tick = 0.0
		_refresh_activity()

func _refresh_activity() -> void:
	if current_room_id < 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var candidates: Array[Node3D] = []
	for id: int in actors_by_room:
		for enemy: Node3D in actors_by_room[id]:
			if not is_instance_valid(enemy) or enemy.health <= 0.0:
				continue
			var near_room: bool = not suspended_for_boss and (id == current_room_id or layout.rooms[current_room_id].neighbors.has(id))
			if near_room and enemy.global_position.distance_to(player.global_position) < 25.0:
				candidates.append(enemy)
			else:
				_set_active(enemy, false)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for index in range(candidates.size()):
		_set_active(candidates[index], index < MAX_ACTIVE_ENEMIES)

func _set_active(enemy: Node3D, enabled: bool) -> void:
	if enemy.combat_active == enabled:
		return
	enemy.combat_active = enabled
	if not enabled:
		enemy.velocity = Vector3.ZERO
		# Discard an old telegraph before freezing, so re-entry never resumes a
		# nearly-complete strike. Health and all defeated-state receipts stay intact.
		if enemy.state in [&"windup", &"attack", &"chase"]:
			enemy._set_state(&"return")
	enemy.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _on_enemy_died(enemy: Node3D) -> void:
	var record := _dead_actor_record(enemy)
	if record.is_empty() or _defeated_receipts.has(record.receipt):
		return
	_defeated_receipts[record.receipt] = true
	var id := int(record.room_id)
	var alive := false
	for actor: Node3D in actors_by_room.get(id, []):
		if is_instance_valid(actor) and actor.health > 0.0:
			alive = true
	if not alive:
		cleared[id] = true
	enemy_defeated.emit(enemy)

func death_record(enemy: Node3D) -> Dictionary:
	var record := _dead_actor_record(enemy)
	if record.is_empty() or not _defeated_receipts.has(record.receipt):
		return {}
	return {"receipt": record.receipt, "room_id": record.room_id,
		"archetype": record.archetype, "elite": record.elite}

func death_receipt(enemy: Node3D) -> String:
	return String(death_record(enemy).get("receipt", ""))

func _dead_actor_record(enemy: Node3D) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or float(enemy.get("health")) != 0.0 or enemy.get("state") != &"dead":
		return {}
	var record: Dictionary = _registered_actors.get(enemy.get_instance_id(), {})
	if record.is_empty() or record.actor.get_ref() != enemy:
		return {}
	var id := int(record.room_id)
	if not rooms.has(id) or enemy.get_parent() != rooms[id] or not actors_by_room.get(id, []).has(enemy):
		return {}
	return record

func active_enemy_count() -> int:
	var count := 0
	for actors: Array in actors_by_room.values():
		for actor: Node3D in actors:
			if is_instance_valid(actor) and actor.health > 0.0 and actor.combat_active:
				count += 1
	return count

func all_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actors: Array in actors_by_room.values():
		for actor: Node3D in actors:
			if is_instance_valid(actor):
				result.append(actor)
	return result
