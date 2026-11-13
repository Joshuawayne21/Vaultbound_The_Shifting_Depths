extends Node3D
## Native six-room activity. Session alone owns puzzle, combat and reward receipts.
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
const Builder = preload("res://scripts/activities/gilded_builder.gd")
const Layout = preload("res://resources/activities/gilded_layout.tres")
const Exit = preload("res://scripts/activities/activity_exit.gd")
const CacheManager = preload("res://scripts/treasure/loot_cache_manager.gd")
const SOURCE_SCRIPTS := {
	"clue": preload("res://scripts/activities/gilded_clue.gd"), "puzzle": preload("res://scripts/activities/gilded_puzzle.gd"),
	"plate": preload("res://scripts/activities/gilded_plate.gd"), "treasury": preload("res://scripts/activities/gilded_treasury.gd"),
	"reveal": preload("res://scripts/activities/gilded_reveal.gd"), "trap": preload("res://scripts/activities/gilded_trap.gd")}
const GROUPS := ["enemies", "combat_targets", "combat_telegraphs", "bosses"]
const ROOM_SCRIPT := "res://scripts/world/abyss_room.gd"
const BODY_RADIUS := 0.34
const BODY_HEIGHT := 1.7
var display_name := "THE GILDED VAULT"
var objective := "Read the tablet · awaken three seals · defeat the guardian · search and return"
var run_generation := -1
var expedition_seed := 0
var layout: Dictionary = {}
var _context: Dictionary = {}
var _layout_copy: Dictionary = {}
var _rooms: Dictionary = {}
var _room_pins: Dictionary = {}
var _registry: Dictionary = {}
var _guardian: Node3D
var _guardian_pin: Dictionary = {}
var _guardian_root: Node3D
var _guardian_admitted := false
var _guardian_activated := false
var _guardian_death_accepted := false
var _guardian_fault_reported := false
var _guardian_attempt_frame := -1
var _guardian_retry := 0.0
var _holder: Node3D
var _cache_manager: Node3D
var _player: WeakRef
var _owner: WeakRef
var _session: Node
var _built := false
var _retired := false
var _revision := 0
var _branch_observed := false
var _decision_elapsed := 0.0
var _discovered: Array[int] = [0]
var _current_room := 0
var _visual_report: Dictionary = {}

func configure_activity(context: Dictionary) -> bool:
	if is_inside_tree() or not _context.is_empty() or not Plan.exact_keys(context, ["activity_id", "definition_version", "serial", "seed", "generation", "plan"]) \
			or context.activity_id != Plan.ID or context.definition_version != 1 or not Plan.integer(context.generation, 0) \
			or not Plan.valid(context.plan) or context.serial != context.plan.serial or context.seed != context.plan.seed: return false
	_context = context.duplicate(true)
	run_generation = int(context.generation)
	expedition_seed = int(context.seed)
	return true

func issued_activity_context() -> Dictionary: return _context.duplicate(true)

func _ready() -> void:
	if _context.is_empty() or _built: return
	_built = true
	_session = get_node_or_null("/root/ExpeditionSession")
	var built: Dictionary = Builder.build(self, _context.plan, expedition_seed)
	_rooms = built.get("rooms", {})
	_holder = built.get("holder") as Node3D
	_visual_report = built.get("visual_report", {})
	if _rooms.size() != 6 or not is_instance_valid(_holder) or _holder.get_parent() != self: return
	for row: Dictionary in _context.plan.layout.rooms:
		var room := _rooms.get(int(row.id)) as Node3D
		if not is_instance_valid(room): continue
		_pin_room(room, row)
	_build_navigation_layout()
	for row: Dictionary in _context.plan.sources:
		if row.slot_id == "guardian": continue
		var source: Node3D = Exit.new() if row.kind == "exit" else SOURCE_SCRIPTS[row.kind].new()
		source.name = String(row.slot_id).to_pascal_case()
		source.position = _point(row.position)
		source.rotation.y = float(row.yaw)
		var configured: bool = source.configure(self, run_generation) if row.kind == "exit" else source.configure(self, row, run_generation)
		if not configured:
			source.free()
			continue
		_rooms[int(row.room_id)].add_child(source)
		_registry[String(row.slot_id)] = {"node": weakref(source), "row": row.duplicate(true), "parent": source.get_parent().get_instance_id(), "transform": source.transform}
	_prepare_guardian()

static func _point(values: Array) -> Vector3: return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _pin_room(room: Node3D, row: Dictionary) -> void:
	var floor := room.get_node_or_null("Floor/Body") as StaticBody3D
	var shape := room.get_node_or_null("Floor/Body/Collision") as CollisionShape3D
	var doors: Dictionary = {}
	for direction: String in ["north", "east", "south", "west"]:
		var door := room.get_node_or_null("DoorFillers/" + direction.capitalize()) as Node3D
		var body := door.get_node_or_null("Body") as StaticBody3D if door != null else null
		var collision := body.get_node_or_null("Collision") as CollisionShape3D if body != null else null
		if body != null and collision != null:
			doors[direction] = {"node": weakref(door), "parent": weakref(door.get_parent()), "body": weakref(body), "collision": weakref(collision),
				"transform": door.transform, "global_transform": door.global_transform,
				"shape": collision.shape, "layer": 0 if row.openings.has(direction) else 1}
	_room_pins[int(row.id)] = {"node": weakref(room), "row": row.duplicate(true), "transform": room.transform,
		"floor": weakref(floor) if floor != null else null, "collision": weakref(shape) if shape != null else null,
		"floor_parent": weakref(floor.get_parent()) if floor != null else null,
		"floor_transform": floor.global_transform if floor != null else Transform3D.IDENTITY,
		"floor_shape": shape.shape if shape != null else null, "doors": doors}

func _room_current(id: int, full: bool = true) -> bool:
	if not _room_pins.has(id) or not is_instance_valid(_holder) or _holder.get_parent() != self \
			or _holder.transform != Transform3D.IDENTITY: return false
	var pin: Dictionary = _room_pins[id]
	var room := pin.node.get_ref() as Node3D
	if not is_instance_valid(room) or not room.is_inside_tree() or room.is_queued_for_deletion() or room.get_parent() != _holder \
			or room.scene_file_path != pin.row.scene or room.get_script() == null or room.get_script().resource_path != ROOM_SCRIPT \
			or not room.transform.is_equal_approx(pin.transform) or String(room.get("module_id")) != pin.row.module_id: return false
	if not full: return true
	var floor := pin.floor.get_ref() as StaticBody3D if pin.floor != null else null
	var collision := pin.collision.get_ref() as CollisionShape3D if pin.collision != null else null
	if floor == null or collision == null or not floor.is_inside_tree() or floor.is_queued_for_deletion() \
			or pin.floor_parent == null or floor.get_parent() != pin.floor_parent.get_ref() or floor.get_parent().get_parent() != room \
			or room.get_node_or_null("Floor/Body") != floor or collision.get_parent() != floor or collision.disabled \
			or collision.is_queued_for_deletion() or not collision.is_inside_tree() \
			or not floor.global_transform.is_equal_approx(pin.floor_transform) or collision.transform != Transform3D.IDENTITY \
			or floor.collision_layer != 1 or floor.collision_mask != 0 or collision.shape != pin.floor_shape \
			or not collision.shape is BoxShape3D or collision.shape.size != Vector3(24, 0.5, 24) or pin.doors.size() != 4: return false
	for direction: String in pin.doors:
		var entry: Dictionary = pin.doors[direction]
		var door := entry.node.get_ref() as Node3D
		var body := entry.body.get_ref() as StaticBody3D
		var shape := entry.collision.get_ref() as CollisionShape3D
		if door == null or body == null or shape == null or not is_instance_valid(door.get_parent()) \
				or door.get_parent() != entry.parent.get_ref() or door.get_parent().get_parent() != room \
				or room.get_node_or_null("DoorFillers/" + direction.capitalize()) != door or body.get_parent() != door \
				or door.is_queued_for_deletion() or body.is_queued_for_deletion() or shape.is_queued_for_deletion() \
				or not door.is_inside_tree() or not body.is_inside_tree() or not shape.is_inside_tree() \
				or not door.global_transform.is_equal_approx(entry.global_transform) \
				or shape.get_parent() != body or not door.transform.is_equal_approx(entry.transform) or body.transform != Transform3D.IDENTITY \
				or shape.transform != Transform3D.IDENTITY or shape.disabled or shape.shape != entry.shape \
				or not shape.shape is BoxShape3D or shape.shape.size != Vector3(6, 2.4, 0.5) \
				or body.collision_mask != 0 or body.collision_layer != int(entry.layer): return false
	return true

func _build_navigation_layout() -> void:
	var rows: Array[Dictionary] = []
	for row: Dictionary in _context.plan.layout.rooms:
		rows.append({"id": int(row.id), "cell": Vector2i(int(row.cell[0]), int(row.cell[1])),
			"neighbors": row.neighbors.duplicate(), "module_id": row.module_id,
			"kind": "secret" if int(row.id) == 5 else ("entrance" if int(row.id) == 0 else "treasure")})
	layout = {"rooms": rows}
	_layout_copy = layout.duplicate(true)

func activity_ready_valid() -> bool:
	return not _context.is_empty() and Plan.valid(_context.plan) and _native_runtime_valid(false)

func activity_runtime_matches(context: Dictionary) -> bool:
	return context == _context and _native_runtime_valid(true)

func _native_runtime_valid(require_live: bool) -> bool:
	if not _built or not is_inside_tree() or is_queued_for_deletion() or (require_live and _retired) \
			or global_transform != Transform3D.IDENTITY or run_generation != int(_context.get("generation", -1)) \
			or expedition_seed != int(_context.get("seed", -1)) or layout != _layout_copy \
			or _rooms.size() != 6 or _room_pins.size() != 6 or _registry.size() != 10: return false
	for id in range(6):
		if not _room_current(id): return false
	for id: String in Plan.SOURCE_IDS:
		if id == "guardian":
			# Admission needs the complete original candidate. Later actor loss
			# denies its independent death/drain proofs, but never traps a party
			# behind a broken reward objective without the original abandon route.
			if not _guardian_admitted and not owns_gilded_guardian(_guardian): return false
		elif not _registry.has(id) or not owns_source(_registry[id].node.get_ref(), id): return false
	return true

func owns_source(source: Node3D, id: String) -> bool:
	if id == "guardian": return owns_gilded_guardian(source)
	if not _registry.has(id) or not is_instance_valid(source) or source.is_queued_for_deletion(): return false
	if not source.is_inside_tree(): return id == "return_spring" and _owns_retained_exit(source)
	var pin: Dictionary = _registry[id]
	var row: Dictionary = pin.row
	if pin.node.get_ref() != source or source.get_parent().get_instance_id() != int(pin.parent) \
			or source.get_parent() != _rooms.get(int(row.room_id)) or not _room_current(int(row.room_id), false) \
			or source.get_script() == null or source.get_script().resource_path != row.script or not source.transform.is_equal_approx(pin.transform): return false
	if source.identity_snapshot() != {"slot_id": id, "kind": row.kind, "generation": run_generation}: return false
	if row.kind != "exit" and not source.source_configuration_matches(row, run_generation): return false
	if row.kind == "plate" and not source.native_footprint_valid(): return false
	if row.kind == "reveal" and not source.barrier_native_valid(): return false
	return true

func _owns_retained_exit(source: Node3D) -> bool:
	# Completed return proof survives only Game's exact detached rollback owner.
	# This proves identity, never live reach, combat, or another reward claim.
	if not _built or not _retired or is_inside_tree() or is_queued_for_deletion() or get_parent() != null \
			or transform != Transform3D.IDENTITY or get_script() == null \
			or get_script().resource_path != "res://scripts/activities/gilded_level.gd" \
			or run_generation != int(_context.get("generation", -1)) or expedition_seed != int(_context.get("seed", -1)): return false
	var owner := _owner.get_ref() as Node if _owner != null else null
	if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion() \
			or owner.get_script() == null or owner.get_script().resource_path != "res://scripts/systems/game.gd" \
			or not bool(owner.get("transitioning")) or owner.get("_travel_retained_world") != self \
			or owner.get("current_location") != &"realm_nexus" or owner.get("player") != bound_activity_player(): return false
	var destination := owner.get("active_world") as Node3D
	var world_root := owner.get("world_root") as Node
	if not is_instance_valid(destination) or not destination.is_inside_tree() or destination.is_queued_for_deletion() \
			or not is_instance_valid(world_root) or world_root.get_parent() != owner or destination.get_parent() != world_root \
			or destination.get_script() == null or destination.get_script().resource_path != "res://scripts/world/realm_nexus.gd" \
			or not is_instance_valid(_holder) or _holder.is_queued_for_deletion() or _holder.get_parent() != self \
			or _holder.transform != Transform3D.IDENTITY or not _room_pins.has(0): return false
	var pin: Dictionary = _registry.return_spring
	var room_pin: Dictionary = _room_pins[0]
	var room := room_pin.node.get_ref() as Node3D
	if not is_instance_valid(room) or room.is_queued_for_deletion() or room.is_inside_tree() or _rooms.get(0) != room \
			or room.get_parent() != _holder or room.get_script() == null or room.get_script().resource_path != ROOM_SCRIPT \
			or room.scene_file_path != room_pin.row.scene or String(room.get("module_id")) != room_pin.row.module_id \
			or not room.transform.is_equal_approx(room_pin.transform) or pin.row != Plan.source(_context.plan, "return_spring") \
			or pin.node.get_ref() != source or source.get_parent() != room or room.get_instance_id() != int(pin.parent) \
			or source.get_script() == null or source.get_script() != Exit or not source.transform.is_equal_approx(pin.transform): return false
	return source.identity_snapshot() == {"slot_id": "return_spring", "kind": "exit", "generation": run_generation}

func registered_activity_sources() -> Dictionary:
	var result: Dictionary = {}
	for id: String in Plan.SOURCE_IDS:
		var source := _guardian if id == "guardian" else (_registry[id].node.get_ref() as Node3D if _registry.has(id) else null)
		result[id] = source if owns_source(source, id) else null
	return result

func bind_activity_actor(player: Node3D, game_owner: Node) -> bool:
	if not activity_ready_valid() or not is_instance_valid(player) or not player.is_inside_tree() or not is_instance_valid(game_owner): return false
	if _player != null or _owner != null: return _player != null and _owner != null and _player.get_ref() == player and _owner.get_ref() == game_owner
	_player = weakref(player)
	_owner = weakref(game_owner)
	_cache_manager = CacheManager.new()
	_cache_manager.name = "GildedLootCaches"
	_cache_manager.configure(_session, _rooms, player, self, run_generation)
	add_child(_cache_manager)
	return true

func bound_activity_player() -> Node3D: return _player.get_ref() as Node3D if _player != null else null

func run_source_context_valid() -> bool:
	var owner := _owner.get_ref() as Node if _owner != null else null
	return activity_runtime_matches(_context) and is_instance_valid(owner) and owner.get("active_world") == self \
		and not bool(owner.get("transitioning")) and is_instance_valid(_session) and _session.gilded_runtime_context_valid(self, run_generation)

func gilded_clock_available() -> bool:
	return not _retired and _controls_available()

func _controls_available() -> bool:
	var owner := _owner.get_ref() as Node if _owner != null else null
	var input := get_node_or_null("/root/InputHub")
	return is_instance_valid(owner) and owner.get("active_world") == self and not bool(owner.get("transitioning")) \
		and bool(owner.get("_application_focused")) \
		and not bool(owner.get("_modal_open")) and process_mode != Node.PROCESS_MODE_DISABLED \
		and input != null and input.is_gameplay_input_available()

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 6))

func validate_activity_arrival(entry_id: StringName) -> bool:
	if entry_id != &"default" or not activity_ready_valid(): return false
	var spawn := get_spawn_transform(entry_id).origin
	var excluded := _retained_rids()
	for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 2.2), Vector3(1.6, 0, 2.2)]:
		if not _owned_floor_clear(0, spawn + offset, BODY_RADIUS, BODY_HEIGHT, excluded): return false
	for edge: Array in [[0, 1], [1, 2], [2, 3], [3, 4], [4, 1]]:
		for lateral: float in [-2.4, 0.0, 2.4]:
			if not gilded_connector_clear(int(edge[0]), int(edge[1]), lateral, excluded): return false
	return true

func gilded_connector_clear(from_id: int, to_id: int, lateral: float = 0.0, excluded: Array[RID] = []) -> bool:
	if not _room_current(from_id) or not _room_current(to_id) or not layout.rooms[from_id].neighbors.has(to_id) \
			or not is_finite(lateral) or absf(lateral) > 2.4: return false
	var from: Vector3 = _rooms[from_id].global_position
	var toward: Vector3 = _rooms[to_id].global_position
	var direction := (toward - from).normalized()
	var side := Vector3(-direction.z, 0, direction.x)
	var middle := (from + toward) * 0.5 + side * lateral + Vector3.UP * 0.15
	var floors: Array = [_room_pins[from_id].floor.get_ref(), _room_pins[to_id].floor.get_ref()]
	var space := get_world_3d().direct_space_state
	for index in range(9):
		var point := middle + direction * (-1.0 + index * 0.25)
		for offset: Vector3 in [Vector3.ZERO, side * BODY_RADIUS, -side * BODY_RADIUS]:
			var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
			ray.exclude = excluded
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not floors.has(hit.collider) or Vector3(hit.normal).y < 0.98 or absf(Vector3(hit.position).y) > 0.025: return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.exclude = excluded
	query.transform.origin = middle - direction + Vector3.UP * BODY_HEIGHT * 0.5
	query.motion = direction * 2
	query.margin = 0.005
	if not space.intersect_shape(query, 1).is_empty(): return false
	var movement := space.cast_motion(query)
	return movement.size() == 2 and movement[0] >= 0.995

func _retained_rids() -> Array[RID]:
	var result: Array[RID] = []
	if get_parent() == null: return result
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"): continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false): result.append((body as CollisionObject3D).get_rid())
	return result

func _owned_floor_clear(room_id: int, point: Vector3, radius: float, height: float, excluded: Array[RID] = []) -> bool:
	if not point.is_finite() or not _room_current(room_id) or not is_finite(radius) or radius <= 0 or radius > 2: return false
	var floor: StaticBody3D = _room_pins[room_id].floor.get_ref()
	var space := get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
		var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
		ray.exclude = excluded
		ray.collide_with_areas = false
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.collider != floor or Vector3(hit.normal).y < 0.98 or absf(Vector3(hit.position).y) > 0.025: return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2 + 0.02)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = Vector3(point.x, maxf(point.y, 0.04), point.z) + Vector3.UP * capsule.height * 0.5
	query.collision_mask = 1 | 16
	query.exclude = excluded
	query.margin = 0.005
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()

func can_reach_activity_source(source: Node3D, actor: Node3D, radius := 2.8) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(source) or not source.is_inside_tree(): return false
	var input := get_node_or_null("/root/InputHub")
	if not is_instance_valid(actor) or actor != bound_activity_player() or not is_instance_valid(source) or source.get_parent() == null \
			or actor.get_world_3d() != get_world_3d() or not actor.is_inside_tree() or actor.is_queued_for_deletion() \
			or not source.is_visible_in_tree() or not actor.global_position.is_finite() or not source.global_position.is_finite() \
			or float(actor.get("health")) <= 0 or bool(actor.get("downed")) or bool(actor.get("eliminated")) \
			or not bool(actor.get("controls_enabled")) or input == null or not input.is_gameplay_input_available() \
			or actor.get("combat") == null or actor.combat.state != &"idle" or not is_finite(radius) or radius <= 0 or radius > 3 \
			or not _controls_available() or actor.global_position.distance_to(source.global_position) > radius: return false
	var id := String(source.identity_snapshot().get("slot_id", "")) if source.has_method("identity_snapshot") else ""
	if not owns_source(source, id): return false
	var room_id := int(_registry[id].row.room_id)
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.3, 1 | 16)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty() \
		and _owned_floor_clear(room_id, source.global_position + Vector3.UP * 0.15, 0.4, BODY_HEIGHT) \
		and _owned_floor_clear(room_id, actor.global_position, BODY_RADIUS, BODY_HEIGHT)

func gilded_source_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not can_reach_activity_source(source, actor): return {}
	var id := String(source.identity_snapshot().slot_id)
	var row: Dictionary = _registry[id].row
	return {"slot_id": id, "kind": row.kind, "receipt": row.receipt, "room_id": int(row.room_id)}

func activity_exit_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not owns_source(source, "return_spring") or gilded_source_record(source, actor).is_empty(): return {}
	return _context.plan.exit.duplicate(true)

func gilded_plate_record(puzzle: Node3D, actor: Node3D) -> Dictionary:
	if not run_source_context_valid() or not owns_source(puzzle, "rune_puzzle") or actor != bound_activity_player(): return {}
	var plates: Array[Dictionary] = []
	for id: String in _context.plan.puzzle.plate_ids:
		var source := _registry[id].node.get_ref() as Area3D
		if not owns_source(source, id): return {}
		plates.append({"slot_id": id, "source": source})
	return {"receipt": _context.plan.puzzle.receipt, "plates": plates}

func gilded_plate_floor_valid(plate: Area3D, actor: Node3D) -> bool:
	if actor != bound_activity_player() or not is_instance_valid(actor) or not is_instance_valid(plate) or not plate.has_method("identity_snapshot"): return false
	var id := String(plate.identity_snapshot().slot_id)
	return owns_source(plate, id) and _owned_floor_clear(2, plate.global_position + Vector3.UP * 0.15, 0.8, BODY_HEIGHT) \
		and _owned_floor_clear(2, actor.global_position, BODY_RADIUS, BODY_HEIGHT)

func present_gilded_puzzle(progress: int, solved: bool) -> void:
	if not run_source_context_valid(): return
	for index in range(3):
		var id := "plate_" + String(_context.plan.puzzle.order[index])
		var plate: Node3D = _registry[id].node.get_ref()
		if owns_source(plate, id): plate.set_accepted(solved or index < progress)

func _prepare_guardian() -> void:
	if not _rooms.has(3): return
	_guardian_root = Node3D.new()
	_guardian_root.name = "CombatActors"
	_rooms[3].add_child(_guardian_root)
	var member: Dictionary = _context.plan.guardian.actor
	var scene := load(String(member.canonical_scene)) as PackedScene
	if scene == null: return
	_guardian = scene.instantiate() as Node3D
	if not Plan.prepare_actor(_guardian, member):
		_guardian.free()
		_guardian = null
		return
	_guardian.position = _point(_context.plan.guardian.position)
	_guardian.process_mode = Node.PROCESS_MODE_DISABLED
	_guardian.set("combat_active", false)
	_guardian_root.add_child(_guardian)
	_guardian_pin = {"node": weakref(_guardian), "parent": _guardian_root.get_instance_id(), "member": member.duplicate(true),
		"data": weakref(_guardian.get("data")), "layer": int(_guardian.get("collision_layer")), "mask": int(_guardian.get("collision_mask")), "groups": []}
	for group: String in GROUPS:
		if _guardian.is_in_group(group):
			_guardian_pin.groups.append(group)
			_guardian.remove_from_group(group)
	_guardian.set("collision_layer", 0)
	_guardian.set("collision_mask", 0)
	_guardian.died.connect(_on_guardian_died)
	_guardian_attempt_frame = Engine.get_physics_frames()

func owns_gilded_guardian(actor: Node3D) -> bool:
	return not _guardian_pin.is_empty() and is_instance_valid(actor) and actor == _guardian and _guardian_pin.node.get_ref() == actor \
		and actor.is_inside_tree() and not actor.is_queued_for_deletion() and is_instance_valid(_guardian_root) \
		and actor.get_parent() == _guardian_root and _guardian_root.get_instance_id() == int(_guardian_pin.parent) \
		and _guardian_root.get_parent() == _rooms.get(3) and _guardian_root.transform == Transform3D.IDENTITY \
		and _guardian_pin.data.get_ref() == actor.get("data") \
		and _room_current(3, false) and Plan.actor_data_matches(actor, _guardian_pin.member)

func gilded_guardian_record(actor: Node3D) -> Dictionary:
	if not owns_gilded_guardian(actor): return {}
	return {"slot_id": "guardian", "receipt": _context.plan.guardian.receipt, "actor": actor}

func validate_gilded_guardian_spawn(actor: Node3D) -> bool:
	if not owns_gilded_guardian(actor) or not actor.position.is_equal_approx(_point(_context.plan.guardian.position)) \
			or actor.rotation != Vector3.ZERO or actor.scale != Vector3.ONE: return false
	var data: Dictionary = _guardian_pin.member.data_snapshot
	if not _owned_floor_clear(3, actor.global_position, float(data.collision_radius), float(data.collision_height)): return false
	for member: Node3D in _party_members():
		if member.global_position.distance_to(actor.global_position) < 6.0: return false
	for index in range(5):
		var point: Vector3 = actor.global_position.lerp(_rooms[3].global_position + Vector3(0, 0.15, 4), index / 4.0)
		if not _owned_floor_clear(3, point, float(data.collision_radius), float(data.collision_height)): return false
	return true

func _physics_process(delta: float) -> void:
	if not run_source_context_valid() or not gilded_clock_available(): return
	_decision_elapsed += clampf(delta, 0.0, 0.25)
	if _decision_elapsed < 0.1: return
	var elapsed := _decision_elapsed
	_decision_elapsed = 0.0
	_discover_current_room()
	if _guardian_admitted:
		if not owns_gilded_guardian(_guardian):
			if not _guardian_fault_reported:
				_guardian_fault_reported = true
				objective = "The original guardian is unavailable · return to abandon safely; no treasury reward was unlocked"
				if is_instance_valid(_session): _session.notice.emit(objective)
			return
		if not _guardian_activated: _activate_guardian()
		if not _guardian_death_accepted and owns_gilded_guardian(_guardian) and _guardian.get("state") == &"dead": _on_guardian_died(_guardian)
		if _guardian_death_accepted and gilded_guardian_drained(): _guardian.visible = false
		return
	_guardian_retry = maxf(0.0, _guardian_retry - elapsed)
	if _guardian_retry > 0 or Engine.get_physics_frames() <= _guardian_attempt_frame or not validate_gilded_guardian_spawn(_guardian): return
	var result: Dictionary = _session.admit_gilded_guardian(self, _guardian, run_generation)
	if not bool(result.get("ok", false)) or not bool(result.get("still_current", false)) or not run_source_context_valid():
		_guardian_retry = 0.5
		return
	_guardian_admitted = true
	if gilded_clock_available(): _activate_guardian()

func _activate_guardian() -> void:
	if _guardian_activated or not _guardian_admitted or not owns_gilded_guardian(_guardian) or not run_source_context_valid() or not gilded_clock_available(): return
	_guardian_activated = true
	for group: String in _guardian_pin.groups: _guardian.add_to_group(group)
	_guardian.set("collision_layer", int(_guardian_pin.layer))
	_guardian.set("collision_mask", int(_guardian_pin.mask))
	_guardian.set("combat_active", true)
	_guardian.process_mode = Node.PROCESS_MODE_INHERIT

func _on_guardian_died(actor: Node3D) -> void:
	if not run_source_context_valid() or not owns_gilded_guardian(actor) or _guardian_death_accepted: return
	var result: Dictionary = _session.record_gilded_guardian_death(self, actor, run_generation)
	if is_instance_valid(self) and bool(result.get("ok", false)) and bool(result.get("still_current", false)) \
			and bool(result.get("guardian_defeated", false)) and run_source_context_valid(): _guardian_death_accepted = true

func gilded_guardian_death_record(actor: Node3D) -> Dictionary:
	if not owns_gilded_guardian(actor) or actor.get("state") != &"dead" or float(actor.get("health")) != 0.0: return {}
	return {"slot_id": "guardian", "receipt": _context.plan.guardian.receipt, "archetype": "golem"}

func gilded_guardian_drained() -> bool:
	return owns_gilded_guardian(_guardian) and _guardian.get("state") == &"dead" and float(_guardian.get("health")) == 0.0 \
		and not bool(_guardian.get("attack_dispatch_in_progress")) and _guardian.get_danger_zones().is_empty()

func _party_members() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var owner := _owner.get_ref() as Node if _owner != null else null
	var party: Node = owner.get("party") if is_instance_valid(owner) else null
	if not is_instance_valid(party) or party.get("world") != self: return result
	var members: Dictionary = party.get("members")
	for actor: Variant in members.values():
		if actor is Node3D and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
				and not bool(actor.get("eliminated")) and (float(actor.get("health")) > 0 or bool(actor.get("downed"))): result.append(actor)
	return result

func gilded_party_target_valid(actor: Node3D) -> bool:
	return is_instance_valid(actor) and _party_members().has(actor) and CombatRules.party_target_available(actor)

func observe_gilded_branch_open(source: Node3D) -> void:
	if _branch_observed or not owns_source(source, "hidden_reveal") or not source.barrier_physically_open(): return
	_branch_observed = true
	_revision += 1

func stationary_blocker_revision() -> int: return _revision

func gilded_branch_physically_open() -> bool:
	var reveal: Node3D = _registry.hidden_reveal.node.get_ref() if _registry.has("hidden_reveal") else null
	return owns_source(reveal, "hidden_reveal") and reveal.barrier_physically_open()

func gilded_trap_escape_valid(trap: Node3D, actor: Node3D) -> bool:
	if actor != bound_activity_player() or not is_instance_valid(actor) \
			or not owns_source(trap, "optional_trap") or not gilded_branch_physically_open(): return false
	var clear := 0
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var safe := true
		for index in range(7):
			var point := trap.global_position + Vector3.UP * 0.15 + direction * (3.2 * index / 6.0)
			if not _owned_floor_clear(5, point, 0.4, BODY_HEIGHT):
				safe = false
				break
		if safe: clear += 1
	return clear >= 2

func gilded_damage_delivery_in_progress() -> bool:
	if owns_gilded_guardian(_guardian) and bool(_guardian.get("attack_dispatch_in_progress")): return true
	var trap: Node3D = _registry.optional_trap.node.get_ref() if _registry.has("optional_trap") else null
	return owns_source(trap, "optional_trap") and bool(trap.activation_snapshot().get("delivery_in_progress", false))

func gilded_cache_record(source: Node3D) -> Dictionary:
	if not is_instance_valid(source) or not source.has_method("identity_snapshot"): return {}
	var id := String(source.identity_snapshot().slot_id)
	if not owns_source(source, id) or id not in ["main_treasury", "optional_treasury"]: return {}
	for row: Dictionary in _context.plan.treasuries:
		if row.slot_id == id:
			return {"slot_id": id, "receipt": row.receipt, "room_id": int(row.cache.room_id),
				"position": _rooms[int(row.cache.room_id)].to_global(_point(row.cache.position))}
	return {}

func checkpoint_cache_placement_allowed(point: Vector3, radius: float) -> bool:
	if not run_source_context_valid() or not Layout.cache_allowed(_context.plan, point, radius): return false
	for id: int in [4, 5]:
		var local: Vector3 = _rooms[id].to_local(point)
		if absf(local.x) <= 10.5 and absf(local.z) <= 10.5:
			if id == 5 and not gilded_branch_physically_open(): return false
			var grounded := Vector3(point.x, 0.15, point.z)
			if not _owned_floor_clear(id, grounded, radius, BODY_HEIGHT): return false
			var approach := source_approach_position("main_treasury" if id == 4 else "optional_treasury")
			for index in range(7):
				if not _owned_floor_clear(id, grounded.lerp(approach, index / 6.0), 0.4, BODY_HEIGHT): return false
			return true
	return false

func gilded_cache_view(id: String) -> Node3D:
	if not run_source_context_valid() or not is_instance_valid(_cache_manager): return null
	_cache_manager.refresh()
	return _cache_manager.view_for(id)

func source_approach_position(id: String) -> Vector3: return Layout.source_approach(_context.plan, id)

func retire_gilded_runtime(generation: int) -> void:
	if generation != run_generation or _retired: return
	_retired = true
	if owns_gilded_guardian(_guardian):
		_guardian.set("combat_active", false)
		_guardian.process_mode = Node.PROCESS_MODE_DISABLED
		_guardian.set("collision_layer", 0)
		_guardian.set("collision_mask", 0)
		for group: String in GROUPS: _guardian.remove_from_group(group)
	var trap: Node3D = _registry.optional_trap.node.get_ref() if _registry.has("optional_trap") else null
	if owns_source(trap, "optional_trap"): trap.cancel()

func _discover_current_room() -> void:
	var actor := bound_activity_player()
	if not is_instance_valid(actor): return
	var cell := Vector2i(roundi(actor.global_position.x / 24.0), roundi(actor.global_position.z / 24.0))
	for room: Dictionary in layout.rooms:
		if room.cell != cell or (int(room.id) == 5 and not gilded_branch_physically_open()): continue
		_current_room = int(room.id)
		if not _discovered.has(_current_room): _discovered.append(_current_room)
		return

func snapshot() -> Dictionary:
	var spring: Node3D = _registry.return_spring.node.get_ref() if _registry.has("return_spring") else null
	var actor := bound_activity_player()
	var return_available := false
	if owns_source(spring, "return_spring") and is_instance_valid(actor):
		return_available = bool(spring.get_exit_status(actor).get("ok", false))
	var rows: Array[Dictionary] = []
	for row: Dictionary in layout.get("rooms", []):
		var copy := row.duplicate(true)
		copy.x = row.cell.x
		copy.y = row.cell.y
		copy.hidden = int(row.id) == 5 and not gilded_branch_physically_open()
		copy.discovered = _discovered.has(int(row.id))
		rows.append(copy)
	return {"active": true, "run_kind": "activity", "activity_id": Plan.ID, "theme_label": "The Gilded Vault", "seed": expedition_seed,
		"rooms": rows, "discovered": _discovered.duplicate(), "current_room_id": _current_room, "current_room": _current_room,
		"room_count": 6, "discovered_count": _discovered.size(), "objective": objective, "boss_active": false,
		"active_enemies": 1 if _guardian_admitted and owns_gilded_guardian(_guardian) and _guardian.get("state") != &"dead" else 0,
		"return_springs": [{"room_id": 0, "checkpoint_id": "return_spring", "available": return_available}]}

func presentation_snapshot() -> Dictionary:
	return {"native_placeholder_art": true, "local_treasure_expedition": true, "room_count": 6,
		"guardian_cap": 1, "trap_cap": 1, "cache_view_cap": 8, "visual_report": _visual_report.duplicate(true)}
