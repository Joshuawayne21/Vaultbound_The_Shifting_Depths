extends "res://tests/test_harness.gd"
## Drive the actual player through touch input while both real companions follow.
## A completed journey requires physical movement, never stuck-recovery relocation.
const Navigator = preload("res://scripts/party/companion_navigation.gd")
const PROFILE := "/tmp/vaultbound-6b-city-navigation/profile.json"
var leader_navigation: RefCounted
var actors: Array[CharacterBody3D] = []
var previous: Dictionary = {}
var travelled: Dictionary = {}
var middle_height: Dictionary = {}
var recoveries: Dictionary = {}
var observed_frames := 0
var maximum_step := 0.0
var previous_sample_frame := 0
var maximum_step_actor: StringName = &""
var maximum_step_frame_gap := 0
var maximum_step_physics_frame := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CITY NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "City traversal uses an isolated progression profile")
	if not await boot_game():
		finish()
		return
	if not check(game.active_world.has_method("get_city_layout"), "Live Sanctuary exposes its authored city routes"):
		finish()
		return
	check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Both actual companion controllers join the traversal party")
	actors.assign([game.player, game.party.members.guardian, game.party.members.mystic])
	await frames(5)
	leader_navigation = Navigator.new()
	leader_navigation.bind(game.player, game.party)
	for actor in actors:
		previous[actor.name] = actor.global_position
		travelled[actor.name] = 0.0
		middle_height[actor.name] = false
		if actor != game.player: recoveries[actor.name] = actor.recovery_count
	previous_sample_frame = Engine.get_physics_frames()
	var layout: Dictionary = game.active_world.get_city_layout()
	var graph: Dictionary = game.active_world.get_companion_navigation_graph()
	check(graph.points.size() <= 48 and graph.points.size() >= 25, "City routing uses a bounded authored ring, district and ramp graph")
	# New booth journeys use the real player input and both real followers.
	# No resets, teleports or navigation mocks are allowed in this loop.
	var booths: Array = layout.exchange_booths
	check(booths.size() == 6, "Actual city layout exposes all six shared Exchange approaches")
	for index in range(booths.size()):
		input_hub.request_action(&"camera_toggle")
		# Followers continue settling during both directions of camera transition.
		# Observe every tick so a 36-frame displacement is never called one step.
		for _transition_frame in range(36):
			await physics_frame
			_record_motion()
		var booth: Dictionary = booths[index]
		check(await _walk_to(booth.approach + Vector3.UP * 0.06, 16.0), "Player physically reaches booth " + String(booth.id) + " in alternating camera modes")
		check(await _regroup(9.0), "Both companions physically regroup at booth " + String(booth.id))
	check(await _walk_to(Vector3(-8.5, 0.06, 8), 14.0), "Player walks from new booths to the unchanged legacy City Guide")
	check(await _regroup(9.0), "Both followers return from the new inner circulation to the legacy guide")
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var point := Vector3(sin(angle) * float(layout.ring_radius), 0.06, cos(angle) * float(layout.ring_radius))
		if not check(await _walk_to(point, 10.0), "Player physically reaches ring sector %d with the original movement controller" % index):
			break
	check(await _regroup(8.0), "Both followers complete the ring journey by walking")
	var districts: Array = layout.districts
	# The two raised districts E/H are visited through their ramps below.
	for id: StringName in [&"A", &"B", &"C", &"G", &"D", &"F"]:
		for district: Dictionary in districts:
			if district.id == id:
				check(await _walk_to(district.approach + Vector3.UP * 0.06, 22.0), "Player reaches authored district " + String(id) + " entirely on foot")
				check(await _regroup(9.0), "Both followers walk to district " + String(id))
	for ramp: Dictionary in layout.ramps:
		await _terrace(ramp)
	for actor in actors:
		check(float(travelled[actor.name]) > 150.0, "%s accumulated a full physical city journey" % actor.name)
		if actor != game.player:
			check(actor.recovery_count == int(recoveries[actor.name]), "%s completed all routes without recovery teleportation" % actor.name)
			check(actor.navigator.replan_count < observed_frames / 5 + 20, "%s path planning remains throttled below physics frequency" % actor.name)
	if maximum_step >= 0.35:
		print("CITY MAXIMUM STEP DIAGNOSTIC: ", JSON.stringify({"actor": maximum_step_actor, "distance": maximum_step, "sample_frame_gap": maximum_step_frame_gap, "physics_frame": maximum_step_physics_frame}))
	check(maximum_step < 0.35, "No observed actor movement step hides a relocation during traversal")
	var metrics := {"observed_physics_frames": observed_frames, "maximum_actor_step": maximum_step, "distance": travelled, "player": {"replans": leader_navigation.replan_count, "geometry_probes": leader_navigation.geometry_probe_count}}
	for actor in actors:
		if actor != game.player: metrics[actor.name] = {"replans": actor.navigator.replan_count, "geometry_probes": actor.navigator.geometry_probe_count, "recoveries": actor.recovery_count}
	print("CITY NAVIGATION COUNTS: ", JSON.stringify(metrics))
	input_hub.set_touch_move(Vector2.ZERO)
	finish()

func _terrace(ramp: Dictionary) -> void:
	var label := String(ramp.id)
	check(await _walk_to(ramp.bottom + Vector3.UP * 0.06, 22.0), "Party leader reaches the " + label + " ramp on foot")
	check(await _regroup(9.0), "Followers regroup below the " + label + " terrace")
	for actor in actors: middle_height[actor.name] = false
	var outward: Vector3 = ramp.top - ramp.bottom
	outward.y = 0.0
	var landing: Vector3 = ramp.top + outward.normalized() * 2.7 + Vector3.UP * 0.06
	check(await _walk_to(landing, 9.0), "Actual player ascends the " + label + " ramp")
	check(await _wait_for(func() -> bool: return _all_on_terrace(), 9.0), "Both actual followers reach the elevated " + label + " terrace")
	for actor in actors:
		check(bool(middle_height[actor.name]), "%s crosses intermediate ramp heights on %s ascent" % [actor.name, label])
	check(game.party.issue_command(&"hold"), "Hold order is accepted on the " + label + " terrace")
	var held := {}
	for actor in actors:
		if actor != game.player: held[actor.name] = actor.global_position
	# Stand far enough beyond the lip for the existing 2.2 m rear formation
	# offsets to land on level ground after Retreat, rather than on the ramp.
	var departure: Vector3 = ramp.bottom - outward.normalized() * 2.7 + Vector3.UP * 0.06
	check(await _walk_to(departure, 9.0), "Actual player descends the " + label + " ramp while companions hold")
	for actor in actors:
		if actor != game.player:
			check(actor.global_position.distance_to(held[actor.name]) < 0.9 and actor.global_position.y > 0.65, "%s holds its raised position on %s" % [actor.name, label])
	for actor in actors: middle_height[actor.name] = false
	check(game.party.issue_command(&"retreat"), "Retreat order is accepted below the " + label + " terrace")
	check(await _wait_for(func() -> bool: return _all_below_terrace(), 10.0), "Both followers physically descend the " + label + " ramp under Retreat")
	for actor in actors:
		if actor != game.player: check(bool(middle_height[actor.name]), "%s crosses intermediate ramp heights on %s descent" % [actor.name, label])
	check(game.party.issue_command(&"follow"), "Follow resumes after the " + label + " terrace")

func _walk_to(destination: Vector3, timeout: float) -> bool:
	leader_navigation.clear()
	var reached := false
	for index in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_record_motion()
		var offset: Vector3 = destination - game.player.global_position
		if Vector2(offset.x, offset.z).length() < 0.55 and absf(offset.y) < 0.25:
			reached = true
			break
		var direction: Vector3 = leader_navigation.direction_to(destination, 1.0 / Engine.physics_ticks_per_second)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	for index in range(14):
		await physics_frame
		_record_motion()
	if not reached:
		print("CITY ROUTE DIAGNOSTIC: ", destination, " actor=", game.player.global_position, " path=", leader_navigation.path, " failed=", leader_navigation.path_failed)
	return reached

func _regroup(timeout: float) -> bool:
	return await _wait_for(func() -> bool:
		for actor in actors:
			if actor != game.player and actor.global_position.distance_to(game.party.formation_position(actor)) > 1.4: return false
		return true, timeout)

func _wait_for(predicate: Callable, timeout: float) -> bool:
	for index in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_record_motion()
		if predicate.call(): return true
	return false

func _all_on_terrace() -> bool:
	for actor in actors:
		if actor.global_position.y < 0.65 or actor.global_position.distance_to(game.player.global_position) > 5.0: return false
	return true

func _all_below_terrace() -> bool:
	for actor in actors:
		if actor.global_position.y > 0.15 or actor.global_position.distance_to(game.player.global_position) > 5.0: return false
	return true

func _record_motion() -> void:
	observed_frames += 1
	var frame := Engine.get_physics_frames()
	for actor in actors:
		var step: float = actor.global_position.distance_to(previous[actor.name])
		if step > maximum_step:
			maximum_step_actor = actor.name
			maximum_step_frame_gap = frame - previous_sample_frame
			maximum_step_physics_frame = frame
		maximum_step = maxf(maximum_step, step)
		travelled[actor.name] = float(travelled[actor.name]) + step
		previous[actor.name] = actor.global_position
		middle_height[actor.name] = bool(middle_height[actor.name]) or (actor.global_position.y > 0.15 and actor.global_position.y < 0.65)
	previous_sample_frame = frame
