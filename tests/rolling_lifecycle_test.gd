extends "res://tests/rolling_world_fixture.gd"
const PROFILE := "/tmp/vaultbound-d7-rolling-lifecycle/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROLLING LIFECYCLE"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_rolling_world(PROFILE):
		finish()
		return
	if await enter_rolling_world(): await _one_entry()
	if await enter_rolling_world(true): await _downed_lane()
	if await enter_rolling_world(true): await _disabled_lane(false)
	if await enter_rolling_world(true): await _disabled_lane(true)
	if await enter_rolling_world(): await _held_warning()
	if await enter_rolling_world(false, 31, true): await _child_legacy_replacement()
	if await enter_rolling_world(false, 31, false, true): await _visibility_typed_replacement()
	if await enter_rolling_world(false, 31, false, true): await _busy_helper_preserved()
	await retire_game()
	finish()

func _state() -> Dictionary:
	return level.rolling_slot_snapshot(String(rolling_slot.id))

func _one_entry() -> void:
	var id := int(rolling_slot.room_id)
	await enter_native_room(id, Vector3(0, 0.15, 5))
	var actor := rolling_actor()
	if not check(is_instance_valid(actor) and actor.active and _state().state == "accepted", "Actual first trap entry accepts one registered rolling warning"): return
	var serial: int = actor.typed_activation_snapshot().cast_serial
	var no_roots := true
	for hazard: Node3D in level.registered_hazard_actors(): no_roots = no_roots and hazard.legacy_activation_snapshot().serial == 0
	check(no_roots and level.encounters.actors_by_room[id].size() >= 1 and level.encounters.actors_by_room[id].size() <= 2 \
		and not level.initial_trap_resolved(id), "Rolling replaces only initial roots while retaining the original trap pack and outstanding opportunity")
	check(level.scheduler.budget_snapshot().active_hazards == 1 and level.scheduler.budget_snapshot().reserved_hazards == 0,
		"The real shown warning retains one bound shared hazard budget")
	await enter_native_room(int(level.layout.entrance_id))
	check(_state().state == "terminal" and _state().terminal_cause == "cancelled" and _state().cast_serial == serial \
		and not actor.active and level.initial_trap_resolved(id), "Normal room exit records original cancelled identity and releases live danger")
	await enter_native_room(id, Vector3(0, 0.15, 5))
	advance_world(10.0)
	check(not actor.active and _state().cast_serial == serial and _state().state == "terminal", "Later reentry and world time cannot reroll or resume a consumed stone")

func _downed_lane() -> void:
	var id := int(rolling_slot.room_id)
	var guardian: Node3D = game.party.members[&"guardian"]
	var mystic: Node3D = game.party.members[&"mystic"]
	guardian.global_position = level.rooms[id].to_global(Vector3(0, 0.15, 0))
	mystic.global_position = level.rooms[id].to_global(Vector3(0, 0.15, 5))
	guardian.set_controls_enabled(true)
	guardian.invulnerable_remaining = 0.0
	guardian.take_damage(100000.0)
	if not check(game.party.is_downed(guardian) and guardian.health <= 0.0, "Actual damage creates an immobile participating Guardian on the prospective lane"): return
	await enter_native_room(id, Vector3(0, 0.15, 5))
	check(_state().state == "omitted" and _state().cast_serial == 0 and rolling_actor() == null and level.initial_trap_resolved(id),
		"Unsafe downed-party escape harmlessly omits the single opportunity before warning")
	guardian.global_position = level.rooms[id].to_global(Vector3(0, 0.15, 5))
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(id, Vector3(0, 0.15, 5))
	check(_state().state == "omitted" and rolling_actor() == null, "Removing the original escape obstruction cannot retry the one-shot omission")

func _held_warning() -> void:
	var observed := {"fired": false, "held": false}
	var on_pack: Callable = func(id: int) -> void:
		if id != int(rolling_slot.room_id) or observed.fired: return
		observed.fired = true
		level.awareness.increase(25.0)
		level._process(0.0)
		observed.held = level.awareness.pending_kind == &"patrol" and level.scheduler.budget_snapshot().event_active
	level.encounters.encounter_started.connect(on_pack)
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	level.encounters.encounter_started.disconnect(on_pack)
	check(observed.fired and observed.held and _state().state == "omitted" and rolling_actor() == null,
		"An actual existing patrol warning keeps its budget and harmlessly refuses the one new optional attempt")
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	check(_state().state == "omitted" and rolling_actor() == null, "Later released warning capacity does not rearm an omitted stone")

func _move_to(id: int, at: Vector3) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].to_global(at)))
	player.set_physics_process(false)
	player.invulnerable_remaining = 90.0
	level._enter_room(id)

func _child_legacy_replacement() -> void:
	var observed := {"fired": false, "actor": null, "serial": 0}
	var on_added: Callable = func(node: Node) -> void:
		if observed.fired or node.name != &"TypedHazardVisual": return
		var actor := node.get_parent() as Node3D
		if not is_instance_valid(actor) or not actor.has_method("typed_snapshot") or actor.typed_snapshot().get("source_receipt") != rolling_slot.id: return
		observed.fired = true
		observed.actor = weakref(actor)
		observed.serial = actor.typed_activation_snapshot().cast_serial
		actor.cancel()
		_move_to(rolling_legacy_room, Vector3(0, 0.15, 5))
	node_added.connect(on_added)
	_move_to(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	node_added.disconnect(on_added)
	if not check(observed.fired, "Actual rolling child attachment reaches same-wrapper legacy replacement boundary"): return
	var actor: Node3D = observed.actor.get_ref() as Node3D
	check(is_instance_valid(actor) and actor.active and actor.typed_snapshot().is_empty() \
		and actor.legacy_activation_snapshot().room_id == rolling_legacy_room and actor.legacy_activation_snapshot().active,
		"Stale typed attachment tail preserves the actual new legacy roots on the same wrapper")
	check(_state().state == "terminal" and _state().cast_serial == observed.serial and _state().terminal_cause == "cancelled" \
		and level.scheduler.budget_snapshot().reserved_hazards == 0 and level.scheduler.budget_snapshot().active_hazards == 1,
		"Original terminal proof and exact reservation cleanup cannot retire replacement roots")

func _visibility_typed_replacement() -> void:
	var observed := {"fired": false, "actor": null, "serial": 0}
	var callbacks: Array[Callable] = []
	var actors: Array[Node3D] = level.registered_hazard_actors()
	for actor: Node3D in actors:
		var reference: WeakRef = weakref(actor)
		var callback: Callable = func() -> void:
			var current := reference.get_ref() as Node3D
			if observed.fired or not is_instance_valid(current) or not current.visible or current.typed_snapshot().get("source_receipt") != rolling_slot.id: return
			observed.fired = true
			observed.actor = weakref(current)
			observed.serial = current.typed_activation_snapshot().cast_serial
			current.cancel()
			_move_to(int(rolling_typed_slot.room_id), Vector3(0, 0.15, 5))
			advance_world(0.26)
		actor.visibility_changed.connect(callback)
		callbacks.append(callback)
	_move_to(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	for index in range(actors.size()): actors[index].visibility_changed.disconnect(callbacks[index])
	if not check(observed.fired, "Actual rolling visibility reaches same-wrapper typed replacement boundary"): return
	var actor: Node3D = observed.actor.get_ref() as Node3D
	var replacement: Dictionary = actor.typed_snapshot()
	check(actor.active and replacement.get("source_receipt") == rolling_typed_slot.id \
		and level.registered_hazard_cast_valid(actor, int(replacement.run_generation), String(replacement.source_receipt), int(replacement.cast_serial)),
		"Stale rolling tail preserves the separately selected real typed replacement and its source")
	check(_state().state == "terminal" and _state().cast_serial == observed.serial \
		and level.scheduler.budget_snapshot().reserved_hazards == 0 and level.scheduler.budget_snapshot().active_hazards == 1,
		"Only old rolling reservation retires while replacement typed warning retains its bound budget")

func _busy_helper_preserved() -> void:
	var observed := {"fired": false, "older_serial": 0, "room": -1, "actor": null, "record_preserved": false}
	var on_added: Callable = func(node: Node) -> void:
		if observed.fired or node.name != &"TypedHazardVisual": return
		var actor := node.get_parent() as Node3D
		if not is_instance_valid(actor) or not actor.has_method("typed_snapshot") or actor.typed_snapshot().get("source_receipt") != rolling_typed_slot.id: return
		observed.fired = true
		observed.older_serial = actor.typed_activation_snapshot().cast_serial
		observed.room = int(actor.typed_snapshot().room_id)
		observed.actor = weakref(actor)
		_move_to(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
		observed.record_preserved = level._events._hazard_records.get(actor.get_instance_id(), {}).get("issued", {}).get("source_receipt") == rolling_typed_slot.id
	node_added.connect(on_added)
	_move_to(int(rolling_typed_slot.room_id), Vector3(0, 0.15, 5))
	advance_world(0.26)
	node_added.disconnect(on_added)
	if not check(observed.fired and observed.older_serial > 0, "Actual older typed attachment provides a genuinely busy pre-accept wrapper"): return
	var older: Node3D = observed.actor.get_ref() as Node3D
	var current := rolling_actor()
	check(observed.record_preserved and is_instance_valid(current) and current != older and current.active and _state().state == "accepted",
		"Busy accepted helper retains its source record while the new opportunity uses another truly free wrapper")
	check(not older.active and older.typed_terminal_snapshot().get("cast_serial") == observed.older_serial \
		and older.typed_terminal_snapshot().get("source_receipt") == rolling_typed_slot.id \
		and level.scheduler.budget_snapshot().reserved_hazards == 0 and level.scheduler.budget_snapshot().active_hazards == 1,
		"Older source performs its own normal cancellation without erasing the accepted replacement budget")
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	check(_state().state == "terminal" and not current.active, "The accepted alternate-wrapper opportunity still cannot rearm after exit")

func _disabled_lane(enabled: bool) -> void:
	var id := int(rolling_slot.room_id)
	var guardian: Node3D = game.party.members[&"guardian"]
	guardian.global_position = level.rooms[id].to_global(Vector3(0, 0.15, 0))
	guardian.set_controls_enabled(enabled)
	guardian.set_physics_process(false)
	game.party.members[&"mystic"].global_position = level.rooms[id].to_global(Vector3(0, 0.15, 5))
	if not check(guardian.health > 0.0 and not game.party.is_downed(guardian), "Control eligibility case uses a genuinely healthy participating Guardian"): return
	await enter_native_room(id, Vector3(0, 0.15, 5))
	if enabled:
		check(_state().state == "accepted" and is_instance_valid(rolling_actor()) and rolling_actor().active,
			"Restored normal controls permit the healthy occupant's proven native escape")
	else:
		check(_state().state == "omitted" and rolling_actor() == null,
			"Healthy controls-disabled occupant is not assumed able to escape the lane")
