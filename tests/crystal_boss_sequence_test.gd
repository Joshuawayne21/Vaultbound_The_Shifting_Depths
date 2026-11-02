extends "res://tests/crystal_boss_fixture.gd"
## Native two-stage timing, identities, admission failure and phase selection.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND CRYSTAL BOSS SEQUENCES", "/tmp/vaultbound-d5-boss-sequences/profile.json"):
		finish()
		return
	await _historical_single_stage()
	if await start_crystal("prism_conductor"):
		await _two_stage_cycle(&"conductor_alternating_lanes")
		await _two_stage_cycle(&"conductor_sequential_cross")
		await _second_stage_failure()
		await _sequence_cancellation()
		await _replacement_callback()
	if await start_crystal("geode_colossus"):
		await _two_stage_cycle(&"colossus_double_slam")
	if await start_crystal("prism_conductor", "refracted_pattern"):
		await _refracted_phase_selection()
	await retire_fixture()
	finish()

func _historical_single_stage() -> void:
	var resource: Resource = load("res://resources/bosses/attacks/sentinel_cleave.tres")
	var old: Dictionary = resource.snapshot()
	check(CrystalAttack.exact_keys(old, CrystalAttack.SNAPSHOT_KEYS) and old.pattern_version == 1 \
		and not old.has("stage_two") and old.warning_time == 1.6 and old.active_time == 0.18 \
		and old.recovery_time == 1.3 and old.damage == 22.0 and old.stagger == 0.25,
		"Historical v1 cleave retains its exact schema and authored timing/damage")
	var detached: Dictionary = CrystalAttack.stage_snapshot(old, 0)
	detached.parameters.radius = 0.5
	check(old.parameters.radius == 4.2 and CrystalAttack.stage_snapshot(old, 1).is_empty() \
		and CrystalAttack.stage_snapshot(old, -1).is_empty(), "Historical stage adapter is detached and cannot invent a second stage")
	if not await start_selected("thornmarshal", 6): return
	await focus(boss)
	var before: float = player.health
	if not check(boss.request_attack(&"sentinel_cleave"), "Actual historical Sentinel still admits its one-stage controller"): return
	var token: Dictionary = boss._cast.token()
	check(token.stage_id == 0 and not boss.snapshot().has("sequence_stage"), "Rootbound does not acquire a Crystal sequence cursor")
	commit(boss)
	step(boss, 0.19)
	check(is_equal_approx(player.health, before - 22.0 * float(world.issued_depth_policy().damage_multiplier)) \
		and boss.state == &"recovery" and is_equal_approx(float(boss.snapshot().remaining), 1.3) \
		and not boss.cast_token_valid(token), "Historical cast delivers once and enters its original full recovery without a stage gap")

func _two_stage_cycle(pattern: StringName) -> void:
	await focus(boss)
	var schedule: Dictionary = attack_snapshot(boss, String(pattern))
	var warnings: Array[Dictionary] = []
	var commits: Array[int] = []
	var on_warning: Callable = func(_pattern: StringName) -> void: warnings.append(boss._cast.token())
	var on_commit: Callable = func(id: int) -> void: commits.append(id)
	boss.attack_started.connect(on_warning)
	boss.attack_committed.connect(on_commit)
	if not check(boss.request_attack(pattern), "Native actor admits complete sequence " + String(pattern)):
		boss.attack_started.disconnect(on_warning)
		boss.attack_committed.disconnect(on_commit)
		return
	var first: Dictionary = boss._cast.token()
	var sequence: int = boss.snapshot().sequence_serial
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var locked := crystal_footprints(zones)
	var before: float = player.health
	check(valid_crystal_zones(zones, 0) and boss.has_pending_attack() and boss.snapshot().stage_count == 2 \
		and warnings.size() == 1 and commits.is_empty(), "Stage zero has one complete warning and a real pending sequence")
	var exposed: Dictionary = boss._cast.stage_snapshot()
	exposed.damage = 99.0
	exposed.parameters.radius = 0.25
	check(boss._cast.stage_snapshot() == CrystalAttack.stage_snapshot(schedule, 0), "Resolved live stage is detached from its inspection copy")
	var substitute := schedule.duplicate(true)
	substitute.damage = float(substitute.damage) + 1.0
	check(CrystalAttack.valid_snapshot(substitute) and not boss._cast.begin(substitute, zones) \
		and not boss._cast.begin(schedule, zones, 2) and boss._cast.token() == first,
		"Structurally valid replacement damage and an extra stage cannot replace the exact issued live cast")
	place_player(boss.spawn_position + Vector3(1.8, 0, 2.4))
	input_hub.request_action(&"camera_toggle")
	step(boss, float(schedule.warning_time) - 0.01)
	check(player.health == before and boss.state == &"windup" and crystal_footprints(boss.get_danger_zones()) == locked,
		"Movement and a camera switch cannot retarget geometry or consume the full warning")
	place_player(zones[0].position)
	step(boss, 20.0)
	var first_damage := crystal_damage(String(pattern), 0)
	check(boss.state == &"active" and is_equal_approx(float(boss.snapshot().remaining), float(schedule.active_time)) \
		and is_equal_approx(player.health, before - first_damage) and commits == [int(first.attack_id)],
		"Oversized warning step commits only the first real damage edge and preserves its active interval")
	step(boss, 0.05)
	check(is_equal_approx(player.health, before - first_damage), "First-stage repeated contact cannot repeat its target receipt")
	step(boss, 20.0)
	check(boss.state == &"stage_gap" and is_equal_approx(float(boss.snapshot().remaining), float(schedule.stage_gap)) \
		and boss.get_danger_zones().is_empty() and boss.has_pending_attack() and not boss.cast_token_valid(first) \
		and not boss.request_attack(pattern), "First active completion retires its token before the full harmless pending gap")
	# Stage one must admit independently; Colossus locks this new target point.
	place_player(boss.spawn_position + Vector3(2.6, 0, 2.4))
	step(boss, float(schedule.stage_gap) - 0.01)
	check(boss.state == &"stage_gap" and warnings.size() == 1 and commits.size() == 1,
		"Quiet gap has no attack edge or second warning before its own expiry")
	step(boss, 20.0)
	var second: Dictionary = boss._cast.token()
	zones = boss.get_danger_zones()
	var stage_one: Dictionary = CrystalAttack.stage_snapshot(schedule, 1)
	check(boss.state == &"windup" and is_equal_approx(float(boss.snapshot().remaining), float(stage_one.warning_time)) \
		and boss.snapshot().sequence_serial == sequence and boss.snapshot().sequence_stage == 1 \
		and valid_crystal_zones(zones, 1) and second.attack_id != first.attack_id and second.cast_serial != first.cast_serial \
		and warnings.size() == 2 and commits.size() == 1 and not boss.cast_token_valid(first),
		"Oversized gap step starts a full second warning with fresh stage identity and no catch-up hit")
	if zones.is_empty():
		boss.attack_started.disconnect(on_warning)
		boss.attack_committed.disconnect(on_commit)
		return
	var first_zone: Dictionary = locked[0]
	if pattern == &"conductor_alternating_lanes":
		check(is_equal_approx(flat_distance(first_zone.position, zones[0].position), 2.8), "Alternating stage offsets its locked parallel lane by the authored 2.8 metres")
	elif pattern == &"conductor_sequential_cross":
		var axis: Vector3 = (first_zone.end - first_zone.start).normalized()
		var next_axis: Vector3 = (zones[0].end - zones[0].start).normalized()
		check(absf(axis.dot(next_axis)) < 0.0001 and first_zone.position.is_equal_approx(zones[0].position), "Cross rotates ninety degrees around the original locked midpoint")
	else:
		check(zones[0].position.distance_to(first_zone.position) > 1.0 and CrystalGeometry.contains(zones[0], player.global_position),
			"Second Geode slam independently marks the newly eligible target position")
	place_player(zones[0].position)
	step(boss, float(stage_one.warning_time) - 0.01)
	check(is_equal_approx(player.health, before - first_damage) and boss.state == &"windup", "Second stage gives its complete independent reaction window")
	step(boss, 0.02)
	var total := first_damage + crystal_damage(String(pattern), 1)
	check(is_equal_approx(player.health, before - total) and commits == [int(first.attack_id), int(second.attack_id)],
		"Second advertised edge delivers one fresh receipt with its actual stage damage")
	step(boss, 20.0)
	check(boss.state == &"recovery" and is_equal_approx(float(boss.snapshot().remaining), float(schedule.recovery_time)) \
		and not boss.has_pending_attack() and boss.get_danger_zones().is_empty() and not boss.cast_token_valid(second) \
		and not boss.request_attack(pattern), "Only final completion starts the full final recovery and retires both stages")
	boss.attack_started.disconnect(on_warning)
	boss.attack_committed.disconnect(on_commit)

func _second_stage_failure() -> void:
	await focus(boss)
	if not check(boss.request_attack(&"conductor_sequential_cross"), "Cross starts before a real second-stage obstruction"): return
	var first: Dictionary = boss.get_danger_zones()[0]
	commit(boss)
	step(boss, 0.21)
	var before: float = player.health
	var wall := obstacle(first.position + Vector3.UP * 1.4, Vector3(0.7, 3.0, 0.7))
	await frames(2)
	step(boss, 20.0)
	check(boss.state == &"recovery" and is_equal_approx(float(boss.snapshot().remaining), 1.8) \
		and not boss.has_pending_attack() and boss.get_danger_zones().is_empty() and player.health == before,
		"Blocked second-stage native admission aborts harmlessly into full final recovery")
	check(not boss.request_attack(&"conductor_sequential_cross"), "Failed second stage cannot retry during its recovery")
	remove_probe(wall)

func _sequence_cancellation() -> void:
	for boundary: String in ["warning", "active", "gap", "second_warning"]:
		await focus(boss)
		if not check(boss.request_attack(&"conductor_sequential_cross"), "Cancellation probe admits sequence at " + boundary): continue
		var token: Dictionary = boss._cast.token()
		if boundary != "warning": commit(boss)
		if boundary in ["gap", "second_warning"]: step(boss, 0.21)
		if boundary == "second_warning":
			step(boss, 20.0)
			token = boss._cast.token()
		var before: float = player.health
		var sequence: int = boss.snapshot().sequence_serial
		boss.combat_active = false
		check(not boss.has_pending_attack() and boss.snapshot().sequence_serial > sequence \
			and boss.snapshot().sequence_stage == -1 and boss.get_danger_zones().is_empty() and not boss.cast_token_valid(token),
			"Culling synchronously drops the pending cursor at " + boundary)
		step(boss, 20.0)
		check(player.health == before, "Cancelled " + boundary + " cannot deliver a later stage")
		world._process(0.01)
		check(boss.request_attack(&"conductor_sequential_cross") and boss.snapshot().sequence_stage == 0 \
			and is_equal_approx(float(boss.snapshot().remaining), 1.8), "Reactivation begins a new complete stage-zero warning")
	await focus(boss)
	check(boss.request_attack(&"conductor_sequential_cross"), "Commit callback probe starts a native sequence")
	var before: float = player.health
	boss.attack_committed.connect(func(_id: int) -> void: boss.cancel_pending(&"test_commit_cancel"), CONNECT_ONE_SHOT)
	commit(boss)
	check(player.health == before and not boss.has_pending_attack() and boss.get_danger_zones().is_empty(), "Synchronous commit cancellation blocks the first damage edge and every pending stage")
	await focus(boss)
	check(boss.request_attack(&"conductor_sequential_cross"), "Invalid clock probe starts a native sequence")
	step(boss, NAN)
	check(not boss.has_pending_attack() and boss.get_danger_zones().is_empty(), "Nonfinite delta retires the sequence without a timing catch-up")

func _replacement_callback() -> void:
	await focus(boss)
	if not check(boss.request_attack(&"conductor_sequential_cross"), "Old cross starts before gap callback replacement"): return
	commit(boss)
	var old_serial: int = boss.snapshot().sequence_serial
	var replacement := {"admitted": false, "serial": -1}
	var on_state: Callable = func(next: StringName) -> void:
		if next != &"stage_gap": return
		boss.cancel_pending(&"test_replacement")
		replacement["admitted"] = bool(boss.request_attack(&"conductor_alternating_lanes"))
		replacement["serial"] = int(boss.snapshot().sequence_serial)
	boss.state_changed.connect(on_state)
	step(boss, 20.0)
	boss.state_changed.disconnect(on_state)
	check(replacement.admitted and replacement.serial > old_serial and boss.snapshot().sequence_serial == replacement.serial \
		and boss.attack_name == &"conductor_alternating_lanes" and boss.state == &"windup" \
		and boss.snapshot().sequence_stage == 0 and is_equal_approx(float(boss.snapshot().remaining), 1.8) \
		and valid_crystal_zones(boss.get_danger_zones(), 0), "Old completion callback cannot consume or hide a newly admitted replacement sequence")

func _refracted_phase_selection() -> void:
	await focus(boss)
	var profile: Dictionary = world.issued_run_plan().boss
	check(profile.phase_one_patterns == ["conductor_alternating_lanes", "conductor_sequential_cross"] \
		and profile.phase_two_patterns == ["conductor_alternating_lanes", "conductor_refracted_cross"] \
		and not boss.request_attack(&"conductor_refracted_cross"), "Strong Conductor admits only the normal cross in phase one")
	# Observe both automatic choices; the cursor advances once per whole sequence.
	step(boss, 1.0)
	step(boss, 0.01)
	check(boss.attack_name == &"conductor_alternating_lanes" and finish_crystal_sequence(), "Automatic phase-one sequence starts with alternating lanes")
	step(boss, 20.0)
	step(boss, 0.01)
	if not check(boss.attack_name == &"conductor_sequential_cross" and boss.state == &"windup", "Automatic phase-one cursor selects normal cross after one entire sequence"): return
	commit(boss)
	step(boss, 20.0)
	step(boss, 20.0)
	check(boss.get_danger_zones().size() == 1 and is_equal_approx(float(boss.snapshot().remaining), 1.8), "Strong phase-one cross retains one second lane and its normal 1.8-second warning")
	var old: Dictionary = boss._cast.token()
	var incoming := {"damage": boss.max_health * 0.7, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}
	check(boss.receive_hit(incoming) and boss.phase == 2 and boss.state == &"phase_transition" \
		and is_equal_approx(float(boss.snapshot().remaining), 1.8) and not boss.cast_token_valid(old) and not boss.has_pending_attack(),
		"Real damage cancels the old second warning before the full harmless phase transition")
	var hp: float = boss.health
	check(not boss.receive_hit(incoming) and boss.health == hp, "Repeated incoming receipt cannot repeat damage or phase entry")
	step(boss, 1.79)
	check(boss.state == &"phase_transition" and boss.get_danger_zones().is_empty(), "Phase transition cannot start another warning early")
	step(boss, 20.0)
	check(boss.state == &"approach" and not boss.request_attack(&"conductor_sequential_cross"), "Huge transition step cannot skip a warning or restore the phase-one-only cross")
	step(boss, 0.01)
	check(boss.attack_name == &"conductor_alternating_lanes" and finish_crystal_sequence(), "Phase-two automatic cursor restarts with its complete first sequence")
	step(boss, 20.0)
	step(boss, 0.01)
	if not check(boss.attack_name == &"conductor_refracted_cross" and boss.state == &"windup", "Automatic phase-two cursor actually selects the stronger Refracted cross"): return
	commit(boss)
	step(boss, 20.0)
	step(boss, 20.0)
	var zones: Array[Dictionary] = boss.get_danger_zones()
	check(zones.size() == 2 and valid_crystal_zones(zones, 1) and is_equal_approx(float(boss.snapshot().remaining), 2.2),
		"Refracted second stage displays two lanes with its complete 2.2-second warning")
	if zones.size() == 2:
		check(is_equal_approx(flat_distance(zones[0].position, zones[1].position), 3.6) \
			and flat_distance(zones[0].position, zones[1].position) - float(zones[0].radius) * 2.0 >= 2.0,
			"Refracted lanes preserve the authored 3.6-metre spacing and two-metre clear opening")
	check(finish_crystal_sequence() and not boss.has_pending_attack(), "Stronger complete sequence retires normally without an extra stage")
