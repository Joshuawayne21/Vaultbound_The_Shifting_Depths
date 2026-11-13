extends Node3D
## An issued local discovery visit. Session owns the only bag, source receipts,
## saved completion and return proof; this world only admits its authored nodes.
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const Layout = preload("res://resources/activities/beastwilds_layout.tres")
const Builder = preload("res://scripts/activities/beastwilds_builder.gd")
const Discovery = preload("res://scripts/activities/activity_discovery.gd")
const Exit = preload("res://scripts/activities/activity_exit.gd")
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
var display_name := "THE BEASTWILDS"
var objective := "Read the trail · recover the egg · rescue the spirit · return to secure"
var run_generation := -1
var expedition_seed := 0
var _context: Dictionary = {}
var _registry: Dictionary = {}
var _floor: StaticBody3D
var _player: WeakRef
var _owner: WeakRef
var _session: Node
var _built := false
var _specimens: Array[Node3D] = []
var _visual_report: Dictionary = {}
var _visual_elapsed := 0.0
var _visual_clock := 0.0
var _visual_interval := 0.15
var _motion := 1.0
var _discovered: Array[int] = [0]
var _current_room_id := 0

func configure_activity(context: Dictionary) -> bool:
	if is_inside_tree() or not _context.is_empty(): return false
	if not Plan.exact_keys(context, ["activity_id", "definition_version", "serial", "seed", "generation", "plan"]) \
		or context.activity_id != "beastwilds" or context.definition_version != 1 \
		or not Plan.integer(context.generation, 0) or not Plan.valid(context.plan) \
		or context.serial != context.plan.serial or context.seed != context.plan.seed: return false
	_context = context.duplicate(true)
	run_generation = int(context.generation)
	expedition_seed = int(context.seed)
	return true

func issued_activity_context() -> Dictionary:
	return _context.duplicate(true)

func _ready() -> void:
	if _context.is_empty() or _built: return
	_built = true
	_session = get_node_or_null("/root/ExpeditionSession")
	_visual_report = Builder.build(self, Layout, expedition_seed)
	_floor = _visual_report.floor
	_specimens.assign(_visual_report.specimens)
	for row: Dictionary in _context.plan.sources:
		var source := Discovery.new()
		source.name = String(row.slot_id).to_pascal_case()
		source.position = Layout.source_position(row.slot_id, expedition_seed)
		if not source.configure(self, row.slot_id, row.kind, run_generation):
			source.free()
			continue
		add_child(source)
		_register_source(row, source, Plan.SOURCE_SCRIPT)
	var exit := Exit.new()
	exit.name = "BeastwildsReturnSpring"
	exit.position = Layout.RETURN_POSITION
	if exit.configure(self, run_generation):
		add_child(exit)
		_register_source(_context.plan.exit, exit, Plan.EXIT_SCRIPT)
	else:
		exit.free()
	add_to_group("visual_quality")
	var preferences := get_node_or_null("/root/VisualSettings")
	apply_visual_settings(preferences.snapshot() if preferences != null else {"quality": 1})

func _register_source(row: Dictionary, source: Node3D, script_path: String) -> void:
	if _registry.has(row.slot_id):
		push_error("An activity source cannot be registered twice.")
		return
	_registry[row.slot_id] = {"node": weakref(source), "transform": source.transform,
		"script": script_path, "slot_id": String(row.slot_id), "kind": String(row.kind), "receipt": String(row.receipt)}

func bind_activity_actor(player: Node3D, game_owner: Node) -> bool:
	# Candidate binding precedes publication; do not require owner.active_world
	# to point at this candidate before Game has validated its actual floor.
	if not is_inside_tree() or not activity_ready_valid() or not is_instance_valid(player) \
		or not player.is_inside_tree() or not is_instance_valid(game_owner): return false
	if _player != null or _owner != null:
		return _player != null and _owner != null and _player.get_ref() == player and _owner.get_ref() == game_owner
	_player = weakref(player)
	_owner = weakref(game_owner)
	return true

func activity_ready_valid() -> bool:
	if not _built or not is_inside_tree() or is_queued_for_deletion() or not Plan.valid(_context.get("plan")): return false
	if not is_instance_valid(_floor) or not _floor.is_inside_tree() or not is_ancestor_of(_floor): return false
	if run_generation != int(_context.generation) or expedition_seed != int(_context.seed) or _registry.size() != 5: return false
	for id: String in Plan.SOURCE_IDS + ["return_spring"]:
		var record: Dictionary = _registry.get(id, {})
		if record.is_empty() or not owns_source(record.node.get_ref(), id): return false
	return true

func owns_source(source: Node3D, slot_id: String) -> bool:
	if not _built or is_queued_for_deletion() or not _registry.has(slot_id) or not is_instance_valid(source): return false
	var row: Dictionary = _registry[slot_id]
	if row.node.get_ref() != source or source.get_parent() != self or source.is_queued_for_deletion(): return false
	if source.get_script() == null or source.get_script().resource_path != row.script or not source.transform.is_equal_approx(row.transform): return false
	return source.identity_snapshot() == {"slot_id": slot_id, "kind": row.kind, "generation": run_generation}

func registered_activity_sources() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _registry:
		var source := _registry[id].node.get_ref() as Node3D
		result[id] = source if owns_source(source, id) else null
	return result

func run_source_context_valid() -> bool:
	if not activity_ready_valid() or not is_instance_valid(_session) or not _session.has_method("activity_context_valid"): return false
	var owner := _owner.get_ref() as Node if _owner != null else null
	return is_instance_valid(owner) and owner.get("active_world") == self and not bool(owner.get("transitioning")) \
		and bool(_session.activity_context_valid(self, run_generation))

func can_reach_activity_source(source: Node3D, actor: Node3D, radius: float = 2.8) -> bool:
	# Physical/control check can also review a completed exit for a failed-return
	# retry. It never proves the visit is active or grants permission to reward it.
	if not is_inside_tree() or is_queued_for_deletion() or not is_finite(radius) or radius <= 0 or radius > 3.0: return false
	var player := _player.get_ref() as Node3D if _player != null else null
	var owner := _owner.get_ref() as Node if _owner != null else null
	var input := get_node_or_null("/root/InputHub")
	if not is_instance_valid(actor) or actor != player or not is_instance_valid(owner) or owner.get("active_world") != self \
		or bool(owner.get("transitioning")) or actor.is_queued_for_deletion() or not actor.is_inside_tree() \
		or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_visible_in_tree() \
		or source.get_parent() != self or source.get_viewport() != actor.get_viewport() or source.get_world_3d() != actor.get_world_3d() \
		or not source.global_position.is_finite() or not actor.global_position.is_finite() \
		or float(actor.get("health")) <= 0 or bool(actor.get("downed")) or bool(actor.get("eliminated")) \
		or not bool(actor.get("controls_enabled")) or input == null or not input.is_gameplay_input_available() \
		or actor.get("combat") == null or actor.combat.state != &"idle" \
		or actor.global_position.distance_to(source.global_position) > radius: return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.3, 1 | 16)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and _source_floor_clear(source)

func _source_floor_clear(source: Node3D) -> bool:
	if not is_instance_valid(_floor) or not _floor.is_inside_tree(): return false
	var point := source.global_position
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point - Vector3.UP * 0.3, 1)
	ray.collide_with_areas = false
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.collider != _floor or Vector3(hit.normal).y < 0.98 or absf(Vector3(hit.position).y - point.y) > 0.025: return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.40
	capsule.height = ACTOR_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = point + Vector3.UP * 0.90
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	return space.intersect_shape(query, 1).is_empty()

func activity_claim_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not can_reach_activity_source(source, actor): return {}
	for id: String in Plan.SOURCE_IDS:
		if owns_source(source, id):
			var row: Dictionary = _registry[id]
			return {"slot_id": id, "kind": row.kind, "receipt": row.receipt}
	return {}

func activity_exit_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not owns_source(source, "return_spring") or not can_reach_activity_source(source, actor): return {}
	var row: Dictionary = _registry.return_spring
	return {"slot_id": "return_spring", "kind": "exit", "receipt": row.receipt}

func source_approach_position(slot_id: String) -> Vector3:
	return to_global(Layout.approach_position(slot_id, expedition_seed))

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Layout.SPAWN_POSITION)

func get_companion_navigation_profile() -> Dictionary:
	return {"mode": &"terraced_city", "floor_min": 0.0, "floor_max": 0.0}

func get_companion_navigation_graph() -> Dictionary:
	var graph: Dictionary = Layout.navigation_graph(expedition_seed)
	var points: PackedVector3Array = graph.points
	for index in range(points.size()): points[index] = to_global(points[index])
	graph.points = points
	return graph

func validate_activity_arrival(entry_id: StringName) -> bool:
	if entry_id != &"default" or not activity_ready_valid(): return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0): return false
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"): continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false): excluded.append((body as CollisionObject3D).get_rid())
	var capsule := CapsuleShape3D.new()
	capsule.radius = ACTOR_RADIUS
	capsule.height = ACTOR_HEIGHT
	var space := get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 2.2), Vector3(1.6, 0, 2.2)]:
		var point := spawn.origin + spawn.basis * offset
		for radial: Vector3 in [Vector3.ZERO, Vector3(ACTOR_RADIUS, 0, 0), Vector3(-ACTOR_RADIUS, 0, 0), Vector3(0, 0, ACTOR_RADIUS), Vector3(0, 0, -ACTOR_RADIUS)]:
			var ray := PhysicsRayQueryParameters3D.create(point + radial + Vector3.UP * 0.5, point + radial - Vector3.UP * 0.5, 1)
			ray.exclude = excluded
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != _floor or Vector3(hit.normal).dot(Vector3.UP) < 0.98 \
				or absf(Vector3(hit.position).y - (spawn.origin.y - 0.15)) > 0.025: return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(spawn.basis, point + Vector3.UP * ACTOR_HEIGHT * 0.5)
		query.collision_mask = 1 | 16
		query.exclude = excluded
		query.margin = 0.005
		query.collide_with_areas = false
		if not space.intersect_shape(query, 1).is_empty(): return false
	return true

func apply_visual_settings(settings: Dictionary) -> void:
	_motion = clampf(float(settings.get("decorative_motion_scale", 0.0 if bool(settings.get("reduced_motion", false)) else 1.0)), 0.0, 1.0)
	_visual_interval = 0.25 if int(settings.get("quality", 1)) == 0 else 0.15
	set_process(_motion > 0.0)
	for specimen: Node3D in _specimens:
		if is_instance_valid(specimen): specimen.apply_visual_settings(settings)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_visual_elapsed += clampf(delta, 0.0, 0.1)
	if _visual_elapsed < _visual_interval: return
	_visual_clock += _visual_elapsed * _motion
	_visual_elapsed = 0.0
	for index in range(_specimens.size()):
		if is_instance_valid(_specimens[index]): _specimens[index].pose(&"idle", _visual_clock + float(index) * 0.7)

func presentation_snapshot() -> Dictionary:
	return {"habitats": 4, "display_specimens": _specimens.size(), "active_enemies": 0,
		"extra_local_lights": 0, "fauna_regions": int(_visual_report.get("fauna_regions", 0)),
		"navigation_points": Layout.navigation_graph(expedition_seed).points.size(),
		"native_placeholder_art": true, "direct_pet_capture": false,
		"batch_report": _visual_report.get("batch_report", {}).duplicate(true)}

func snapshot() -> Dictionary:
	# Reuse the existing compact minimap. Discovery is presentation state for
	# this visit; it cannot claim objectives, ownership or progression.
	var anchors: Array[Vector3] = [Layout.SPAWN_POSITION]
	anchors.append_array(Layout.CENTERS)
	var cells: Array[Vector2i] = [Vector2i(0, 2), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1)]
	var neighbors: Array = [[1, 4], [0, 2], [1, 3], [2, 4], [3, 0]]
	var player := _player.get_ref() as Node3D if _player != null else null
	if is_instance_valid(player) and player.is_inside_tree() and player.get_world_3d() == get_world_3d():
		var nearest := 0
		var local := to_local(player.global_position)
		for index in range(anchors.size()):
			if local.distance_squared_to(anchors[index]) < local.distance_squared_to(anchors[nearest]): nearest = index
			if local.distance_to(anchors[index]) < 9.0 and index not in _discovered: _discovered.append(index)
		_current_room_id = nearest
	var rooms: Array[Dictionary] = []
	for index in range(anchors.size()):
		rooms.append({"id": index, "cell": cells[index], "x": cells[index].x, "y": cells[index].y,
			"kind": "extraction" if index == 0 else "habitat", "hidden": false,
			"discovered": index in _discovered, "neighbors": neighbors[index].duplicate()})
	return {"active": true, "run_kind": "activity", "activity_id": "beastwilds", "theme_label": "The Beastwilds",
		"seed": expedition_seed, "rooms": rooms, "discovered": _discovered.duplicate(),
		"current_room_id": _current_room_id, "current_room": _current_room_id,
		"room_count": rooms.size(), "discovered_count": _discovered.size(),
		"boss": {"visible": false}, "active_enemies": 0, "objective": objective}
