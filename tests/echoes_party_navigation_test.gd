extends "res://tests/echoes_combat_fixture.gd"
## After actual arrival, no actor transform/reset writes: movement is touch
## joystick input, companions use their existing navigator and combat controller.
const Navigator = preload("res://scripts/party/companion_navigation.gd")
var navigator: RefCounted
var measured: Array[CharacterBody3D] = []
var previous: Dictionary = {}
var distances: Dictionary = {}
var recoveries: Dictionary = {}
var companion_attacks: Dictionary = {}
var modes := {"third_person": 0.0, "isometric": 0.0, "transition": 0.0}
var max_step := 0.0
var samples := 0
var camera_toggles := 0
var measuring := false
var stable := true
var generation := -1

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ECHOES PARTY NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	var seed_value := 17
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int(): seed_value = argument.trim_prefix("--seed=").to_int()
	if not await prepare_echoes("walk-%d" % seed_value) or not await enter_echoes(seed_value):
		finish()
		return
	var before := saved_possessions()
	generation = session.run_generation
	navigator = Navigator.new()
	navigator.bind(game.player, game.party)
	measured.assign([game.player, game.party.members.guardian, game.party.members.mystic])
	for actor: CharacterBody3D in measured:
		previous[actor.get_instance_id()] = actor.global_position
		distances[actor.get_instance_id()] = 0.0
		if actor != game.player:
			recoveries[actor.get_instance_id()] = actor.recovery_count
			companion_attacks[actor.get_instance_id()] = {"before": actor.combat.attack_id, "seen": false}
	measuring = true
	physics_frame.connect(_sample)
	if not check(await _walk(world.source_approach_position("break_shrine"), 20.0), "Player walks from arrival to the original shrine with both followers"):
		_end(seed_value)
		return
	check(await _regroup(), "Guardian and Mystic physically reach shrine formation")
	var shrine: Node3D = world.registered_activity_sources().break_shrine
	check(game.player.interaction_target == shrine, "Actual on-foot arrival selects original shrine")
	input_hub.request_action(&"interact")
	tap(overlay.echoes_panel.continue_rect().get_center())
	if not await await_wave(1):
		_end(seed_value)
		return
	var player_attack_id: int = game.player.combat.attack_id
	var native_actors := current_actors()
	var ally_damage := false
	for enemy: Node3D in native_actors:
		if enemy.health <= 0.0: continue
		var health_before: float = enemy.health
		var toward_south := Vector3(0, 0, 4.0)
		check(await _walk(enemy.global_position + toward_south, 25.0), "Party walks into a real native echo encounter")
		check(await eventually(func() -> bool: return enemy.health < health_before, 12.0), "Existing companions actually damage the eligible echo")
		ally_damage = ally_damage or enemy.health < health_before
		check(await eventually(func() -> bool: return enemy.state == &"dead", 20.0), "Existing Guardian/Mystic combat can defeat a real wave member")
	check(game.player.combat.attack_id == player_attack_id and ally_damage,
		"Companion combat assistance caused real enemy damage without a player attack or test damage command")
	check(await eventually(func() -> bool: return session.activity_snapshot().phase == "break", 4.0), "Companion terminal kills complete the same original wave")
	var wave: Dictionary = EchoesPlan.wave(world.issued_activity_context().plan, 1)
	var manager: Node3D = world.get_node("EchoesLootCaches")
	manager.refresh()
	var view: Node3D = manager.view_for(wave.receipt)
	if check(view != null, "Native companion victory exposes the real wave cache"):
		check(await _walk(view.global_position + Vector3(0, 0.15, -1.9), 25.0), "Party walks from combat to the actual safe cache approach")
		input_hub.request_action(&"interact")
		if check(overlay.mode == &"loot", "On-foot cache approach opens actual Search"):
			tap(overlay.loot_panel.take_all_rect().get_center())
			check(session.has_claimed(wave.receipt), "Actual Search secures findings into the pending bag")
	check(await _walk(world.source_approach_position("return_spring"), 20.0), "Party walks from cache to the original return spring")
	check(await _regroup(), "Both followers physically reach return formation")
	var spring: Node3D = world.registered_activity_sources().return_spring
	check(game.player.interaction_target == spring and spring.get_exit_status(game.player).get("can_abandon", false),
		"On-foot party can review reliable early abandonment")
	input_hub.request_action(&"interact")
	check(overlay.mode == &"sanctuary" and panel.visible, "Original return card opens from the measured physical route")
	check(stable and generation == session.run_generation, "Same admitted player, party and generation survive movement, combat and cameras")
	check(camera_toggles >= 4 and modes.third_person > 3.0 and modes.isometric > 3.0,
		"Actual joystick movement and followers work in both settled perspectives and live transitions")
	for actor: CharacterBody3D in measured:
		check(float(distances[actor.get_instance_id()]) > 10.0, String(actor.name) + " physically travelled between activity stations")
		if actor != game.player:
			check(actor.recovery_count == recoveries[actor.get_instance_id()], String(actor.name) + " uses no recovery teleport during measured traversal")
			check(companion_attacks[actor.get_instance_id()].seen, String(actor.name) + " uses its original weapon combat during the wave")
	check(max_step < 0.50, "Every measured physics step stays below the relocation threshold")
	check(saved_possessions() == before, "Traversal and pending rewards preserve all secured progression")
	# Finish the real visit before engine shutdown. Sampling ends before the
	# intentional scene transition so arrival cannot count as walking/recovery.
	measuring = false
	if physics_frame.is_connected(_sample): physics_frame.disconnect(_sample)
	var retained_world: Node3D = world
	tap(panel.primary_rect().get_center())
	await arrive(&"realm_nexus")
	check(not session.active and game.party.world == game.active_world \
		and game.player == measured[0] and game.party.members.guardian == measured[1] \
		and game.party.members.mystic == measured[2] and not is_instance_valid(retained_world),
		"Reviewed abandonment returns the same real party and retires the native combat world")
	check(session.unsecured_gold == 0 and session.run_items.is_empty() and saved_possessions() == before,
		"Actual early return loses only this trial's unsecured findings and preserves all secured ownership")
	_end(seed_value)

func _walk(destination: Vector3, timeout: float) -> bool:
	navigator.clear()
	var reached := false
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		if not stable or game.player.health <= 0.0 or game.player.downed: break
		var offset: Vector3 = destination - game.player.global_position
		if Vector2(offset.x, offset.z).length() < 0.55 and absf(offset.y) < 0.35:
			reached = true
			break
		if tick == Engine.physics_ticks_per_second / 2 or tick == Engine.physics_ticks_per_second * 2:
			input_hub.request_action(&"camera_toggle")
			camera_toggles += 1
		var direction: Vector3 = navigator.direction_to(destination, 1.0 / Engine.physics_ticks_per_second)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	await frames(14)
	return reached

func _regroup() -> bool:
	return await eventually(func() -> bool:
		for actor: CharacterBody3D in measured:
			if actor != game.player and actor.global_position.distance_to(game.party.formation_position(actor)) > 1.6: return false
		return true, 10.0)

func _sample() -> void:
	if not measuring: return
	samples += 1
	stable = stable and is_instance_valid(world) and game.active_world == world and session.run_generation == generation \
		and game.player == measured[0] and game.party.members.guardian == measured[1] and game.party.members.mystic == measured[2]
	for actor: CharacterBody3D in measured:
		if not is_instance_valid(actor) or not actor.global_position.is_finite():
			stable = false
			continue
		var id := actor.get_instance_id()
		var step: float = actor.global_position.distance_to(previous[id])
		max_step = maxf(max_step, step)
		distances[id] = float(distances[id]) + step
		previous[id] = actor.global_position
		if actor == game.player:
			var mode := "third_person" if game.camera_rig.mode_blend <= 0.01 else "isometric" if game.camera_rig.mode_blend >= 0.99 else "transition"
			modes[mode] = float(modes[mode]) + step
		elif int(actor.combat.attack_id) > int(companion_attacks[id].before): companion_attacks[id].seen = true

func _end(seed_value: int) -> void:
	measuring = false
	if physics_frame.is_connected(_sample): physics_frame.disconnect(_sample)
	input_hub.set_touch_move(Vector2.ZERO)
	var companions := {}
	for actor: CharacterBody3D in measured:
		if is_instance_valid(actor) and actor != game.player:
			companions[String(actor.name)] = {"distance": distances.get(actor.get_instance_id(), 0.0),
				"recoveries": int(actor.recovery_count) - int(recoveries.get(actor.get_instance_id(), 0)),
				"combat_used": companion_attacks.get(actor.get_instance_id(), {}).get("seen", false)}
	print("ECHOES_PARTY_METRICS ", JSON.stringify({"seed": seed_value, "physics_frames": samples,
		"player_distance": distances.get(game.player.get_instance_id(), 0.0), "maximum_step": max_step,
		"camera_toggles": camera_toggles, "camera_distance": modes, "companions": companions}))
	if navigator != null: navigator.clear()
	navigator = null
	measured.clear()
	finish()
