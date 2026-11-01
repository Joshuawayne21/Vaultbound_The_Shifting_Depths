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
	if previous != null and previous != owner: return false
	if previous == null:
		_cancel_environment()
		_boss_owner = weakref(owner)
	return true

func select_active_ordinary(candidates: Array[Node3D]) -> Array[Node3D]:
	var selected: Array[Node3D] = []
	if not _current() or _boss() != null: return selected
	var world := _get_world()
	var remaining := maxi(0, int(_plan.event_profile.enemy_limit) - _reserved_enemies())
	for candidate: Node3D in candidates:
		if selected.size() >= remaining: break
		if is_instance_valid(candidate) and world.encounters.owns_live_actor(candidate) and not selected.has(candidate):
			selected.append(candidate)
	return selected

func reserve_hazard(room_id: int, event_receipt: String) -> int:
	_prune()
	var owns_event_cast: bool = not _event.is_empty() and _event.get("state") == "executing" \
		and _event.get("definition_id") == "roots" and _event.get("receipt") == event_receipt \
		and int(_event.get("reserved_hazards", 0)) == 1
	if not _current() or _boss() != null or event_receipt.is_empty() or event_receipt.length() > 160 \
			or (not _event.is_empty() and not owns_event_cast) or not _room_allowed(room_id) \
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
	_hazards[hazard.get_instance_id()] = {"hazard": weakref(hazard), "room_id": record.room_id, "receipt": record.receipt}
	_reservations.erase(reservation_id)
	return true

func release_reservation(reservation_id: int) -> void:
	_reservations.erase(reservation_id)

func request_event(room_id: int, definition_id: String, event_receipt: String) -> bool:
	_prune()
	if not _current() or not _event.is_empty() or _boss() != null or not _room_allowed(room_id) \
			or event_receipt.is_empty() or event_receipt.length() > 160 or _event_receipts.has(event_receipt) \
			or event_receipt != "awareness_" + definition_id \
			or not _plan.event_profile.event_ids.has(definition_id) or not _hazards.is_empty() or not _reservations.is_empty():
		return false
	var needed := 0 if definition_id == "roots" else 1
	if _active_ordinary() + _reserved_enemies() + needed > int(_plan.event_profile.enemy_limit): return false
	_event = {"room_id": room_id, "definition_id": definition_id, "receipt": event_receipt, "reserved_enemies": needed,
		"reserved_hazards": 1 if definition_id == "roots" else 0, "state": "warning", "remaining": float(_plan.event_profile.warning_seconds)}
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

func reserve_boss_adds(_owner: Node3D, _cast_serial: int, _archetypes: Array[StringName], _sockets: Array[Vector3]) -> Dictionary:
	# Rootwarden has no summon pattern. Reject the seam explicitly until an
	# actual registered controller and its positive summon tests are available.
	return {"ok": false, "reservation_id": -1, "sockets": [], "reason": "No executable boss summon profile in this content version."}

func commit_boss_adds(_owner: Node3D, _reservation_id: int, _cast_serial: int) -> Array[Node3D]:
	return []

func cancel_owner(owner: Node3D, _reason: StringName) -> void:
	if _boss() == owner: _boss_owner = null

func cancel_all(_reason: StringName) -> void:
	_cancel_environment()
	_boss_owner = null

func budget_snapshot() -> Dictionary:
	_prune()
	var world := _get_world()
	return {"enemy_limit": 6, "active_ordinary": _active_ordinary(), "active_boss_adds": 0,
		"reserved_enemies": _reserved_enemies(), "boss_active": _boss() != null,
		"hazard_limit": 2, "active_hazards": _hazards.size(), "reserved_hazards": _reserved_hazards(),
		"event_active": not _event.is_empty(), "pending_event_count": int(world.pending_environment_events()) if is_instance_valid(world) else 0}

func _cancel_environment() -> void:
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
	if _boss_owner != null and _boss() == null: _boss_owner = null

func _source_valid(owner: Node3D) -> bool:
	var world := _get_world()
	return is_instance_valid(world) and owner == world.get("boss") \
		and world.registered_combat_source_valid(owner, _generation, "rootwarden_reward")

func _boss() -> Node3D:
	var actor := _boss_owner.get_ref() as Node3D if _boss_owner != null else null
	return actor if is_instance_valid(actor) and float(actor.get("health")) > 0.0 else null

func _active_ordinary() -> int:
	var world := _get_world()
	return int(world.encounters.active_enemy_count()) if is_instance_valid(world) and world.get("encounters") != null else 0

func _reserved_enemies() -> int:
	return int(_event.get("reserved_enemies", 0))

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
