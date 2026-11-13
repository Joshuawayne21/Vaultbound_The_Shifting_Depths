extends Node3D
## Native world proof for the finite five-wave trial. The Session issues every
## roster/reward and owns all progression. No Rootbound depth payload is used.
const Plan = preload("res://scripts/activities/echoes_run_plan.gd")
const Base = preload("res://scripts/activities/activity_run_plan.gd")
const Layout = preload("res://resources/activities/echoes_layout.tres")
const Builder = preload("res://scripts/activities/echoes_builder.gd")
const Director = preload("res://scripts/activities/echoes_director.gd")
const BreakSource = preload("res://scripts/activities/echoes_break.gd")
const Exit = preload("res://scripts/activities/activity_exit.gd")
const CacheManager = preload("res://scripts/treasure/loot_cache_manager.gd")
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const SOURCE_IDS := ["trial_director", "break_shrine", "return_spring"]
const COMBAT_GROUPS := ["combat_targets", "enemies", "bosses", "combat_telegraphs"]
const PROJECTILE_SCRIPT := "res://scripts/combat/projectile.gd"
var display_name := "ECHOES OF ETERNITY"
var objective := "Five waves · search each cache · choose at waves 2 and 4 · secure return"
var run_generation := -1
var expedition_seed := 0
var _context: Dictionary = {}
var _registry: Dictionary = {}
var _actors: Dictionary = {}
var _terminal: Dictionary = {}
var _accepted_deaths: Dictionary = {}
var _sealed: Dictionary = {}
var _spawn_selections: Dictionary = {}
var _floor: StaticBody3D
var _combat_root: Node3D
var _cache_room: Node3D
var _cache_manager: Node3D
var _player: WeakRef
var _owner: WeakRef
var _session: Node
var _built := false
var _visual_report: Dictionary = {}
var _configured_transform := Transform3D.IDENTITY
var _runtime_retired := false

func configure_activity(context: Dictionary) -> bool:
	if is_inside_tree() or not _context.is_empty(): return false
	if not Base.exact_keys(context, ["activity_id", "definition_version", "serial", "seed", "generation", "plan"]) \
			or context.activity_id != Plan.ID or context.definition_version != 1 or not Base.integer(context.generation, 0) \
			or not Plan.valid(context.plan) or context.serial != context.plan.serial or context.seed != context.plan.seed: return false
	_context = context.duplicate(true)
	run_generation = int(context.generation)
	expedition_seed = int(context.seed)
	return true

func issued_activity_context() -> Dictionary:
	return _context.duplicate(true)

func _ready() -> void:
	if _context.is_empty() or _built: return
	_built = true
	_configured_transform = global_transform
	_session = get_node_or_null("/root/ExpeditionSession")
	_visual_report = Builder.build(self, Layout, expedition_seed)
	_floor = _visual_report.floor
	_combat_root = Node3D.new()
	_combat_root.name = "CombatActors"
	add_child(_combat_root)
	_cache_room = Node3D.new()
	_cache_room.name = "CacheAlcove"
	_cache_room.position = Layout.CACHE_ROOM_ORIGIN
	add_child(_cache_room)
	var director := Director.new()
	director.name = "TrialDirector"
	if director.configure(self, run_generation):
		add_child(director)
		_register_source(_context.plan.director, director, Plan.DIRECTOR_SCRIPT)
	else: director.free()
	var shrine := BreakSource.new()
	shrine.name = "EchoShrine"
	shrine.position = Layout.BREAK_POSITION
	if shrine.configure(self, run_generation):
		add_child(shrine)
		_register_source(_context.plan.break_source, shrine, Plan.BREAK_SCRIPT)
	else: shrine.free()
	var exit := Exit.new()
	exit.name = "EchoesReturnSpring"
	exit.position = Layout.RETURN_POSITION
	if exit.configure(self, run_generation):
		add_child(exit)
		_register_source(_context.plan.exit, exit, Base.EXIT_SCRIPT)
	else: exit.free()

func _register_source(row: Dictionary, source: Node3D, script_path: String) -> void:
	if _registry.has(row.slot_id): return
	_registry[row.slot_id] = {"node": weakref(source), "transform": source.transform,
		"script": script_path, "slot_id": String(row.slot_id), "kind": String(row.kind), "receipt": String(row.receipt)}

func bind_activity_actor(player: Node3D, game_owner: Node) -> bool:
	if not is_inside_tree() or not activity_ready_valid() or not is_instance_valid(player) \
			or not player.is_inside_tree() or not is_instance_valid(game_owner): return false
	if _player != null or _owner != null:
		return _player != null and _owner != null and _player.get_ref() == player and _owner.get_ref() == game_owner
	_player = weakref(player)
	_owner = weakref(game_owner)
	_cache_manager = CacheManager.new()
	_cache_manager.name = "EchoesLootCaches"
	_cache_manager.configure(_session, {0: _cache_room}, player, self, run_generation)
	add_child(_cache_manager)
	return true

func activity_ready_valid() -> bool:
	if not _built or not is_inside_tree() or is_queued_for_deletion() or not Plan.valid(_context.get("plan")): return false
	if not is_instance_valid(_floor) or not _floor.is_inside_tree() or not is_ancestor_of(_floor) \
			or not is_instance_valid(_combat_root) or _combat_root.get_parent() != self \
			or not is_instance_valid(_cache_room) or _cache_room.get_parent() != self \
			or _cache_room.position != Layout.CACHE_ROOM_ORIGIN: return false
	if run_generation != int(_context.generation) or expedition_seed != int(_context.seed) or _registry.size() != 3: return false
	for id: String in SOURCE_IDS:
		var row: Dictionary = _registry.get(id, {})
		if row.is_empty() or not owns_source(row.node.get_ref(), id): return false
	return true

func activity_runtime_matches(context: Dictionary) -> bool:
	# Cheap runtime seam; mutation/admission APIs still validate the complete plan.
	if not _built or not is_inside_tree() or is_queued_for_deletion() or _runtime_retired \
			or context != _context or run_generation != int(_context.get("generation", -1)) \
			or expedition_seed != int(_context.get("seed", -1)) or not global_transform.is_equal_approx(_configured_transform) \
			or not is_instance_valid(_floor) or not _floor.is_inside_tree() or not is_ancestor_of(_floor) \
			or not is_instance_valid(_combat_root) or _combat_root.get_parent() != self \
			or not is_instance_valid(_cache_room) or _cache_room.get_parent() != self \
			or _cache_room.position != Layout.CACHE_ROOM_ORIGIN or _registry.size() != 3: return false
	for id: String in SOURCE_IDS:
		if not _registry.has(id) or not owns_source(_registry[id].node.get_ref(), id): return false
	return true

func owns_source(source: Node3D, slot_id: String) -> bool:
	if not _built or is_queued_for_deletion() or not _registry.has(slot_id) or not is_instance_valid(source): return false
	var row: Dictionary = _registry[slot_id]
	if row.node.get_ref() != source or source.get_parent() != self or source.is_queued_for_deletion() \
			or source.get_script() == null or source.get_script().resource_path != row.script \
			or not source.transform.is_equal_approx(row.transform): return false
	return source.identity_snapshot() == {"slot_id": slot_id, "kind": row.kind, "generation": run_generation}

func registered_activity_sources() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _registry:
		var source := _registry[id].node.get_ref() as Node3D
		result[id] = source if owns_source(source, id) else null
	return result

func run_source_context_valid() -> bool:
	if not activity_runtime_matches(_context) or not is_instance_valid(_session) or not _session.has_method("echoes_runtime_context_valid"): return false
	var owner := _owner.get_ref() as Node if _owner != null else null
	return is_instance_valid(owner) and owner.get("active_world") == self and not bool(owner.get("transitioning")) \
		and bool(_session.echoes_runtime_context_valid(self, run_generation))

func echoes_clock_available() -> bool:
	# Director has just checked the original runtime identity. This separate
	# input pause check does not reconstruct plans or repeat authority polling.
	var input := get_node_or_null("/root/InputHub")
	return input != null and input.is_gameplay_input_available()

func can_reach_activity_source(source: Node3D, actor: Node3D, radius: float = 2.8) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_finite(radius) or radius <= 0.0 or radius > 3.0: return false
	var player := _player.get_ref() as Node3D if _player != null else null
	var owner := _owner.get_ref() as Node if _owner != null else null
	var input := get_node_or_null("/root/InputHub")
	if not is_instance_valid(actor) or actor != player or not is_instance_valid(owner) or owner.get("active_world") != self \
			or bool(owner.get("transitioning")) or actor.is_queued_for_deletion() or not actor.is_inside_tree() \
			or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_visible_in_tree() \
			or source.get_parent() != self or source.get_viewport() != actor.get_viewport() or source.get_world_3d() != actor.get_world_3d() \
			or not source.global_position.is_finite() or not actor.global_position.is_finite() \
			or float(actor.get("health")) <= 0.0 or bool(actor.get("downed")) or bool(actor.get("eliminated")) \
			or not bool(actor.get("controls_enabled")) or input == null or not input.is_gameplay_input_available() \
			or actor.get("combat") == null or actor.combat.state != &"idle" \
			or actor.global_position.distance_to(source.global_position) > radius: return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.3, 1 | 16)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty() \
		and _owned_floor_clear(source.global_position + Vector3.UP * 0.15, 0.40, ACTOR_HEIGHT)

func echoes_break_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not owns_source(source, "break_shrine") or not can_reach_activity_source(source, actor): return {}
	return {"slot_id": "break_shrine", "kind": "break", "receipt": _registry.break_shrine.receipt}

func activity_exit_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not owns_source(source, "return_spring") or not can_reach_activity_source(source, actor): return {}
	return {"slot_id": "return_spring", "kind": "exit", "receipt": _registry.return_spring.receipt}

func source_approach_position(slot_id: String) -> Vector3:
	if slot_id == "return_spring": return to_global(Layout.RETURN_POSITION + Vector3(0, 0.15, -1.2))
	if slot_id == "break_shrine": return to_global(Layout.BREAK_POSITION + Vector3(0, 0.15, -1.2))
	return Vector3.INF

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Layout.SPAWN_POSITION)

func get_companion_navigation_profile() -> Dictionary:
	return {"mode": &"terraced_city", "floor_min": 0.0, "floor_max": 0.0}

func get_companion_navigation_graph() -> Dictionary:
	var graph: Dictionary = Layout.navigation_graph()
	var points: PackedVector3Array = graph.points
	for index in range(points.size()): points[index] = to_global(points[index])
	graph.points = points
	return graph

func validate_activity_arrival(entry_id: StringName) -> bool:
	if entry_id != &"default" or not activity_ready_valid(): return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0): return false
	for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 2.2), Vector3(1.6, 0, 2.2)]:
		if not _owned_floor_clear(spawn.origin + spawn.basis * offset, ACTOR_RADIUS, ACTOR_HEIGHT, _retained_world_rids()): return false
	return true

func _retained_world_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"): continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false): excluded.append((body as CollisionObject3D).get_rid())
	return excluded

func _owned_floor_clear(point: Vector3, radius: float, height: float, excluded: Array[RID] = []) -> bool:
	if not point.is_finite() or not is_instance_valid(_floor) or not _floor.is_inside_tree(): return false
	var space := get_world_3d().direct_space_state
	for radial: Vector3 in [Vector3.ZERO, Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
		var ray := PhysicsRayQueryParameters3D.create(point + radial + Vector3.UP * 0.5, point + radial - Vector3.UP * 0.5, 1)
		ray.exclude = excluded
		ray.collide_with_areas = false
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.collider != _floor or Vector3(hit.normal).y < 0.98 \
				or absf(Vector3(hit.position).y - to_global(Vector3.ZERO).y) > 0.025: return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0 + 0.02)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = point + Vector3.UP * capsule.height * 0.5
	query.collision_mask = 1 | 16
	query.exclude = excluded
	query.margin = 0.005
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()

func echoes_party_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var seen: Dictionary = {}
	for group: String in ["player", "party_members"]:
		for actor: Node in get_tree().get_nodes_in_group(group):
			if not actor is Node3D or not is_instance_valid(actor) or actor.is_queued_for_deletion() \
					or actor.get_world_3d() != get_world_3d() or seen.has(actor.get_instance_id()) \
					or bool(actor.get("eliminated")) or (float(actor.get("health")) <= 0.0 and not bool(actor.get("downed"))): continue
			if actor.global_position.is_finite():
				seen[actor.get_instance_id()] = true
				result.append(actor.global_position)
	return result

func echoes_party_moved(previous: Array[Vector3], distance: float) -> bool:
	var now := echoes_party_positions()
	if now.size() != previous.size(): return true
	for index in range(now.size()):
		if now[index].distance_to(previous[index]) >= distance: return true
	return false

func _director_phase(director: Node3D, wave: int, phase: String) -> bool:
	if not run_source_context_valid() or not owns_source(director, "trial_director"): return false
	var status: Dictionary = _session.echoes_director_status(self, director, run_generation)
	return bool(status.get("ok", false)) and int(status.get("wave", 0)) == wave and status.get("phase") == phase

func select_echoes_spawn_positions(director: Node3D, wave: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not _director_phase(director, wave, "awaiting_roster"): return result
	var row: Dictionary = Plan.wave(_context.plan, wave)
	if row.is_empty(): return result
	var sockets: Array[Vector3] = []
	if wave == 5: sockets.append(Layout.BOSS_POSITION)
	else: sockets.assign(Layout.spawn_positions())
	for slot: int in row.spawn_order:
		var member: Dictionary = row.members[result.size()]
		var point: Vector3 = sockets[slot]
		if _spawn_clear(point, member, result): result.append(point)
		if result.size() == row.members.size():
			_spawn_selections[wave] = result.duplicate()
			return result
	_spawn_selections.erase(wave)
	return []

func _spawn_clear(local_point: Vector3, member: Dictionary, used: Array[Vector3]) -> bool:
	var point := to_global(local_point)
	var radius := 0.8 if member.archetype == "rootwarden" else float(member.data_snapshot.collision_radius)
	var height := 3.5 if member.archetype == "rootwarden" else float(member.data_snapshot.collision_height)
	if not _owned_floor_clear(point, radius, height): return false
	for party_position: Vector3 in echoes_party_positions():
		if Vector2(point.x - party_position.x, point.z - party_position.z).length() < 6.0: return false
	for previous: Vector3 in used:
		if local_point.distance_to(previous) < radius * 2.0 + 1.0: return false
	# Every spawn has a broad, floor-backed route out to the central court.
	var destination := to_global(Vector3(0, 0.15, 8))
	for index in range(9):
		if not _owned_floor_clear(point.lerp(destination, float(index) / 8.0), 0.42, 1.7): return false
	return true

func prepare_echoes_roster(director: Node3D, wave: int, positions: Array[Vector3]) -> bool:
	if not _director_phase(director, wave, "awaiting_roster") or _sealed.has(wave): return false
	var row: Dictionary = Plan.wave(_context.plan, wave)
	if row.is_empty() or positions.size() != row.members.size() or _spawn_selections.get(wave) != positions: return false
	discard_echoes_unsealed_roster(director, wave)
	var used: Array[Vector3] = []
	var sockets: Array[Vector3] = []
	if wave == 5: sockets.append(Layout.BOSS_POSITION)
	else: sockets.assign(Layout.spawn_positions())
	for index in range(row.members.size()):
		var member: Dictionary = row.members[index]
		if positions[index] not in sockets or not _spawn_clear(positions[index], member, used):
			discard_echoes_unsealed_roster(director, wave)
			return false
		used.append(positions[index])
		var packed := load(String(member.canonical_scene)) as PackedScene
		if packed == null:
			discard_echoes_unsealed_roster(director, wave)
			return false
		var actor := packed.instantiate() as CharacterBody3D
		if actor == null or not Plan.prepare_actor(actor, member):
			if is_instance_valid(actor): actor.free()
			discard_echoes_unsealed_roster(director, wave)
			return false
		actor.name = String(member.member_id).to_pascal_case()
		actor.position = positions[index]
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		_combat_root.add_child(actor)
		if not is_instance_valid(actor) or not _director_phase(director, wave, "awaiting_roster"):
			if is_instance_valid(actor): actor.queue_free()
			return false
		# Existing _ready adds groups and collision even for a disabled process.
		# Remove them synchronously before exposing the candidate to a physics tick.
		var groups: Array[String] = []
		for group: String in COMBAT_GROUPS:
			if actor.is_in_group(group):
				groups.append(group)
				actor.remove_from_group(group)
		var layer := actor.collision_layer
		var mask := actor.collision_mask
		actor.collision_layer = 0
		actor.collision_mask = 0
		_actors[member.member_id] = {"node": weakref(actor), "parent": weakref(_combat_root), "wave": wave,
			"member": member.duplicate(true), "data": weakref(actor.get("data")), "position": positions[index],
			"layer": layer, "mask": mask, "groups": groups}
		actor.died.connect(_on_echo_died)
		if not _candidate_actor_valid(actor, member):
			discard_echoes_unsealed_roster(director, wave)
			return false
	return true

func echoes_prepared_roster_valid(director: Node3D, wave: int, positions: Array[Vector3]) -> bool:
	if not _director_phase(director, wave, "awaiting_roster") or _sealed.has(wave): return false
	var row: Dictionary = Plan.wave(_context.plan, wave)
	if row.is_empty() or positions.size() != row.members.size(): return false
	var used: Array[Vector3] = []
	for index in range(row.members.size()):
		var member: Dictionary = row.members[index]
		var entry: Dictionary = _actors.get(member.member_id, {})
		var actor := entry.node.get_ref() as Node3D if not entry.is_empty() else null
		if not owns_echoes_actor(actor, member.member_id) or not _candidate_actor_valid(actor, member) \
				or not actor.position.is_equal_approx(positions[index]) or not _spawn_clear(positions[index], member, used): return false
		used.append(positions[index])
	return true

func _candidate_actor_valid(actor: Node3D, member: Dictionary) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() \
			or actor.get_parent() != _combat_root or not Plan.actor_data_matches(actor, member) \
			or not is_equal_approx(float(actor.get("health")), Plan.actor_max_health(member)) \
			or not is_equal_approx(float(actor.get("max_health")), Plan.actor_max_health(member)) \
			or actor.get("state") != &"idle" or bool(actor.get("combat_active")) \
			or actor.process_mode != Node.PROCESS_MODE_DISABLED or actor.collision_layer != 0 or actor.collision_mask != 0: return false
	for group: String in COMBAT_GROUPS:
		if actor.is_in_group(group): return false
	return true

func validate_echoes_spawn_candidate(enemy: Node3D, member_id: String) -> bool:
	if not owns_echoes_actor(enemy, member_id): return false
	var row: Dictionary = _actors[member_id]
	if _sealed.has(int(row.wave)) or not _candidate_actor_valid(enemy, row.member) \
			or not enemy.position.is_equal_approx(row.position) or not _spawn_selections.has(int(row.wave)): return false
	var selected: Array = _spawn_selections[int(row.wave)]
	if int(row.member.ordinal) < 1 or int(row.member.ordinal) > selected.size() \
			or selected[int(row.member.ordinal) - 1] != row.position: return false
	var used: Array[Vector3] = []
	for index in range(int(row.member.ordinal) - 1): used.append(selected[index])
	return _spawn_clear(row.position, row.member, used)

func discard_echoes_unsealed_roster(director: Node3D, wave: int) -> void:
	if not owns_source(director, "trial_director") or _sealed.has(wave): return
	for id: String in _actors.keys():
		var row: Dictionary = _actors[id]
		if int(row.wave) != wave: continue
		var actor := row.node.get_ref() as Node3D
		if is_instance_valid(actor) and actor.get_parent() == _combat_root:
			actor.set("combat_active", false)
			actor.hide()
			actor.queue_free()
		_actors.erase(id)

func activate_echoes_roster(director: Node3D, wave: int) -> bool:
	if not _director_phase(director, wave, "fighting") or _sealed.has(wave): return false
	var plan: Dictionary = Plan.wave(_context.plan, wave)
	for member: Dictionary in plan.members:
		var row: Dictionary = _actors.get(member.member_id, {})
		var actor := row.node.get_ref() as Node3D if not row.is_empty() else null
		if not owns_echoes_actor(actor, member.member_id) or not _candidate_actor_valid(actor, member): return false
	_sealed[wave] = true
	for member: Dictionary in plan.members:
		if not _director_phase(director, wave, "fighting"):
			retire_echoes_combat()
			return false
		var row: Dictionary = _actors[member.member_id]
		var actor := row.node.get_ref() as CharacterBody3D
		for group: String in row.groups: actor.add_to_group(group)
		actor.collision_layer = int(row.layer)
		actor.collision_mask = int(row.mask)
		actor.set("combat_active", true)
		actor.process_mode = Node.PROCESS_MODE_INHERIT
	# Keep original dead nodes/proofs, but hide previous native corpses so the
	# presentation cannot accumulate eleven visible high-detail enemy bodies.
	for id: String in _accepted_deaths:
		var row: Dictionary = _actors.get(id, {})
		var actor := row.node.get_ref() as Node3D if not row.is_empty() else null
		if is_instance_valid(actor) and int(row.wave) < wave:
			actor.hide()
			actor.process_mode = Node.PROCESS_MODE_DISABLED
	return true

func owns_echoes_actor(enemy: Node3D, member_id: String) -> bool:
	if not is_instance_valid(enemy) or not _actors.has(member_id) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion(): return false
	var row: Dictionary = _actors[member_id]
	return row.node.get_ref() == enemy and row.parent.get_ref() == _combat_root and enemy.get_parent() == _combat_root \
		and is_instance_valid(_combat_root) and _combat_root.get_parent() == self and enemy.get_world_3d() == get_world_3d() \
		and row.data.get_ref() == enemy.get("data") and Plan.actor_data_matches(enemy, row.member) \
		and enemy.global_position.is_finite() and is_finite(float(enemy.get("health"))) \
		and is_equal_approx(float(enemy.get("max_health")), Plan.actor_max_health(row.member))

func echoes_roster_record(director: Node3D, wave: int) -> Dictionary:
	if not run_source_context_valid() or not owns_source(director, "trial_director"): return {}
	var plan: Dictionary = Plan.wave(_context.plan, wave)
	if plan.is_empty(): return {}
	var members: Array[Dictionary] = []
	for member: Dictionary in plan.members:
		var row: Dictionary = _actors.get(member.member_id, {})
		var actor := row.node.get_ref() as Node3D if not row.is_empty() else null
		if not owns_echoes_actor(actor, member.member_id): return {}
		if not _sealed.has(wave) and not validate_echoes_spawn_candidate(actor, member.member_id): return {}
		members.append({"member_id": member.member_id, "receipt": member.receipt, "actor": actor})
	return {"wave": wave, "receipt": plan.receipt, "members": members}

func _on_echo_died(enemy: Node3D) -> void:
	if not run_source_context_valid() or not is_instance_valid(enemy): return
	for id: String in _actors:
		var row: Dictionary = _actors[id]
		if row.node.get_ref() != enemy: continue
		if not _sealed.has(int(row.wave)) or not owns_echoes_actor(enemy, id) or enemy.get("state") != &"dead" \
				or float(enemy.get("health")) != 0.0 or _terminal.has(id): return
		_terminal[id] = {"wave": int(row.wave), "member_id": id, "receipt": row.member.receipt, "archetype": row.member.archetype}
		var result: Dictionary = _session.record_echoes_death(self, enemy, run_generation)
		if not is_instance_valid(self): return
		if bool(result.get("ok", false)) and bool(result.get("still_current", false)) and run_source_context_valid() \
				and owns_echoes_actor(enemy, id): _accepted_deaths[id] = true
		return

func echoes_death_record(enemy: Node3D) -> Dictionary:
	if not run_source_context_valid() or not is_instance_valid(enemy): return {}
	for id: String in _terminal:
		if owns_echoes_actor(enemy, id) and enemy.get("state") == &"dead" and float(enemy.get("health")) == 0.0:
			return _terminal[id].duplicate(true)
	return {}

func echoes_live_roster_intact(wave: int) -> bool:
	if not run_source_context_valid() or not _sealed.has(wave): return false
	for member: Dictionary in _context.plan.waves[wave - 1].members:
		var row: Dictionary = _actors.get(member.member_id, {})
		var actor := row.node.get_ref() as Node3D if not row.is_empty() else null
		if not owns_echoes_actor(actor, member.member_id): return false
	return true

func echoes_all_deaths_accepted(wave: int) -> bool:
	if not echoes_live_roster_intact(wave): return false
	for member: Dictionary in _context.plan.waves[wave - 1].members:
		if not _accepted_deaths.has(member.member_id): return false
	return true

func _wave_owned_projectiles(wave: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group("combat_projectiles"):
		if not node is Node3D or not is_instance_valid(node) or node.is_queued_for_deletion() or not is_ancestor_of(node) \
				or node.get_script() == null or node.get_script().resource_path != PROJECTILE_SCRIPT: continue
		var actor := node.get("source") as Node3D
		for id: String in _actors:
			var row: Dictionary = _actors[id]
			# This is cleanup provenance, not reward admission. Even a corrupted
			# original actor must have its own already-issued bolts retired safely.
			if int(row.wave) <= wave and is_instance_valid(actor) and row.node.get_ref() == actor:
				result.append(node)
				break
	return result

func retire_echoes_wave_projectiles(wave: int) -> void:
	if not run_source_context_valid() or not echoes_all_deaths_accepted(wave): return
	for projectile: Node3D in _wave_owned_projectiles(wave):
		if is_instance_valid(projectile): projectile.cancel_cast()

func echoes_danger_drained(wave: int) -> bool:
	if wave == 0: return run_source_context_valid() and _sealed.is_empty()
	if wave < 1 or wave > Plan.TOTAL_WAVES or not echoes_all_deaths_accepted(wave): return false
	for member: Dictionary in _context.plan.waves[wave - 1].members:
		var actor: Node3D = _actors[member.member_id].node.get_ref()
		if actor.get("state") != &"dead" or float(actor.get("health")) != 0.0: return false
		if actor.has_method("get_danger_zones") and not actor.get_danger_zones().is_empty(): return false
		if member.archetype != "rootwarden" and bool(actor.get("attack_dispatch_in_progress")): return false
	for projectile: Node3D in _wave_owned_projectiles(wave):
		if is_instance_valid(projectile) and projectile.is_flight_active(): return false
	return true

func retire_echoes_combat() -> void:
	# Cleanup is deliberately limited to our original descendants and their own
	# bolts. Player/companion and retained-world projectiles are never cancelled.
	for id: String in _actors:
		var row: Dictionary = _actors[id]
		var actor := row.node.get_ref() as Node3D
		if is_instance_valid(actor) and actor.get_parent() == _combat_root:
			actor.set("combat_active", false)
			actor.process_mode = Node.PROCESS_MODE_DISABLED
	for projectile: Node3D in _wave_owned_projectiles(Plan.TOTAL_WAVES):
		if is_instance_valid(projectile): projectile.cancel_cast()

func retire_echoes_runtime(generation: int) -> void:
	if generation != run_generation or _runtime_retired: return
	_runtime_retired = true
	retire_echoes_combat()

func echoes_cache_record(director: Node3D, wave: int) -> Dictionary:
	if not run_source_context_valid() or not owns_source(director, "trial_director") or not echoes_danger_drained(wave): return {}
	var plan: Dictionary = Plan.wave(_context.plan, wave)
	if plan.is_empty(): return {}
	var at := Vector3(plan.cache.position[0], plan.cache.position[1], plan.cache.position[2])
	return {"wave": wave, "receipt": plan.receipt, "room_id": 0, "position": to_global(at)}

func checkpoint_cache_placement_allowed(point: Vector3, radius: float) -> bool:
	if not run_source_context_valid() or not point.is_finite() or not is_finite(radius) or radius < 0.4 or radius > 1.1: return false
	var local := to_local(point)
	# Whole visible cache footprint stays in the safe, unobstructed southern
	# alcove. The exact floor proof rejects a retained Nexus floor underneath.
	if absf(local.x) + radius > 8.0 or local.z - radius < 14.7 or local.z + radius > 19.0: return false
	return _owned_floor_clear(to_global(Vector3(local.x, 0.15, local.z)), radius, 1.7)

func snapshot() -> Dictionary:
	var director: Node3D = registered_activity_sources().get("trial_director")
	var status: Dictionary = director.snapshot() if director != null else {}
	var active_count := 0
	var boss: Dictionary = {}
	for id: String in _actors:
		var row: Dictionary = _actors[id]
		var actor := row.node.get_ref() as Node3D
		if not owns_echoes_actor(actor, id) or actor.get("state") == &"dead" or not bool(actor.get("combat_active")): continue
		active_count += 1
		if row.member.archetype == "rootwarden": boss = actor.snapshot()
	return {"active": true, "run_kind": "activity", "activity_id": Plan.ID, "theme_label": "Echoes of Eternity",
		"seed": expedition_seed, "rooms": [{"id": 0, "cell": Vector2i.ZERO, "x": 0, "y": 0, "kind": "combat", "hidden": false, "discovered": true, "neighbors": []}],
		"discovered": [0], "current_room_id": 0, "current_room": 0, "room_count": 1, "discovered_count": 1,
		"active_enemies": active_count, "objective": status.get("message", objective), "echoes_director": status,
		"boss_active": not boss.is_empty(), "boss_health": boss.get("health", 0.0), "boss_max_health": boss.get("max_health", 1.0),
		"boss_phase": boss.get("phase", 1), "boss_id": "rootwarden", "boss_name": "Rootwarden Echo", "boss_role": "required",
		"boss_phase_label": "GUARDIAN'S FURY" if int(boss.get("phase", 1)) > 1 else "ROOTWARDEN ECHO", "boss": boss}

func presentation_snapshot() -> Dictionary:
	return {"native_placeholder_art": true, "local_trial": true, "waves": Plan.TOTAL_WAVES,
		"simultaneous_ordinary_cap": 3, "simultaneous_boss_cap": 1, "cache_view_cap": 8,
		"retained_actor_cap": 11, "extra_local_lights": 0, "batch_report": _visual_report.get("batch_report", {}).duplicate(true)}
