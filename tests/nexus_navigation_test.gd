extends "res://tests/nexus_fixture.gd"
## One continuous journey through all ten portals using real movement and AI.
const Navigator = preload("res://scripts/party/companion_navigation.gd")
var navigator: RefCounted
var actors: Array[CharacterBody3D] = []
var previous: Dictionary = {}
var distance: Dictionary = {}
var recoveries: Dictionary = {}
var max_step := 0.0
var observed_frames := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND NEXUS PHYSICAL PARTY NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_nexus("navigation", true):
		finish()
		return
	var saved := save_files()
	actors.assign([game.player, game.party.members.guardian, game.party.members.mystic])
	navigator = Navigator.new()
	navigator.bind(game.player, game.party)
	for actor: CharacterBody3D in actors:
		previous[actor.name] = actor.global_position
		distance[actor.name] = 0.0
		if actor != game.player: recoveries[actor.name] = actor.recovery_count
	# No reset_for_spawn, position assignment, simulated collision or recovery
	# allowance occurs after sampling begins. Input is transformed by the real camera.
	for id: StringName in Catalog.IDS:
		input_hub.request_action(&"camera_toggle")
		for tick in range(28):
			await physics_frame
			_sample()
		check(await _walk(hall.get_poi_approach_position(id), 20.0), "Player physically reaches " + String(id) + " with alternating camera modes")
		check(await _regroup(9.0), "Both actual companions walk into formation at " + String(id))
		check(game.player.interaction_target == source(id), "Walking selects the real visible gateway prompt: " + String(id))
	check(await _walk(hall.get_poi_approach_position(&"nexus_return"), 20.0), "Party leader physically returns to the Sanctuary exit")
	check(await _regroup(9.0), "Both companions walk back to the actual return gateway")
	for actor: CharacterBody3D in actors:
		check(float(distance[actor.name]) > 80.0, String(actor.name) + " completed a meaningful continuous hall journey")
		if actor != game.player:
			check(actor.recovery_count == recoveries[actor.name], String(actor.name) + " required no stuck-recovery teleport")
			check(actor.navigator.replan_count < observed_frames / 5 + 20, String(actor.name) + " retains throttled path planning")
	check(max_step < 0.35, "Every sampled actor step stays below the relocation threshold")
	check(save_files() == saved and session.profile.companions.guardian.recruited and session.profile.companions.mystic.recruited, "Physical route and camera changes preserve recruitment and secured save bytes")
	print("NEXUS NAVIGATION METRICS: ", JSON.stringify({"distance": distance, "maximum_step": max_step, "observed_frames": observed_frames, "player_replans": navigator.replan_count, "player_probes": navigator.geometry_probe_count}))
	input_hub.set_touch_move(Vector2.ZERO)
	finish()

func _walk(destination: Vector3, timeout: float) -> bool:
	navigator.clear()
	var reached := false
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_sample()
		var offset: Vector3 = destination - game.player.global_position
		if Vector2(offset.x, offset.z).length() < 0.55 and absf(offset.y) < 0.25:
			reached = true
			break
		var direction: Vector3 = navigator.direction_to(destination, 1.0 / Engine.physics_ticks_per_second)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0
		back.y = 0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	for tick in range(14):
		await physics_frame
		_sample()
	if not reached: print("NEXUS WALK DIAGNOSTIC: ", destination, " actor=", game.player.global_position, " path=", navigator.path, " failed=", navigator.path_failed)
	return reached

func _regroup(timeout: float) -> bool:
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		_sample()
		var grouped := true
		for actor: CharacterBody3D in actors:
			if actor != game.player and actor.global_position.distance_to(game.party.formation_position(actor)) > 1.4: grouped = false
		if grouped: return true
	return false

func _sample() -> void:
	observed_frames += 1
	for actor: CharacterBody3D in actors:
		var step: float = actor.global_position.distance_to(previous[actor.name])
		max_step = maxf(max_step, step)
		distance[actor.name] = float(distance[actor.name]) + step
		previous[actor.name] = actor.global_position
