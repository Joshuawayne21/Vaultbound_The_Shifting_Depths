extends RefCounted
## One selected initial opportunity. Damage/cursor remain in the actual HazardCast.
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
var _world: WeakRef
var _runtime: WeakRef
var _generation := -1
var _rows: Dictionary = {}

func configure(runtime: Node, world: Node3D) -> void:
	_runtime = weakref(runtime)
	_world = weakref(world)
	_generation = int(world.run_generation)

func prepare(slot: Dictionary, room: Node3D, profile: Dictionary, path: Dictionary) -> bool:
	if not _current() or not _rows.is_empty() or not is_instance_valid(room): return false
	var world := _world.get_ref() as Node3D
	var geometry := room.get_parent() as Node3D
	var cell: Vector2i = world.layout.rooms[int(slot.room_id)].cell
	var expected := Transform3D(Basis.IDENTITY, Vector3(cell.x * float(world.layout.cell_size), 0, cell.y * float(world.layout.cell_size)))
	if not is_instance_valid(geometry) or geometry.get_parent() != world or geometry.transform != Transform3D.IDENTITY or room.transform != expected: return false
	var proof := Spawn.rolling_floor_snapshot(world, room, path, profile)
	var admitted := not proof.is_empty() and Spawn.rolling_path_clear(world, room, path, profile)
	var sphere := SphereShape3D.new()
	sphere.radius = float(profile.radius)
	_rows[String(slot.id)] = {"slot": slot.duplicate(true), "profile": profile.duplicate(true), "path": path.duplicate(true),
		"room": weakref(room), "geometry": weakref(geometry), "room_transform": room.transform, "geometry_transform": geometry.transform,
		"world_transform": world.global_transform, "floor": proof, "sphere": sphere, "admitted": admitted,
		"state": "unvisited" if admitted else "omitted", "issued": {}, "actor": null, "actor_id": 0, "terminal": {}, "accepted": false}
	return true

func is_admitted(id: String) -> bool:
	return bool(_rows.get(id, {}).get("admitted", false))

func admission_valid(slots: Array[Dictionary]) -> bool:
	var count := 0
	for slot: Dictionary in slots:
		if slot.definition_id != "root_rolling_stone": continue
		count += 1
		var row: Dictionary = _rows.get(String(slot.id), {})
		if row.is_empty() or row.slot != slot or not row.admitted or not _identity(row): return false
	var expected := 0
	for row: Dictionary in _rows.values():
		if row.admitted: expected += 1
	return count == expected

func has_room(id: int) -> bool:
	return not _room_row(id).is_empty()

func enter(id: int) -> void:
	var row := _room_row(id)
	if row.is_empty() or row.state != "unvisited": return
	row.state = "attempting" # Publish before reservation, source or visual callbacks.
	if not _current() or not _identity(row):
		row.state = "omitted"
		return
	var runtime := _runtime.get_ref() as Node
	runtime.arm_rolling(row.slot)
	if _current() and row.state == "attempting":
		row.state = "omitted" if row.issued.is_empty() else "unproven"

func accepting(slot_id: String, actor: Node3D, issued: Dictionary) -> bool:
	var row: Dictionary = _rows.get(slot_id, {})
	if not _current() or row.is_empty() or row.state != "attempting" or not _identity(row) \
		or not is_instance_valid(actor) or issued.shape != row.path or issued.profile != row.profile: return false
	row.actor = weakref(actor)
	row.actor_id = actor.get_instance_id()
	row.issued = issued.duplicate(true)
	return true

func finish_attempt(slot_id: String, actor_id: int, issued: Dictionary, accepted: bool, never_accepted: bool = false) -> void:
	var row: Dictionary = _rows.get(slot_id, {})
	if not _current() or row.is_empty() or row.issued != issued or int(row.actor_id) != actor_id or row.state == "terminal": return
	row.accepted = bool(row.accepted) or accepted
	row.state = "accepted" if accepted else "omitted" if never_accepted else "unproven"

func source_valid(actor: Node3D, issued: Dictionary) -> bool:
	var row: Dictionary = _rows.get(String(issued.source_receipt), {})
	return _current() and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and not row.is_empty() and row.state in ["attempting", "accepted"] \
		and row.actor != null and row.actor.get_ref() == actor and row.issued == issued and _identity(row) \
		and (not bool(actor.active) or (actor.global_position == row.path.position and actor.global_basis == Basis.IDENTITY))

func segment_clear(actor: Node3D, issued: Dictionary, from_distance: float, to_distance: float) -> bool:
	if not source_valid(actor, issued) or not is_finite(from_distance) or not is_finite(to_distance): return false
	var row: Dictionary = _rows[String(issued.source_receipt)]
	var travel: Dictionary = actor.typed_travel_snapshot()
	if travel.size() != 4 or not travel.get("active") is bool or not travel.active \
		or not travel.get("distance") is float or travel.distance != from_distance \
		or not travel.get("remaining_distance") is float or not travel.get("position") is Vector3 \
		or not is_finite(travel.distance) or not is_finite(travel.remaining_distance) or not travel.position.is_finite() \
		or from_distance < 0.0 or to_distance < from_distance or to_distance > float(row.profile.axis_length) \
		or to_distance - from_distance > float(row.profile.travel_speed) * float(row.profile.max_step_delta) + 0.000001: return false
	var expected: Vector3 = Vector3(row.path.start).lerp(Vector3(row.path.end), from_distance / float(row.profile.axis_length))
	if travel.position != expected \
		or not is_equal_approx(travel.remaining_distance, float(row.profile.axis_length) - from_distance): return false
	var world := _world.get_ref() as Node3D
	var room := row.room.get_ref() as Node3D
	var clear := Spawn.rolling_segment_clear(world, room, row.path, row.profile, from_distance, to_distance, row.sphere)
	return clear and source_valid(actor, issued)

func retired(actor: Node3D, terminal: Dictionary, issued: Dictionary) -> void:
	var row: Dictionary = _rows.get(String(issued.source_receipt), {})
	# Terminal identity is already checked by DungeonEvents. Normal cancellation
	# still resolves after room exit or native-floor loss; it never grants damage.
	if not _current() or row.is_empty() or row.issued != issued or row.actor == null or row.actor.get_ref() != actor: return
	row.terminal = terminal.duplicate(true)
	row.accepted = true
	row.state = "terminal"

func resolved(id: int) -> bool:
	var row := _room_row(id)
	if row.is_empty(): return false
	if row.state == "omitted": return true
	if row.state != "terminal" or row.terminal.is_empty(): return false
	var actor := row.actor.get_ref() as Node3D if row.actor != null else null
	return not is_instance_valid(actor) or not bool(actor.typed_activation_snapshot().get("delivery_in_progress", true))

func snapshot(id: String) -> Dictionary:
	var row: Dictionary = _rows.get(id, {})
	if row.is_empty(): return {}
	return {"id": id, "room_id": int(row.slot.room_id), "state": String(row.state),
		"source_receipt": String(row.issued.get("source_receipt", "")) if row.accepted else "",
		"cast_serial": int(row.issued.get("cast_serial", 0)) if row.accepted else 0,
		"terminal_cause": String(row.terminal.get("cause", ""))}

func _room_row(id: int) -> Dictionary:
	for row: Dictionary in _rows.values():
		if int(row.slot.room_id) == id: return row
	return {}

func _identity(row: Dictionary) -> bool:
	if not _current(): return false
	var world := _world.get_ref() as Node3D
	var geometry := row.geometry.get_ref() as Node3D
	var room := row.room.get_ref() as Node3D
	return is_instance_valid(geometry) and is_instance_valid(room) and geometry.is_inside_tree() and room.is_inside_tree() \
		and not geometry.is_queued_for_deletion() and not room.is_queued_for_deletion() \
		and geometry.get_parent() == world and room.get_parent() == geometry and world.rooms.get(int(row.slot.room_id)) == room \
		and world.global_transform == row.world_transform and geometry.transform == row.geometry_transform and room.transform == row.room_transform \
		and Spawn.rolling_floor_matches(world, room, row.path, row.profile, row.floor)

func _current() -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	var runtime := _runtime.get_ref() as Node if _runtime != null else null
	return is_instance_valid(world) and is_instance_valid(runtime) and world.is_inside_tree() and runtime.is_inside_tree() \
		and not world.is_queued_for_deletion() and not runtime.is_queued_for_deletion() \
		and int(world.run_generation) == _generation and world.run_source_context_valid()
