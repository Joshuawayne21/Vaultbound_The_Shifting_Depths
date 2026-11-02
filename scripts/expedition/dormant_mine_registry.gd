extends RefCounted
## One private finite slot per issued Ember floor. Dormancy is never pending damage.
const Visual = preload("res://scripts/visual/dormant_mine_visual.gd")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
var _runtime: WeakRef
var _world: WeakRef
var _generation := -1
var _policy: Dictionary = {}
var _rows: Dictionary = {}
var _poll := 0.0

func configure(runtime: Node, world: Node3D, plan: Dictionary) -> void:
	_runtime = weakref(runtime)
	_world = weakref(world)
	_generation = int(world.run_generation)
	_policy = plan.room_content_rules.duplicate(true) if plan.get("theme_id") == "ember_crypt" else {}

func prepare(slot: Dictionary, room: Node3D, materials: Dictionary) -> bool:
	if not _current() or _policy.is_empty() or not _rows.is_empty() or not is_instance_valid(room): return false
	var world := _world.get_ref() as Node3D
	var geometry := room.get_parent() as Node3D
	var cell: Vector2i = world.layout.rooms[int(slot.room_id)].cell
	var expected := Transform3D(Basis.IDENTITY, Vector3(cell.x * float(world.layout.cell_size), 0, cell.y * float(world.layout.cell_size)))
	if not is_instance_valid(geometry) or geometry.get_parent() != world or geometry.transform != Transform3D.IDENTITY or room.transform != expected: return false
	var marker := Visual.new()
	if not marker.configure(materials):
		marker.free()
		return false
	marker.name = String(slot.id) + "_DormantSeal"
	marker.position = slot.local_position
	var record := {"slot": slot.duplicate(true), "marker": weakref(marker), "room": weakref(room), "room_transform": room.transform, "geometry": weakref(geometry), "geometry_transform": geometry.transform,
		"state": "dormant", "failed_attempts": 0, "issued": {}, "actor": null, "actor_id": 0, "terminal": {}}
	_rows[slot.id] = record
	room.add_child(marker)
	return _current() and _identity(record)

func admission_valid(slots: Array[Dictionary]) -> bool:
	var count := 0
	for slot: Dictionary in slots:
		if slot.definition_id != "ember_arcane_mine": continue
		count += 1
		if not _rows.has(slot.id) or _rows[slot.id].slot != slot or not _identity(_rows[slot.id]): return false
	return count == _rows.size()

func snapshot(id: String) -> Dictionary:
	var row: Dictionary = _rows.get(id, {})
	if row.is_empty(): return {}
	return {"id": id, "room_id": int(row.slot.room_id), "state": String(row.state), "failed_attempts": int(row.failed_attempts),
		"source_receipt": String(row.issued.get("source_receipt", "")), "cast_serial": int(row.issued.get("cast_serial", 0))}

func tick(delta: float) -> void:
	if _rows.is_empty() or not _current() or not is_finite(delta) or delta < 0.0: return
	_poll = maxf(0.0, _poll - delta)
	if _poll > 0.0: return
	_poll = float(_policy.mine_retry_seconds)
	var world := _world.get_ref() as Node3D
	for row: Dictionary in _rows.values():
		if row.state not in ["dormant", "deferred"] or int(row.slot.room_id) != int(world.current_room_id): continue
		if not _identity(row):
			_omit(row)
			return
		if not _proximity(row) or not _current() or not _identity(row): return
		var runtime := _runtime.get_ref() as Node
		var result: String = runtime.arm_mine(row.slot)
		if not _current(): return
		if row.state not in ["dormant", "deferred"]: return
		if result == "omitted":
			_omit(row)
			return
		row.failed_attempts = int(row.failed_attempts) + 1
		row.state = "deferred"
		if int(row.failed_attempts) >= int(_policy.mine_failure_limit): _omit(row)

func accepting(slot_id: String, actor: Node3D, issued: Dictionary) -> bool:
	var row: Dictionary = _rows.get(slot_id, {})
	if not _current() or row.is_empty() or row.state not in ["dormant", "deferred"] or not _identity(row): return false
	row.state = "accepting"
	row.actor = weakref(actor)
	row.actor_id = actor.get_instance_id()
	row.issued = issued.duplicate(true)
	return true

func finish_attempt(slot_id: String, actor_id: int, issued: Dictionary, accepted: bool) -> void:
	var row: Dictionary = _rows.get(slot_id, {})
	if not _current() or row.is_empty() or row.issued != issued or int(row.actor_id) != actor_id: return
	if row.state == "terminal": return
	# An accepted identity consumes the only opportunity even if a callback
	# immediately cancelled it. Unproven accepted cleanup cannot rearm a mine.
	if accepted:
		row.state = "shown"
		_retire_marker(row)
	else:
		row.state = "deferred"
		row.actor = null
		row.actor_id = 0
		row.issued = {}

func retired(actor: Node3D, terminal: Dictionary, issued: Dictionary) -> void:
	var row: Dictionary = _rows.get(String(issued.source_receipt), {})
	if not _current() or row.is_empty() or row.issued != issued or row.actor == null or row.actor.get_ref() != actor: return
	row.terminal = terminal.duplicate(true)
	row.state = "terminal"
	_retire_marker(row)

func _proximity(row: Dictionary) -> bool:
	if not _current() or not _identity(row): return false
	var world := _world.get_ref() as Node3D
	var room := row.room.get_ref() as Node3D
	var center: Vector3 = room.to_global(row.slot.local_position)
	for member: Node3D in Spawn.current_party_occupants(world):
		if not CombatRules.party_target_available(member): continue
		var position := member.global_position
		if absf(position.y - center.y) > float(_policy.mine_trigger_height) \
			or Vector2(position.x - center.x, position.z - center.z).length() > float(_policy.mine_trigger_radius): continue
		if CombatRules.visible_from(world, position + Vector3.UP, center + Vector3.UP * 0.08): return true
	return false

func _identity(row: Dictionary) -> bool:
	var world := _world.get_ref() as Node3D
	var room := row.room.get_ref() as Node3D
	var marker := row.marker.get_ref() as Node3D
	var geometry := row.geometry.get_ref() as Node3D
	return is_instance_valid(geometry) and geometry.is_inside_tree() and not geometry.is_queued_for_deletion() and is_instance_valid(world) and is_instance_valid(room) and is_instance_valid(marker) \
		and world.is_inside_tree() and not world.is_queued_for_deletion() and room.is_inside_tree() and not room.is_queued_for_deletion() \
		and geometry.get_parent() == world and room.get_parent() == geometry and geometry.transform == row.geometry_transform \
		and marker.is_inside_tree() and not marker.is_queued_for_deletion() and marker.get_script() == Visual and marker.get_parent() == room \
		and world.rooms.get(int(row.slot.room_id)) == room and room.transform == row.room_transform \
		and marker.position == row.slot.local_position and marker.basis == Basis.IDENTITY

func _omit(row: Dictionary) -> void:
	row.state = "omitted"
	_retire_marker(row)

func _retire_marker(row: Dictionary) -> void:
	var marker := row.marker.get_ref() as Node3D
	if is_instance_valid(marker): marker.retire()

func _current() -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	var runtime := _runtime.get_ref() as Node if _runtime != null else null
	return is_instance_valid(world) and is_instance_valid(runtime) and world.is_inside_tree() and runtime.is_inside_tree() \
		and not world.is_queued_for_deletion() and not runtime.is_queued_for_deletion() \
		and int(world.run_generation) == _generation and world.run_source_context_valid()
