extends "res://tests/crystal_companion_fixture.gd"
## Actual issued initial Crystal lane and the existing timed companion consumers.
var active_edge := false
var trap_room_id := -1

func _initialize() -> void:
	active_edge = OS.get_cmdline_user_args().has("--active-edge")
	suite_name = "VAULTBOUND CRYSTAL HAZARD COMPANIONS " + ("ACTIVE" if active_edge else "WARNING")
	_run.call_deferred()

func _run() -> void:
	if not await prepare_crystal_party("/tmp/vaultbound-7d5-crystal-hazard-" + ("active" if active_edge else "warning") + "/profile.json"): finish(); return
	for companion: String in ["guardian", "mystic"]:
		for perspective in range(2):
			if not await _enter_trap(companion): break
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			await _avoid_actual_lane(game.party.members[companion])
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	await finish_crystal()

func _enter_trap(companion: String) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	game.hud.close_modals()
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var chosen := -1
	for candidate in range(1024):
		var plan: Dictionary = content.resolve_run_plan(candidate, 6)
		if plan.get("theme_id") != "crystal_caverns": continue
		var layout: Dictionary = generator.generate_for_run(candidate, 6)
		for entry: Dictionary in layout.rooms:
			if entry.kind == &"trap": trap_room_id = int(entry.id); chosen = candidate; break
		if chosen >= 0: break
	if not check(chosen >= 0, "Public Crystal seed has an actual authored trap-role room"): return false
	await game.start_expedition(chosen, 6)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	world.set_process(false)
	world.awareness.time_rate = 0.0
	var room: Node3D = world.rooms[trap_room_id]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(0, 0.15, 5))))
	player.invulnerable_remaining = 120.0
	for actor: CharacterBody3D in [guardian, mystic]:
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(0, 0.06, 0) if actor.companion_id == companion else Vector3(5, 0.06, -5))))
		actor.set_controls_enabled(false)
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
	game.party.issue_command(&"hold")
	await frames(2)
	world.set_process(true)
	if not check(await eventually(func() -> bool: return world.current_room_id == trap_room_id, 1.0), "Actual player position activates the native Crystal trap room"): return false
	for enemy: Node3D in world.encounters.all_actors():
		if enemy.combat_active and enemy.health > 0.0:
			enemy.set_physics_process(false)
			Rules.apply_hit(player, enemy, 100000.0, Rules.next_attack_id(), &"melee")
	return check(await eventually(func() -> bool: return is_instance_valid(_actual_lane()), 2.0), "Actual once-only initial opportunity admits its registered resonance lane")

func _actual_lane() -> Node3D:
	for actor: Node3D in world.registered_hazard_actors():
		var state: Dictionary = actor.typed_snapshot()
		if actor.active and state.get("definition_id") == "crystal_resonance_lane" and int(state.get("room_id", -1)) == trap_room_id: return actor
	return null

func _avoid_actual_lane(actor: CharacterBody3D) -> void:
	var hazard: Node3D = _actual_lane()
	if not check(is_instance_valid(hazard), "Companion observes an actual registered pool actor"): return
	if active_edge:
		if not check(await eventually(func() -> bool: return int(hazard.typed_snapshot().get("pulses_delivered", 0)) == 1, 3.0), "Actual persistent Crystal lane reaches its first spaced damage edge"): return
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	var issued: Dictionary = hazard.typed_snapshot()
	if not check(not zones.is_empty() and inside_danger(zones, actor.global_position) \
		and zones[0].shape == &"capsule" and Danger.validate(zones[0]).is_empty(), "Actual companion begins inside the issued capsule plus0.65m clearance"): return
	check(zones[0].phase == (&"active" if active_edge else &"warning") \
		and String(issued.source_receipt).begins_with("initial_trap_room_"), "Warning/next-edge clock belongs to the actual initial Crystal source")
	check(actor.brain._position_dangerous(actor.global_position), "Existing revive-safety consumer recognizes the real pending lane")
	game.party.hold_positions[actor.companion_id] = actor.global_position
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.combat.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval
	var health: float = actor.health
	var position: Vector3 = actor.global_position
	var decisions: int = actor.brain.decision_count
	var generation: int = session.run_generation
	var serial: int = hazard.cast_serial
	var camera: String = game.camera_rig.mode_name
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(position) < 0.08, "Lane warning does not grant perfect immediate companion reaction")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(generation == session.run_generation and serial == hazard.cast_serial and issued.source_receipt == hazard.typed_snapshot().source_receipt, "Camera switching retains the real hazard source and cast")
	var allowed: float = maxf(0.1, float(zones[0].remaining) - 0.08)
	check(await eventually(func() -> bool: return not inside_danger(zones, actor.global_position), allowed), "Companion leaves the full padded Crystal lane before its next real edge: " + String(actor.companion_id))
	check(actor.navigator.is_position_safe(actor.global_position) and actor.global_position.distance_to(position) > 0.45 \
		and actor.brain.decision_count - decisions <= 8, "Actual lane escape reaches grounded clear floor within bounded decisions")
	check(await eventually(func() -> bool: return not hazard.active, 5.5), "Registered Crystal lane reaches finite retirement")
	check(is_equal_approx(actor.health, health) and hazard.get_danger_zones().is_empty(), "Warned escape avoids every remaining actual pulse and leaves no damaging tail")
	actor.navigator.select_danger_escape()
	check(not actor.brain._position_dangerous(actor.global_position) and actor.navigator._zones.is_empty(), "Next real path/revive queries drop the retired Crystal danger")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name == camera and game.party.command == &"hold", "Both camera perspectives preserve the same direct Hold command")
	actor.set_controls_enabled(false)
