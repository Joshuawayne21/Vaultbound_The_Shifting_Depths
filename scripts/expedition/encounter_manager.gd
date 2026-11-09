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
const Content = preload("res://scripts/expedition/dungeon_content.gd")
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
var _content_plan: Dictionary = {}
var _initial_packs: Dictionary = {}

func configure(value: Dictionary, instances: Dictionary, level: Node3D, expedition_seed: int, expedition_depth: int = 1) -> void:
	if is_inside_tree() or not _depth_policy.is_empty():
		return
	# The world froze this plan before admission. Room activation may happen much
	# later, so never resolve live Resource values when spawning an encounter.
	var policy: Dictionary = level.issued_depth_policy() if is_instance_valid(level) and level.has_method("issued_depth_policy") else DEPTH_POLICY.describe_depth(expedition_depth)
	if not VaultDepthPolicy.valid_snapshot(policy, expedition_depth):
		return
	_depth_policy = policy.duplicate(true)
	_content_plan = level.issued_run_plan() if is_instance_valid(level) and level.has_method("issued_run_plan") else {}
	layout = value.duplicate(true)
	rooms = instances
	_level = level
	seed_value = expedition_seed

func activate_room(id: int) -> void:
	current_room_id = id
	if not spawned.has(id):
		spawned[id] = true
		var room: Dictionary = layout.rooms[id]
		if room.kind in [&"combat", &"trap"] and (not _level.has_method("optional_room_reserved") or not _level.optional_room_reserved(id)):
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
	var composition: Dictionary = _content_plan.get("ordinary_profile", {})
	var skeleton_threshold := float(composition.get("weights", {}).get("skeleton", 55)) / 100.0
	var archer_threshold := (float(composition.get("weights", {}).get("skeleton", 55)) + float(composition.get("weights", {}).get("archer", 33))) / 100.0
	_initial_packs[id] = {"state": "initializing", "expected": mini(count, points.size()), "receipts": []}
	for index in range(mini(count, points.size())):
		var roll := rng.randf()
		var archetype: StringName = &"skeleton" if roll < skeleton_threshold else (&"archer" if roll < archer_threshold else &"golem")
		if archetype == &"golem":
			if room.depth < 3 or has_golem:
				archetype = &"skeleton"
			else:
				has_golem = true
		var elite: bool = room.depth >= 3 and rng.randf() < 0.12
		var actor := _spawn(id, archetype, points[index], elite, 1.0 + minf(0.2, room.depth * 0.025))
		if not is_instance_valid(self): return
		if is_instance_valid(actor): _initial_packs[id].receipts.append(live_receipt(actor))
	var initial: Dictionary = _initial_packs[id]
	initial.state = "issued" if initial.receipts.size() == int(initial.expected) and not initial.receipts.has("") else "failed"
	encounter_started.emit(id)

func _spawn(room_id: int, archetype: StringName, local_point: Vector3, elite: bool, strength: float = 1.0,
		support_receipt: String = "", owner_receipt: String = "", event_definition: String = "", boss_definition: String = "rootbound_boss_defender") -> Node3D:
	if _depth_policy.is_empty() or not rooms.has(room_id) or not ENEMIES.has(archetype):
		return null
	if not support_receipt.is_empty():
		if _level.scheduler == null: return null
		if event_definition.is_empty():
			if not _level.scheduler.support_spawn_authorized(owner_receipt, support_receipt, room_id, local_point, boss_definition, archetype): return null
		elif not _level.scheduler.event_support_spawn_authorized(owner_receipt, support_receipt, room_id, local_point, event_definition): return null
	for record: Dictionary in _registered_actors.values():
		if not support_receipt.is_empty() and record.receipt == support_receipt: return null
	var enemy := ENEMIES[archetype].instantiate() as Node3D
	var data: Resource = enemy.data.duplicate(true)
	var descriptor: Dictionary = {}
	if not _content_plan.is_empty():
		var ordinary_id := String(_content_plan.ordinary_profile.definition_ids[String(archetype)])
		var definition_id := event_definition if not event_definition.is_empty() else ordinary_id if support_receipt.is_empty() else boss_definition
		descriptor = Content.source_descriptor(_content_plan, definition_id, "elite" if elite else "none")
		if descriptor.is_empty():
			enemy.free()
			return null
		for key: String in _content_plan.encounters[definition_id].data:
			data.set(key, _content_plan.encounters[definition_id].data[key])
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
	if not _content_plan.is_empty() and not enemy.configure_cosmetic_profile(StringName(_content_plan.ordinary_profile.visual_profile_id)):
		enemy.free()
		return null
	enemy.set_meta("abyss_room", room_id)
	enemy.set_meta("elite", elite)
	var ordinal := int(_spawn_ordinals.get(room_id, 0))
	_spawn_ordinals[room_id] = ordinal + 1
	var receipt := "enemy_room_%d_spawn_%d" % [room_id, ordinal] if support_receipt.is_empty() else support_receipt
	enemy.set_meta("loot_receipt", receipt)
	# Metadata is a presentation/debug hint. Identity and reward source come from
	# this spawn registry, so a foreign actor or repeated died signal grants nothing.
	_registered_actors[enemy.get_instance_id()] = {"actor": weakref(enemy), "receipt": receipt,
		"room_id": room_id, "archetype": String(archetype), "elite": elite, "descriptor": descriptor.duplicate(true),
		"owner_encounter_receipt": owner_receipt}
	enemy.position = local_point + Vector3.UP * 0.15
	if not _content_plan.is_empty(): enemy.combat_active = false
	# add_child emits synchronous tree callbacks. Preserve this attempt's owners
	# before attaching; cancellation/retirement must not append a stale actor.
	var receiver_ref: WeakRef = weakref(self)
	var world_ref: WeakRef = weakref(_level)
	var room: Node3D = rooms[room_id]
	var room_ref: WeakRef = weakref(room)
	var enemy_ref: WeakRef = weakref(enemy)
	var actor_id := enemy.get_instance_id()
	var had_content := not _content_plan.is_empty()
	var generation := int(_level.run_generation) if had_content else -1
	var receiver_inside := is_inside_tree()
	var world_inside := _level.is_inside_tree()
	var room_inside := room.is_inside_tree()
	room.add_child(enemy)
	var receiver := receiver_ref.get_ref() as Node
	var remaining_world := world_ref.get_ref() as Node3D
	var remaining_room := room_ref.get_ref() as Node3D
	var created := enemy_ref.get_ref() as Node3D
	var attached: bool = is_instance_valid(receiver) and not receiver.is_queued_for_deletion() \
		and is_instance_valid(remaining_world) and not remaining_world.is_queued_for_deletion() \
		and is_instance_valid(remaining_room) and not remaining_room.is_queued_for_deletion() \
		and is_instance_valid(created) and not created.is_queued_for_deletion()
	if attached:
		attached = (not receiver_inside or receiver.is_inside_tree()) and (not world_inside or remaining_world.is_inside_tree()) \
			and (not room_inside or remaining_room.is_inside_tree()) and receiver._level == remaining_world \
			and receiver.rooms.get(room_id) == remaining_room and created.get_parent() == remaining_room
	if attached and had_content:
		attached = int(remaining_world.run_generation) == generation and remaining_world.run_source_context_valid() \
			and remaining_world.issued_run_plan_matches(receiver._content_plan)
		if attached and not support_receipt.is_empty():
			attached = remaining_world.scheduler.support_spawn_authorized(owner_receipt, support_receipt, room_id, local_point, boss_definition, archetype) if event_definition.is_empty() \
				else remaining_world.scheduler.event_support_spawn_authorized(owner_receipt, support_receipt, room_id, local_point, event_definition)
	if not attached:
		if is_instance_valid(receiver):
			var pending: Dictionary = receiver._registered_actors.get(actor_id, {})
			if not pending.is_empty() and pending.actor.get_ref() == created: receiver._registered_actors.erase(actor_id)
		if is_instance_valid(created): created.queue_free()
		return null
	if not actors_by_room.has(room_id):
		actors_by_room[room_id] = []
	actors_by_room[room_id].append(enemy)
	enemy.died.connect(_on_enemy_died)
	if not _content_plan.is_empty(): _refresh_activity()
	return enemy

func spawn_boss_support(room_id: int, point: Vector3, receipt: String, owner_receipt: String,
		definition_id: String = "rootbound_boss_defender", archetype: StringName = &"skeleton") -> Node3D:
	return _spawn(room_id, archetype, point, false, 1.0, receipt, owner_receipt, "", definition_id)

func discard_boss_support(actor: Node3D, owner_receipt: String) -> void:
	var record := _actor_record(actor)
	if record.is_empty() or record.get("owner_encounter_receipt", "") != owner_receipt or owner_receipt.is_empty(): return
	_set_active(actor, false)
	if not is_instance_valid(self) or not is_instance_valid(actor) or _actor_record(actor) != record: return
	actor.velocity = Vector3.ZERO
	if is_inside_tree():
		for value: Variant in get_tree().get_nodes_in_group("combat_projectiles"):
			if is_instance_valid(value) and value.get("source") == actor and value.has_method("cancel_cast"):
				value.cancel_cast()
				if not is_instance_valid(self) or not is_instance_valid(actor) or _actor_record(actor) != record: return
	if not is_instance_valid(self) or not is_instance_valid(actor) or _actor_record(actor) != record: return
	if actor.died.is_connected(_on_enemy_died): actor.died.disconnect(_on_enemy_died)
	_registered_actors.erase(actor.get_instance_id())
	actors_by_room[int(record.room_id)].erase(actor)
	actor.queue_free()

func support_owner_receipt(actor: Node3D) -> String:
	return String(_actor_record(actor).get("owner_encounter_receipt", ""))

func spawn_patrol(room_id: int, elite: bool = false) -> bool:
	if active_enemy_count() >= MAX_ACTIVE_ENEMIES or not rooms.has(room_id):
		return false
	var record: Dictionary = layout.rooms[room_id]
	if record.kind in [&"entrance", &"extraction", &"boss", &"secret"]:
		return false
	# Bound all awareness reinforcements to two per room and one per event.
	var actors: Array[Node3D] = _retained_actors(room_id)
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
	if not is_inside_tree() or is_queued_for_deletion() or current_room_id < 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var candidates: Array[Node3D] = []
	for id: int in actors_by_room:
		for enemy: Node3D in _retained_actors(id):
			if not is_instance_valid(enemy) or enemy.health <= 0.0:
				continue
			if not support_owner_receipt(enemy).is_empty():
				_set_active(enemy, _level.scheduler != null and _level.scheduler.support_active(enemy))
				continue
			var near_room: bool = not suspended_for_boss and (id == current_room_id or layout.rooms[current_room_id].neighbors.has(id))
			if near_room and enemy.global_position.distance_to(player.global_position) < 25.0:
				candidates.append(enemy)
			else:
				_set_active(enemy, false)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var selected: Array[Node3D] = []
	if is_instance_valid(_level) and _level.get("scheduler") != null:
		selected = _level.scheduler.select_active_ordinary(candidates)
	else:
		for index in range(mini(MAX_ACTIVE_ENEMIES, candidates.size())): selected.append(candidates[index])
	for index in range(candidates.size()):
		_set_active(candidates[index], selected.has(candidates[index]))

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
	if not String(record.get("owner_encounter_receipt", "")).is_empty():
		# Supported actors are actual enemies, but not independent reward sources.
		if String(record.get("descriptor", {}).get("encounter_definition_id", "")).begins_with("root_event_"):
			_level.record_event_member_death(enemy, death_record(enemy))
		return
	var id := int(record.room_id)
	var alive := false
	for actor: Node3D in _retained_actors(id):
		if is_instance_valid(actor) and actor.health > 0.0:
			alive = true
	if not alive:
		cleared[id] = true
	enemy_defeated.emit(enemy)

func death_record(enemy: Node3D) -> Dictionary:
	var record := _dead_actor_record(enemy)
	if record.is_empty() or not _defeated_receipts.has(record.receipt):
		return {}
	var result := {"receipt": record.receipt, "room_id": record.room_id,
		"archetype": record.archetype, "elite": record.elite}
	if not record.get("descriptor", {}).is_empty():
		result.merge(record.descriptor.duplicate(true))
		result["owner_encounter_receipt"] = String(record.get("owner_encounter_receipt", ""))
	return result

func owns_live_actor(enemy: Node3D) -> bool:
	return not _actor_record(enemy).is_empty() and float(enemy.get("health")) > 0.0 and enemy.get("state") != &"dead"

func live_receipt(enemy: Node3D) -> String:
	return String(_actor_record(enemy).get("receipt", "")) if owns_live_actor(enemy) else ""

func death_receipt(enemy: Node3D) -> String:
	return String(death_record(enemy).get("receipt", ""))

func _dead_actor_record(enemy: Node3D) -> Dictionary:
	# Public source probes can name a hazard or scenery node without health.
	# Validate private enrollment before reading the registered enemy contract.
	var record := _actor_record(enemy)
	if record.is_empty() or float(enemy.get("health")) != 0.0 or enemy.get("state") != &"dead":
		return {}
	return record

func _actor_record(enemy: Node3D) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion(): return {}
	var record: Dictionary = _registered_actors.get(enemy.get_instance_id(), {})
	if record.is_empty() or record.actor.get_ref() != enemy:
		return {}
	var id := int(record.room_id)
	if not rooms.has(id) or enemy.get_parent() != rooms[id] or not actors_by_room.get(id, []).has(enemy):
		return {}
	return record

func active_enemy_count() -> int:
	var count := 0
	for id: int in actors_by_room:
		for actor: Node3D in _retained_actors(id):
			if is_instance_valid(actor) and actor.health > 0.0 and actor.combat_active:
				count += 1
	return count

func active_ordinary_count() -> int:
	var count := 0
	for actor: Node3D in all_actors():
		if float(actor.health) > 0.0 and bool(actor.combat_active) and support_owner_receipt(actor).is_empty(): count += 1
	return count

func all_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for id: int in actors_by_room:
		for actor: Node3D in _retained_actors(id):
			if is_instance_valid(actor):
				result.append(actor)
	return result

func spawn_event_support(room_id: int, point: Vector3, receipt: String, owner_receipt: String, archetype: StringName) -> Node3D:
	return _spawn(room_id, archetype, point, false, 1.0, receipt, owner_receipt, "root_event_" + String(archetype))

func ordinary_room_proven_clear(room_id: int) -> bool:
	if not spawned.has(room_id): return false
	var found := false
	for record: Dictionary in _registered_actors.values():
		if int(record.room_id) != room_id or not String(record.get("owner_encounter_receipt", "")).is_empty(): continue
		found = true
		if not _defeated_receipts.has(record.receipt): return false
	return found

func event_support_record(actor: Node3D) -> Dictionary:
	var record := _actor_record(actor)
	if record.is_empty() or not String(record.get("descriptor", {}).get("encounter_definition_id", "")).begins_with("root_event_"): return {}
	return {"receipt": String(record.receipt), "archetype": String(record.archetype), "owner_encounter_receipt": String(record.owner_encounter_receipt),
		"encounter_definition_id": String(record.descriptor.encounter_definition_id), "room_id": int(record.room_id)}

func _retained_actors(room_id: int) -> Array[Node3D]:
	# Corpse disposal may leave a freed Object Variant in the old room array.
	# Validate before assigning to a typed Node variable; never turn absence
	# into a death or erase the private source/death receipt registry.
	var result: Array[Node3D] = []
	for candidate: Variant in actors_by_room.get(room_id, []):
		if is_instance_valid(candidate) and candidate is Node3D: result.append(candidate as Node3D)
	if actors_by_room.has(room_id): actors_by_room[room_id] = result
	return result

func checkpoint_room_status(room_id: int) -> Dictionary:
	if not rooms.has(room_id): return {"complete": false, "reason": "This chamber is unavailable"}
	if layout.rooms[room_id].kind in [&"combat", &"trap"]:
		var initial: Dictionary = _initial_packs.get(room_id, {})
		if initial.get("state", "") != "issued": return {"complete": false, "reason": "The chamber encounter is unresolved"}
		for receipt: String in initial.receipts:
			if not _defeated_receipts.has(receipt): return {"complete": false, "reason": "Clear this chamber before returning"}
	for record: Dictionary in _registered_actors.values():
		if int(record.room_id) != room_id: continue
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(actor) and bool(actor.get("attack_dispatch_in_progress")):
			return {"complete": false, "reason": "An attack is still resolving"}
		if not _defeated_receipts.has(record.receipt): return {"complete": false, "reason": "A local threat remains"}
	return {"complete": true, "reason": ""}

func checkpoint_registered_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in _registered_actors.values():
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(actor) and actor.get_parent() == rooms.get(int(record.room_id)): result.append(actor)
	return result

func checkpoint_actor_owned(actor: Node3D) -> bool:
	if not is_instance_valid(actor): return false
	var record: Dictionary = _registered_actors.get(actor.get_instance_id(), {})
	return not record.is_empty() and record.actor.get_ref() == actor and actor.get_parent() == rooms.get(int(record.room_id))
