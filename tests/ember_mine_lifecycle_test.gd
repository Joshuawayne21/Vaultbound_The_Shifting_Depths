extends "res://tests/ember_world_fixture.gd"
const PROFILE := "/tmp/vaultbound-d6-mine-lifecycle/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EMBER MINE LIFECYCLE"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_crystal_world(PROFILE):
		finish()
		return
	if await enter_ember_world("furnace_warden", true): await _finite_refusals()
	if await enter_ember_world("furnace_warden", true): await _native_identity()
	if await enter_ember_world("furnace_warden", true): await _queued_identity()
	if await enter_ember_world("furnace_warden", true): await _queued_room()
	if await enter_ember_world("furnace_warden", true): await _nested_replacement()
	await retire_game()
	finish()

func _state() -> Dictionary:
	return level.mine_slot_snapshot(String(mine_slot.id))

func _finite_refusals() -> void:
	var id := int(mine_slot.room_id)
	await enter_native_room(id, Vector3(3.5, 0.15, 0))
	var actors: Array = level.encounters.actors_by_room.get(id, [])
	check(actors.size() >= 2 and actors.size() <= 3 and _state().state == "dormant", "Dormant mine preserves its original ordinary pack and has no active damage source")
	for _index in range(12): advance_world(0.5)
	check(_state().failed_attempts == 0 and _state().source_receipt == "" and _state().cast_serial == 0 and mine_actor() == null,
		"Outside real three-metre proximity, elapsed world time consumes no attempts or pool actor")
	var detached := _state()
	detached.state = "terminal"
	detached.failed_attempts = 99
	check(_state().state == "dormant" and _state().failed_attempts == 0, "Public mine status cannot mutate the private finite lifecycle")
	level.awareness.increase(25.0)
	advance_world(0.0)
	if not check(level.awareness.pending_kind == &"patrol" and level.scheduler.budget_snapshot().event_active, "Actual full patrol warning owns capacity before nearby mine attempts"): return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].to_global(Vector3(-3.0, 0.15, 0))))
	player.set_physics_process(false)
	for index in range(5):
		advance_world(0.5)
		check(_state().state == "deferred" and _state().failed_attempts == index + 1 and mine_actor() == null,
			"Actual held warning refuses eligible mine admission at bounded half-second attempt%d" % (index + 1))
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(id, Vector3(3.5, 0.15, 0))
	check(_state().failed_attempts == 5 and level.awareness.pending_kind == &"patrol" and level.awareness.pending_seconds == 3.5,
		"Room reentry preserves refusal count while the real cancelled patrol starts a fresh complete warning")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].to_global(Vector3(-3.0, 0.15, 0))))
	player.set_physics_process(false)
	for _index in range(5): advance_world(0.5)
	check(_state().state == "omitted" and _state().failed_attempts == 10 and mine_actor() == null \
		and _state().source_receipt == "" and _state().cast_serial == 0, "Tenth refused admission permanently omits the harmless opportunity without inventing accepted evidence")
	clear_actual_ordinary()
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(id, Vector3(-3.0, 0.15, 0))
	for _index in range(4): advance_world(0.5)
	check(_state().state == "omitted" and _state().failed_attempts == 10 and mine_actor() == null,
		"Cleared capacity and later reentry cannot reset an exhausted mine")

func _native_identity() -> void:
	var room: Node3D = level.rooms[int(mine_slot.room_id)]
	var marker: Node3D = room.get_node(String(mine_slot.id) + "_DormantSeal")
	check(level.combat_admission_valid() and marker.visible and not marker.is_in_group("combat_targets") and not marker.is_in_group("combat_telegraphs"), "Actual dormant native marker is visible without target or attack authority")
	room.remove_child(marker)
	check(not level.combat_admission_valid(), "Detached actual mine marker invalidates late candidate admission")
	room.add_child(marker)
	check(level.combat_admission_valid(), "Restoring the same unchanged marker restores its exact registry identity")
	var parent: Node = room.get_parent()
	parent.remove_child(room)
	check(not level.combat_admission_valid(), "Detached registered room cannot preserve a false native mine identity")
	parent.add_child(room)
	check(level.combat_admission_valid(), "Restoring the same native room preserves the original dormant source")
	var geometry := parent as Node3D
	geometry.position.x += 0.5
	check(not level.combat_admission_valid(), "Moving the admitted geometry frame cannot preserve a false mine location")
	geometry.position.x -= 0.5
	var foreign_parent := Node3D.new()
	level.add_child(foreign_parent)
	parent.remove_child(room)
	foreign_parent.add_child(room)
	check(not level.combat_admission_valid(), "Reparenting the same room under another world child invalidates exact native ownership")
	foreign_parent.remove_child(room)
	parent.add_child(room)
	foreign_parent.queue_free()
	check(level.combat_admission_valid(), "Exact geometry parent and transforms restore the unchanged dormant source")
	await enter_native_room(int(mine_slot.room_id), Vector3(3.5, 0.15, 0))
	room.remove_child(marker)
	level._events.tick(0.5)
	check(_state().state == "omitted" and mine_actor() == null, "Detached marker during actual processing safely omits instead of using off-tree positions")
	room.add_child(marker)

func _queued_identity() -> void:
	var room: Node3D = level.rooms[int(mine_slot.room_id)]
	var marker: Node3D = room.get_node(String(mine_slot.id) + "_DormantSeal")
	await enter_native_room(int(mine_slot.room_id), Vector3(3.5, 0.15, 0))
	marker.queue_free()
	check(not level.combat_admission_valid(), "Queued native marker is invalid before deferred deletion")
	level._events.tick(0.5)
	check(_state().state == "omitted" and mine_actor() == null, "Queued marker cannot trigger a cast during its remaining tree lifetime")
	await frames(2)

func _nested_replacement() -> void:
	await enter_native_room(int(mine_slot.room_id), Vector3(3.5, 0.15, 0))
	clear_actual_ordinary()
	# Consume only the ordinary queued warning in the actual safe entrance; it
	# remains queued and cannot interfere with this direct room activation.
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(int(mine_slot.room_id), Vector3(3.5, 0.15, 0))
	var observed := {"fired": false, "actor": null, "accepted": {}}
	var on_added: Callable = func(node: Node) -> void:
		if observed.fired or node.name != &"TypedHazardVisual": return
		var actor := node.get_parent() as Node3D
		if not is_instance_valid(actor) or not actor.has_method("typed_snapshot") or actor.typed_snapshot().get("source_receipt") != mine_slot.id: return
		observed.fired = true
		observed.actor = weakref(actor)
		observed.accepted = actor.typed_activation_snapshot()
		actor.cancel()
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[trap_room].to_global(Vector3(0, 0.15, 0))))
		player.set_physics_process(false)
		level._enter_room(trap_room)
		clear_actual_ordinary()
		advance_world(0.26)
	node_added.connect(on_added)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(mine_slot.room_id)].to_global(Vector3(-3.0, 0.15, 0))))
	player.set_physics_process(false)
	advance_world(0.5)
	node_added.disconnect(on_added)
	if not check(observed.fired, "Actual mine activation reaches the native attachment callback"): return
	var actor: Node3D = observed.actor.get_ref() as Node3D
	check(_state().state == "terminal" and _state().source_receipt == mine_slot.id and _state().cast_serial == observed.accepted.cast_serial,
		"Cancellation during attachment permanently consumes exactly the original accepted mine")
	check(is_instance_valid(actor) and actor.active and actor.typed_snapshot().source_receipt == "initial_trap_room_%d_ember_flame_vent_0" % trap_room \
		and level.registered_hazard_cast_valid(actor, level.run_generation, String(actor.typed_snapshot().source_receipt), int(actor.cast_serial)),
		"Old mine cleanup cannot cancel or erase the nested replacement vent on the same pool actor")
	if is_instance_valid(actor): actor.cancel()
	await enter_native_room(int(mine_slot.room_id), Vector3(-3.0, 0.15, 0))
	advance_world(1.0)
	check(_state().state == "terminal" and _state().cast_serial == observed.accepted.cast_serial, "Reentry preserves consumed original evidence after pool reuse")

func _queued_room() -> void:
	await enter_native_room(int(mine_slot.room_id), Vector3(3.5, 0.15, 0))
	var room: Node3D = level.rooms[int(mine_slot.room_id)]
	room.queue_free()
	check(not level.combat_admission_valid(), "Queued actual room invalidates its mine before any global native position query")
	level._events.tick(0.5)
	check(_state().state == "omitted" and mine_actor() == null, "Queued room processing safely omits the dormant opportunity without an attack")
	# Retire the run synchronously through its normal travel path before another
	# world tick can use the deliberately destroyed fixture room.
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
