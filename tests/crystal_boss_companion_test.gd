extends "res://tests/crystal_companion_fixture.gd"
## Actual native controllers and paid companion decisions, in both camera modes.
var family := "conductor"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
	suite_name = "VAULTBOUND CRYSTAL COMPANIONS " + family.to_upper()
	_run.call_deferred()

func _run() -> void:
	if not check(family in ["conductor", "colossus", "wraith", "lancekeeper"], "Only authored companion test families are requested"): finish(); return
	if not await prepare_crystal_party("/tmp/vaultbound-7d5-crystal-companions-" + family + "/profile.json"): finish(); return
	var id := "prism_conductor"
	var patterns: Array[StringName] = [&"conductor_alternating_lanes", &"conductor_sequential_cross"]
	if family == "colossus":
		id = "geode_colossus"
		patterns.assign([&"colossus_cone_swing", &"colossus_double_slam"])
	elif family == "wraith":
		id = "shard_wraith"
		patterns.assign([&"wraith_aimed_burst", &"wraith_exposed_cast"])
	elif family == "lancekeeper": patterns.assign([&"crystal_lance_thrust"])
	if await enter_crystal(id, "none", family == "lancekeeper"):
		for perspective in range(2):
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			for actor: CharacterBody3D in [guardian, mystic]:
				for pattern: StringName in patterns:
					await _observe_escape(actor, pattern)
					if not failures.is_empty(): break
				if not failures.is_empty(): break
			if not failures.is_empty(): break
		if failures.is_empty(): await _commands_and_cancel(patterns[0])
		if failures.is_empty() and family == "wraith": await _relocation()
		if failures.is_empty() and family == "conductor": await _blocked_escape()
	if failures.is_empty() and family == "conductor" and await enter_crystal(id, "refracted_pattern"):
		var strong: Dictionary = session.issued_run_plan().boss
		check("conductor_sequential_cross" in strong.phase_one_patterns and not "conductor_refracted_cross" in strong.phase_one_patterns \
			and "conductor_refracted_cross" in strong.phase_two_patterns and not "conductor_sequential_cross" in strong.phase_two_patterns, "Issued stronger profile keeps the normal phase-one cross and explicitly selects its separate phase-two attack")
		if failures.is_empty(): await _observe_escape(guardian, &"conductor_sequential_cross")
		if not failures.is_empty(): await finish_crystal(); return
		await focus(boss, 7.0)
		boss.take_hit(float(boss.max_health) * 0.76, player.global_position)
		boss.set_physics_process(true)
		if check(await eventually(func() -> bool: return int(boss.phase) == 2 and boss.state != &"phase_transition", 3.0), "Actual Refracted Conductor reaches its second phase"):
			boss.set_physics_process(false)
			for actor: CharacterBody3D in [guardian, mystic]:
				await _observe_escape(actor, &"conductor_refracted_cross")
				if not failures.is_empty(): break
	await finish_crystal()

func _observe_escape(actor: CharacterBody3D, pattern: StringName) -> void:
	if not await stage_companion(actor, 4.8 if pattern == &"wraith_aimed_burst" else 2.4): return
	var zones := requested_warning(pattern, actor, pattern == &"wraith_aimed_burst")
	if zones.is_empty(): return
	if not check(inside_danger(zones, actor.global_position), "Actual admitted warning threatens the tested companion's full clearance envelope"): return
	var start: Vector3 = actor.global_position
	var health: float = actor.health
	var decisions: int = actor.brain.decision_count
	var probes: int = actor.navigator.geometry_probe_count
	var generation: int = session.run_generation
	var identity: int = boss.get_instance_id()
	var initial_attack: int = boss.attack_id
	var initial_serial: int = boss.cast_serial
	var initial_camera: String = game.camera_rig.mode_name
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(start) < 0.08, "Crystal warning respects the companion's configured reaction delay")
	for camera in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(boss.get_instance_id() == identity and session.run_generation == generation and boss.attack_id == initial_attack \
			and boss.cast_serial == initial_serial and footprints(boss.get_danger_zones()) == footprints(zones), "Camera switch preserves the same real Crystal stage and locked warning")
	check(game.camera_rig.mode_name == initial_camera, "Both camera perspectives return without resetting gameplay")
	boss.set_physics_process(true)
	var seen: Dictionary = {}
	var active_stages: Dictionary = {}
	var seen_gap := false
	var active_camera_switched := false
	var completed := false
	var sequence: bool = pattern in [&"conductor_alternating_lanes", &"conductor_sequential_cross", &"conductor_refracted_cross", &"colossus_double_slam"]
	var timeout := Time.get_ticks_msec() + 11000
	while Time.get_ticks_msec() < timeout:
		var current: Array[Dictionary] = boss.get_danger_zones()
		var state: StringName = boss.state
		if state == &"stage_gap" and not seen_gap:
			seen_gap = true
			check(current.is_empty(), "Harmless sequence gap publishes no stale damage geometry")
		for zone: Dictionary in current:
			var stage: int = int(zone.stage_id)
			if not seen.has(stage):
				seen[stage] = {"attack": int(zone.attack_id), "serial": int(zone.cast_serial) if zone.has("cast_serial") else int(boss.cast_serial)}
				check(zone.phase == &"warning" and float(zone.remaining) >= 1.5 and Danger.validate(zone).is_empty(), "Each actual Crystal stage starts with its own full readable warning")
				if stage == 1 and pattern == &"conductor_sequential_cross":
					check(current.size() == 1, "Normal cross retains one second-stage lane, including the stronger actor's first phase")
				elif stage == 1 and pattern == &"conductor_refracted_cross":
					var opening: Vector3 = (Vector3(current[0].position) + Vector3(current[-1].position)) * 0.5
					check(int(boss.phase) == 2 and current.size() == 2 and float(zone.remaining) >= 2.0 \
						and int(current[0].attack_id) == int(current[-1].attack_id) and not inside_danger(current, opening) \
						and actor.navigator.is_position_safe(opening), "Explicit phase-two Refracted attack warns two same-ID lanes with a real grounded padded opening")
			if zone.phase == &"active" and not active_stages.has(stage):
				active_stages[stage] = true
				check(not inside_danger(current, actor.global_position) and actor.navigator.is_position_safe(actor.global_position), "Companion reaches actual grounded clearance before this Crystal damage stage")
				if not active_camera_switched:
					var live_attack: int = boss.attack_id
					var live_serial: int = boss.cast_serial
					input_hub.request_action(&"camera_toggle")
					active_camera_switched = true
					check(boss.attack_id == live_attack and boss.cast_serial == live_serial and session.run_generation == generation, "Switching during actual damage preserves cast receipts and the same run")
		if state == &"recovery":
			completed = true
			break
		await physics_frame
	check(completed and seen.size() == (2 if sequence else 1) and active_stages.size() == seen.size(), "Actual authored stages reach damage and finite recovery without an invisible skipped stage")
	if sequence:
		check(seen_gap and seen.has(0) and seen.has(1) and seen[0].attack != seen[1].attack and seen[0].serial != seen[1].serial, "Second warned stage follows a harmless gap with fresh cast and attack identities")
	check(actor.global_position.distance_to(start) > 0.45 and is_equal_approx(actor.health, health) \
		and actor.brain.decision_count - decisions <= 40 and actor.navigator.geometry_probe_count - probes < 600, "Real companion escapes remaining damage with bounded decisions/native probes and no spawn immunity")
	check(game.party.command == &"retreat" and boss.get_danger_zones().is_empty(), "Safety response preserves direct Retreat and retires actual warnings at recovery")
	if game.camera_rig.mode_name != initial_camera: input_hub.request_action(&"camera_toggle")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)
	actor.set_controls_enabled(false)

func _commands_and_cancel(pattern: StringName) -> void:
	for actor: CharacterBody3D in [guardian, mystic]:
		if not await stage_companion(actor, 2.0 if actor == guardian else 5.0): return
		var before: float = boss.health
		check(game.party.issue_command(&"attack", boss), "Existing Attack Target accepts the registered Crystal actor")
		check(await eventually(func() -> bool: return boss.health < before, 3.0), "Actual companion reaches and damages Crystal target through its existing weapon: " + String(actor.companion_id))
		check(game.party.issue_command(&"retreat"), "Retreat remains accepted during Crystal combat")
		check(await eventually(func() -> bool: return actor.target == null, 1.0), "Companion releases the actual Crystal target for its direct Retreat order")
		actor.set_controls_enabled(false)
	if not await stage_companion(guardian, 4.8 if pattern == &"wraith_aimed_burst" else 2.4): return
	var zones := requested_warning(pattern, guardian, pattern == &"wraith_aimed_burst")
	if zones.is_empty(): return
	guardian.set_controls_enabled(false)
	var health: float = guardian.health
	boss.cancel_pending(&"fixture_cancel")
	check(boss.get_danger_zones().is_empty(), "Actual cancellation synchronously removes Crystal cast geometry")
	guardian.navigator.select_danger_escape()
	check(guardian.navigator._zones.is_empty() and not guardian.brain._position_dangerous(guardian.global_position), "Next real path query and revive-safety query are unconstrained after Crystal cancellation")
	await frames(10)
	check(is_equal_approx(guardian.health, health), "Canceled Crystal warning produces no delayed hit")

func _relocation() -> void:
	if not await stage_companion(mystic, 4.8): return
	guardian.set_controls_enabled(false)
	mystic.set_controls_enabled(false)
	var start: Vector3 = boss.global_position
	if not check(boss.request_attack(&"wraith_marked_relocation"), "Actual Wraith admits a native grounded relocation"): return
	check(boss.get_danger_zones().is_empty() and not mystic.brain._position_dangerous(mystic.global_position), "Harmless relocation marker is not falsely advertised as damaging geometry")
	boss.set_physics_process(true)
	var previous: Vector3 = start
	var largest_step := 0.0
	var grounded := true
	var moved := false
	var timeout := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < timeout:
		await physics_frame
		var current: Vector3 = boss.global_position
		largest_step = maxf(largest_step, previous.distance_to(current))
		grounded = grounded and guardian.navigator.is_position_safe(current)
		moved = moved or current.distance_to(start) > 0.4
		previous = current
		if boss.state == &"recovery": break
	check(moved and grounded and largest_step < 0.3 and boss.get_danger_zones().is_empty(), "Actual Wraith moves continuously over native floor without teleporting or a damage trail")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)

func _blocked_escape() -> void:
	if not await stage_companion(guardian): return
	var zones := requested_warning(&"conductor_alternating_lanes", guardian)
	if zones.is_empty(): return
	guardian.set_controls_enabled(false)
	var initial: Vector3 = guardian.navigator.select_danger_escape()
	if not check(initial.is_finite(), "Actual Crystal lane has an admitted clear exit"): return
	var blocker: StaticBody3D = obstacle(initial + Vector3.UP * 0.9, Vector3(0.8, 1.8, 0.8))
	await frames(2)
	guardian.navigator.invalidate_geometry()
	var alternative: Vector3 = guardian.navigator.select_danger_escape()
	check(alternative.is_finite() and alternative.distance_to(initial) > 0.5 \
		and guardian.navigator.is_position_safe(alternative) and not inside_danger(zones, alternative), "Native obstruction rejects the first lane exit and admits a different clear grounded route")
	blocker.get_parent().remove_child(blocker)
	blocker.queue_free()
	guardian.navigator.invalidate_geometry()
	mystic.navigator.invalidate_geometry()
	boss.cancel_pending(&"fixture_complete")
