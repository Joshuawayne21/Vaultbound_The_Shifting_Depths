class_name DungeonCheckpoints
extends Node
## Private source and completion identity. Public slots/tokens cannot grant rewards.
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Point = preload("res://scripts/expedition/checkpoint_point.gd")
const Safety = preload("res://scripts/expedition/checkpoint_safety.gd")
const TOKEN_KEYS := ["run_generation", "outcome", "receipt", "checkpoint_id", "checkpoint_policy_version"]
var world: Node3D
var _slots: Array[Dictionary] = []
var _records: Dictionary = {}
var _materials: Dictionary = {}
var _prepared := false
var _generation := -1

func configure(owner_world: Node3D, materials: Dictionary) -> void:
	world = owner_world
	_generation = int(world.run_generation)
	_slots = Planner.checkpoint_slots(world.layout, world.issued_run_plan())
	_materials = materials

func prepare() -> bool:
	if _prepared: return admission_valid()
	if not world.run_source_context_valid(): return false
	for slot: Dictionary in _slots:
		var room := world.rooms[int(slot.room_id)] as Node3D
		var geometry := room.get_parent() as Node3D
		var cell: Vector2i = world.layout.rooms[int(slot.room_id)].cell
		var expected := Transform3D(Basis.IDENTITY, Vector3(cell.x * float(world.layout.cell_size), 0, cell.y * float(world.layout.cell_size)))
		if not is_instance_valid(geometry) or geometry.get_parent() != world or geometry.transform != Transform3D.IDENTITY or room.transform != expected: return false
		if not Spawn.checkpoint_anchor_clear(world, room): return false
		var actor := Point.new()
		actor.name = String(slot.id)
		if not actor.configure(world, slot, _materials):
			actor.free()
			return false
		actor.position = slot.local_position
		_records[actor.get_instance_id()] = {"actor": weakref(actor), "slot": slot.duplicate(true), "generation": _generation, "room_transform": room.transform,
			"geometry": weakref(geometry), "geometry_transform": geometry.transform}
		room.add_child(actor)
		if not is_instance_valid(self): return false
		if not is_instance_valid(world) or not world.run_source_context_valid() or not _identity(actor): return false
	_prepared = true
	return admission_valid()

func admission_valid() -> bool:
	if not is_instance_valid(world) or world.is_queued_for_deletion(): return false
	if not _prepared or _slots != Planner.checkpoint_slots(world.layout, world.issued_run_plan()) or _records.size() != _slots.size(): return false
	for row: Dictionary in _records.values():
		var actor := row.actor.get_ref() as Node3D
		if not _identity(actor): return false
	return true

func _identity(source: Node3D) -> bool:
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_instance_valid(source) or source.is_queued_for_deletion() \
		or source.get_script() != Point or int(world.run_generation) != _generation: return false
	var row: Dictionary = _records.get(source.get_instance_id(), {})
	if row.is_empty() or row.actor.get_ref() != source or int(row.generation) != _generation: return false
	var room := world.rooms.get(int(row.slot.room_id)) as Node3D
	var geometry := row.geometry.get_ref() as Node3D
	return is_instance_valid(room) and not room.is_queued_for_deletion() and is_instance_valid(geometry) and not geometry.is_queued_for_deletion() \
		and geometry.get_parent() == world and room.get_parent() == geometry and geometry.transform == row.geometry_transform \
		and room.transform == row.room_transform and source.get_parent() == room \
		and source.position == row.slot.local_position and source.basis == Basis.IDENTITY \
		and source.issued_slot() == row.slot and _slots.has(row.slot)

func slots() -> Array[Dictionary]:
	return _slots.duplicate(true)

func sources() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for row: Dictionary in _records.values():
		var source := row.actor.get_ref() as Node3D
		if _identity(source): result.append(source)
	return result

func status(source: Node3D, player: Node3D) -> Dictionary:
	var result := {"ok": false, "reason": "Return spring unavailable", "checkpoint_id": "", "room_id": -1}
	if not _prepared or not _identity(source) or not world.run_source_context_valid(): return result
	var row: Dictionary = _records[source.get_instance_id()]
	result.checkpoint_id = String(row.slot.id)
	result.room_id = int(row.slot.room_id)
	if world._boss_dead or bool(world._session.boss_defeated):
		result.reason = "The final extraction spring is awakened"
		return result
	if not world.can_use_run_source(source, player, 3.0) or int(world.current_room_id) != int(row.slot.room_id):
		result.reason = "Approach while ready to interact"
		return result
	if is_instance_valid(player.party) and player.party.is_reviving(player):
		result.reason = "Finish or cancel the revive first"
		return result
	if not CombatRules.has_line_of_sight(player, source):
		result.reason = "The return spring is obstructed"
		return result
	var captured := source.get_instance_id()
	var evaluation: Dictionary = Safety.evaluate(world, int(row.slot.room_id), source.global_position, 4.0)
	# Safety asks actual actors/casts; their synchronous callbacks may retire us.
	if not is_instance_valid(self) or not is_instance_valid(source) or source.get_instance_id() != captured \
		or not _identity(source) or not world.run_source_context_valid() or not is_instance_valid(player) \
		or not world.can_use_run_source(source, player, 3.0) or not CombatRules.has_line_of_sight(player, source) \
		or bool(world._boss_dead) or bool(world._session.boss_defeated) \
		or (is_instance_valid(player.party) and player.party.is_reviving(player)): return result
	if not Safety.valid_result(evaluation):
		result.reason = "Local safety evaluation unavailable"
		return result
	result.reason = String(evaluation.reason)
	result.ok = bool(evaluation.ok)
	return result

func record(source: Node3D, player: Node3D) -> Dictionary:
	var value := status(source, player)
	if not bool(value.ok): return {}
	return {"receipt": String(value.checkpoint_id), "room_id": int(value.room_id),
		"checkpoint_id": String(value.checkpoint_id), "checkpoint_policy_version": 1}

func completed_matches(source: Node3D, generation: int, token: Dictionary) -> bool:
	if not _prepared or not _identity(source) or generation != _generation or token.size() != TOKEN_KEYS.size(): return false
	for key: String in TOKEN_KEYS:
		if not token.has(key): return false
	var row: Dictionary = _records[source.get_instance_id()]
	return token.run_generation is int and int(token.run_generation) == generation and token.outcome is String \
		and token.outcome == "secured_early" and token.receipt is String and token.receipt == row.slot.id \
		and token.checkpoint_id is String and token.checkpoint_id == row.slot.id \
		and token.checkpoint_policy_version is int and token.checkpoint_policy_version == 1

func room_reserved(room_id: int) -> bool:
	for slot: Dictionary in _slots:
		if int(slot.room_id) == room_id: return true
	return false

func cache_allowed(at: Vector3, footprint: float) -> bool:
	if not at.is_finite() or not is_finite(footprint) or footprint < 0.1 or footprint > 1.1: return false
	for source: Node3D in sources():
		var offset := at - source.global_position
		if absf(offset.y) <= 0.165 and Vector2(offset.x, offset.z).length() < 1.8 + footprint: return false
	return true

func map_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Node3D in sources():
		var slot: Dictionary = _records[source.get_instance_id()].slot
		result.append({"room_id": int(slot.room_id), "checkpoint_id": String(slot.id), "available": source.advisory_available()})
	return result
