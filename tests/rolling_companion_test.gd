extends "res://tests/rolling_world_fixture.gd"
## Actual one-shot source, moving danger and paid Guardian/Mystic decisions.
const Danger = preload("res://scripts/combat/danger_geometry.gd")
var companion: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROLLING STONE COMPANIONS"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_rolling_world("/tmp/vaultbound-7d7-rolling-companions/profile.json"):
		finish()
		return
	for id: String in ["guardian", "mystic"]:
		for perspective in range(2):
			if not await _stage_actual_warning(id, perspective): break
			await _avoid_and_observe(perspective == 1)
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	if is_instance_valid(game): await retire_game()
	finish()

func _stage_actual_warning(id: String, perspective: int) -> bool:
	if not await enter_rolling_world(true, 11): return false
	if not check(game.party.members.size() == 3 and game.party.members.has(id), "Actual recruited three-member party supplies " + id): return false
	companion = game.party.members[id]
	var room: Node3D = level.rooms[int(rolling_slot.room_id)]
	game.party.set_paused(false)
	for member_id: String in ["guardian", "mystic"]:
		var actor: CharacterBody3D = game.party.members[member_id]
		var point: Vector3 = room.to_global(Vector3(0, 0.06, 0) if member_id == id else Vector3(4, 0.06, -4))
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
		# Hold fixture movement only until the source publishes its full warning.
		# Real controls/health/party eligibility remain enabled for admission.
		actor.set_physics_process(false)
		actor.set_controls_enabled(true)
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
	if not check(companion.navigator.is_position_safe(companion.global_position) \
		and companion.navigator.danger_body_path_clear(companion.global_position, companion.global_position), "Threatened companion starts on the actual clear native rolling room floor"): return false
	game.party.issue_command(&"hold")
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	var hazard: Node3D = rolling_actor()
	if not check(is_instance_valid(hazard) and hazard.active, "Normal first room entry admits the real registered rolling warning once"): return false
	# Ordinary actors belong to the real encounter. Their actual deaths isolate
	# the trap response without replacing their source or changing the stone.
	for enemy: Node3D in level.encounters.all_actors():
		enemy.set_physics_process(false)
		if enemy.combat_active and enemy.health > 0.0: enemy.take_hit(100000.0, player.global_position)
	var state: Dictionary = level.rolling_slot_snapshot(String(rolling_slot.id))
	var issued: Dictionary = hazard.typed_snapshot()
	if not check(state.state == "accepted" and state.source_receipt == rolling_slot.id \
		and int(state.cast_serial) == int(issued.cast_serial) and issued.source_receipt == rolling_slot.id \
		and int(issued.room_id) == int(rolling_slot.room_id), "Companion test observes the privately accepted initial slot and exact pooled serial"): return false
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	if not check(zones.size() == 1 and zones[0].phase == &"warning" and float(zones[0].remaining) >= 1.9 \
		and Danger.validate(zones[0]).is_empty() and _inside(zones, companion.global_position), "Full two-second rolling warning covers the companion's unchanged0.65m padded footprint"): return false
	if perspective == 1: input_hub.request_action(&"camera_toggle")
	return true

func _avoid_and_observe(cancel_on_exit: bool) -> void:
	var hazard: Node3D = rolling_actor()
	var initial: Dictionary = hazard.typed_snapshot()
	var full: Dictionary = initial.shape.duplicate(true)
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	var anchor: Transform3D = hazard.global_transform
	var generation: int = session.run_generation
	var serial: int = int(initial.cast_serial)
	var attack: int = int(initial.attack_id)
	var camera: String = game.camera_rig.mode_name
	var start: Vector3 = companion.global_position
	var health: float = companion.health
	var decisions: int = companion.brain.decision_count
	var probes: int = companion.navigator.geometry_probe_count
	companion.brain.reset()
	companion.navigator.clear()
	companion.brain.decision_remaining = companion.data.decision_interval
	companion.set_physics_process(true)
	hazard.set_physics_process(true)
	await frames(2)
	check(companion.brain.decision_count == decisions and companion.global_position.distance_to(start) < 0.08,
		"Rolling avoidance pays the configured reaction delay instead of instant movement")
	check(is_zero_approx(companion.invulnerable_remaining) and is_zero_approx(companion.combat.invulnerable_remaining),
		"Actual escape begins without spawn or fixture invulnerability")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name != camera and session.run_generation == generation \
		and hazard.cast_serial == serial and hazard.typed_snapshot().attack_id == attack \
		and hazard.typed_snapshot().shape == full and hazard.global_transform == anchor,
		"Both camera perspectives retain the same fixed source, whole-pass attack and issued lane")
	var deadline: float = maxf(0.1, float(hazard.get_danger_zones()[0].remaining) - 0.08)
	if not check(await eventually(func() -> bool: return not _inside(zones, companion.global_position), deadline),
		"Actual " + String(companion.companion_id) + " leaves the full padded lane before rolling begins"): return
	check(companion.navigator.is_position_safe(companion.global_position) and companion.global_position.distance_to(start) > 0.45 \
		and companion.brain.decision_count - decisions <= 8 and companion.navigator.geometry_probe_count - probes < 600,
		"Paid rolling escape reaches native grounded clearance within the existing decision and query budgets")
	if not check(await eventually(func() -> bool: return hazard.active and hazard.typed_travel_snapshot().active \
		and float(hazard.typed_travel_snapshot().distance) >= 2.6, 3.0), "Actual stone advances far enough to clear a real rear segment"): return
	var travel: Dictionary = hazard.typed_travel_snapshot()
	var moving: Array[Dictionary] = hazard.get_danger_zones()
	var heading: Vector3 = (Vector3(full.end) - Vector3(full.start)).normalized()
	var rear: Vector3 = Vector3(full.start) + heading * 0.2 + Vector3.UP * 0.06
	var future: Vector3 = Vector3(full.end) - heading * 0.2 + Vector3.UP * 0.06
	check(moving.size() == 1 and moving[0].phase == &"active" and moving[0].shape == &"capsule" \
		and Vector3(moving[0].start).is_equal_approx(Vector3(travel.position)) and moving[0].end == full.end \
		and float(travel.remaining_distance) < Vector3(full.start).distance_to(Vector3(full.end)) \
		and int(moving[0].attack_id) == attack and int(moving[0].stage_id) == 0,
		"Published active danger shrinks from the actual stone center to its original endpoint with one damage identity")
	check(Danger.contains(full, rear, 0.65) and not _inside(moving, rear) and _inside(moving, future) \
		and not companion.brain._position_dangerous(rear) and companion.brain._position_dangerous(future),
		"Existing avoidance and revive safety release the truly passed rear while retaining the remaining lane")
	var rear_path: PackedVector3Array = companion.navigator.plan_path(rear)
	check(not rear_path.is_empty() and Vector3(rear_path[-1]).distance_to(rear) < 0.1 \
		and companion.navigator.is_position_safe(rear), "Existing native path planner can reach the passed lane without treating the immutable full path as active")
	check(hazard.typed_snapshot().shape == full and hazard.global_transform == anchor \
		and is_equal_approx(companion.health, health), "Moving danger leaves the source fixed and the genuinely escaped companion unharmed")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name == camera and session.run_generation == generation \
		and hazard.cast_serial == serial and game.party.command == &"hold", "Active travel camera switching preserves the party's direct Hold order and same source")
	if cancel_on_exit:
		await enter_native_room(int(level.layout.entrance_id), Vector3(0, 0.15, 0))
		check(not hazard.active and hazard.get_danger_zones().is_empty(), "Actual room exit synchronously cancels remaining rolling danger")
	else:
		check(await eventually(func() -> bool: return not hazard.active, 2.0), "Actual finite rolling pass reaches terminal retirement without a harmful tail")
	var terminal: Dictionary = level.rolling_slot_snapshot(String(rolling_slot.id))
	check(terminal.state == "terminal" and terminal.source_receipt == rolling_slot.id \
		and int(terminal.cast_serial) == serial and terminal.terminal_cause == ("cancelled" if cancel_on_exit else "expired"),
		"Real terminal evidence preserves the exact accepted source and distinguishes cancellation from completion")
	companion.navigator.select_danger_escape()
	check(hazard.get_danger_zones().is_empty() and not companion.brain._position_dangerous(rear) \
		and companion.navigator._zones.is_empty() and is_equal_approx(companion.health, health),
		"The next actual path and revive queries retire the stone without ghost danger or additional damage")
	companion.set_physics_process(false)
	companion.set_controls_enabled(false)
	if cancel_on_exit:
		await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
		check(not hazard.active and level.rolling_slot_snapshot(String(rolling_slot.id)) == terminal,
			"Reentering the real room cannot restart the consumed rolling opportunity or its damage identity")

func _inside(zones: Array[Dictionary], point: Vector3) -> bool:
	for zone: Dictionary in zones:
		if Danger.contains(zone, point, 0.65): return true
	return false
