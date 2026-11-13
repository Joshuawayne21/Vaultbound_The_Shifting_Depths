extends "res://tests/beastwilds_travel_fixture.gd"
## One uninterrupted trip through the real admitted discovery world. Fixture
## placements stop before measurement; movement, followers and claims are real.
const Navigator = preload("res://scripts/party/companion_navigation.gd")
const CLAIM_ORDER: Array[String] = ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]
var navigator: RefCounted
var actors: Array[CharacterBody3D] = []
var previous: Dictionary = {}
var travelled: Dictionary = {}
var recovery_start: Dictionary = {}
var plan_start: Dictionary = {}
var probe_start: Dictionary = {}
var actor_ids: Array[int] = []
var observed_frames := 0
var max_step := 0.0
var max_step_actor := ""
var max_step_frame_gap := 0
var previous_sample_frame := 0
var camera_toggles := 0
var camera_travel := {"third_person": 0.0, "isometric": 0.0, "transition": 0.0}
var route_context_valid := true
var finite_positions := true
var measured_generation := -1
var measured_world_id := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND BEASTWILDS CONTINUOUS PARTY NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	var seed_value := _selected_seed()
	if not await prepare_beastwilds("navigation-%d" % seed_value) or not await enter_beastwilds(seed_value, true):
		finish()
		return
	# The shared fixture enters through the real Nexus gate/card using an earned
	# Depth-2 profile, recruited Guardian/Mystic, protected items and owned pet.
	var saved_files := files()
	var saved_profile: Dictionary = session.profile.duplicate(true)
	var issued: Dictionary = session.issued_activity_context()
	measured_generation = session.run_generation
	measured_world_id = world.get_instance_id()
	actors.assign([game.player, game.party.members.guardian, game.party.members.mystic])
	navigator = Navigator.new()
	navigator.bind(game.player, game.party)
	for actor: CharacterBody3D in actors:
		actor_ids.append(actor.get_instance_id())
		previous[actor.name] = actor.global_position
		travelled[actor.name] = 0.0
		if actor != game.player:
			recovery_start[actor.name] = actor.recovery_count
			plan_start[actor.name] = actor.navigator.replan_count
			probe_start[actor.name] = actor.navigator.geometry_probe_count
	previous_sample_frame = Engine.get_physics_frames()
	var original_sources: Dictionary = world.registered_activity_sources()
	var claimed: Array[String] = []
	# From this point until finish: no actor transform writes, reset_for_spawn,
	# fixture approach helpers, recovery allowance, paused-party walking or mock AI.
	for id: String in CLAIM_ORDER:
		if not check(await _walk(world.source_approach_position(id), 30.0), "Player continuously walks to " + id):
			_report(seed_value)
			finish()
			return
		check(await _regroup(10.0), "Guardian and Mystic physically regain formation at " + id)
		var source: Node3D = original_sources[id]
		if not check(is_instance_valid(source) and game.player.interaction_target == source and source.can_interact(game.player),
			"Continuous approach selects the original visible discovery: " + id):
			_report(seed_value)
			finish()
			return
		var before: Dictionary = session.activity_snapshot()
		input_hub.request_action(&"interact")
		await _ticks(8)
		var after: Dictionary = session.activity_snapshot()
		claimed.append(id)
		check(source.claimed and id in after.claimed and after.claimed.size() == before.claimed.size() + 1,
			"Actual player input claims this issued source exactly once: " + id)
		check(session.profile == saved_profile and files() == saved_files,
			"Discovery remains unsecured and preserves exact saved profile/files: " + id)
		check(session.issued_activity_context() == issued and world.owns_source(source, id),
			"Claim retains the same issued world/source identity: " + id)
	if check(await _walk(world.source_approach_position("return_spring"), 30.0), "Party leader continuously walks back to the actual return spring"):
		check(await _regroup(10.0), "Both companions physically return to the spring")
		var spring: Node3D = original_sources.return_spring
		check(game.player.interaction_target == spring and spring.can_interact(game.player), "Walking selects the original return source")
		input_hub.request_action(&"interact")
		check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.visible and panel.entry_enabled \
			and not game._activity_exit_review.is_empty(), "Real spring interaction reviews the completed objectives without settling")
		# Closing the review restores controls. Never press SECURE/ABANDON here;
		# the separate authority/fault suites own transaction and return coverage.
		game.hud.close_modals()
		await _ticks(14)
	var status: Dictionary = session.activity_snapshot()
	check(claimed == CLAIM_ORDER and status.can_complete and int(status.objectives_completed) == 3 \
		and status.claimed.size() == 4, "One physical journey completed all three required discoveries and optional forage")
	check(route_context_valid and finite_positions and game.current_location == &"beastwilds" \
		and world == game.active_world and session.activity_context_valid(world, measured_generation),
		"The same finite player/party/world/generation remained active throughout the journey")
	check(camera_toggles >= 8 and float(camera_travel.third_person) > 5.0 and float(camera_travel.isometric) > 5.0,
		"The party journey includes real movement in both fully settled camera modes and live transitions")
	var replan_cap := ceili(float(observed_frames) / 5.0) + 20
	check(navigator.replan_count > 0 and navigator.replan_count < replan_cap, "Player navigation stays below the existing bounded planning-frequency cap")
	for actor: CharacterBody3D in actors:
		check(float(travelled[actor.name]) > 75.0, String(actor.name) + " physically travelled the full habitat circuit")
		if actor != game.player:
			check(actor.recovery_count == recovery_start[actor.name], String(actor.name) + " used no stuck-recovery teleport")
			var plans := int(actor.navigator.replan_count) - int(plan_start[actor.name])
			check(plans > 0 and plans < replan_cap, String(actor.name) + " keeps follower replanning below physics frequency")
	check(max_step < 0.35, "Every measured actor step stays below the relocation threshold")
	check(session.profile == saved_profile and files() == saved_files and session.active \
		and session.profile.companions.guardian.recruited and session.profile.companions.mystic.recruited,
		"Walking, cameras, claims and exit review preserve exact secured profile/files and recruited party until quit")
	check(int(session.unsecured_gold) > 0 and not session._pet_pending.ingredients.is_empty(),
		"Verified discoveries remain in the existing pending currency/pet bag before settlement")
	_report(seed_value)
	input_hub.set_touch_move(Vector2.ZERO)
	finish()

func _selected_seed() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			var value := argument.trim_prefix("--seed=")
			if value.is_valid_int(): return clampi(int(value), 0, 2147483646)
	return 71

func _walk(destination: Vector3, timeout: float) -> bool:
	navigator.clear()
	var reached := false
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_sample()
		if not route_context_valid: break
		var offset: Vector3 = destination - game.player.global_position
		if Vector2(offset.x, offset.z).length() < 0.55 and absf(offset.y) < 0.25:
			reached = true
			break
		# Each substantial leg crosses both modes while touch movement remains
		# active; direction is recomputed from the actual rendered camera basis.
		if tick == int(float(Engine.physics_ticks_per_second) * 0.5) or tick == Engine.physics_ticks_per_second * 2:
			input_hub.request_action(&"camera_toggle")
			camera_toggles += 1
		var direction: Vector3 = navigator.direction_to(destination, 1.0 / Engine.physics_ticks_per_second)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	await _ticks(14)
	if not reached: print("BEASTWILDS WALK DIAGNOSTIC: ", destination, " actor=", game.player.global_position, " path=", navigator.path, " failed=", navigator.path_failed)
	return reached

func _regroup(timeout: float) -> bool:
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_sample()
		if not route_context_valid: return false
		var grouped := true
		for actor: CharacterBody3D in actors:
			if actor != game.player and actor.global_position.distance_to(game.party.formation_position(actor)) > 1.4: grouped = false
		if grouped: return true
	return false

func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame
		_sample()

func _sample() -> void:
	observed_frames += 1
	var frame := Engine.get_physics_frames()
	route_context_valid = route_context_valid and is_instance_valid(game.active_world) \
		and game.active_world.get_instance_id() == measured_world_id and session.run_generation == measured_generation \
		and game.player == actors[0] and game.party.members.get(&"guardian") == actors[1] \
		and game.party.members.get(&"mystic") == actors[2]
	for index in range(actors.size()):
		var actor: CharacterBody3D = actors[index]
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.get_instance_id() != actor_ids[index]:
			route_context_valid = false
			continue
		finite_positions = finite_positions and actor.global_position.is_finite()
		var step: float = actor.global_position.distance_to(previous[actor.name])
		if step > max_step:
			max_step_actor = String(actor.name)
			max_step_frame_gap = frame - previous_sample_frame
		max_step = maxf(max_step, step)
		travelled[actor.name] = float(travelled[actor.name]) + step
		previous[actor.name] = actor.global_position
		if actor == game.player:
			var mode := "third_person" if float(game.camera_rig.mode_blend) <= 0.01 else "isometric" if float(game.camera_rig.mode_blend) >= 0.99 else "transition"
			camera_travel[mode] = float(camera_travel[mode]) + step
	previous_sample_frame = frame

func _report(seed_value: int) -> void:
	var metrics := {"seed": seed_value, "observed_physics_frames": observed_frames, "distance": travelled,
		"maximum_actor_step": max_step, "maximum_step_actor": max_step_actor, "maximum_step_frame_gap": max_step_frame_gap,
		"camera_toggles": camera_toggles, "camera_distance": camera_travel,
		"player": {"replans": navigator.replan_count, "geometry_probes": navigator.geometry_probe_count}, "companions": {}}
	for actor: CharacterBody3D in actors:
		if is_instance_valid(actor) and actor != game.player:
			metrics.companions[String(actor.name)] = {"replans": int(actor.navigator.replan_count) - int(plan_start[actor.name]),
				"geometry_probes": int(actor.navigator.geometry_probe_count) - int(probe_start[actor.name]),
				"recoveries": int(actor.recovery_count) - int(recovery_start[actor.name])}
	print("BEASTWILDS NAVIGATION METRICS: ", JSON.stringify(metrics))
