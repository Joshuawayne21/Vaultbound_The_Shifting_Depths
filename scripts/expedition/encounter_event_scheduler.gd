class_name EncounterEventScheduler
extends RefCounted
## One current-world budget for enemies, environmental casts and future boss adds.
## No reward APIs live here; reservations are opaque and never actor metadata.
var _world: WeakRef
var _generation := -1
var _plan: Dictionary = {}
var _boss_owner: WeakRef
var _sequence := 0
var _reservations: Dictionary = {}
var _hazards: Dictionary = {}
var _event: Dictionary = {}
var _event_receipts: Dictionary = {}
const SpawnPlanner = preload("res://scripts/expedition/encounter_spawn_planner.gd")
var _adds: Dictionary = {}
var _spawn_authority: Dictionary = {}
var _summon_receipts: Dictionary = {}
var _registered_event: WeakRef
var _event_spawn_authority: Dictionary = {}
var _event_rest := 0.0

func configure(world: Node3D, plan: Dictionary, generation: int) -> bool:
	if _world != null or not is_instance_valid(world) or generation < 0 \
			or not VaultDungeonContent.valid_run_plan(plan, world.issued_depth_policy()):
		return false
	_world = weakref(world)
	_generation = generation
	_plan = plan.duplicate(true)
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	if not _current():
		cancel_all(&"world_invalid")
		return
	_prune()
	_event_rest = maxf(0.0, _event_rest - delta)
	if not _event.is_empty() and _event.state == "warning":
		_event.remaining = maxf(0.0, float(_event.remaining) - delta)
	for id: int in _reservations.keys():
		_reservations[id].remaining = maxf(0.0, float(_reservations[id].remaining) - delta)
		if float(_reservations[id].remaining) <= 0.0:
			_reservations.erase(id)

func set_boss_owner(owner: Node3D) -> bool:
	var previous := _boss()
	if owner == null:
		if previous != null: cancel_owner(previous, &"boss_released")
		_boss_owner = null
		return true
	if not _current() or not _source_valid(owner): return false
	if previous != null and previous != owner: cancel_owner(previous, &"boss_changed")
	if previous == null or previous != owner:
		_cancel_environment()
		_boss_owner = weakref(owner)
	return true

func select_active_ordinary(candidates: Array[Node3D]) -> Array[Node3D]:
	var selected: Array[Node3D] = []
	if not _current() or _boss() != null or _event_owner() != null: return selected
	var world := _get_world()
	var remaining := maxi(0, int(_plan.event_profile.enemy_limit) - _reserved_enemies() - _core_count())
	var typed := _typed_hazard_count()
	if typed > 0: remaining = mini(remaining, 4 - typed)
	for candidate: Node3D in candidates:
		if selected.size() >= remaining: break
		if is_instance_valid(candidate) and world.encounters.owns_live_actor(candidate) and not selected.has(candidate):
			selected.append(candidate)
	return selected

func reserve_hazard(room_id: int, event_receipt: String) -> int:
	_prune()
	var owns_event_cast: bool = not _event.is_empty() and _event.get("state") == "executing" \
		and _event.get("definition_id") == _plan.trap_policy.awareness.event_id and _event.get("receipt") == event_receipt \
		and int(_event.get("room_id", -1)) == room_id \
		and int(_event.get("reserved_hazards", 0)) == 1
	if not _current() or _boss() != null or event_receipt.is_empty() or event_receipt.length() > 160 \
			or _event_owner() != null or (not _event.is_empty() and not owns_event_cast) or not _room_allowed(room_id) \
			or _hazards.size() + _reserved_hazards() - (1 if owns_event_cast else 0) >= int(_plan.event_profile.hazard_limit):
		return -1
	for reservation: Dictionary in _reservations.values():
		if reservation.kind == "hazard" and reservation.receipt == event_receipt: return -1
	_sequence += 1
	if owns_event_cast: _event.reserved_hazards = 0
	_reservations[_sequence] = {"kind": "hazard", "room_id": room_id, "receipt": event_receipt, "remaining": 1.0}
	return _sequence

func bind_hazard(reservation_id: int, hazard: Node3D) -> bool:
	var record: Dictionary = _reservations.get(reservation_id, {})
	var world := _get_world()
	if not _current() or record.is_empty() or record.kind != "hazard" or not is_instance_valid(hazard) \
			or not world.owns_environment_hazard(hazard) or not bool(hazard.get("active")) \
			or int(hazard.get("room_id")) != int(record.room_id) or not _room_allowed(int(record.room_id)):
		return false
	_hazards[hazard.get_instance_id()] = {"hazard": weakref(hazard), "room_id": record.room_id, "receipt": record.receipt, "typed": bool(record.get("typed", false))}
	_reservations.erase(reservation_id)
	return true

func release_reservation(reservation_id: int) -> void:
	_reservations.erase(reservation_id)

func request_event(room_id: int, definition_id: String, event_receipt: String) -> bool:
	_prune()
	if not _current() or not _event.is_empty() or _event_owner() != null or _boss() != null or _typed_hazard_count() > 0 or _event_rest > 0.0 or not _room_allowed(room_id) \
			or event_receipt.is_empty() or event_receipt.length() > 160 or _event_receipts.has(event_receipt) \
			or event_receipt != "awareness_" + definition_id \
			or not _plan.event_profile.event_ids.has(definition_id) or not _hazards.is_empty() or not _reservations.is_empty():
		return false
	var environmental: bool = definition_id == _plan.trap_policy.awareness.event_id
	var typed: bool = environmental and _plan.trap_policy.awareness.mode == "registered_typed"
	var needed := 0 if environmental else 1
	if typed and _active_ordinary() + _core_count() > 3: return false
	if _active_ordinary() + _reserved_enemies() + _core_count() + needed > int(_plan.event_profile.enemy_limit): return false
	_event = {"room_id": room_id, "definition_id": definition_id, "receipt": event_receipt, "reserved_enemies": needed,
		"reserved_hazards": 1 if environmental else 0, "typed": typed, "state": "warning", "remaining": float(_plan.event_profile.warning_seconds)}
	return true

func commit_event(room_id: int, definition_id: String, event_receipt: String) -> bool:
	if not _current() or _event.is_empty() or _event.state != "warning" or float(_event.remaining) > 0.00001 \
			or int(_event.room_id) != room_id or _event.definition_id != definition_id or _event.receipt != event_receipt \
			or not _room_allowed(room_id) or _boss() != null or _event_receipts.has(event_receipt):
		return false
	_event.state = "executing"
	_event_receipts[event_receipt] = true
	return true

func cancel_event(event_receipt: String) -> void:
	if _event.get("receipt", "") == event_receipt: _event = {}

func finish_event(event_receipt: String) -> void:
	if _event.get("receipt", "") == event_receipt and _event.get("state", "") == "executing": _event = {}

func reserve_boss_adds(owner: Node3D, cast_serial: int, archetypes: Array[StringName], sockets: Array[Vector3]) -> Dictionary:
	var denied := {"ok": false, "reservation_id": -1, "sockets": [], "reason": "No safe registered summon is available."}
	_prune()
	if not _current() or _boss() != owner or not _source_valid(owner) or not owner.has_method("cast_reservation_valid") \
			or not owner.cast_reservation_valid(cast_serial) or archetypes.is_empty() or archetypes.size() > 2 or sockets.size() > 8 \
			or not owned_boss_adds(owner).is_empty() or not _reservations.is_empty(): return denied
	var world := _get_world()
	var source: Dictionary = world.registered_boss_source(owner)
	if source.descriptor.encounter_definition_id != "mycelial_cantor": return denied
	for archetype: StringName in archetypes:
		if archetype != &"skeleton": return denied
	var receipt := String(source.receipt) + "_cast_%d" % cast_serial
	if _summon_receipts.has(receipt): return denied
	# A failed attempt is still consumed; reentry cannot farm a new socket roll.
	_summon_receipts[receipt] = true
	var room: Node3D = world.rooms[int(source.room_id)]
	var local_sockets: Array[Vector3] = []
	for point: Vector3 in sockets: local_sockets.append(room.to_local(point))
	var points := SpawnPlanner.admit_sockets(world, room, local_sockets, 0.4, 1.9,
		mini(archetypes.size(), 2), world.encounters.all_actors())
	if points.is_empty() or _active_ordinary() + _reserved_enemies() + points.size() > int(_plan.event_profile.enemy_limit): return denied
	_sequence += 1
	_reservations[_sequence] = {"kind": "boss_add", "owner": weakref(owner), "owner_receipt": String(source.receipt),
		"receipt": receipt, "serial": cast_serial, "room_id": int(source.room_id), "sockets": points.duplicate(), "remaining": 5.0}
	var world_sockets: Array[Vector3] = []
	for point: Vector3 in points: world_sockets.append(room.to_global(point))
	return {"ok": true, "reservation_id": _sequence, "sockets": world_sockets, "reason": ""}

func commit_boss_adds(owner: Node3D, reservation_id: int, cast_serial: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var record: Dictionary = _reservations.get(reservation_id, {})
	if not _current() or record.is_empty() or record.kind != "boss_add" or record.owner.get_ref() != owner \
			or int(record.serial) != cast_serial or _boss() != owner or not _source_valid(owner) \
			or not owner.has_method("boss_add_commit_ready") or not owner.boss_add_commit_ready(cast_serial): return result
	var world := _get_world()
	var candidates: Array[Vector3] = []
	candidates.assign(record.sockets)
	var points := SpawnPlanner.admit_sockets(world, world.rooms[int(record.room_id)], candidates, 0.4, 1.9,
		mini(2, candidates.size()), world.encounters.all_actors())
	# Revalidate at the commit edge. A changed party/socket never forces a spawn.
	_reservations.erase(reservation_id)
	for index in range(points.size()):
		if not _current() or _boss() != owner or not _source_valid(owner) or not owner.boss_add_commit_ready(cast_serial): break
		var receipt := String(record.receipt) + "_member_%d" % index
		_spawn_authority = {"owner_receipt": String(record.owner_receipt), "receipt": receipt,
			"room_id": int(record.room_id), "point": points[index]}
		var actor: Node3D = world.encounters.spawn_boss_support(int(record.room_id), points[index], receipt, String(record.owner_receipt))
		_spawn_authority = {}
		if not is_instance_valid(actor): continue
		if not _current() or _boss() != owner or not _source_valid(owner):
			world.encounters.discard_boss_support(actor, String(record.owner_receipt))
			break
		_adds[actor.get_instance_id()] = {"actor": weakref(actor), "owner": weakref(owner), "owner_receipt": String(record.owner_receipt), "room_id": int(record.room_id)}
		result.append(actor)
	world.encounters._refresh_activity()
	return result

func support_spawn_authorized(owner_receipt: String, receipt: String, room_id: int, point: Vector3) -> bool:
	return _current() and not _spawn_authority.is_empty() and _spawn_authority.owner_receipt == owner_receipt \
		and _spawn_authority.receipt == receipt and int(_spawn_authority.room_id) == room_id and _spawn_authority.point == point

func owned_boss_adds(owner: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in _adds.values():
		var actor := record.actor.get_ref() as Node3D
		if record.owner.get_ref() == owner and is_instance_valid(actor) and float(actor.health) > 0.0: result.append(actor)
	return result

func support_active(actor: Node3D) -> bool:
	var world := _get_world()
	var event_owner: Node3D = world.event_member_owner(actor) if is_instance_valid(world) and world.has_method("event_member_owner") else null
	if event_owner != null: return _current() and _event_owner() == event_owner and event_owner.member_active()
	var record: Dictionary = _adds.get(actor.get_instance_id(), {}) if is_instance_valid(actor) else {}
	return _current() and not record.is_empty() and record.actor.get_ref() == actor and _boss() != null \
		and record.owner.get_ref() == _boss() and _source_valid(_boss()) and int(_get_world().current_room_id) == int(record.room_id)

func cancel_owner(owner: Node3D, _reason: StringName) -> void:
	for id: int in _reservations.keys():
		var reservation: Dictionary = _reservations[id]
		if reservation.kind == "boss_add" and reservation.owner.get_ref() == owner: _reservations.erase(id)
	var world := _get_world()
	for id: int in _adds.keys():
		var record: Dictionary = _adds[id]
		if record.owner.get_ref() != owner: continue
		var actor := record.actor.get_ref() as Node3D
		_adds.erase(id)
		if is_instance_valid(world) and world.encounters != null and is_instance_valid(actor):
			world.encounters.discard_boss_support(actor, String(record.owner_receipt))
	if _boss_owner != null and _boss_owner.get_ref() == owner: _boss_owner = null
	_spawn_authority = {}

func cancel_all(_reason: StringName) -> void:
	var owner := _boss_owner.get_ref() as Node3D if _boss_owner != null else null
	if is_instance_valid(owner): cancel_owner(owner, _reason)
	var world := _get_world()
	for id: int in _adds.keys():
		var record: Dictionary = _adds[id]
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(world) and world.encounters != null and is_instance_valid(actor):
			world.encounters.discard_boss_support(actor, String(record.owner_receipt))
	_adds.clear()
	_spawn_authority = {}
	_cancel_environment()
	_boss_owner = null

func budget_snapshot() -> Dictionary:
	_prune()
	var world := _get_world()
	return {"enemy_limit": 6, "active_ordinary": _active_ordinary(), "active_boss_adds": owned_boss_adds(_boss()).size() if _boss() != null else 0,
		"reserved_enemies": _reserved_enemies(), "boss_active": _boss() != null,
		"hazard_limit": 2, "active_hazards": _hazards.size(), "reserved_hazards": _reserved_hazards(),
		"event_active": not _event.is_empty() or _event_owner() != null, "active_event_members": _event_owner().members().size() if _event_owner() != null else 0, "active_cores": _core_count(), "typed_hazards": _typed_hazard_count(), "pending_event_count": int(world.pending_environment_events()) if is_instance_valid(world) else 0}

func _cancel_environment() -> void:
	var event_owner := _event_owner()
	if event_owner != null: event_owner.pause()
	_registered_event = null
	for record: Dictionary in _hazards.values():
		var hazard := record.hazard.get_ref() as Node3D
		if is_instance_valid(hazard): hazard.cancel()
	_hazards.clear()
	_reservations.clear()
	_event.clear()

func _prune() -> void:
	var world := _get_world()
	for id: int in _hazards.keys():
		var record: Dictionary = _hazards[id]
		var hazard := record.hazard.get_ref() as Node3D
		if not is_instance_valid(hazard) or not bool(hazard.get("active")):
			_hazards.erase(id)
		elif not is_instance_valid(world) or int(world.current_room_id) != int(record.room_id):
			hazard.cancel()
			_hazards.erase(id)
	for id: int in _reservations.keys():
		if not is_instance_valid(world) or int(world.current_room_id) != int(_reservations[id].room_id):
			_reservations.erase(id)
	if not _event.is_empty() and (not is_instance_valid(world) or int(world.current_room_id) != int(_event.room_id)):
		_event.clear()
	if _boss_owner != null:
		var owner := _boss_owner.get_ref() as Node3D
		if is_instance_valid(owner) and (float(owner.health) <= 0.0 or not owner.is_inside_tree()): cancel_owner(owner, &"owner_invalid")
		elif not is_instance_valid(owner): _boss_owner = null
	for id: int in _adds.keys():
		var record: Dictionary = _adds[id]
		var owner := record.owner.get_ref() as Node3D
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(owner) and owner.is_inside_tree() and is_instance_valid(actor): continue
		_adds.erase(id)
		if is_instance_valid(world) and world.encounters != null and is_instance_valid(actor):
			world.encounters.discard_boss_support(actor, String(record.owner_receipt))

func _source_valid(owner: Node3D) -> bool:
	var world := _get_world()
	return is_instance_valid(world) and not world.registered_boss_source(owner).is_empty()

func _boss() -> Node3D:
	var actor := _boss_owner.get_ref() as Node3D if _boss_owner != null else null
	return actor if is_instance_valid(actor) and float(actor.get("health")) > 0.0 else null

func _active_ordinary() -> int:
	var world := _get_world()
	return int(world.encounters.active_ordinary_count()) if is_instance_valid(world) and world.get("encounters") != null else 0

func _reserved_enemies() -> int:
	var count := int(_event.get("reserved_enemies", 0))
	for reservation: Dictionary in _reservations.values():
		if reservation.kind in ["boss_add", "event_wave"]: count += reservation.sockets.size()
	return count

func _reserved_hazards() -> int:
	var count := int(_event.get("reserved_hazards", 0))
	for record: Dictionary in _reservations.values():
		if record.kind == "hazard": count += 1
	return count

func _room_allowed(id: int) -> bool:
	var world := _get_world()
	return is_instance_valid(world) and id == int(world.current_room_id) and world.rooms.has(id) \
		and world.layout.rooms[id].kind not in [&"entrance", &"extraction", &"boss", &"secret"]

func _current() -> bool:
	var world := _get_world()
	return is_instance_valid(world) and int(world.run_generation) == _generation \
		and world.run_source_context_valid() and world.issued_run_plan_matches(_plan)

func _get_world() -> Node3D:
	return _world.get_ref() as Node3D if _world != null else null

func boss_active() -> bool:
	return _boss() != null

func reserve_typed_hazard(room_id: int, receipt: String) -> int:
	_prune()
	if not _current() or _event_owner() != null or not _event.is_empty() or _boss() != null or _event_rest > 0.0 \
			or _active_ordinary() + _core_count() > 3 - _typed_hazard_count(): return -1
	var result := reserve_hazard(room_id, receipt)
	if result >= 0: _reservations[result]["typed"] = true
	return result

func reserve_typed_event_hazard(room_id: int, event_receipt: String) -> int:
	# Transfer only the exact already-warned environmental reservation. The held
	# warning budget becomes this typed cast's budget; it is never booked twice.
	_prune()
	if not _current() or _event.is_empty() or not bool(_event.get("typed", false)) \
		or _event.get("state") != "executing" or _event.get("receipt") != event_receipt \
		or int(_event.get("room_id", -1)) != room_id or int(_event.get("reserved_hazards", 0)) != 1 \
		or _plan.trap_policy.awareness.mode != "registered_typed" \
		or _event.definition_id != _plan.trap_policy.awareness.event_id \
		or _active_ordinary() + _core_count() > 3: return -1
	var reservation := reserve_hazard(room_id, event_receipt)
	if reservation >= 0: _reservations[reservation]["typed"] = true
	return reservation

func _typed_hazard_count() -> int:
	var count := 1 if bool(_event.get("typed", false)) and int(_event.get("reserved_hazards", 0)) == 1 else 0
	for record: Dictionary in _hazards.values():
		var actor := record.hazard.get_ref() as Node3D
		if is_instance_valid(actor) and actor.has_method("typed_snapshot") and not actor.typed_snapshot().is_empty(): count += 1
	for record: Dictionary in _reservations.values():
		if record.get("typed", false): count += 1
	return count

func _core_count() -> int:
	var world := _get_world()
	return int(world.active_event_core_count()) if is_instance_valid(world) and world.has_method("active_event_core_count") else 0

func _event_owner() -> Node3D:
	return _registered_event.get_ref() as Node3D if _registered_event != null else null

func begin_registered_event(owner: Node3D) -> bool:
	_prune()
	var world := _get_world()
	if not _current() or not is_instance_valid(owner) or world.registered_event_source(owner).is_empty() or _boss() != null: return false
	if not _room_allowed(int(world.registered_event_source(owner).room_id)): return false
	if _event_owner() == owner: return true
	if _event_owner() != null or _event_rest > 0.0 or not _event.is_empty() or not _hazards.is_empty() or not _reservations.is_empty(): return false
	if not world.event_reserve_roster(owner): return false
	_registered_event = weakref(owner)
	world.encounters._refresh_activity()
	return true

func finish_registered_event(owner: Node3D) -> void:
	cancel_event_wave(owner)
	if _event_owner() == owner:
		if owner.snapshot().event_state in ["complete", "cancelled"]: _event_rest = float(_plan.event_profile.minimum_gap)
		_registered_event = null
	var world := _get_world()
	if is_instance_valid(world) and is_instance_valid(world.encounters) and world.encounters.is_inside_tree(): world.encounters._refresh_activity()

func cancel_event_wave(owner: Node3D) -> void:
	for id: int in _reservations.keys():
		var record: Dictionary = _reservations[id]
		if record.kind == "event_wave" and record.owner.get_ref() == owner: _reservations.erase(id)
	_event_spawn_authority = {}

func reserve_event_wave(owner: Node3D, wave: int) -> Dictionary:
	var denied := {"reservation_id": -1, "sockets": []}
	var world := _get_world()
	if not _current() or _event_owner() != owner or not owner.wave_reservation_valid(wave) or not _reservations.is_empty(): return denied
	var source: Dictionary = world.registered_event_source(owner)
	if source.is_empty(): return denied
	var archetypes: Array[StringName] = owner.expected_members(wave)
	if archetypes.size() < 2 or archetypes.size() > 3: return denied
	var points := _event_points(owner, source, archetypes)
	if points.size() != archetypes.size() or points.size() + _core_count() + owner.members().size() > 6: return denied
	_sequence += 1
	_reservations[_sequence] = {"kind": "event_wave", "owner": weakref(owner), "room_id": int(source.room_id), "receipt": String(source.receipt),
		"wave": wave, "sockets": points, "archetypes": archetypes.duplicate(), "remaining": 5.0}
	var sockets: Array[Vector3] = []
	for point: Vector3 in points: sockets.append(world.rooms[int(source.room_id)].to_global(point))
	return {"reservation_id": _sequence, "sockets": sockets}

func _event_points(owner: Node3D, source: Dictionary, archetypes: Array[StringName], fixed: Array[Vector3] = [], ignored: Array[Node3D] = []) -> Array[Vector3]:
	var world := _get_world()
	var points: Array[Vector3] = fixed.duplicate()
	if points.is_empty():
		points.assign([Vector3(-5, 0, -5), Vector3(-5, 0, 5), Vector3(5, 0, 5)])
		if source.definition_id != "root_spore_hive": points.append(Vector3(5, 0, -5))
	var occupied: Array[Node3D] = world.encounters.all_actors()
	for actor: Node3D in ignored: occupied.erase(actor)
	var core: Node3D = owner.core()
	if is_instance_valid(core) and float(core.health) > 0.0: occupied.append(core)
	var radius := 0.7 if archetypes.has(&"golem") else 0.4
	var height := 2.7 if archetypes.has(&"golem") else 1.9
	return SpawnPlanner.admit_event_sockets(world, world.rooms[int(source.room_id)], points, radius, height, archetypes.size(), occupied)

func commit_event_wave(owner: Node3D, reservation_id: int, wave: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var record: Dictionary = _reservations.get(reservation_id, {})
	if not _current() or _event_owner() != owner or record.is_empty() or record.kind != "event_wave" \
			or record.owner.get_ref() != owner or int(record.wave) != wave or not owner.wave_commit_ready(wave): return result
	var world := _get_world()
	var source: Dictionary = world.registered_event_source(owner)
	if source.is_empty(): return result
	var archetypes: Array[StringName] = []
	archetypes.assign(record.archetypes)
	var candidates: Array[Vector3] = []
	candidates.assign(record.sockets)
	var points := _event_points(owner, source, archetypes, candidates)
	_reservations.erase(reservation_id)
	if points.size() != archetypes.size(): return result
	for index in range(points.size()):
		if not _current() or _event_owner() != owner or not owner.wave_commit_ready(wave): break
		if _event_points(owner, source, archetypes, points, result).size() != archetypes.size(): break
		var receipt := String(source.receipt) + "_wave_%d_member_%d" % [wave, index]
		_event_spawn_authority = {"owner_receipt": String(source.receipt), "receipt": receipt, "room_id": int(source.room_id),
			"point": points[index], "definition_id": "root_event_" + String(archetypes[index])}
		var actor: Node3D = world.encounters.spawn_event_support(int(source.room_id), points[index], receipt, String(source.receipt), archetypes[index])
		_event_spawn_authority = {}
		if not is_instance_valid(actor): break
		result.append(actor)
	var construction_valid := result.size() == archetypes.size() and _current()
	if construction_valid:
		construction_valid = _event_points(owner, source, archetypes, points, result).size() == archetypes.size()
		for index in range(result.size()):
			construction_valid = construction_valid and is_instance_valid(result[index]) and result[index].global_position == world.rooms[int(source.room_id)].to_global(points[index] + Vector3.UP * 0.15)
	if not construction_valid or not world.accept_event_members(owner, wave, result):
		for actor: Node3D in result:
			if is_instance_valid(actor): world.encounters.discard_boss_support(actor, String(source.receipt))
		result.clear()
	world.encounters._refresh_activity()
	return result

func event_support_spawn_authorized(owner_receipt: String, receipt: String, room_id: int, point: Vector3, definition_id: String) -> bool:
	return _current() and _event_owner() != null and not _event_spawn_authority.is_empty() \
			and _event_spawn_authority.owner_receipt == owner_receipt and _event_spawn_authority.receipt == receipt \
			and _event_spawn_authority.room_id == room_id and _event_spawn_authority.point == point and _event_spawn_authority.definition_id == definition_id

func checkpoint_pending_danger(room_id: int, _center: Vector3, _radius: float) -> bool:
	if not _current(): return true
	if not _event.is_empty() and int(_event.get("room_id", -1)) == room_id: return true
	for reservation: Dictionary in _reservations.values():
		if int(reservation.get("room_id", -1)) == room_id: return true
	var event := _event_owner()
	if event != null:
		var world := _get_world()
		var record: Dictionary = world.registered_event_source(event)
		if not record.is_empty() and int(record.room_id) == room_id: return true
	return false
